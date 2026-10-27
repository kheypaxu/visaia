import 'package:flutter/material.dart';
import 'package:visaia/services/connectivity_service.dart';
import 'package:visaia/services/local_write_service.dart';
import 'package:visaia/services/offline_sync_service.dart';
import 'package:visaia/widgets/pending_detection_list.dart';

/// The same persistent detections shown in Report History, with sync controls.
class OfflineQueueSheet extends StatelessWidget {
  const OfflineQueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final service = OfflineSyncService();
    return SafeArea(
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Sync details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Close sync details',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Text(
              'Review completed AI results, assign a cycle, then save your report. These detections also stay in Report History.',
            ),
            const SizedBox(height: 8),
            Expanded(
              child: PendingDetectionList(
                onOpen: (item) {
                  // Keep the parent navigator alive after dismissing the sheet.
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  PendingDetectionList.openResult(
                    context,
                    item,
                    navigator: navigator,
                  );
                },
              ),
            ),
            AnimatedBuilder(
              animation: Listenable.merge([
                service.queueRevision,
                service.isSyncing,
                ConnectivityService().isOnlineNotifier,
                LocalWriteService.pendingCount,
              ]),
              builder: (context, _) {
                final online = ConnectivityService().isOnline;
                return Column(
                  children: [
                    if (LocalWriteService.pendingCount.value > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${LocalWriteService.pendingCount.value} other saved change(s) will sync automatically.',
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            online &&
                                !service.isSyncing.value &&
                                service.hasSyncWork
                            ? () => service.syncAll()
                            : null,
                        icon: const Icon(Icons.sync),
                        label: Text(
                          !online
                              ? 'Waiting for connection'
                              : service.isSyncing.value
                              ? 'Processing detections…'
                              : service.hasSyncWork
                              ? 'Sync now'
                              : 'All results ready for review',
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
