import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:visaia/services/auth_cache_service.dart';
import 'package:visaia/utils/geo_utils.dart';

class FarmService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _effectiveUid => _auth.currentUser?.uid ?? AuthCacheService().cachedUid;

  // ================= SAVE FARM (AUTO CALCULATE AREA) =================
  Future<void> saveFarm({
    required String name,
    required List<LatLng> points,
  }) async {
    final uid = _effectiveUid;
    if (uid == null) throw Exception('User not authenticated');

    final areaSqm = GeoUtils.calculateAreaSqm(points);
    final acres = GeoUtils.toAcres(areaSqm);

    await _db.collection('users').doc(uid).collection('farms').add({
      'name': name,
      'acres': acres, // ✅ FIXED
      'boundaries': points
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ================= SAVE FIELDS =================
  Future<void> saveFields({
    required String farmId,
    required List<Map<String, dynamic>> fields,
  }) async {
    final uid = _effectiveUid;
    if (uid == null) throw Exception('User not authenticated');

    for (var field in fields) {
      final boundaries = field['boundaries'] as List<LatLng>;

      final areaSqm = GeoUtils.calculateAreaSqm(boundaries);
      final acres = GeoUtils.toAcres(areaSqm);

      await _db.collection('users').doc(uid).collection('fields').add({
        'farmId': farmId,
        'name': field['name'],
        'acres': acres,
        'crop': field['crop'],
        'boundaries': boundaries
            .map((p) => {
                  'lat': p.latitude,
                  'lng': p.longitude,
                })
            .toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}