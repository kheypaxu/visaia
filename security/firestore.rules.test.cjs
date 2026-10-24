const { before, beforeEach, after, test } = require('node:test');
const { readFileSync } = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require('../../visaia-dashboard/node_modules/typescript');
const { initializeApp: initializeAdmin, deleteApp: deleteAdmin, cert } = require('firebase-admin/app');
const { generateKeyPairSync } = require('node:crypto');
const { getFirestore: adminFirestore } = require('firebase-admin/firestore');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const {
  doc, collection, collectionGroup, getDoc, getDocs, setDoc, updateDoc, deleteDoc,
  query, where, writeBatch, Timestamp, setLogLevel,
} = require('firebase/firestore');
setLogLevel('silent');
let env;
let regionalAdmin;
const now = Timestamp.fromDate(new Date('2026-10-24T00:00:00Z'));
const db = uid => uid ? env.authenticatedContext(uid, { email: `${uid}@example.test`, email_verified: true }).firestore()
  : env.unauthenticatedContext().firestore();
const profile = uid => ({ uid, name: uid, role: 'farmer', userType: 'app' });
const report = (uid, extra = {}) => ({ farmerId: uid, userId: uid, farmId: `farm-${uid}`, cycleId: 'cycle-a', status: 'pending', ...extra });
const resolution = { status: 'resolved', resolvedAt: now, resolvedBy: 'farmer-a', resolvedByUserName: 'Farmer A',
  resolutionReason: 'Treatment completed', resolutionExplanation: 'No active infestation', reportCategory: 'regular' };

before(async () => {
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8085').split(':');
  env = await initializeTestEnvironment({ projectId: 'demo-visaia-rules', firestore: {
    host, port: Number(port), rules: readFileSync(path.join(__dirname, '../firestore.rules'), 'utf8'),
  } });
});
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const admin = context.firestore();
    const records = {
      'users/farmer-a': profile('farmer-a'), 'users/farmer-b': profile('farmer-b'),
      'users/pending': profile('pending'),
      'users/mao': { role: 'mao_admin', userType: 'dashboard' },
      'users/rcpc': { role: 'rcpc_admin', userType: 'dashboard' },
      'farmers/farmer-a': { uid: 'farmer-a', status: 'verified', name: 'Farmer A', farmerIdImage: 'private-a' },
      'farmers/farmer-b': { uid: 'farmer-b', status: 'verified', name: 'Farmer B', farmerIdImage: 'private-b' },
      'farmers/pending': { uid: 'pending', status: 'pending', name: 'Pending' },
      'users/farmer-a/farms/farm-farmer-a': { name: 'Farm A' },
      'users/farmer-b/farms/farm-farmer-b': { name: 'Farm B' },
      'users/farmer-a/fields/field-a': { name: 'Field A' },
      'users/farmer-a/cycles/cycle-a': { plantingDate: now },
      'users/farmer-a/cycles/cycle-a/weeks/week_1': { completedStations: 1 },
      'users/farmer-a/cycles/cycle-a/dailyLogs/day_01/activities/log-a': { status: 'completed' },
      'users/farmer-a/notifications/n-a': { read: false, title: 'Official' },
      'reports/r-a': report('farmer-a'), 'reports/r-b': report('farmer-b'),
      'reports/legacy-a': { userId: 'farmer-a', status: 'pending' },
      'reports/validated-a': report('farmer-a', { status: 'validated', validatedBy: 'RCPC' }),
      'clustered_reports/c-a': report('farmer-a'),
      'plant_damage_reports/p-a': report('farmer-a'),
      'validations/v-a': { reportId: 'validated-a', farmerId: 'farmer-a', expertDiagnosis: 'confirmed' },
      'validations/v-b': { reportId: 'r-b', farmerId: 'farmer-b' },
      'alerts/a-a': { farmerId: 'farmer-a', status: 'unread', title: 'Official advice' },
      'alerts/a-b': { farmerId: 'farmer-b', status: 'unread' },
      'pushDevices/device-a': { uids: ['farmer-a'], token: 'private-token' },
      'pushEvents/event-a': { farmerId: 'farmer-a' },
      'app_config/release': { version: '2.0.2' }, 'dispatches/d-a': { title: 'Advisory' },
    };
    const batch = writeBatch(admin);
    for (const [key, value] of Object.entries(records)) batch.set(doc(admin, key), value);
    await batch.commit();
  });
});
after(async () => { await env?.cleanup(); if (regionalAdmin) await deleteAdmin(regionalAdmin); });

