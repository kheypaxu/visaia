import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:visaia/services/auth_cache_service.dart';

class FarmProvider extends ChangeNotifier {
  String? _activeFarmId;
  String? _activeFarmName;
  bool _isLoading = true;

  String? get activeFarmId => _activeFarmId;
  String? get activeFarmName => _activeFarmName;
  bool get isLoading => _isLoading;

  final AuthCacheService _cacheService = AuthCacheService();

  Future<void> init() async {
    await _cacheService.init();

    // 1. Immediately populate from local cache if available (instant offline UI)
    if (_cacheService.cachedActiveFarmId != null) {
      _activeFarmId = _cacheService.cachedActiveFarmId;
      _activeFarmName = _cacheService.cachedActiveFarmName ?? 'My Farm';
      _isLoading = false;
      notifyListeners();
    }

    final uid = FirebaseAuth.instance.currentUser?.uid ?? _cacheService.cachedUid;
    if (uid == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    // 2. Fetch from Firestore (will resolve from cache offline or server online)
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('farms')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();
      } catch (orderErr) {
        debugPrint('FarmProvider orderBy error, fallback to simple get: $orderErr');
        snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('farms')
            .limit(1)
            .get();
      }

      if (snapshot.docs.isNotEmpty) {
        _activeFarmId = snapshot.docs.first.id;
        _activeFarmName = snapshot.docs.first.data()['name'] ?? 'My Farm';
        await _cacheService.updateFarmData(
          activeFarmId: _activeFarmId,
          activeFarmName: _activeFarmName,
        );
      }
    } catch (e) {
      debugPrint('FarmProvider init error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void switchFarm(String farmId, String farmName) {
    _activeFarmId = farmId;
    _activeFarmName = farmName;
    _cacheService.updateFarmData(
      activeFarmId: farmId,
      activeFarmName: farmName,
    );
    notifyListeners(); // all screens listening will rebuild
  }

  // Clear the farm selection
  void clearFarm() {
    _activeFarmId = null;
    _activeFarmName = null;
    _cacheService.updateFarmData(
      activeFarmId: null,
      activeFarmName: null,
    );
    notifyListeners();
  }
}