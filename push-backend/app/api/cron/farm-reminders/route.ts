import { timingSafeEqual } from 'node:crypto';
import { Timestamp } from 'firebase-admin/firestore';
import { getFirebaseAdmin } from '@/src/config/firebaseAdmin';
import { enqueue, eventId, deliver } from '@/src/notifications/push';
import { loggedToday, manilaDay, reminderPeriod, scoutingComplete } from '@/src/notifications/policy';

export const runtime = 'nodejs';
export const maxDuration = 60;
export const dynamic = 'force-dynamic';
export async function GET(request: Request) {
  const secret = process.env.CRON_SECRET;
  const provided = Buffer.from(request.headers.get('authorization') ?? '');
  const expected = Buffer.from(`Bearer ${secret ?? ''}`);
  if (!secret || provided.length !== expected.length || !timingSafeEqual(provided, expected)) {
    return Response.json({ error: 'Unauthorized' }, { status: 401 });
  }
  const { db } = getFirebaseAdmin();
  const now = new Date();
  const today = manilaDay(now);
  const expiresAt = Timestamp.fromMillis(Date.parse(`${today}T23:59:59+08:00`));
  let queued = 0;
  try {
    // Explicit pilot cap avoids accidentally consuming Spark quotas at scale.
    const devices = await db.collection('pushDevices').limit(501).get();
    const uids = [...new Set(devices.docs.filter(d =>
      d.data().updatedAt?.toMillis() >= now.getTime() - 45 * 86400000).map(d => d.data().uid as string))];
    if (devices.size > 500 || uids.length > 100) {
      return Response.json({ error: 'Free-plan pilot capacity exceeded; review quotas before increasing limits' }, { status: 503 });
    }
    const pending = await db.collection('pushEvents').where('status', '==', 'pending').limit(100).get();
    for (const event of pending.docs) await deliver(event.id);
    for (const uid of uids) {
      const farmer = await db.collection('farmers').doc(uid).get();
      if (farmer.data()?.status !== 'verified') continue;
      const cycles = await db.collection('users').doc(uid).collection('cycles').get();
      for (const cycle of cycles.docs) {
        const period = reminderPeriod(cycle.data(), now);
        if (!period) continue;
        const week = await cycle.ref.collection('weeks').doc(period.weekId).get();
        const activities = await cycle.ref.collection('dailyLogs').doc(period.dayId).collection('activities').get();
        const missingLog = !activities.docs.some(a => loggedToday(a.data(), now));
        const missingScout = !scoutingComplete(week.data() ?? {});
        for (const type of ['daily_log_reminder', 'scouting_reminder']) {
          if (type === 'daily_log_reminder' ? !missingLog : !missingScout) continue;
          const id = eventId(`${uid}:${cycle.id}:${today}:${type}`);
          await enqueue(id, { farmerId: uid, cycleId: cycle.id, type, expiresAt,
            title: type === 'daily_log_reminder' ? 'Add your daily farm log' : 'Your weekly field scouting is due',
            body: type === 'daily_log_reminder' ? 'You have not logged an activity today. Open VISAIA to add one.' :
              `Field scouting for crop week ${period.week} is not complete. Open VISAIA to finish your stations.`,
          });
          await deliver(id);
          queued++;
        }
      }
    }
    // Manual cleanup: Firestore TTL is a billing-enabled feature.
    const old = await db.collection('pushEvents').where('expiresAt', '<', Timestamp.fromMillis(now.getTime() - 7 * 86400000)).limit(400).get();
    if (!old.empty) {
      const batch = db.batch();
      old.docs.forEach(d => batch.delete(d.ref));
      await batch.commit();
    }
    return Response.json({ success: true, accounts: uids.length, queued });
  } catch (error) {
    console.error('Morning reminder job failed:', error);
    return Response.json({ error: 'Reminder job failed; completed events will not be resent on retry' }, { status: 500 });
  }
}
