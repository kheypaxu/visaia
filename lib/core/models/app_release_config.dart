class PlatformReleaseConfig {
  const PlatformReleaseConfig({
    required this.latestVersion,
    required this.latestBuild,
    required this.minimumBuild,
  });

  final String latestVersion;
  final int latestBuild;
  final int minimumBuild;

  factory PlatformReleaseConfig.fromMap(Map<String, dynamic> data) {
    return PlatformReleaseConfig(
      latestVersion: data['latestVersion'] as String? ?? '',
      latestBuild: (data['latestBuild'] as num?)?.toInt() ?? 0,
      minimumBuild: (data['minimumBuild'] as num?)?.toInt() ?? 0,
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
    final platformData = data[platform];
    if (platformData is! Map) {
      throw FormatException('Missing release configuration for $platform.');
    }

    return AppReleaseConfig(
      release: PlatformReleaseConfig.fromMap(
        Map<String, dynamic>.from(platformData),
      ),
      downloadUrl: data['downloadUrl'] as String? ?? '',
      updateMessage:
          data['updateMessage'] as String? ??
          'A newer version of VISAAIA is available.',
      maintenanceMode: data['maintenanceMode'] as bool? ?? false,
    );
  }
}
