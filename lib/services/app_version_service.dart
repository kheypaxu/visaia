import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:visaia/core/models/app_release_config.dart';

enum UpdateStatus { upToDate, requiredUpdate, maintenance, unavailable }

class AppVersionCheckResult {
  const AppVersionCheckResult({required this.status, this.config});

  final UpdateStatus status;
  final AppReleaseConfig? config;
}

class AppVersionService {
  AppVersionService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<AppVersionCheckResult> check() async {
    final platform = _platformName;
    if (platform == null) {
      return const AppVersionCheckResult(status: UpdateStatus.unavailable);
    }

    try {
      final results = await Future.wait<Object>([
        _firestore.collection('app_config').doc('release').get(),
        PackageInfo.fromPlatform(),
      ]);
      final snapshot = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final packageInfo = results[1] as PackageInfo;
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return const AppVersionCheckResult(status: UpdateStatus.unavailable);
      }

      final config = AppReleaseConfig.fromMap(data, platform: platform);
      if (config.maintenanceMode) {
        return AppVersionCheckResult(
          status: UpdateStatus.maintenance,
          config: config,
        );
      }

      final installedBuild = int.tryParse(packageInfo.buildNumber);
      if (installedBuild == null) {
        return const AppVersionCheckResult(status: UpdateStatus.unavailable);
      }

      return AppVersionCheckResult(
        status: compareBuilds(
          installedBuild: installedBuild,
          latestBuild: config.release.latestBuild,
        ),
        config: config,
      );
    } catch (error, stackTrace) {
      debugPrint('App version check failed: $error\n$stackTrace');
      return const AppVersionCheckResult(status: UpdateStatus.unavailable);
    }
  }

  static UpdateStatus compareBuilds({
    required int installedBuild,
    required int latestBuild,
  }) {
    if (installedBuild < latestBuild) {
      return UpdateStatus.requiredUpdate;
    }
    return UpdateStatus.upToDate;
  }

  String? get _platformName {
    if (kIsWeb) return null;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
  }
}
