import { FieldValue } from 'firebase-admin/firestore';
import { getFirebaseAdmin } from '@/src/config/firebaseAdmin';
import { authenticatedUser, errorResponse } from '@/src/notifications/push';

export const runtime = 'nodejs';
async function change(request: Request, remove: boolean) {
  try {
    const user = await authenticatedUser(request);
    const body = await request.json();
    if (!/^[a-f0-9]{64}$/.test(body.installationId) ||
        (!remove && (typeof body.token !== 'string' || body.token.length < 20 || body.token.length > 4096))) {
      throw new Error('INVALID_REQUEST');
    }
    const { db } = getFirebaseAdmin();
    const ref = db.collection('pushDevices').doc(body.installationId);
    await db.runTransaction(async tx => {
      const snapshot = await tx.get(ref);
      if (remove) {
        if (snapshot.data()?.uid === user.uid) tx.delete(ref);
      } else {
        // One installation belongs to one account; other devices stay registered.
        tx.set(ref, { uid: user.uid, token: body.token, updatedAt: FieldValue.serverTimestamp() });
      }
    });
    return Response.json({ success: true });
  } catch (error) { return errorResponse(error); }
}
export const POST = (request: Request) => change(request, false);
export const DELETE = (request: Request) => change(request, true);
