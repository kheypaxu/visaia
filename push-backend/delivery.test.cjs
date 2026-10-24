const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require('../../visaia-dashboard/node_modules/typescript');

function fixture() {
  const records = new Map();
  const sent = [];
  const stamp = ms => ({ toMillis: () => ms });
  const FieldValue = {
    serverTimestamp: () => stamp(Date.now()),
    delete: () => ({ operation: 'delete' }),
    arrayUnion: value => ({ operation: 'union', value }),
  };
  const snapshot = ref => ({ ref, id: ref.id, exists: records.has(ref.path), data: () => records.get(ref.path) });
  function ref(key) {
    return {
      path: key, id: key.split('/').at(-1),
      get: async () => snapshot(ref(key)),
      collection: name => collection(`${key}/${name}`),
      update: async data => {
        const current = { ...records.get(key) };
        for (const [field, value] of Object.entries(data)) {
          if (value?.operation === 'delete') delete current[field];
          else if (value?.operation === 'union') current[field] = [...new Set([...(current[field] ?? []), value.value])];
          else current[field] = value;
        }
        records.set(key, current);
      },
    };
  }
  function collection(key, predicate = () => true) {
    return {
      doc: id => ref(`${key}/${id}`),
      where: (field, op, value) => collection(key, item => predicate(item) &&
        (op === 'array-contains' ? item[field]?.includes(value) : item[field] === value)),
      get: async () => ({ docs: [...records.entries()].filter(([p, item]) =>
        p.startsWith(`${key}/`) && !p.slice(key.length + 1).includes('/') && predicate(item))
        .map(([p]) => snapshot(ref(p))) }),
    };
  }
  const db = {
    collection,
    runTransaction: async fn => fn({
      get: async target => target.get(),
      set: (target, data) => records.set(target.path, data),
      create: (target, data) => records.set(target.path, data),
      delete: target => records.delete(target.path),
      update: (target, data) => target.update(data),
    }),
  };
  const cache = {};
  const load = file => {
    if (cache[file]) return cache[file];
    const output = ts.transpileModule(fs.readFileSync(path.join(__dirname, file), 'utf8'), {
      compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
    }).outputText;
    const module = { exports: {} };
    const mockRequire = name => {
      if (name === '@/src/config/firebaseAdmin') return { getFirebaseAdmin: () => ({
        app: {}, db, messaging: { send: async payload => { sent.push(payload); return 'message-id'; } },
      }) };
      if (name === 'firebase-admin/auth') return { getAuth: () => ({
        verifyIdToken: async token => { if (!token.startsWith('valid:')) throw Error('bad token'); return { uid: token.slice(6) }; },
      }) };
      if (name === 'firebase-admin/firestore') return { FieldValue, Timestamp: { fromMillis: stamp } };
      if (name === '@/src/notifications/push') return load('src/push.ts');
      if (name === './policy') return require('./src/policy.ts');
      return require(name);
    };
    vm.runInThisContext(`(function(require,module,exports){${output}\n})`, { filename: file })(mockRequire, module, module.exports);
    cache[file] = module.exports;
    return module.exports;
  };
  const device = load('app/api/notifications/device/route.ts');
  const push = load('src/push.ts');
  function request(uid, body = {}) {
    return new Request('https://test.invalid/api/notifications/device', {
      method: 'POST', headers: uid ? { Authorization: `Bearer valid:${uid}`, 'Content-Type': 'application/json' } : {},
      body: JSON.stringify(body),
    });
  }
  function event(farmerId = 'farmer-a') {
    records.set('pushEvents/approval', {
      farmerId, type: 'account_approved', title: 'Approved', body: 'Approved', status: 'pending', delivered: [],
      expiresAt: stamp(Date.now() + 86400000),
    });
  }
  return { records, sent, stamp, request, device, push, event };
}

