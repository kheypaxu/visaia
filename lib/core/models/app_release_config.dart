class PlatformReleaseConfig {
  const PlatformReleaseConfig({
    required this.latestVersion,
    required this.latestBuild,
    this.minBuild = 0,
    this.minVersion = '',
  });

  final String latestVersion;
  final int latestBuild;
  final int minBuild;
  final String minVersion;

  factory PlatformReleaseConfig.fromMap(
    Map<String, dynamic> data, {
    String platform = 'android',
  }) {
    Map<String, dynamic> platformData = {};
    if (data[platform] is Map) {
      platformData = Map<String, dynamic>.from(data[platform] as Map);
    }

    int parseInt(List<dynamic> candidates, [int fallback = 0]) {
      for (final val in candidates) {
        if (val == null) continue;
        if (val is num) return val.toInt();
        if (val is String) {
          final parsed = int.tryParse(val.trim()) ??
              double.tryParse(val.trim())?.toInt();
          if (parsed != null) return parsed;
        }
      }
      return fallback;
    }

    String parseString(List<dynamic> candidates, [String fallback = '']) {
      for (final val in candidates) {
        if (val == null) continue;
        final str = val.toString().trim();
        if (str.isNotEmpty) return str;
      }
      return fallback;
    }

    final latestBuild = parseInt([
      platformData['latestBuild'],
      platformData['buildNumber'],
      platformData['build'],
      platformData['latest_build'],
      data['latestBuild'],
      data['buildNumber'],
      data['build'],
      data['latest_build'],
    ]);

    final minBuild = parseInt([
      platformData['minBuild'],
      platformData['min_build'],
      platformData['minimumBuild'],
      data['minBuild'],
      data['min_build'],
      data['minimumBuild'],
    ]);

    final latestVersion = parseString([
      platformData['latestVersion'],
      platformData['version'],
      platformData['latest_version'],
      data['latestVersion'],
      data['version'],
      data['latest_version'],
    ], '2.0.0');

    final minVersion = parseString([
      platformData['minVersion'],
      platformData['min_version'],
      data['minVersion'],
      data['min_version'],
    ]);

    return PlatformReleaseConfig(
      latestVersion: latestVersion,
      latestBuild: latestBuild,
      minBuild: minBuild,
      minVersion: minVersion,
    );
  }
}

class AppReleaseConfig {
  const AppReleaseConfig({
    required this.release,
    required this.downloadUrl,
    required this.updateMessage,
    required this.maintenanceMode,
  });

  final PlatformReleaseConfig release;
  final String downloadUrl;
  final String updateMessage;
  final bool maintenanceMode;

  factory AppReleaseConfig.fromMap(
    Map<String, dynamic> data, {
    required String platform,
  }) {
    Map<String, dynamic> platformData = {};
    if (data[platform] is Map) {
      platformData = Map<String, dynamic>.from(data[platform] as Map);
    }

    String parseString(List<dynamic> candidates, [String fallback = '']) {
      for (final val in candidates) {
        if (val == null) continue;
        final str = val.toString().trim();
        if (str.isNotEmpty) return str;
      }
      return fallback;
    }

    bool parseBool(List<dynamic> candidates, [bool fallback = false]) {
      for (final val in candidates) {
        if (val == null) continue;
        if (val is bool) return val;
        if (val is String) {
          final s = val.toLowerCase().trim();
          if (s == 'true' || s == '1' || s == 'yes') return true;
          if (s == 'false' || s == '0' || s == 'no') return false;
        }
        if (val is num) return val != 0;
      }
      return fallback;
    }

    final downloadUrl = parseString([
      platformData['downloadUrl'],
      platformData['apkUrl'],
      platformData['download_url'],
      platformData['url'],
      platformData['apk_url'],
      data['downloadUrl'],
      data['apkUrl'],
      data['download_url'],
      data['url'],
      data['apk_url'],
    ], 'https://visaialanding.vercel.app/download');

    final updateMessage = parseString([
      platformData['updateMessage'],
      platformData['message'],
      platformData['releaseNotes'],
      platformData['notes'],
      data['updateMessage'],
      data['message'],
      data['releaseNotes'],
      data['notes'],
    ], 'A newer version of VISAAIA is available. Please update to continue.');

    final maintenanceMode = parseBool([
      platformData['maintenanceMode'],
      platformData['maintenance_mode'],
      platformData['maintenance'],
      data['maintenanceMode'],
      data['maintenance_mode'],
      data['maintenance'],
    ], false);

    return AppReleaseConfig(
      release: PlatformReleaseConfig.fromMap(data, platform: platform),
      downloadUrl: downloadUrl,
      updateMessage: updateMessage,
      maintenanceMode: maintenanceMode,
    );
  }
}
