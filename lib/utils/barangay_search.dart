import 'package:visaia/utils/location_constants.dart';

String _normalizeBarangayQuery(String value) => value
    .toLowerCase()
    .replaceAll('ñ', 'n')
    .replaceAll(RegExp(r'\b(poblacion|pob)\b'), 'zone')
    .replaceAllMapped(RegExp(r'([a-z])(\d)'), (m) => '${m[1]} ${m[2]}')
    .replaceAll(
      RegExp(r'\b(brgy|barangay|cabatuan|iloilo|philippines|province)\b'),
      ' ',
    )
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim();

/// Uses exactly the same labels as registration, including all eleven zones.
List<String> searchCabatuanBarangays(String query) {
  if (query.trim().isEmpty) return [];
  final normalized = _normalizeBarangayQuery(query);
  if (normalized.isEmpty) {
    return RegExp(r'\b(cabatuan|brgy|barangay)\b', caseSensitive: false).hasMatch(query)
        ? List.of(LocationConstants.cabatuanBarangays)
        : [];
  }
  final tokens = normalized.split(RegExp(r'\s+'));
  return LocationConstants.cabatuanBarangays.where((name) {
    final candidate = _normalizeBarangayQuery(name);
    final words = candidate.split(RegExp(r'\s+'));
    return tokens.every((token) {
      if (RegExp(r'^\d+$').hasMatch(token) ||
          (tokens.contains('zone') && RegExp(r'^[ivx]+$').hasMatch(token))) {
        return words.contains(token);
      }
      return words.any((word) => word.contains(token)) ||
          candidate.replaceAll(' ', '').contains(token);
    });
  }).toList();
}
