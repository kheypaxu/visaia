import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visaia/services/connectivity_service.dart';

void main() {
  test(
    'temporary probe failures keep online; repeated failures and recovery update state',
    () async {
      var reachable = false;
      var transport = ConnectivityResult.wifi;
      final service = ConnectivityService.forTesting(
        checkTransport: () async => [transport],
        probeInternet: () async => reachable,
      );
      addTearDown(service.dispose);
      expect(await service.checkConnection(), isTrue);
      expect(await service.checkConnection(), isTrue);
      expect(await service.checkConnection(), isFalse);
      final restored = expectLater(service.onConnectivityRestored, emits(true));
      reachable = true;
      expect(await service.checkConnection(), isTrue);
      await restored;
      reachable = false;
      expect(await service.checkConnection(), isTrue);
      transport = ConnectivityResult.none;
      expect(await service.checkConnection(), isFalse);
    },
  );

  test('a failed platform query preserves the last known state', () async {
    final service = ConnectivityService.forTesting(
      checkTransport: () async => throw StateError('Platform unavailable'),
      probeInternet: () async => true,
    );
    addTearDown(service.dispose);
    expect(await service.checkConnection(), isTrue);
  });
}
