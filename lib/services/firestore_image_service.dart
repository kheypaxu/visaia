import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Stores each compressed image in a separate Firestore document. Other
/// documents retain only a small reference, avoiding Firestore's 1 MiB limit.
class FirestoreImageService {
  static const referencePrefix = 'firestore-image://';
  static const int maxEncodedBytes = 850000;

  static Future<String> upload({
    required Uint8List bytes,
    required String userId,
    required String cycleId,
    required String category,
    int? stationIndex,
  }) async {
    final encoded = base64Encode(bytes);
    if (encoded.length > maxEncodedBytes) {
      throw StateError('The compressed image is still too large. Please choose a smaller image.');
    }

    final imageRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cycles')
        .doc(cycleId)
        .collection('images')
        .doc();

    await imageRef.set({
      'data': encoded,
      'contentType': 'image/jpeg',
      'category': category,
      if (stationIndex != null) 'stationIndex': stationIndex,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return '$referencePrefix${imageRef.path}';
  }

  static Future<Uint8List> load(String reference) async {
    if (!reference.startsWith(referencePrefix)) {
      final encoded = reference.contains(',')
          ? reference.substring(reference.indexOf(',') + 1)
          : reference;
      return base64Decode(encoded);
    }

    final path = reference.substring(referencePrefix.length);
    DocumentSnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await FirebaseFirestore.instance.doc(path).get();
    } catch (_) {
      snapshot = await FirebaseFirestore.instance
          .doc(path)
          .get(const GetOptions(source: Source.cache));
    }
    final data = snapshot.data()?['data'];
    if (data is! String || data.isEmpty) {
      throw StateError('Image no longer exists');
    }
    return base64Decode(data);
  }

  static Future<void> delete(String reference) async {
    if (!reference.startsWith(referencePrefix)) return;
    await FirebaseFirestore.instance
        .doc(reference.substring(referencePrefix.length))
        .delete();
  }
}
