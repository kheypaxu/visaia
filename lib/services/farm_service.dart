import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';

class FarmService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Save farm boundary
  Future<void> saveFarm({
    required String name,
    required List<LatLng> points,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _db.collection('users').doc(user.uid).collection('farms').add({
      'name': name,
      'boundaries': points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Save fields for a farm
  Future<void> saveFields({
    required List<Map<String, dynamic>> fields,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    for (var field in fields) {
      final boundaries = field['boundaries'] as List<LatLng>?;
      
      await _db.collection('users').doc(user.uid).collection('fields').add({
        'name': field['name'],
        'acres': field['acres'] ?? 0,
        'crop': field['crop'],
        'boundaries': boundaries?.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList() ?? [],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}