// src/config/firebaseAdmin.ts
import { getApps, initializeApp, cert, App } from 'firebase-admin/app';
import { getFirestore, Firestore } from 'firebase-admin/firestore';
import { getMessaging, Messaging } from 'firebase-admin/messaging';
import path from 'path';
import fs from 'fs';

let adminApp: App | null = null;
let adminDb: Firestore | null = null;
let adminMessaging: Messaging | null = null;

export function getFirebaseAdmin(): {
  app: App;
  db: Firestore;
  messaging: Messaging;
} {
  if (!adminApp) {
    if (getApps().length > 0) {
      adminApp = getApps()[0];
    } else {
      const saPath = path.join(process.cwd(), 'src', 'scripts', 'service-account.json');
      const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
      if (serviceAccountJson) {
        const serviceAccount = JSON.parse(serviceAccountJson);
        adminApp = initializeApp({
          credential: cert(serviceAccount),
          projectId: serviceAccount.project_id || 'visaia',
        });
      } else if (fs.existsSync(saPath)) {
        const sa = JSON.parse(fs.readFileSync(saPath, 'utf8'));
        adminApp = initializeApp({
          credential: cert(sa),
          projectId: sa.project_id || 'visaia',
        });
      } else {
        adminApp = initializeApp({
          projectId: 'visaia',
        });
      }
    }
    adminDb = getFirestore(adminApp);
    adminMessaging = getMessaging(adminApp);
  }

  return {
    app: adminApp,
    db: adminDb!,
    messaging: adminMessaging!,
  };
}
