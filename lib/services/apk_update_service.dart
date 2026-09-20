import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

enum UpdateInstallStatus {
  idle,
  downloading,
  installing,
  completed,
  cancelled,
  error,
}

class ApkDownloadProgress {
  final double progress; // 0.0 to 1.0
  final int receivedBytes;
  final int totalBytes;
  final String speedText;

  const ApkDownloadProgress({
    required this.progress,
    required this.receivedBytes,
    required this.totalBytes,
    this.speedText = '',
  });

  String get receivedMB => (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
  String get totalMB => totalBytes > 0
      ? (totalBytes / (1024 * 1024)).toStringAsFixed(1)
      : '--';
  String get percentage => (progress * 100).toStringAsFixed(0);
}

class ApkUpdateService {
  factory ApkUpdateService() => _instance;
  ApkUpdateService._internal();
  static final ApkUpdateService _instance = ApkUpdateService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      followRedirects: true,
      maxRedirects: 5,
    ),
  );

  CancelToken? _cancelToken;

  /// Cancel any active download
  void cancelDownload() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('User cancelled download');
      _cancelToken = null;
    }
  }

  /// Downloads the APK and directly triggers the Android Package Installer.
  Future<OpenResult?> downloadAndInstall({
    required String apkUrl,
    required void Function(ApkDownloadProgress progress) onProgress,
    required void Function(String errorMessage) onError,
  }) async {
    _cancelToken = CancelToken();

    try {
      final tempDir = await getTemporaryDirectory();
      final apkFilePath = '${tempDir.path}/visaia_update.apk';
      final file = File(apkFilePath);

      // Clean up previous incomplete/old downloads
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (e) {
          debugPrint('⚠️ [ApkUpdateService] Could not delete old APK: $e');
        }
      }

      int lastReceived = 0;
      DateTime lastTime = DateTime.now();
      String speedText = '';

      debugPrint('📥 [ApkUpdateService] Starting download from $apkUrl to $apkFilePath');

      await _dio.download(
        apkUrl,
        apkFilePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          final now = DateTime.now();
          final duration = now.difference(lastTime).inMilliseconds;

          if (duration >= 500 && duration > 0) {
            final bytesSince = received - lastReceived;
            final speedBytesPerSec = (bytesSince / (duration / 1000));
            speedText = _formatSpeed(speedBytesPerSec);
            lastReceived = received;
            lastTime = now;
          }

          final progress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;

          onProgress(
            ApkDownloadProgress(
              progress: progress,
              receivedBytes: received,
              totalBytes: total,
              speedText: speedText,
            ),
          );
        },
      );

      debugPrint('✅ [ApkUpdateService] Download finished. Prompting system installer...');

      // Trigger Android System Package Installer
      final result = await OpenFilex.open(
        apkFilePath,
        type: 'application/vnd.android.package-archive',
      );

      debugPrint('📱 [ApkUpdateService] OpenFilex result: ${result.type} | ${result.message}');

      if (result.type != ResultType.done) {
        onError('Failed to open installer: ${result.message}');
      }

      return result;
    } on DioException catch (dioError) {
      if (CancelToken.isCancel(dioError)) {
        debugPrint('⏹️ [ApkUpdateService] Download cancelled by user.');
      } else {
        debugPrint('❌ [ApkUpdateService] Dio error: ${dioError.message}');
        onError(dioError.message ?? 'Network error while downloading update.');
      }
      return null;
    } catch (e) {
      debugPrint('❌ [ApkUpdateService] General error: $e');
      onError(e.toString());
      return null;
    } finally {
      _cancelToken = null;
    }
  }

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec < 1024) {
      return '${bytesPerSec.toStringAsFixed(0)} B/s';
    } else if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }
}
