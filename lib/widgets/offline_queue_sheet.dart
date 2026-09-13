import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:visaia/services/connectivity_service.dart';
import 'package:visaia/services/offline_sync_service.dart';

/// Modal bottom sheet allowing users to view pending offline items and trigger manual sync.
class OfflineQueueSheet extends StatelessWidget {
  const OfflineQueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final syncService = OfflineSyncService();
    final connectivityService = ConnectivityService();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3DE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  color: Color(0xFF1A5C30),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offline Sync Queue',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF0C503C),
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'Items waiting to synchronize with cloud',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF757575),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Queue list
          Flexible(
            child: ValueListenableBuilder<int>(
              valueListenable: syncService.pendingSyncCount,
              builder: (context, count, _) {
                final items = syncService.queue;

                if (items.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 48,
                          color: Color(0xFF4E9F3D),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Everything is up to date!',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: const Color(0xFF1A1C1E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No pending offline uploads or reports.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _buildQueueItem(item);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Sync Now Action Button
          ValueListenableBuilder<bool>(
            valueListenable: connectivityService.isOnlineNotifier,
            builder: (context, isOnline, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: syncService.isSyncing,
                builder: (context, isSyncing, _) {
                  final canSync = isOnline && !isSyncing && syncService.queue.isNotEmpty;

                  return SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: canSync ? () => syncService.syncAll() : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A5C30),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFE0E0E0),
                        disabledForegroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: isSyncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.sync_rounded),
                      label: Text(
                        isSyncing
                            ? 'Syncing items...'
                            : isOnline
                                ? 'Sync Now'
                                : 'Offline (Will sync when connected)',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQueueItem(QueuedOfflineItem item) {
    final file = File(item.imagePath);
    final fileExists = file.existsSync();
    final timeStr = DateFormat('MMM d, h:mm a').format(
      DateTime.fromMillisecondsSinceEpoch(item.timestamp),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EAE5)),
      ),
      child: Row(
        children: [
          // Image thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 52,
              height: 52,
              child: fileExists
                  ? Image.file(file, fit: BoxFit.cover)
                  : Container(
                      color: const Color(0xFFE0E0E0),
                      child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 20),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pest Observation Report',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: const Color(0xFF1A1C1E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildStatusChip(item.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.areaName.isNotEmpty ? item.areaName : 'Coordinates: ${item.latitude.toStringAsFixed(3)}, ${item.longitude.toStringAsFixed(3)}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF5E6266),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  timeStr,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: const Color(0xFF8A9B8F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'syncing':
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        label = 'Syncing...';
        break;
      case 'failed':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        label = 'Failed';
        break;
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = 'Queued';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
