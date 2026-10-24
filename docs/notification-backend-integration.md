# Notification delivery

For Android phone delivery, MAO account approval, and morning farm reminders,
see [Free-plan phone notifications](push-notifications-setup.md). The report feed
behavior and report-outcome trigger follow-up below remain separate.

The app merges alerts with the latest status of owned reports and clustered_reports.
Clustered reports support farmerId and legacy userId ownership. The bell and inbox
use the same feed. Explicit report alerts supersede matching derived entries.
Report read receipts are stored per signed-in UID on the device; existing alert
read receipts continue to use alerts.status. Report status itself is never modified.
This provides in-app updates, not background push delivery or a historical event log.
A report with no status timestamp uses its available saved timestamp for display;
no fabricated current timestamp is used. Ordinary edits do not reset its read receipt.

## Report-status follow-up (automatic transition trigger is not implemented)

Create an idempotent trusted trigger for status transitions in reports and
clustered_reports. Resolve the owner using farmerId/userId, and write an alert
with farmerId, reportId, reportType (regular or clustered), type, title, message,
createdAt (server timestamp), and status=unread. Use validation_confirmed,
validation_rejected, or report_resolved types for those outcomes. Deduplicate
trigger retries with a stable ID derived from report path and event ID. Persist
statusUpdatedAt on each transition. Do not notify on unrelated report edits.

Restrict alert reads and read-state updates to the recipient. Only trusted server
code should create report outcome alerts; recipients must not change their content
or report status. Verify both clustered ownership schemas against deployed rules.
For all-state history and synchronized read receipts, extend this producer to each
supported transition and migrate derived fallback entries only after backfilling.
Optional FCM delivery should use the same persisted events, with retry deduplication.

Validate on staging: regular/clustered pending -> validated/rejected -> resolved,
including updates while offline, repeated trigger delivery, two accounts, reopening
the app, report navigation, unread badge and mark-all-read. No backend was deployed
as part of this client change.
