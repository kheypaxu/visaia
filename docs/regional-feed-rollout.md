# Regional privacy fix and rollout

The local mobile/dashboard code now replaces both regional raw-data readers with
`GET /api/mobile/regional-risk`. It authenticates the Firebase user, requires a
verified farmer in the supported Cabatuan pilot (or an authorized dashboard role),
and returns only a defined regional projection. No production settings changed.

## What changed

- Municipal assessment returns barangay/life-stage totals and known crop-stage labels.
- Nearby risk returns opaque IDs, canonical barangay, validated pest counts, DAP,
  risk inputs, observation date and a detection point. Map coordinates are deliberately
  shared for proximity monitoring; the feed is not a promise of geographic anonymity.
- The server resolves a regular report's linked field/farm location, never camera
  upload GPS. Private boundary polygons are not returned.
- No farmer UID, raw report/cycle/farm/field ID, farmer name, contact information,
  RSBSA details, ID image, photo, arbitrary notes or individual treatment text is sent.
- Shared snapshots use keyed, opaque owner references internally. Each response
  excludes the caller's own map reports while municipal totals still include them.
- Both snapshots and daily read budgets are server-only in `firestore.rules`.
- Corrected station counters and validated life stages take precedence over stale
  original totals. Duplicate scouting reports are collapsed by owner/cycle/week.
- Pending, resolved, rejected, archived and explicitly non-FAW reports are excluded.
- The existing risk matrix, wind scaling and field-boundary distance calculations
  continue in Flutter on the public projection. Private own-field data still uses
  owner-scoped Firestore access.
- The UI labels an unavailable regional feed explicitly and offers retry. A denied
  request, quota guard or malformed response never becomes a fake zero-risk result.

## Free-plan limits

No Cloud Functions deployment, paid Scheduler, Firestore TTL, new paid service or
billing upgrade is used. The endpoint runs on the existing Vercel dashboard.

The shared server snapshot is refreshed on demand after five minutes. The mobile
assessment refreshes near that expiry while the app is active, pauses in the
background, and shares requests/cache with the map for the same signed-in account.
New validations/resolutions can take about five minutes to reach the regional feed.
The map reloads when its existing load/refresh action runs; it is not a live stream.

Pilot guards: at most 200 validated records from each report collection, 100 source
owners and 300 distinct linked-site reads per rebuild. Overflow returns unavailable
instead of silently dropping reports. Archived records still returned by the
validated-status query count toward that source-query cap.

The server conservatively limits regional source scans to 12,000 document reads
per Philippine calendar day. Failed builds retain a 1,000-read reservation;
successful builds return the unused portion. This is an application guard, not a
Firebase billing cap: authentication/profile/cache reads, rule lookups, the rest of
the app and retries still share the project's Spark allowance. Do not assume these
limits guarantee headroom for an arbitrarily large or constantly active deployment.
Failures remain visible, with no paid overflow or unsafe direct-query fallback.

## Publish order

1. Review all privileged `users/{uid}` records against your real MAO/RCPC staff.
   The old catch-all allowed role tampering. IDs must match Firebase Auth UIDs;
   client email-based legacy lookup does not provision a trusted UID-keyed admin.
2. If a service-account key was pushed to GitHub, replace/revoke the exposed key
   and update the Vercel secret. The local credential file is retained but removed
   from future Git tracking; Git history was not rewritten.
3. Set/confirm Vercel **Production** variables `FIREBASE_SERVICE_ACCOUNT_JSON` and
   `CRON_SECRET` (at least 32 characters). The new endpoint uses the latter to make
   opaque IDs. It does not need a third secret or an additional cron job.
4. Push/deploy the updated `visaia-dashboard`. Confirm the production deployment
   succeeds, then use the updated app with a verified test account to exercise the
   endpoint. Opening the endpoint in a normal browser without a token should return
   401, not data.
5. Let the existing GitHub Action build the updated Flutter app. Install that update
   on the pilot phones **before** tightening rules. Old APKs still use the broad
   regional reads and are not compatible with the new privacy rules.
6. In Firebase **Firestore Database > Rules**, replace the old catch-all with the
   **entire contents** of the root `firestore.rules`. Publish after the rollout and
   staff review; do not append the rules underneath the catch-all.
7. Smoke-test registration, both MAO verification buttons, own farms/logs/scouting,
   RCPC validation, report resolution, the regional assessment/map, and notification
   delivery on real devices. Switch accounts and confirm identities do not cross.

The rules intentionally preserve current trusted MAO/RCPC dashboard reads across
the pilot. They do not introduce strict cross-municipality isolation. Only Cabatuan
is currently configured in the mobile app. Adding other municipalities requires
explicit scope/query changes, not just another dropdown option.

The pre-existing expert-advisory push path remains separate from the new approval
and morning-reminder producer; this regional change does not migrate its legacy
token/topic delivery. That limitation is documented in the security audit.

## Local validation

```powershell
npm.cmd --prefix ../visaia-dashboard run test:regional
npm.cmd --prefix ../visaia-dashboard run check:security
flutter test --no-pub test/regional_feed_service_test.dart test/farm_risk_proximity_test.dart test/report_map_location_resolver_test.dart test/push_message_policy_test.dart test/notification_feed_test.dart
```

The emulator command in `firestore-security-audit.md` also covers a real Admin SDK
regional build, protected cache access, and a validated-to-resolved update under
the actual rules. Its certificate is generated in memory for the local demo project;
no real service-account credential is used.

The production endpoint, privacy projection and backend tests live directly in
`visaia-dashboard/app/api/mobile` and `visaia-dashboard/src/regional`. Temporary
mirrors and installer scripts have been removed. Commit the real dashboard files
alongside this repository's mobile changes and Firestore rules.

## Validation result

Local checks passed: 30 emulator tests (including the actual server SDK regional
build), 29 combined backend tests and 32 Flutter feed/map/notification tests.
The focused dashboard TypeScript check passed. Flutter analysis found no errors;
11 pre-existing informational dashboard style/deprecation notices remain.
No local APK build was started; the existing GitHub Action can build the update.
Live-device delivery, the Vercel deployment and deployed-rule smoke tests remain
production rollout checks, not claims made by these local tests.
