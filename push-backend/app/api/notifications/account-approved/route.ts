import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { getFirebaseAdmin } from '@/src/config/firebaseAdmin';
import { dashboardRole } from '@/src/config/routeAccess';
import { authenticatedUser, errorResponse, eventId, deliver } from '@/src/notifications/push';

export const runtime = 'nodejs';
export async function POST(request: Request) {
  try {
    const actor = await authenticatedUser(request);
    const { farmerId } = await request.json();
    if (typeof farmerId !== 'string' || !farmerId || farmerId.includes('/') || farmerId.length > 128) {
      throw new Error('INVALID_REQUEST');
    }
    const { db } = getFirebaseAdmin();
    const account = (await db.collection('users').doc(actor.uid).get()).data();
    if (dashboardRole(account) !== 'mao_admin') throw new Error('FORBIDDEN');
    const farmerRef = db.collection('farmers').doc(farmerId);
    const id = eventId(`account-approved:${farmerId}`);
    const eventRef = db.collection('pushEvents').doc(id);
    await db.runTransaction(async tx => {
      const farmer = await tx.get(farmerRef);
      const event = await tx.get(eventRef);
      if (!farmer.exists) throw new Error('INVALID_REQUEST');
      if (account?.municipality && farmer.data()?.municipality !== account.municipality) throw new Error('FORBIDDEN');
      if (farmer.data()?.status === 'verified') return;
      tx.update(farmerRef, { status: 'verified', verifiedAt: FieldValue.serverTimestamp(), verifiedBy: actor.uid });
      if (!event.exists) tx.create(eventRef, {
        farmerId, type: 'account_approved', title: 'Your VISAIA account is verified',
        body: 'MAO has approved your account. You can now sign in to VISAIA.',
        createdAt: FieldValue.serverTimestamp(), expiresAt: Timestamp.fromMillis(Date.now() + 7 * 86400000),
        status: 'pending', delivered: [],
      });
      const alertRef = db.collection('alerts').doc(id);
      tx.set(alertRef, { farmerId, type: 'account_approved', title: 'Account verified',
        message: 'MAO has approved your VISAIA account.', status: 'unread', createdAt: FieldValue.serverTimestamp() });
    });
    // Approval is already committed; a delivery failure must not misreport it.
    let pushPending = false;
    try { await deliver(id); } catch { pushPending = true; }
    return Response.json({ success: true, pushPending });
  } catch (error) { return errorResponse(error); }
}
