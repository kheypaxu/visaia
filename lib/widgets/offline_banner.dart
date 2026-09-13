import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/services/connectivity_service.dart';
import 'package:visaia/services/offline_sync_service.dart';
import 'package:visaia/widgets/offline_queue_sheet.dart';

/// A dynamic banner that displays network connectivity status and sync progress.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  final ConnectivityService _connectivityService = ConnectivityService();
  final OfflineSyncService _syncService = OfflineSyncService();

  bool _showBackOnline = false;

  @override
  void initState() {
    super.initState();
    _connectivityService.onConnectivityRestored.listen((online) {
      if (online && mounted) {
        setState(() => _showBackOnline = true);
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _showBackOnline = false);
        });
      }
    });
  }

  void _openQueueSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const OfflineQueueSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _connectivityService.isOnlineNotifier,
      builder: (context, isOnline, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: _syncService.isSyncing,
          builder: (context, isSyncing, _) {
            return ValueListenableBuilder<int>(
              valueListenable: _syncService.pendingSyncCount,
              builder: (context, pendingCount, _) {
                final shouldShow = !isOnline || isSyncing || _showBackOnline;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: shouldShow ? 38.0 : 0.0,
                  child: shouldShow
                      ? _buildBannerContent(
                          isOnline: isOnline,
                          isSyncing: isSyncing,
                          pendingCount: pendingCount,
                        )
                      : const SizedBox.shrink(),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBannerContent({
    required bool isOnline,
    required bool isSyncing,
    required int pendingCount,
  }) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String message;

    if (isSyncing) {
      bgColor = const Color(0xFF1E3A8A); // Deep blue
      textColor = Colors.white;
      icon = Icons.sync_rounded;
      message = 'Syncing $pendingCount pending item(s)...';
    } else if (!isOnline) {
      bgColor = const Color(0xFF452205); // Warm dark amber/brown
      textColor = const Color(0xFFFFD599);
      icon = Icons.wifi_off_rounded;
      message = 'Offline Mode • Actions saved to device';
    } else {
      bgColor = const Color(0xFF0F5132); // Deep forest green
      textColor = const Color(0xFFD1E7DD);
      icon = Icons.cloud_done_rounded;
      message = 'Connected • All data synchronized';
    }

    return GestureDetector(
      onTap: pendingCount > 0 ? _openQueueSheet : null,
      child: Container(
        width: double.infinity,
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (isSyncing)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Icon(icon, size: 15, color: textColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: textColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (pendingCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$pendingCount Queued',
                      style: GoogleFonts.inter(
                        color: textColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 13, color: textColor),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
