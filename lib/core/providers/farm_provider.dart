import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FarmProvider extends ChangeNotifier {
  String? _activeFarmId;
  String? _activeFarmName;
  bool _isLoading = true;

  String? get activeFarmId => _activeFarmId;
  String? get activeFarmName => _activeFarmName;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('farms')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      _activeFarmId = snapshot.docs.first.id;
      _activeFarmName = snapshot.docs.first.data()['name'] ?? 'My Farm';
    } else {
      // No farms found, clear the active farm
      _activeFarmId = null;
      _activeFarmName = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  void switchFarm(String farmId, String farmName) {
    _activeFarmId = farmId;
    _activeFarmName = farmName;
    notifyListeners(); // all screens listening will rebuild
  }

  // Add this method to clear the farm selection
  void clearFarm() {
    _activeFarmId = null;
    _activeFarmName = null;
    notifyListeners();
  }
}