test('device API rejects unauthenticated registration', async () => {
  const f = fixture();
  assert.equal((await f.device.POST(f.request(null, { installationId: 'a'.repeat(64), token: 't'.repeat(30) }))).status, 401);
  assert.equal(f.records.size, 0);
});
test('account switching retains authenticated accounts and logout removes only its own membership', async () => {
  const f = fixture();
  const first = { installationId: 'a'.repeat(64), token: 'first-token'.repeat(4), uid: 'victim' };
  const second = { installationId: 'b'.repeat(64), token: 'second-token'.repeat(4) };
  assert.equal((await f.device.POST(f.request('farmer-a', first))).status, 200);
  await f.device.POST(f.request('farmer-a', second));
  assert.deepEqual(f.records.get(`pushDevices/${first.installationId}`).uids, ['farmer-a']);
  await f.device.POST(f.request('farmer-b', first));
  assert.deepEqual([...f.records.get(`pushDevices/${first.installationId}`).uids].sort(), ['farmer-a', 'farmer-b']);
  await f.device.DELETE(f.request('farmer-a', first));
  assert.deepEqual(f.records.get(`pushDevices/${first.installationId}`).uids, ['farmer-b']);
  assert.deepEqual(f.records.get(`pushDevices/${second.installationId}`).uids, ['farmer-a']);
});
test('delivery reaches every current recipient device, excludes another farmer, and retries do not repeat', async () => {
  const f = fixture();
  for (const [id, uid] of [['a', 'farmer-a'], ['b', 'farmer-a'], ['c', 'farmer-b']]) {
    f.records.set(`pushDevices/${id}`, { uids: [uid], token: id, updatedAt: f.stamp(Date.now()) });
  }
  f.event();
  await f.push.deliver('approval');
  assert.deepEqual(f.sent.map(item => item.token).sort(), ['a', 'b']);
  assert.equal(f.sent[0].notification, undefined); // Data-only: recipient checked before display.
  await f.push.deliver('approval');
  assert.equal(f.sent.length, 2);
});
test('a shared phone receives events for both saved accounts and token refresh keeps memberships', async () => {
  const f = fixture();
  const installationId = 'd'.repeat(64);
  await f.device.POST(f.request('farmer-a', { installationId, token: 'old-token'.repeat(4) }));
  await f.device.POST(f.request('farmer-b', { installationId, token: 'new-token'.repeat(4) }));
  f.records.set('farmers/farmer-a', { name: 'Farmer A', email: 'a@example.test' });
  f.records.set('farmers/farmer-b', { name: 'Farmer B', email: 'b@example.test' });
  f.event('farmer-a');
  await f.push.deliver('approval');
  f.event('farmer-b');
  await f.push.deliver('approval');
  assert.equal(f.sent.length, 2);
  assert.deepEqual(f.sent.map(message => message.data.accountName), ['Farmer A', 'Farmer B']);
  assert.ok(f.sent.every(message => message.token === 'new-token'.repeat(4)));
});
test('legacy single-account registration migrates without losing its original account', async () => {
  const f = fixture();
  const installationId = 'e'.repeat(64);
  f.records.set(`pushDevices/${installationId}`, { uid: 'farmer-a', token: 'old', updatedAt: f.stamp(Date.now()) });
  await f.device.POST(f.request('farmer-b', { installationId, token: 'new-token'.repeat(4) }));
  assert.deepEqual(f.records.get(`pushDevices/${installationId}`).uids, ['farmer-a', 'farmer-b']);
});
test('expired events do not reach any device', async () => {
  const f = fixture();
  f.event();
  f.records.get('pushEvents/approval').expiresAt = f.stamp(Date.now() - 1);
  await f.push.deliver('approval');
  assert.equal(f.sent.length, 0);
  assert.equal(f.records.get('pushEvents/approval').status, 'expired');
});
test('a reminder queued before a log was completed is cancelled on retry', async () => {
  const f = fixture();
  const now = new Date();
  const policy = require('./src/policy.ts');
  const cycle = { plantingDate: new Date(now.getTime() - 3 * 86400000), harvestDate: new Date(now.getTime() + 60 * 86400000) };
  f.records.set('users/farmer-a/cycles/cycle-a', cycle);
  const period = policy.reminderPeriod(cycle, now);
  f.records.set(`users/farmer-a/cycles/cycle-a/dailyLogs/${period.dayId}/activities/log`, { date: now, status: 'completed' });
  f.event();
  Object.assign(f.records.get('pushEvents/approval'), { type: 'daily_log_reminder', cycleId: 'cycle-a' });
  await f.push.deliver('approval');
  assert.equal(f.sent.length, 0);
  assert.equal(f.records.get('pushEvents/approval').status, 'cancelled');
});
