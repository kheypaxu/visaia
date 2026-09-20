import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
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
  AppVersionService({FirebaseFirestore? firestore, Dio? dio})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                headers: {'Accept': 'application/vnd.github.v3+json'},
              ),
            );

  final FirebaseFirestore _firestore;
  final Dio _dio;

  static const String githubRepo = 'kheypaxu/visaia';

  static String? get platformName {
    if (kIsWeb) return null;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
  }

  /// Evaluates whether an update is required given raw config map and PackageInfo.
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

    // If build numbers are available, compare builds
    if (latestBuild > 0 || minBuild > 0) {
      final status = compareBuilds(
        installedBuild: installedBuild,
        latestBuild: latestBuild,
        minBuild: minBuild,
      );
      return AppVersionCheckResult(status: status, config: config);
    }

    // Fallback: compare semantic versions (e.g. "2.0.1" > "2.0.0")
    final isNewer = isVersionHigher(
      installed: packageInfo.version,
      remote: config.release.latestVersion,
    );

    return AppVersionCheckResult(
      status: isNewer ? UpdateStatus.requiredUpdate : UpdateStatus.upToDate,
      config: config,
    );
  }

  /// Checks for updates. Checks Firestore first; if unavailable or older, checks GitHub Releases.
  Future<AppVersionCheckResult> check() async {
    final platform = platformName;
    if (platform == null) {
      return const AppVersionCheckResult(status: UpdateStatus.unavailable);
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();

      // 1. Try Firestore release config first
      try {
        final snapshot = await _firestore
            .collection('app_config')
            .doc('release')
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 4));

        final data = snapshot.data();
        if (snapshot.exists && data != null) {
          final result = evaluate(data: data, packageInfo: packageInfo);
          if (result.status == UpdateStatus.requiredUpdate ||
              result.status == UpdateStatus.maintenance) {
            return result;
          }
        }
      } catch (e) {
        debugPrint('📱 [AppVersion] Firestore check failed/timed out: $e');
      }

      // 2. Query GitHub Releases API directly
      return await checkGitHubReleases(packageInfo);
    } catch (error, stackTrace) {
      debugPrint('📱 [AppVersion] Check failed: $error\n$stackTrace');
      return const AppVersionCheckResult(status: UpdateStatus.unavailable);
    }
  }

  /// Queries GitHub's public API for the latest release
  Future<AppVersionCheckResult> checkGitHubReleases(
    PackageInfo packageInfo,
  ) async {
    try {
      final response = await _dio.get(
        'https://api.github.com/repos/$githubRepo/releases/latest',
      );

      if (response.statusCode != 200 || response.data == null) {
        return const AppVersionCheckResult(status: UpdateStatus.unavailable);
      }

      final data = response.data is Map ? response.data as Map : jsonDecode(response.data);
      final rawTag = (data['tag_name'] ?? '').toString().replaceFirst('v', '').trim();
      final body = (data['body'] ?? '').toString();

      // Extract version and build from tag (e.g. "2.0.1+12" or "2.0.1")
      String remoteVersion = rawTag;
      int remoteBuild = 0;

      if (rawTag.contains('+')) {
        final parts = rawTag.split('+');
        remoteVersion = parts[0];
        remoteBuild = int.tryParse(parts[1]) ?? 0;
      }

      // Find APK download URL in assets
      String apkUrl =
          'https://github.com/$githubRepo/releases/latest/download/visaia-release.apk';
      final assets = data['assets'] as List<dynamic>?;
      if (assets != null && assets.isNotEmpty) {
        for (final asset in assets) {
          final name = (asset['name'] ?? '').toString();
          if (name.endsWith('.apk')) {
            apkUrl = (asset['browser_download_url'] ?? apkUrl).toString();
            break;
          }
        }
      }

      final installedBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      bool updateNeeded = false;

      if (remoteBuild > 0 && installedBuild > 0) {
        updateNeeded = remoteBuild > installedBuild;
      } else {
        updateNeeded = isVersionHigher(
          installed: packageInfo.version,
          remote: remoteVersion,
        );
      }

      debugPrint(
        '📱 [GitHub Releases] Remote: v$remoteVersion+$remoteBuild | '
        'Installed: v${packageInfo.version}+$installedBuild | Update: $updateNeeded',
      );

      final config = AppReleaseConfig(
        release: PlatformReleaseConfig(
          latestVersion: remoteVersion,
          latestBuild: remoteBuild,
        ),
        downloadUrl: apkUrl,
        updateMessage: body.isNotEmpty
            ? body
            : 'A new version of VISAAIA (v$remoteVersion) is available.',
        maintenanceMode: false,
      );

      return AppVersionCheckResult(
        status:
            updateNeeded ? UpdateStatus.requiredUpdate : UpdateStatus.upToDate,
        config: config,
      );
    } catch (e) {
      debugPrint('📱 [AppVersion] GitHub Releases API check error: $e');
      return const AppVersionCheckResult(status: UpdateStatus.unavailable);
    }
  }

  /// Real-time stream of version check results from Firestore
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

  static bool isVersionHigher({
    required String installed,
    required String remote,
  }) {
    final instParts = installed.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final remParts = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final inst = i < instParts.length ? instParts[i] : 0;
      final rem = i < remParts.length ? remParts[i] : 0;
      if (rem > inst) return true;
      if (rem < inst) return false;
    }
    return false;
  }
}
