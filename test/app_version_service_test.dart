import 'package:flutter_test/flutter_test.dart';
import 'package:visaia/services/app_version_service.dart';

void main() {
  group('AppVersionService.compareBuilds', () {
    test('reports an up-to-date build', () {
      expect(
        AppVersionService.compareBuilds(
          installedBuild: 5,
          latestBuild: 5,
          minimumBuild: 3,
        ),
        UpdateStatus.upToDate,
      );
    });

    test('reports an optional update', () {
      expect(
        AppVersionService.compareBuilds(
          installedBuild: 4,
          latestBuild: 5,
          minimumBuild: 3,
        ),
        UpdateStatus.optionalUpdate,
      );
    });

    test('reports a required update', () {
      expect(
        AppVersionService.compareBuilds(
          installedBuild: 2,
          latestBuild: 5,
          minimumBuild: 3,
        ),
        UpdateStatus.requiredUpdate,
      );
    });
  });
}
