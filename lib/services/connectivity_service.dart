import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Monitors network connectivity and broadcasts real-time online/offline state.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  @visibleForTesting
  ConnectivityService.forTesting({
    required Future<List<ConnectivityResult>> Function() checkTransport,
    required Future<bool> Function() probeInternet,
  }) : _checkTransport = checkTransport,
       _probeInternet = probeInternet;

  Future<List<ConnectivityResult>> Function()? _checkTransport;
  Future<bool> Function()? _probeInternet;

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);
  final StreamController<bool> _reconnectedController =
      StreamController<bool>.broadcast();

  Stream<bool> get onConnectivityRestored => _reconnectedController.stream;

  bool get isOnline => isOnlineNotifier.value;
  bool _lastStatus = true;
  bool _isInitialized = false;
  Timer? _probeTimer;
  int _probeGeneration = 0;
  int _failedProbes = 0;

  Future<bool> _hasInternet() async {
    // Independent hosts avoid treating one blocked/slow endpoint as an outage.
    final checks =
        [
          'https://www.gstatic.com/generate_204',
          'https://cp.cloudflare.com/generate_204',
        ].map((url) async {
          final client = http.Client();
          try {
            final response = await client
                .get(Uri.parse(url))
                .timeout(const Duration(seconds: 8));
            return response.statusCode == 204;
          } catch (_) {
            return false;
          } finally {
            client.close();
          }
        });
    return (await Future.wait(checks)).any((reachable) => reachable);
  }

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final initialResults = await _connectivity.checkConnectivity();
      await _updateStatus(initialResults);
    } catch (e) {
      debugPrint('Error checking initial connectivity: $e');
    }

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      unawaited(_updateStatus(results));
    });
    _probeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(checkConnection());
    });
  }

  Future<void> _updateStatus(List<ConnectivityResult> results) async {
    final generation = ++_probeGeneration;
    final hasTransport = results.any((r) => r != ConnectivityResult.none);
    var online = hasTransport;

    if (online) {
      online = await (_probeInternet ?? _hasInternet)();
    }
    if (generation != _probeGeneration) return;

    if (online || !hasTransport) {
      _failedProbes = 0;
    } else {
      _failedProbes++;
      // A transient probe failure must not switch the entire app offline.
      if (_failedProbes < 3) return;
    }

    final wasOffline = !_lastStatus;
    _lastStatus = online;
    isOnlineNotifier.value = online;

    if (wasOffline && online) {
      debugPrint('🌐 Network connection restored!');
      _reconnectedController.add(true);
    } else if (!online) {
      debugPrint('📴 Network connection lost. Operating in offline mode.');
    }
  }

  Future<bool> checkConnection() async {
    try {
      final results =
          await (_checkTransport ?? _connectivity.checkConnectivity)();
      await _updateStatus(results);
      return isOnline;
    } catch (e) {
      // A platform-check failure is inconclusive, not evidence of an outage.
      return isOnline;
    }
  }

  void dispose() {
    _probeGeneration++;
    _probeTimer?.cancel();
    _subscription?.cancel();
    _reconnectedController.close();
  }
}
