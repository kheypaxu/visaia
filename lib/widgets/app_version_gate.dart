import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visaia/core/models/app_release_config.dart';
import 'package:visaia/services/apk_update_service.dart';
import 'package:visaia/services/app_version_service.dart';

class AppVersionGate extends StatefulWidget {
  const AppVersionGate({
    required this.child,
    required this.navigatorKey,
    super.key,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<AppVersionGate> createState() => _AppVersionGateState();
}

class _AppVersionGateState extends State<AppVersionGate>
    with WidgetsBindingObserver {
  static final Uri _fallbackDownloadUrl = Uri.parse(
    'https://visaialanding.vercel.app/download',
  );

  StreamSubscription<AppVersionCheckResult>? _subscription;
  bool _isDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 1. Subscribe to real-time stream so Firebase updates trigger immediately
    _subscription = AppVersionService().streamResults().listen((result) {
      _handleResult(result);
    });

    // 2. Perform an initial one-shot check
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVersion());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkVersion();
    }
  }

  Future<void> _checkVersion() async {
    final result = await AppVersionService().check();
    _handleResult(result);
  }

  void _handleResult(AppVersionCheckResult result) {
    if (!mounted) return;

    final navContext = widget.navigatorKey.currentContext;
    if (navContext == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleResult(result);
      });
      return;
    }

    switch (result.status) {
      case UpdateStatus.requiredUpdate:
        if (result.config != null && !_isDialogOpen) {
          _showUpdateDialog(result.config!);
        }
      case UpdateStatus.maintenance:
        if (result.config != null && !_isDialogOpen) {
          _showMaintenanceDialog(result.config!);
        }
      case UpdateStatus.upToDate:
      case UpdateStatus.unavailable:
        break;
    }
  }

  Future<void> _showUpdateDialog(AppReleaseConfig config) async {
    final navContext = widget.navigatorKey.currentContext;
    if (navContext == null || _isDialogOpen) return;

    _isDialogOpen = true;

    try {
      await showDialog<void>(
        context: navContext,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: _InAppUpdateDialog(
            config: config,
            onOpenBrowser: () => _openDownloadPage(config.downloadUrl),
          ),
        ),
      );
    } finally {
      _isDialogOpen = false;
    }
  }

  Future<void> _showMaintenanceDialog(AppReleaseConfig config) async {
    final navContext = widget.navigatorKey.currentContext;
    if (navContext == null || _isDialogOpen) return;

    _isDialogOpen = true;

    try {
      await showDialog<void>(
        context: navContext,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Temporarily unavailable'),
            content: Text(config.updateMessage),
          ),
        ),
      );
    } finally {
      _isDialogOpen = false;
    }
  }

  Future<void> _openDownloadPage(String configuredUrl) async {
    final configuredUri = Uri.tryParse(configuredUrl);
    final uri = configuredUri != null && configuredUri.hasScheme
        ? configuredUri
        : _fallbackDownloadUrl;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _InAppUpdateDialog extends StatefulWidget {
  final AppReleaseConfig config;
  final VoidCallback onOpenBrowser;

  const _InAppUpdateDialog({
    required this.config,
    required this.onOpenBrowser,
  });

  @override
  State<_InAppUpdateDialog> createState() => _InAppUpdateDialogState();
}

class _InAppUpdateDialogState extends State<_InAppUpdateDialog> {
  bool _isDownloading = false;
  bool _isInstalling = false;
  String? _errorMessage;
  ApkDownloadProgress _progress = const ApkDownloadProgress(
    progress: 0.0,
    receivedBytes: 0,
    totalBytes: 0,
  );

  void _startUpdate() {
    final apkUrl = widget.config.downloadUrl.trim();

    // If not a direct APK link or custom scheme, open in browser as fallback
    if (!apkUrl.toLowerCase().endsWith('.apk') &&
        !apkUrl.contains('/releases/download/') &&
        !apkUrl.contains('/releases/latest/download/')) {
      widget.onOpenBrowser();
      return;
    }

    setState(() {
      _isDownloading = true;
      _isInstalling = false;
      _errorMessage = null;
      _progress = const ApkDownloadProgress(
        progress: 0.0,
        receivedBytes: 0,
        totalBytes: 0,
      );
    });

    ApkUpdateService().downloadAndInstall(
      apkUrl: apkUrl,
      onProgress: (progress) {
        if (!mounted) return;
        setState(() {
          _progress = progress;
          if (progress.progress >= 0.999) {
            _isInstalling = true;
          }
        });
      },
      onError: (errMsg) {
        if (!mounted) return;
        setState(() {
          _isDownloading = false;
          _isInstalling = false;
          _errorMessage = errMsg;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  color: Color(0xFF198754),
                  size: 38,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _isInstalling
                    ? 'Installing update...'
                    : _isDownloading
                        ? 'Downloading update...'
                        : 'Update required',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF17251D),
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage ?? 'Please update to the latest version to continue using VISAAIA.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                      color: _errorMessage != null
                          ? const Color(0xFFD32F2F)
                          : const Color(0xFF5B665F),
                    ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7F5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.new_releases_outlined,
                      size: 19,
                      color: Color(0xFF198754),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Latest version  v${widget.config.release.latestVersion}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF31473A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Active Download Progress Section
              if (_isDownloading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress.totalBytes > 0 ? _progress.progress : null,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFE0E0E0),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF198754),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_progress.percentage}% completed',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF31473A),
                      ),
                    ),
                    if (_progress.speedText.isNotEmpty)
                      Text(
                        _progress.speedText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7A847E),
                        ),
                      ),
                    Text(
                      '${_progress.receivedMB} MB / ${_progress.totalMB} MB',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7A847E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Action Buttons
              if (!_isDownloading) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _startUpdate,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF198754),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.download_rounded),
                    label: Text(
                      _errorMessage != null ? 'Retry update' : 'Update now',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],

              // Fallback open in browser option
              if (_errorMessage != null || !_isDownloading) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: widget.onOpenBrowser,
                  icon: const Icon(Icons.open_in_browser, size: 16),
                  label: const Text(
                    'Download from landing page instead',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF198754),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 8),
              const Text(
                'You need the latest version to continue using VISAAIA.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Color(0xFF7A847E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
