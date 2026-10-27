# Offline save verification

Automated checks exercise local acknowledgement, remote acknowledgement, early
and late rejection, queue metadata surviving serialization, cycle naming, and
scouting/day calculations. Native Firestore persistence and deployed rules also
need the following Android/iOS device checks before release.

1. Online, open a farm, field, cycle and monitoring week so their data is cached.
2. Enable airplane mode. Create a cycle, press Save twice, and verify one cycle
   appears, feedback appears, and the form closes. Delete it and verify the
   confirmation closes and the cycle disappears locally.
3. Add a daily log with photos and a scheduled activity. Verify saved photos can
   be reopened offline, the activity ID matches its document ID, and a scheduled
   activity and its alert are queued together.
4. Complete a monitoring week offline. Verify one clustered report and one plant
   damage report share a stable ID and the week references both. Close the app
   during completion and reopen monitoring; an explicitly pending submission
   should retry. Historical weeks are not automatically converted into reports.
5. Queue a pest photo offline, force-close and restart. Verify the detection and
   photo remain in header Sync details and Report History > Pending detections.
   Restore internet and verify Uploading photo, Waiting for AI result and Ready
   to review. No regular report should be created by inference alone. Open View
   AI result, assign a cycle and save online. Verify one complete regular report
   is created, then the pending detection is removed after server confirmation.
   Repeat while disconnecting during analysis and report saving.
6. Install traps and record a harvest offline. Verify feedback completes without
   waiting for internet, and data survives restarting the app.
7. Restore internet and verify the same data from another client. Repeat the
   save flows online. Use a test account to check denied writes: a late server
   rejection must display an error, not silently claim server success.
8. Connect to Wi-Fi without internet. Verify the offline state is detected and
   pest photos can be queued. Switch accounts with pending pest uploads and
   verify they cannot be processed as the other account.

Offline reads require cached data. AI analysis requires the backend. The pending
indicator counts tracked Firestore documents and detections awaiting analysis or
review, not unique user actions.

## Pending detection lifecycle

- Close the result screen without saving, restart and reopen the same result.
  Verify the image, boxes/confidence, analysis, treatment and historical context
  survive without a second AI request. Ready items must not be re-analyzed by
  automatic sync or Sync now.
- Simulate an invalid AI response or failed request. The detection and original
  photo stay local with a visible failure and retry action.
- After assigning a cycle, fail the report write. Verify the result, original
  photo and attempted assignment remain. Restart and retry: the frozen submission
  uses the same document ID and completed analysis. Confirm only one report is
  created even if an earlier request received a late acknowledgement.
- Compare a newly submitted queued detection with an online report in mobile
  details and the web dashboard. Both must contain `detection`, `lifeStage`,
  `risk`, `cropAffected`, confidence as a fraction, full analysis/treatment,
  historical context and a JPEG data URL under `imageBase64`. Check the selected
  cycle, week/station, field/farm, DAP, growth stage and location.
- Switch accounts during analysis. The result must persist for its owner without
  appearing in or being submitted by the other account. Switch back to review it.
- Existing queue entries retain their local image and optional legacy `docId`.
  A reviewed submission gets the queue item's stable ID and links the old cloud
  placeholder via `legacyOfflineReportId`. Existing cloud placeholders are not
  overwritten or deleted: deployed ownership rules prevent reassigning their
  cycle/field, and repair/cleanup requires inspecting the records separately.
- Persistence is on this device. A received AI result survives restart; an
  in-flight server request cannot resume across process termination without
  backend job IDs. It may need to run inference again after restart.

Automated coverage: `detection_queue_lifecycle_test.dart`,
`pending_detection_list_test.dart`, `offline_queue_item_test.dart`,
`analysis_request_test.dart` and `connectivity_service_test.dart`. Native image
compression, Firebase server acknowledgement, live dashboard rendering and real
network transitions still require the device checks above.

## Slow analysis and connectivity checks

- Android displays an "AI result ready to review" local notification after a
  queued detection's full result is saved locally. Notifications must be allowed
  and the account retained on the device. Tap to open the owned queued result;
  an already submitted/removed detection does not open a stale result. Verify
  account switching still requires the owner's sign-in and hides result details.
- The queue currently runs in the app process, with no OS background upload
  worker. Closing/killing it before connectivity returns leaves the photo queued
  until reopening. Background suspension can also interrupt an active request.
  This local notification does not introduce server-side job completion push.

- Delay `/predict` headers and its response body beyond 30 seconds (including a
  multi-minute Moondream run). Keep the upload open and verify the original
  result appears without creating an offline queue item.
- With working internet, return HTTP 500/502/504 or an invalid response from
  `/predict`. Verify the analysis error offers Go back/Try again and does not
  automatically queue a report. Retry sends a new request.
- Block one reachability host and verify the app stays online. Briefly fail both
  hosts and verify one failed probe does not switch offline. With Wi-Fi still
  connected but no internet, three consecutive failed checks switch offline;
  the periodic interval is 30 seconds and probe timeout is 8 seconds. A successful
  check restores online status; losing all network transports switches immediately.
- The client no longer imposes a prediction response timeout. Server, ngrok, or
  reverse-proxy timeouts can still terminate a request. For durable processing
  across those failures or app restarts, the backend needs a persisted job ID,
  status polling, and idempotent submission; that backend is outside this repo.
