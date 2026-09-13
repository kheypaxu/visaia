import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Monitors network connectivity and broadcasts real-time online/offline state.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);
  final StreamController<bool> _reconnectedController =
      StreamController<bool>.broadcast();

  Stream<bool> get onConnectivityRestored => _reconnectedController.stream;

  bool get isOnline => isOnlineNotifier.value;
  bool _lastStatus = true;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final initialResults = await _connectivity.checkConnectivity();
      _updateStatus(initialResults);
    } catch (e) {
      debugPrint('Error checking initial connectivity: $e');
    }

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _updateStatus(results);
    });
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final online = results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn);

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
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);
      return isOnline;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _reconnectedController.close();
  }
}
