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
5. Queue a pest photo offline, force-close and restart. Verify the queued item
   and photo remain. Restore internet; verify one report is updated and the queue
   clears only after server confirmation. Repeat while disconnecting mid-sync.
6. Install traps and record a harvest offline. Verify feedback completes without
   waiting for internet, and data survives restarting the app.
7. Restore internet and verify the same data from another client. Repeat the
   save flows online. Use a test account to check denied writes: a late server
   rejection must display an error, not silently claim server success.
8. Connect to Wi-Fi without internet. Verify the offline state is detected and
   pest photos can be queued. Switch accounts with pending pest uploads and
   verify they cannot be processed as the other account.

Offline reads require cached data. AI analysis requires the backend. The pending
indicator counts tracked Firestore documents and AI jobs, not unique user actions.
