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
      const existing = snapshot.data();
      const uids: string[] = Array.isArray(existing?.uids) ? existing.uids :
        typeof existing?.uid === 'string' ? [existing.uid] : [];
      if (remove) {
        const remaining = uids.filter(uid => uid !== user.uid);
        if (remaining.length === 0) tx.delete(ref);
        else if (remaining.length !== uids.length) tx.set(ref, {
          uids: remaining, token: existing!.token, updatedAt: existing!.updatedAt,
        });
      } else {
        // Only the authenticated account can be added. Signing into another
        // account retains this installation's other authenticated memberships.
        tx.set(ref, { uids: [...new Set([...uids, user.uid])], token: body.token, updatedAt: FieldValue.serverTimestamp() });
      }
    });
    return Response.json({ success: true });
  } catch (error) { return errorResponse(error); }
}
export const POST = (request: Request) => change(request, false);
export const DELETE = (request: Request) => change(request, true);
