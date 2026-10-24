"""Stage minimal edits to the sibling dashboard without writing outside VISAIA."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
dashboard = root.parent / 'visaia-dashboard'
stage = root / 'push-backend'
manifest = []

def edit(relative, replacements):
    original = (dashboard / relative).read_bytes()
    text = original.decode('utf-8')
    for before, after in replacements:
        if text.count(before) == 0 and text.count(after) == 1:
            continue  # Already installed; preserve the current dashboard edits.
        if text.count(before) != 1:
            raise RuntimeError(f'Expected one matching edit in {relative}')
        text = text.replace(before, after)
    target = stage / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(text.encode('utf-8'))
    manifest.append({'path': relative, 'before': hashlib.sha256(original).hexdigest()})

edit('app/(dashboard)/account-verification/[id]/page.tsx', [
    ("import { db } from '@/src/config/firebase';", "import { auth, db } from '@/src/config/firebase';"),
    ("      await updateDoc(doc(db, 'farmers', id), { status: 'verified' });", """      const token = await auth.currentUser?.getIdToken();
      if (!token) throw new Error('Please sign in again before verifying a farmer.');
      const response = await fetch('/api/notifications/account-approved', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ farmerId: id }),
      });
      if (!response.ok) throw new Error('Unable to verify farmer. Please try again.');"""),
])
edit('src/config/firebaseAdmin.ts', [
    ("      if (fs.existsSync(saPath)) {", """      const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
      if (serviceAccountJson) {
        const serviceAccount = JSON.parse(serviceAccountJson);
        adminApp = initializeApp({
          credential: cert(serviceAccount),
          projectId: serviceAccount.project_id || 'visaia',
        });
      } else if (fs.existsSync(saPath)) {"""),
])

for source, destination in [
    ('src/policy.ts', 'src/notifications/policy.ts'),
    ('src/push.ts', 'src/notifications/push.ts'),
    ('app/api/notifications/device/route.ts', 'app/api/notifications/device/route.ts'),
    ('app/api/notifications/account-approved/route.ts', 'app/api/notifications/account-approved/route.ts'),
    ('app/api/cron/farm-reminders/route.ts', 'app/api/cron/farm-reminders/route.ts'),
    ('vercel.json', 'vercel.json'),
]:
    target = dashboard / destination
    manifest.append({'path': destination, 'source': source,
                     'before': hashlib.sha256(target.read_bytes()).hexdigest() if target.exists() else None})
(stage / 'install-manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print(f'Staged {len(manifest)} dashboard files; originals fingerprinted.')
