import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visaia/core/models/app_release_config.dart';
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

class _AppVersionGateState extends State<AppVersionGate> {
  static final Uri _fallbackDownloadUrl = Uri.parse(
    'https://visaialanding.vercel.app/download',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVersion());
  }

  Future<void> _checkVersion() async {
    final result = await AppVersionService().check();
    if (!mounted ||
        result.config == null ||
        widget.navigatorKey.currentContext == null) {
      return;
    }

    switch (result.status) {
      case UpdateStatus.requiredUpdate:
        await _showUpdateDialog(result.config!, required: true);
      case UpdateStatus.maintenance:
        await _showMaintenanceDialog(result.config!);
      case UpdateStatus.upToDate:
      case UpdateStatus.unavailable:
        return;
    }
  }

  Future<void> _showUpdateDialog(
    AppReleaseConfig config, {
    required bool required,
  }) {
    return showDialog<void>(
      context: widget.navigatorKey.currentContext!,
      barrierDismissible: !required,
      builder: (dialogContext) => PopScope(
        canPop: !required,
        child: AlertDialog(
          title: Text(required ? 'Update required' : 'Update available'),
          content: Text(
            '${config.updateMessage}\n\nLatest version: '
            '${config.release.latestVersion}',
          ),
          actions: [
            if (!required)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Later'),
              ),
            FilledButton(
              onPressed: () => _openDownloadPage(config.downloadUrl),
              child: const Text('Download update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMaintenanceDialog(AppReleaseConfig config) {
    return showDialog<void>(
      context: widget.navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Temporarily unavailable'),
          content: Text(config.updateMessage),
        ),
      ),
    );
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
