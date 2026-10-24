# Firestore access audit: VISAIA mobile and dashboard

Audited local sources in `C:/PROJECTS/visaia/lib` and
`C:/PROJECTS/visaia-dashboard/app` + `src`. No live database, Firebase rules,
billing settings, credentials in Vercel, or production deployment were changed.

**Status: the regional raw-data blocker is fixed locally and tested. Publish
only after the updated dashboard/app rollout and existing staff-role review.
See [regional feed rollout](regional-feed-rollout.md) for the exact order.**

## Findings and changes

| Finding | Evidence | Result |
| --- | --- | --- |
| Every authenticated user could read/write every document under the supplied rules | User-supplied recursive authenticated catch-all | Replaced in the local candidate with explicit ownership and staff rules; the live rules remain unchanged |
| Farmer profiles include sensitive identity data | `lib/screens/auth/veri_form.dart`, `lib/screens/profile_screens/manage_account.dart` | Candidate allows the owner and trusted staff, not other farmers |
| Roles come from `users/{uid}` | Dashboard `src/context/AuthContext.tsx`, `src/config/routeAccess.ts`; backend `src/notifications/push.ts` | Client role/userType changes and creation of staff profiles are denied; staff must be provisioned through Admin SDK |
| Fast Verify bypassed the notification producer | Dashboard `app/(dashboard)/account-verification/page.tsx` | Changed to use the same authenticated account-approved endpoint as the details page |
| An existing Admin SDK push endpoint had no caller authentication | Dashboard `app/api/notifications/push/route.ts` | Requires a valid Firebase token, a canonical RCPC dashboard role, and a matching validated/resolved report owner |
| Existing advisory caller supplied no bearer token | Dashboard `app/(dashboard)/validation/[id]/page.tsx` | Now supplies a Firebase ID token and handles non-success responses without undoing already committed validation |
| PDF fallback queries used only farmId | `lib/services/farm_report_pdf_service.dart` | Added farmerId constraints; a farm ID by itself is not proof of report ownership |
| A server credential JSON was tracked by Git | Dashboard `src/scripts/service-account.json` | Removed from Git tracking and added to `.gitignore`; local file retained. No key rotation performed |

The credential removal must be included in the next dashboard commit. If the key
was pushed previously, replace/revoke that exposed key through Firebase/Google
Cloud and update the Vercel secret. Removing a tracked file does not remove old
commits or revoke their credentials. Do not paste the key into chat or logs.

## Candidate access policy

| Path / workflow | Owner | MAO | RCPC | Backend Admin SDK |
| --- | --- | --- | --- | --- |
| Own `users/{uid}` display profile | Read/update non-authority fields | Own profile only for edits | Own profile only for edits | Provision roles |
| All user/farmer profiles | No bulk access | Read | Read | Full trusted access |
| Farmer registration | Own pending application, identity/profile edits | Reject/unverify/delete | Read | Approve and enqueue notification atomically |
| Farms, fields, cycles and their logs/images/weeks/traps | Verified owner manages own records | Read | Read | Full trusted access |
| Regular / clustered / plant-damage reports | Submit/edit pending own records; resolve validated own reports | Read | Review, correct, archive, reject | Full trusted access |
| Expert validations | Read own; resolution fields only after report validation | Read | Create/review | Full trusted access |
| Alerts | Read own; read-state changes; create own scheduled-activity alerts only | Create/read/manage | Create/read/manage | Approval/reminder producer |
| User notification subcollection | Read own; update `read`; delete own entries | Create/read | Create/read | Full trusted access |
| Push devices / push events / legacy token subcollection | No direct access | No direct access | No direct access | Server-only |
| `app_config/release` | Public read, including before login | Read | Read | Write |
| Unknown collections | Denied | Denied | Denied | Governed by IAM |

Role lookups support canonical UID-keyed staff records with `role=mao_admin` or
`role=rcpc_admin`; `userType` must be `dashboard` or absent/null for legacy
compatibility. Farmer registrations can never create these privileged records.
The candidate does not require a paid Firebase product or an App Check upgrade.

