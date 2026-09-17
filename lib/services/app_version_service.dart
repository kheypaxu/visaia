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

  static String? get platformName {
    if (kIsWeb) return null;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
  }

  /// Evaluates whether an update is required given raw Firestore data and PackageInfo.
  AppVersionCheckResult evaluate({
    required Map<String, dynamic> data,
    required PackageInfo packageInfo,
  }) {
    final platform = platformName;
    if (platform == null) {
      return const AppVersionCheckResult(status: UpdateStatus.unavailable);
    }

    final config = AppReleaseConfig.fromMap(data, platform: platform);
    if (config.maintenanceMode) {
      return AppVersionCheckResult(
        status: UpdateStatus.maintenance,
        config: config,
      );
    }

    final installedBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
    final latestBuild = config.release.latestBuild;
    final minBuild = config.release.minBuild;

    debugPrint(
      '📱 [AppVersion] Installed: v${packageInfo.version}+$installedBuild | '
      'Remote config: v${config.release.latestVersion}+$latestBuild (minBuild: $minBuild)',
    );

    // If config has no build number specified, default to upToDate
    if (latestBuild <= 0 && minBuild <= 0) {
      return AppVersionCheckResult(
        status: UpdateStatus.upToDate,
        config: config,
      );
    }

    final status = compareBuilds(
      installedBuild: installedBuild,
      latestBuild: latestBuild,
      minBuild: minBuild,
    );

    return AppVersionCheckResult(
      status: status,
      config: config,
    );
  }

  /// Performs a one-time check, trying server first then fallback to cache.
  Future<AppVersionCheckResult> check() async {
    final platform = platformName;
    if (platform == null) {
      return const AppVersionCheckResult(status: UpdateStatus.unavailable);
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();

      DocumentSnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _firestore
            .collection('app_config')
            .doc('release')
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('📱 [AppVersion] Server fetch timed out or failed, using cache: $e');
        snapshot = await _firestore
            .collection('app_config')
            .doc('release')
            .get();
      }

      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        debugPrint('📱 [AppVersion] app_config/release doc does not exist.');
        return const AppVersionCheckResult(status: UpdateStatus.unavailable);
      }

      return evaluate(data: data, packageInfo: packageInfo);
    } catch (error, stackTrace) {
      debugPrint('📱 [AppVersion] Check failed: $error\n$stackTrace');
      return const AppVersionCheckResult(status: UpdateStatus.unavailable);
    }
  }

  /// Real-time stream of version check results
  Stream<AppVersionCheckResult> streamResults() async* {
    final platform = platformName;
    if (platform == null) return;

    PackageInfo? packageInfo;
    try {
      packageInfo = await PackageInfo.fromPlatform();
    } catch (e) {
      debugPrint('📱 [AppVersion] Could not load PackageInfo: $e');
      return;
    }

    yield* _firestore
        .collection('app_config')
        .doc('release')
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return const AppVersionCheckResult(status: UpdateStatus.unavailable);
      }
      return evaluate(data: data, packageInfo: packageInfo!);
    }).handleError((error) {
      debugPrint('📱 [AppVersion] Snapshot stream error: $error');
      return const AppVersionCheckResult(status: UpdateStatus.unavailable);
    });
  }

  static UpdateStatus compareBuilds({
    required int installedBuild,
    required int latestBuild,
    int minBuild = 0,
  }) {
    if (minBuild > 0 && installedBuild < minBuild) {
      return UpdateStatus.requiredUpdate;
    }
    if (latestBuild > 0 && installedBuild < latestBuild) {
      return UpdateStatus.requiredUpdate;
    }
    return UpdateStatus.upToDate;
  }
}