test('release configuration is readable before login; private data is not', async () => {
  await assertSucceeds(getDoc(doc(db(), 'app_config/release')));
  await assertFails(getDoc(doc(db(), 'farmers/farmer-a')));
  await assertFails(getDoc(doc(db(), 'reports/r-a')));
});
test('new farmer can submit registration and a minimal users document', async () => {
  const user = db('new-farmer');
  await assertSucceeds(setDoc(doc(user, 'farmers/new-farmer'), {
    uid: 'new-farmer', name: 'New Farmer', email: 'new-farmer@example.test', status: 'pending', farmerIdImage: 'private',
  }));
  await assertSucceeds(setDoc(doc(user, 'users/new-farmer'), { name: 'New Farmer', municipality: 'Test town', email: 'new-farmer@example.test' }));
});
test('farmer cannot register as already verified or create someone else', async () => {
  await assertFails(setDoc(doc(db('new'), 'farmers/new'), { uid: 'new', status: 'verified' }));
  await assertFails(setDoc(doc(db('new'), 'farmers/victim'), { uid: 'victim', status: 'pending' }));
});
test('an initial profile photo can be merged into a later pending registration', async () => {
  const user = db('new-farmer');
  await assertSucceeds(setDoc(doc(user, 'farmers/new-farmer'), { profileImage: 'own-photo' }));
  await assertSucceeds(setDoc(doc(user, 'farmers/new-farmer'), { uid: 'new-farmer', status: 'pending', name: 'New Farmer' }, { merge: true }));
  await assertFails(updateDoc(doc(user, 'farmers/new-farmer'), { uid: 'victim' }));
});
test('pending farmer can read their application and edit profile, but not self-verify', async () => {
  await assertSucceeds(getDoc(doc(db('pending'), 'farmers/pending')));
  await assertSucceeds(updateDoc(doc(db('pending'), 'farmers/pending'), { farmerIdImageBack: 'private-back', name: 'Updated' }));
  await assertFails(updateDoc(doc(db('pending'), 'farmers/pending'), { status: 'verified' }));
  await assertFails(updateDoc(doc(db('pending'), 'farmers/pending'), { verifiedBy: 'mao' }));
});
test('farmers cannot read or modify another farmer or list private profiles', async () => {
  await assertFails(getDoc(doc(db('farmer-a'), 'farmers/farmer-b')));
  await assertFails(updateDoc(doc(db('farmer-a'), 'farmers/farmer-b'), { name: 'Forged' }));
  await assertFails(getDocs(collection(db('farmer-a'), 'farmers')));
  await assertFails(getDocs(collection(db('farmer-a'), 'users')));
});
test('a farmer may edit their display profile but cannot promote themselves', async () => {
  await assertSucceeds(updateDoc(doc(db('farmer-a'), 'users/farmer-a'), { name: 'Updated', hasFarm: true }));
  await assertFails(updateDoc(doc(db('farmer-a'), 'users/farmer-a'), { role: 'mao_admin', userType: 'dashboard' }));
  await assertFails(setDoc(doc(db('attacker'), 'users/attacker'), { role: 'rcpc_admin', userType: 'dashboard' }));
  await assertFails(updateDoc(doc(db('farmer-a'), 'users/mao'), { role: 'farmer' }));
});
test('even dashboard staff cannot provision roles using the client SDK', async () => {
  await assertSucceeds(updateDoc(doc(db('mao'), 'users/mao'), { avatar: 'new-avatar', email: 'mao@example.test' }));
  await assertFails(updateDoc(doc(db('mao'), 'users/mao'), { role: 'rcpc_admin' }));
  await assertFails(setDoc(doc(db('mao'), 'users/new-admin'), { role: 'mao_admin' }));
});
test('MAO and RCPC can read dashboard datasets', async () => {
  for (const uid of ['mao', 'rcpc']) {
    for (const name of ['users', 'farmers', 'reports', 'clustered_reports', 'validations', 'alerts', 'dispatches']) {
      await assertSucceeds(getDocs(collection(db(uid), name)));
    }
    await assertSucceeds(getDocs(collectionGroup(db(uid), 'farms')));
    await assertSucceeds(getDocs(collection(db(uid), 'users/farmer-a/cycles')));
  }
});
test('MAO can reject or unverify; approval is only through the server route', async () => {
  await assertSucceeds(updateDoc(doc(db('mao'), 'farmers/pending'), { status: 'rejected', rejectionReason: 'Missing ID' }));
  await assertSucceeds(updateDoc(doc(db('mao'), 'farmers/farmer-a'), { status: 'pending' }));
  await assertFails(updateDoc(doc(db('mao'), 'farmers/pending'), { status: 'verified' }));
  await assertFails(updateDoc(doc(db('rcpc'), 'farmers/pending'), { status: 'verified' }));
});
test('verified owner can manage farms, fields, cycles, logs, images, traps and weeks', async () => {
  const user = db('farmer-a');
  for (const key of ['farms/new', 'fields/new', 'cycles/new', 'cycles/cycle-a/weeks/week_2',
    'cycles/cycle-a/dailyLogs/day_02/activities/new', 'cycles/cycle-a/images/new',
    'cycles/cycle-a/trapInspections/new', 'cycles/cycle-a/chemicalApplications/new', 'pests/new']) {
    await assertSucceeds(setDoc(doc(user, `users/farmer-a/${key}`), { name: 'Own record' }));
  }
});
test('pending owner cannot use protected farm workflows', async () => {
  await assertFails(setDoc(doc(db('pending'), 'users/pending/farms/new'), { name: 'Farm' }));
  await assertFails(setDoc(doc(db('pending'), 'reports/new'), report('pending')));
});
test('other farmers cannot read or overwrite nested farm data', async () => {
  await assertFails(getDoc(doc(db('farmer-b'), 'users/farmer-a/fields/field-a')));
  await assertFails(setDoc(doc(db('farmer-b'), 'users/farmer-a/cycles/cycle-a/dailyLogs/day_01/activities/new'), { status: 'completed' }));
  await assertFails(getDocs(collectionGroup(db('farmer-a'), 'farms')));
});
test('farmers submit regular, clustered and plant-damage reports for themselves', async () => {
  for (const name of ['reports', 'clustered_reports', 'plant_damage_reports']) {
    await assertSucceeds(setDoc(doc(db('farmer-a'), name, 'new'), report('farmer-a')));
    await assertFails(setDoc(doc(db('farmer-a'), name, 'forged'), report('farmer-b')));
    await assertFails(setDoc(doc(db('farmer-a'), name, 'mixed-owner'), report('farmer-a', { userId: 'farmer-b' })));
    await assertFails(setDoc(doc(db('farmer-a'), name, 'self-validated'), report('farmer-a', { status: 'validated' })));
  }
});
test('the scouting three-document batch remains supported', async () => {
  const user = db('farmer-a');
  const batch = writeBatch(user);
  batch.set(doc(user, 'clustered_reports/scouting-new'), report('farmer-a', { damageAssessment: { validationStatus: 'pending' } }));
  batch.set(doc(user, 'plant_damage_reports/scouting-new'), report('farmer-a'));
  batch.set(doc(user, 'users/farmer-a/cycles/cycle-a/weeks/week_1'), { clusteredReportId: 'scouting-new' }, { merge: true });
  await assertSucceeds(batch.commit());
});
test('offline report analysis can advance from queued to pending without forging expert fields', async () => {
  const user = db('farmer-a');
  await assertSucceeds(setDoc(doc(user, 'reports/offline'), report('farmer-a', { status: 'pending_offline_sync' })));
  await assertSucceeds(updateDoc(doc(user, 'reports/offline'), { status: 'pending', detection: 'Fall Armyworm', syncedAt: now }));
  await assertFails(updateDoc(doc(user, 'reports/offline'), { validatedBy: 'RCPC', status: 'pending' }));
  await assertFails(updateDoc(doc(user, 'reports/offline'), { farmerId: 'farmer-b' }));
});
test('owner-filtered report queries and the legacy userId schema work', async () => {
  const user = db('farmer-a');
  await assertSucceeds(getDocs(query(collection(user, 'reports'), where('farmerId', '==', 'farmer-a'))));
  await assertSucceeds(getDocs(query(collection(user, 'reports'), where('userId', '==', 'farmer-a'))));
  await assertSucceeds(getDoc(doc(user, 'reports/legacy-a')));
  await assertFails(getDoc(doc(user, 'reports/r-b')));
});
test('unscoped and farm-ID-only queries are rejected, even when results happen to be owned', async () => {
  const user = db('farmer-a');
  await assertFails(getDocs(collection(user, 'reports')));
  await assertFails(getDocs(query(collection(user, 'reports'), where('farmId', '==', 'farm-farmer-a'))));
  await assertSucceeds(getDocs(query(collection(user, 'reports'), where('farmId', '==', 'farm-farmer-a'), where('farmerId', '==', 'farmer-a'))));
});
test('RCPC validates and archives reports; MAO and farmers cannot validate them', async () => {
  await assertSucceeds(updateDoc(doc(db('rcpc'), 'reports/r-a'), { status: 'validated', validatedBy: 'RCPC', validatedAt: now }));
  await assertSucceeds(updateDoc(doc(db('rcpc'), 'reports/r-a'), { isArchived: true, archivedAt: now }));
  await assertFails(updateDoc(doc(db('mao'), 'reports/r-b'), { status: 'validated' }));
  await assertFails(updateDoc(doc(db('farmer-b'), 'reports/r-b'), { status: 'validated' }));
  await assertFails(updateDoc(doc(db('rcpc'), 'reports/r-a'), { farmerId: 'farmer-b' }));
});
test('owner may resolve a validated report but cannot alter expert findings', async () => {
  const user = db('farmer-a');
  await assertFails(updateDoc(doc(user, 'reports/validated-a'), { ...resolution, validatedBy: 'Forged' }));
  await assertFails(updateDoc(doc(user, 'reports/r-a'), resolution));
  await assertFails(updateDoc(doc(db('farmer-b'), 'reports/validated-a'), { ...resolution, resolvedBy: 'farmer-b' }));
  await assertSucceeds(updateDoc(doc(user, 'reports/validated-a'), resolution));
});
test('resolution query and report+validation batch work for the owner', async () => {
  const user = db('farmer-a');
  await assertSucceeds(getDocs(query(collection(user, 'validations'), where('reportId', '==', 'validated-a'))));
  const batch = writeBatch(user);
  batch.update(doc(user, 'reports/validated-a'), resolution);
  batch.update(doc(user, 'validations/v-a'), resolution);
  await assertSucceeds(batch.commit());
});
test('only RCPC creates expert validation records', async () => {
  await assertSucceeds(setDoc(doc(db('rcpc'), 'validations/new'), { reportId: 'r-a', farmerId: 'farmer-a', expertDiagnosis: 'confirmed' }));
  await assertFails(setDoc(doc(db('farmer-a'), 'validations/forged'), { reportId: 'r-a', farmerId: 'farmer-a' }));
  await assertFails(setDoc(doc(db('mao'), 'validations/forged'), { reportId: 'r-a' }));
});
test('a validation cannot be resolved before its underlying report is validated', async () => {
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'validations/premature'), { reportId: 'r-a', farmerId: 'farmer-a' });
  });
  await assertFails(updateDoc(doc(db('farmer-a'), 'validations/premature'), resolution));
});
test('farmer reads only their alert feed and may only change read status', async () => {
  const user = db('farmer-a');
  await assertSucceeds(getDocs(query(collection(user, 'alerts'), where('farmerId', '==', 'farmer-a'))));
  await assertSucceeds(updateDoc(doc(user, 'alerts/a-a'), { status: 'read' }));
  await assertFails(updateDoc(doc(user, 'alerts/a-a'), { title: 'Forged content' }));
  await assertFails(getDoc(doc(user, 'alerts/a-b')));
});
test('scheduled-activity alert and log can be created in one owner batch', async () => {
  const user = db('farmer-a');
  const batch = writeBatch(user);
  batch.set(doc(user, 'users/farmer-a/cycles/cycle-a/dailyLogs/day_01/activities/scheduled'), { status: 'scheduled' });
  batch.set(doc(user, 'alerts/scheduled-a'), { farmerId: 'farmer-a', alertType: 'scheduled_activity', source: 'daily_log', status: 'unread',
    title: 'Upcoming activity', message: 'Do this tomorrow', activityId: 'scheduled', cycleId: 'cycle-a', scheduledFor: now });
  await assertSucceeds(batch.commit());
  await assertFails(setDoc(doc(user, 'alerts/forged'), { farmerId: 'farmer-a', type: 'account_approved', status: 'unread' }));
});
test('a farmer cannot forge approval using extra fields on a scheduled activity', async () => {
  await assertFails(setDoc(doc(db('farmer-a'), 'alerts/spoof'), { farmerId: 'farmer-a', alertType: 'scheduled_activity',
    source: 'daily_log', status: 'unread', type: 'validation_confirmed', reportId: 'r-a' }));
});
test('notifications allow recipient read receipts but not content forgery', async () => {
  const user = db('farmer-a');
  await assertSucceeds(updateDoc(doc(user, 'users/farmer-a/notifications/n-a'), { read: true }));
  await assertFails(updateDoc(doc(user, 'users/farmer-a/notifications/n-a'), { title: 'Forged' }));
  await assertFails(setDoc(doc(user, 'users/farmer-a/notifications/forged'), { title: 'Fake approval' }));
  await assertSucceeds(setDoc(doc(db('mao'), 'users/farmer-a/notifications/from-mao'), { title: 'Official', read: false }));
});
test('push records, regional caches and budget counters are server-only for every client role', async () => {
  for (const uid of [null, 'farmer-a', 'mao', 'rcpc']) {
    for (const name of ['pushDevices', 'pushEvents', 'regionalRiskCache', 'regionalFeedBudgets']) {
      await assertFails(getDocs(collection(db(uid), name)));
      await assertFails(setDoc(doc(db(uid), name, 'forged'), { token: 'fake' }));
    }
  }
});
test('unknown collections, client release updates, and role deletion fail closed', async () => {
  await assertFails(setDoc(doc(db('farmer-a'), 'unexpected/private'), { value: 1 }));
  await assertFails(updateDoc(doc(db('mao'), 'app_config/release'), { version: '999' }));
  await assertFails(deleteDoc(doc(db('farmer-a'), 'users/farmer-a')));
});
test('regional backend uses real emulator Admin SDK queries while clients cannot read its cache', async () => {
  const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
  if (!emulatorHost || !/^127\.0\.0\.1:\d+$/.test(emulatorHost)) throw new Error('Local emulator required for Admin SDK test');
  if (!regionalAdmin) {
    // Ephemeral, emulator-only credentials: no real account/key is loaded.
    const { privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048,
      privateKeyEncoding: { type: 'pkcs8', format: 'pem' }, publicKeyEncoding: { type: 'spki', format: 'pem' } });
    regionalAdmin = initializeAdmin({ projectId: 'demo-visaia-rules',
      credential: cert({ projectId: 'demo-visaia-rules', clientEmail: 'test@demo-visaia-rules.iam.gserviceaccount.com', privateKey }),
    }, 'regional-rules-test');
  }
  const admin = adminFirestore(regionalAdmin);
  const cache = {};
  function load(file) {
    if (cache[file]) return cache[file];
    const code = ts.transpileModule(readFileSync(path.join(__dirname, '../../visaia-dashboard/src/regional', `${file}.ts`), 'utf8'), {
      compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
    }).outputText;
    const module = { exports: {} };
    const localRequire = name => name.startsWith('./') ? load(name.slice(2)) : require(name);
    vm.runInThisContext(`(function(require,module,exports){${code}\n})`)(localRequire, module, module.exports);
    cache[file] = module.exports;
    return module.exports;
  }
  await admin.doc('farmers/farmer-a').set({ municipality: 'Cabatuan', barangay: 'Acao', farmerIdImage: 'PRIVATE ID' }, { merge: true });
  await admin.doc('users/farmer-a/fields/field-a').set({ location: { lat: 10.8, lng: 122.4 }, name: 'PRIVATE FIELD' }, { merge: true });
  await admin.doc('reports/regional-validated').set(report('farmer-a', {
    status: 'validated', detection: 'Fall Armyworm', lifeStage: 'moth', fieldId: 'field-a', timestamp: now.toDate(),
    farmerName: 'PRIVATE FARMER', advisoryMessage: 'PRIVATE ADVICE',
  }));
  const secret = 'emulator-only-secret-'.repeat(3);
  const { regionalSnapshot } = load('feed');
  const policy = load('policy');
  const time = new Date();
  const snapshot = await regionalSnapshot(admin, secret, time);
  const publicData = policy.publicFeed(snapshot, policy.opaqueKey(secret, 'owner:farmer-b'));
  if (publicData.threats.length !== 1 || JSON.stringify(publicData).includes('PRIVATE')) throw new Error('Regional privacy projection failed');
  const cacheDocs = await admin.collection('regionalRiskCache').get();
  await assertFails(getDoc(doc(db('farmer-a'), 'regionalRiskCache', cacheDocs.docs[0].id)));
  await assertSucceeds(updateDoc(doc(db('farmer-a'), 'reports/regional-validated'), resolution));
  const refreshed = await regionalSnapshot(admin, secret, new Date(time.getTime() + 301000));
  if (refreshed.threats.length !== 0 || refreshed.assessment.length !== 0) throw new Error('Resolved report remained in regional feed');
});
