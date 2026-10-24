import { createHash } from 'node:crypto';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { getFirebaseAdmin } from '@/src/config/firebaseAdmin';
import { loggedToday, reminderPeriod, scoutingComplete } from './policy';

export function eventId(key: string) {
  return createHash('sha256').update(key).digest('hex');
}
export async function authenticatedUser(request: Request) {
  const bearer = request.headers.get('authorization');
  if (!bearer?.startsWith('Bearer ')) throw new Error('UNAUTHORIZED');
  try {
    return await getAuth(getFirebaseAdmin().app).verifyIdToken(bearer.slice(7), true);
  } catch { throw new Error('UNAUTHORIZED'); }
}
export function errorResponse(error: unknown) {
  const message = error instanceof Error ? error.message : 'Internal error';
  const status = message === 'UNAUTHORIZED' ? 401 : message === 'FORBIDDEN' ? 403 :
    message === 'INVALID_REQUEST' ? 400 : 500;
  if (status === 500) console.error('Push backend failed:', error);
  return Response.json({ error: status === 500 ? 'Notification service unavailable' : message }, { status });
}
export type PushEvent = {
  farmerId: string; type: string; title: string; body: string;
  cycleId?: string; expiresAt: Timestamp;
};
export async function enqueue(id: string, event: PushEvent) {
  const { db } = getFirebaseAdmin();
  const ref = db.collection('pushEvents').doc(id);
  await db.runTransaction(async tx => {
    if (!(await tx.get(ref)).exists) tx.create(ref, {
      ...event, status: 'pending', createdAt: FieldValue.serverTimestamp(), delivered: [],
    });
  });
  return ref;
}
export async function deliver(id: string) {
  const { db, messaging } = getFirebaseAdmin();
  const ref = db.collection('pushEvents').doc(id);
  const event = await db.runTransaction(async tx => {
    const snapshot = await tx.get(ref);
    const data = snapshot.data();
    if (!data || ['sent', 'expired', 'cancelled'].includes(data.status)) return null;
    if (data.leaseUntil?.toMillis() > Date.now()) return null;
    if (data.expiresAt.toMillis() <= Date.now()) {
      tx.update(ref, { status: 'expired' });
      return null;
    }
    tx.update(ref, { leaseUntil: Timestamp.fromMillis(Date.now() + 90000) });
    return data;
  });
  if (!event) return;
  try {
    // Retry delivery must re-check completion; a farmer may have logged since
    // the cron first enqueued the event, including from another device.
    if (event.type === 'daily_log_reminder' || event.type === 'scouting_reminder') {
      const cycleRef = db.collection('users').doc(event.farmerId).collection('cycles').doc(event.cycleId);
      const cycle = await cycleRef.get();
      const now = new Date();
      const period = reminderPeriod(cycle.data() ?? {}, now);
      let complete = !period;
      if (period && event.type === 'daily_log_reminder') {
        const activities = await cycleRef.collection('dailyLogs').doc(period.dayId).collection('activities').get();
        complete = activities.docs.some(activity => loggedToday(activity.data(), now));
      } else if (period) {
        complete = scoutingComplete((await cycleRef.collection('weeks').doc(period.weekId).get()).data() ?? {});
      }
      if (complete) {
        await ref.update({ status: 'cancelled', leaseUntil: FieldValue.delete() });
        return;
      }
    }
    const memberships = await db.collection('pushDevices').where('uids', 'array-contains', event.farmerId).get();
    // Compatibility for devices registered before multi-account support.
    const legacy = await db.collection('pushDevices').where('uid', '==', event.farmerId).get();
    const devices = new Map([...memberships.docs, ...legacy.docs].map(device => [device.id, device]));
    const farmer = (await db.collection('farmers').doc(event.farmerId).get()).data();
    const accountName = String(farmer?.name || farmer?.fullName || farmer?.email || 'Saved account').slice(0, 100);
    const accountEmail = typeof farmer?.email === 'string' ? farmer.email : '';
    const delivered = new Set<string>(event.delivered ?? []);
    let retry = false;
    for (const device of devices.values()) {
      const data = device.data();
      if (delivered.has(device.id) || data.updatedAt?.toMillis() < Date.now() - 45 * 86400000) continue;
      // Read again immediately before sending to catch account removals.
      const current = (await device.ref.get()).data();
      if (!current || !(current.uids?.includes(event.farmerId) || current.uid === event.farmerId) || current.token !== data.token) continue;
      try {
        await messaging.send({
          token: data.token,
          data: {
            farmerId: event.farmerId, type: event.type, title: event.title,
            accountName, accountEmail,
            body: event.body, eventId: id, cycleId: event.cycleId ?? '',
            expiresAt: String(event.expiresAt.toMillis()),
          },
          android: { priority: 'high', ttl: Math.min(86400000, event.expiresAt.toMillis() - Date.now()) },
        });
        delivered.add(device.id);
        await ref.update({ delivered: FieldValue.arrayUnion(device.id) });
      } catch (error) {
        const code = (error as { code?: string }).code;
        if (code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token') {
          await db.runTransaction(async tx => {
            const latest = await tx.get(device.ref);
            if (latest.data()?.token === data.token) tx.delete(device.ref);
          });
        } else { retry = true; console.error('FCM delivery failed:', code ?? 'unknown'); }
      }
    }
    await ref.update({ status: retry ? 'pending' : 'sent', leaseUntil: FieldValue.delete() });
  } catch (error) {
    await ref.update({ leaseUntil: FieldValue.delete() });
    throw error;
  }
}
