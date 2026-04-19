import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class FarmService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveField({
    required String name,
    required List<LatLng> points,
  }) async {
    // Note: In a real app, you'd nest this under a 'users' collection
    await _db.collection('fields').add({
      'name': name,
      'boundaries': points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      'cropName': null,
      'isActive': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}