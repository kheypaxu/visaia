import 'package:flutter_test/flutter_test.dart';
import 'package:visaia/services/app_version_service.dart';

void main() {
  group('AppVersionService.compareBuilds', () {
    test('reports an up-to-date build', () {
      expect(
        AppVersionService.compareBuilds(installedBuild: 5, latestBuild: 5),
        UpdateStatus.upToDate,
      );
    });

    test('requires an update for any older build', () {
      expect(
        AppVersionService.compareBuilds(installedBuild: 4, latestBuild: 5),
        UpdateStatus.requiredUpdate,
      );
    });
  });
}
