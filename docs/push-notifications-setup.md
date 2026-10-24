# Free-plan phone notifications

This feature uses Firebase Cloud Messaging + the existing Next.js dashboard on
Vercel. It does not deploy Firebase Functions, enable Cloud Scheduler, enable
Firestore TTL, or change Firebase billing. Firebase must remain on Spark.

## What is implemented

- Android foreground and background phone notifications with notification permission.
- MAO verification uses an authenticated server route that commits account approval
  and a durable notification event together. Only MAO dashboard accounts can approve.
- Every installation has a random private ID and multiple authenticated account
  memberships. **Profile > Switch account** retains the current membership while
  signing out, so saved accounts keep receiving notifications on this phone.
- **Logout** removes only that account immediately, including offline, and attempts
  to unregister it server-side. Other saved accounts keep their shared FCM token.
- FCM delivers data messages; `flutter_local_notifications` displays them in the
  Android notification drawer. The active account sees the normal message with its
  name. Inactive/signed-out saved accounts show only an account name and a generic
  "new notification" prompt. Detailed drawer entries are cleared when switching away.
- Tapping another account's notification asks before switching, prefills its email,
  and requires sign-in before opening the requested screen. No extra passwords or
  Firebase sessions are saved for this feature. Logging into a different account
  than the notification recipient does not open its data.
- Registration's automatic sign-out keeps the pending farmer as recipient so MAO
  approval can arrive before the farmer can log in. Switching to another account
  retains this pending account's generic notifications.
- One daily Vercel cron checks missing logs and weekly scouting for active cycles.
  Scheduled activities do not count as a log already made today; an in-progress or
  completed log dated today does. Scouting is complete after five stations.
- Crop weeks follow Monitoring's elapsed-day boundaries, including day 7 in week 1.
- Explicitly harvested/completed cycles are excluded. A forecast harvest date alone
  does not finish a cycle, matching the app's existing completion policy.
- Stable event IDs and device-local receipts suppress duplicate retries. Failed
  sends remain pending for the next cron/manual retry. Retries recheck completion.

## Production setup still required

1. In the existing Vercel project's **Production** environment variables, set:
   - `FIREBASE_SERVICE_ACCOUNT_JSON`: the Firebase service-account JSON for project
     `visaia`, stored as a secret environment value, never in frontend code.
   - `CRON_SECRET`: a cryptographically random secret, at least 32 characters.
   The existing local service-account fallback is retained for local development.
2. Review the deployed Firestore rules. Both new collections are server-only:

   ```
   match /pushDevices/{id} { allow read, write: if false; }
   match /pushEvents/{id} { allow read, write: if false; }
   ```

   Merge these into the existing rules; do not replace the full ruleset. A broader
   wildcard allow rule still grants access and must exclude these collections.
   Neither mobile nor dashboard clients need direct access to these collections.
   Admin SDK server operations bypass client rules.
3. Redeploy `visaia-dashboard` to `https://visaia-web.vercel.app`. The included
   `vercel.json` runs `/api/cron/farm-reminders` at `0 23 * * *` UTC, or 7 AM Manila.
   Vercel Hobby can invoke during the scheduled hour, so expect 7–8 AM rather than
   an exact minute. Cron runs on production deployments only.
4. Ensure the FCM HTTP v1 API is enabled for the existing Firebase project. This
   does not require upgrading Firebase to Blaze.
5. Build/install the updated Android app and allow notifications. Its default
   backend is the production dashboard URL. Override for staging with
   `--dart-define=PUSH_BACKEND_URL=https://your-staging-host`.
6. Confirm registration succeeds (HTTP 200) and that `pushDevices` has an installation
   for the intended farmer. Existing installed app versions do not register tokens.

No Vercel environment variables, deployed Firestore rules, production deployment,
or Firebase billing settings are changed by the local implementation scripts.

## Free-plan capacity and practical limits

FCM delivery is no-cost. Firestore Spark has project-wide daily allowances of
50,000 reads / 20,000 writes, shared with the rest of the app and dashboard.
The morning job fails explicitly above 100 recently active recipients or 500
installation records. This is a conservative pilot guard, not a guarantee of
quota headroom: cycle counts, activity counts, retries and other app use matter.
Device records older than 45 days are ignored until the farmer signs in again.
Expired event records are deleted by the daily job; Firestore paid TTL is unused.
Review project usage before increasing capacity. No paid overflow service is used.

Notifications use data-only high-priority FCM so the app can reject a previously
signed-in farmer's messages. Android power restrictions, lack of internet,
disabled notifications, or force-stopping the app can delay or prevent delivery.
Unsynced offline logs cannot suppress a server reminder yet. Token refresh while
the pending account is automatically signed out cannot reauthenticate registration;
signing into that account again refreshes it. iOS and web push are not configured
in this implementation; the repo currently has Android Firebase configuration.

## Validation

- `node --test push-backend/policy.test.cjs push-backend/delivery.test.cjs`
- `node ../visaia-dashboard/node_modules/typescript/bin/tsc -p push-backend/tsconfig.check.json --incremental false`
- `flutter test test/push_message_policy_test.dart test/daily_log_week_policy_test.dart test/notification_feed_test.dart`
- `flutter analyze --no-pub lib/services/push_notification_service.dart lib/services/push_message_policy.dart lib/main.dart lib/services/auth_service.dart lib/screens/auth/veri_form.dart test/push_message_policy_test.dart`
- `flutter build apk --debug --no-pub`

After deployment, test with two phones signed into Farmer A: both should receive
approval/reminders. Use **Switch account** on one phone to sign into Farmer B:
that phone should receive a generic account-labelled prompt for A and normal
notifications for B. Tapping A's prompt must ask to switch and require sign-in.
Use **Logout** for A: A's messages must be blocked on that installation, while B's
membership and A's other phone remain registered. Repeat logout offline.
Register a pending account and approve it from MAO to test the
automatic-sign-out exception. Test missing/completed/scheduled-only logs, partial
and complete scouting, harvested cycles, and repeated cron calls on the same day.

## Dashboard source staging

`push-backend/` contains the server sources staged for the sibling dashboard.
`python scripts/prepare_push_dashboard.py` fingerprints existing target files and
prepares the minimal verification/admin initialization edits. Then
`python scripts/install_push_dashboard.py` applies only those eight files and
refuses if target files changed since staging. Installing into the sibling folder
requires workspace write approval. These scripts do not deploy anything.

References: [Firebase pricing](https://firebase.google.com/pricing),
[Firestore quotas](https://firebase.google.com/docs/firestore/quotas),
[Vercel cron limits](https://vercel.com/docs/cron-jobs/usage-and-pricing),
[Flutter message delivery](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).
