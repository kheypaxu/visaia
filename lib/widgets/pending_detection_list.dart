import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:visaia/screens/logging_screens/ai_result.dart';
import 'package:visaia/services/offline_sync_service.dart';

/// Shared between the header's sync details and Report History.
class PendingDetectionList extends StatelessWidget {
  const PendingDetectionList({super.key, this.service, this.onOpen});
  final OfflineSyncService? service;
  final void Function(QueuedOfflineItem)? onOpen;

  static Future<void> openResult(
    BuildContext context,
    QueuedOfflineItem item, {
    NavigatorState? navigator,
  }) async {
    final service = OfflineSyncService();
    final active = service.itemById(item.id);
    final result = active?.result;
    if (active == null || result == null) return;
    await (navigator ?? Navigator.of(context)).push(
      MaterialPageRoute(
        builder: (_) => AIResultScreen(
          queuedDetectionId: active.id,
          userId: active.userId,
          imageFile: File(active.imagePath),
          pestName: result.pestName,
          scientificName: result.scientificName,
          severity: result.riskLevel,
          confidencePercent: (result.confidence.clamp(0.0, 1.0) * 100).round(),
          detectionStage: result.lifeStage,
          cropAffected: result.cropAffected,
          analysis: result.analysis,
          treatment: result.treatment,
          historicalContext: result.historicalContext,
          annotatedImageUrl: result.annotatedImageUrl,
          latitude: active.latitude,
          longitude: active.longitude,
          areaName: active.areaName,
          farmId: active.farmId,
          farmName: active.farmName,
          fieldId: active.fieldId,
          fieldName: active.fieldName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sync = service ?? OfflineSyncService();
    return ValueListenableBuilder<int>(
      valueListenable: sync.queueRevision,
      builder: (context, _, child) {
        final items = sync.queue;
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No pending detections. Offline uploads will stay here until you review, assign and save them.',
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            final ready = item.isReady && item.status != 'submitting';
            final busy =
                item.status == 'uploading' ||
                item.status == 'analyzing' ||
                item.status == 'submitting';
            final failed = item.status == 'failed';
            return Card(
              margin: EdgeInsets.zero,
              color: const Color(0xFFF7FAF6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(item.imagePath),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, error, stack) => const SizedBox(
                              width: 48,
                              height: 48,
                              child: Icon(Icons.image_not_supported_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.result?.pestName ?? 'Pest detection',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                [item.farmName, item.fieldName ?? item.areaName]
                                    .whereType<String>()
                                    .where((v) => v.isNotEmpty)
                                    .join(' · '),
                              ),
                              Text(
                                DateFormat('MMM d, h:mm a').format(
                                  DateTime.fromMillisecondsSinceEpoch(
                                    item.timestamp,
                                  ),
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF536257),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (busy) ...[
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            item.statusLabel,
                            style: TextStyle(
                              color: failed
                                  ? const Color(0xFF9E2525)
                                  : const Color(0xFF1A5C30),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (item.errorMessage != null && failed)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          item.errorMessage!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (ready)
                      TextButton.icon(
                        onPressed: () => onOpen != null
                            ? onOpen!(item)
                            : openResult(context, item),
                        icon: const Icon(Icons.fact_check_outlined),
                        label: const Text('View AI result'),
                      )
                    else if (failed)
                      TextButton.icon(
                        onPressed: () => sync.syncAll(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry analysis'),
                      ),
                    if (item.submission != null && failed)
                      TextButton.icon(
                        onPressed: () => sync.syncAll(),
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Retry report save'),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class PendingDetectionsSection extends StatelessWidget {
  const PendingDetectionsSection({super.key, this.service});
  final OfflineSyncService? service;

  @override
  Widget build(BuildContext context) {
    final sync = service ?? OfflineSyncService();
    return ValueListenableBuilder<int>(
      valueListenable: sync.queueRevision,
      builder: (context, _, child) => Card(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: const PageStorageKey('pending-detections'),
          initiallyExpanded: false,
          leading: const Icon(
            Icons.cloud_sync_outlined,
            color: Color(0xFF1A5C30),
          ),
          title: Text(
            'Pending detections (${sync.queue.length})',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          subtitle: Text(
            sync.readyCount > 0
                ? '${sync.readyCount} ready to review and assign'
                : 'Uploads and AI results awaiting review',
          ),
          children: [
            SizedBox(
              height: sync.queue.isEmpty
                  ? 105
                  : (MediaQuery.sizeOf(context).height * .24).clamp(
                      120.0,
                      220.0,
                    ),
              child: PendingDetectionList(service: sync),
            ),
          ],
        ),
      ),
    );
  }
}
