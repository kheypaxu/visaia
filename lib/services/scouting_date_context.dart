import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:visaia/services/firestore_safe_ext.dart';
import 'package:visaia/utils/scouting_display_date.dart';

/// Read-only planting-date lookup, cached for one report-history session.
class ScoutingDateContext {
  final Future<Map<String, dynamic>?> Function(String path) _read;
  final _documents = <String, Future<Map<String, dynamic>?>>{};
  ScoutingDateContext({
    Future<Map<String, dynamic>?> Function(String path)? read,
  }) : _read =
           read ??
           ((path) async =>
               (await FirebaseFirestore.instance.doc(path).safeGet()).data());

  Future<Map<String, dynamic>?> _get(String path) =>
      _documents.putIfAbsent(path, () async {
        try {
          return await _read(path);
        } catch (_) {
          return null;
        }
      });
  String? _id(Object? value) =>
      value is String && value.trim().isNotEmpty && !value.contains('/')
      ? value.trim()
      : null;

  Future<Map<String, dynamic>> withPlantingDate(
    Map<String, dynamic> data, {
    String? fallbackOwnerId,
  }) async {
    final info = data['cycleInfo'];
    if (parseScoutingDate(data['plantingDate']) != null ||
        (info is Map && parseScoutingDate(info['plantingDate']) != null)) {
      return data;
    }
    final cycle = _id(data['cycleId']);
    if (cycle == null) return data;
    final owner =
        _id(data['userId']) ?? _id(data['farmerId']) ?? _id(fallbackOwnerId);
    final paths = [
      if (owner != null) 'users/$owner/cycles/$cycle',
      'cycles/$cycle',
    ];
    for (final path in paths) {
      final document = await _get(path);
      if (parseScoutingDate(document?['plantingDate']) != null) {
        return {...data, 'plantingDate': document!['plantingDate']};
      }
    }
    return data;
  }
}