## Publish blockers and compatibility decisions

1. **Regional mobile assessment: fixed locally.**
   `MunicipalFawService` now consumes an authenticated, projected backend feed.
   It does not subscribe to all farmer/user/report collections. Only validated
   barangay/life-stage totals and known growth labels reach this feature.
2. **Regional risk-map reads: fixed locally.**
   `FawRiskService` now uses the same feed. Linked-field resolution runs on the
   server, and opaque map entries exclude owner IDs, names, photos, boundaries
   and individual report notes. Failed requests show unavailable data rather
   than zero risk. Detection points remain shared for geographic monitoring.
   Five-minute shared caching, source-size caps and a daily source-read budget
   limit free-plan use. See the rollout guide for limits and refresh behavior.
3. **Review existing staff roles before trusting them.**
   The previous catch-all allowed role tampering. In Firebase Console, check every
   privileged `users` record against the authorized MAO/RCPC users. Rules freeze
   future client role changes; they do not repair historical data. Canonical IDs
   must equal the Firebase Authentication UID. The dashboard's legacy email-based
   lookup is insufficient for privileged access if no UID-keyed staff record exists.
   Do not let the client create an admin role during migration.
4. **Municipal scope is not yet enforced at the database layer.**
   The current dashboards query entire datasets and often filter on the client.
   The candidate deliberately permits trusted MAO/RCPC staff reads needed by those
   queries; it does not claim municipality-by-municipality isolation. If a MAO
   must be technically unable to read other municipalities, add scope fields and
   matching query constraints before publishing that stricter policy.
5. **The legacy advisory delivery path is separate from the new push delivery.**
   Authentication is fixed, but `api/notifications/push` still uses its older token
   fields/topics and notification payload. Account approval and morning reminders
   use the new multi-account device registry and data-only rendering. Migrating
   expert-advisory pushes to that same producer is needed for identical saved-account
   preview behavior across all notification types. This audit does not claim that
   legacy advisories now use the new registration path.

## Tests and reproduction

Install the local test tools once:

```powershell
npm.cmd install --prefix security
```

Run the rules against an isolated emulator using the installed Firebase CLI and
a Java version supported by that CLI:

```powershell
$env:JAVA_HOME = 'C:/Program Files/Java/jdk-26'
$env:PATH = $env:JAVA_HOME + '/bin;' + $env:PATH
firebase.cmd emulators:exec --only firestore --project demo-visaia-rules --config firebase.security.json 'node --test --test-concurrency=1 security/firestore.rules.test.cjs'
```

The `demo-visaia-rules` ID prevents these tests from using the production project.
Tests cover registration/profile-photo merges, forged approval/roles, nested
ownership, staff dashboards and farm collection-group reads, offline report
analysis, the three-document scouting batch, RCPC review, owner resolution and
its validation batch, alert receipts, scheduled alerts, forged notifications,
and server-only push data. Rejected bulk/mobile queries are tested explicitly.

The dashboard fixes are maintained directly in the dashboard repository.
The mobile security suite includes a cross-project emulator test and expects
`visaia-dashboard` checked out beside `visaia`, with dependencies installed in
both repositories and under `security/`. It reads the canonical dashboard source;
no duplicate server source is kept in the mobile repository.

Additional checks:

```powershell
npm.cmd --prefix ../visaia-dashboard run test:notifications
npm.cmd --prefix ../visaia-dashboard run check:security
flutter analyze --no-pub lib/services/farm_report_pdf_service.dart
```

The notification tests load the canonical protected advisory route in the
dashboard repository. Production activation remains pending
the rollout, existing-role review, Vercel configuration, and real-device validation.

References: [Rules are not filters](https://firebase.google.com/docs/firestore/security/rules-query),
[field access](https://firebase.google.com/docs/firestore/security/rules-fields),
[rules emulator testing](https://firebase.google.com/docs/firestore/security/test-rules-emulator).
