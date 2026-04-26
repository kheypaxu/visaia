import 'package:latlong2/latlong.dart';

class FieldModel {
  final String id;
  final String name;
  final double acres;
  final String? crop;
  final List<LatLng> boundaries;

  FieldModel({
    required this.id,
    required this.name,
    required this.acres,
    required this.boundaries,
    this.crop,
  });

  factory FieldModel.fromMap(String id, Map<String, dynamic> data) {
    return FieldModel(
      id: id,
      name: data['name'] ?? '',
      acres: (data['acres'] ?? 0).toDouble(),
      crop: data['crop'],
      boundaries: (data['boundaries'] as List)
          .map((p) => LatLng(
                (p['latitude'] ?? p['lat']).toDouble(),
                (p['longitude'] ?? p['lng']).toDouble(),
              ))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'acres': acres,
      'crop': crop,
      'boundaries': boundaries
          .map((p) => {
                'lat': p.latitude,
                'lng': p.longitude,
              })
          .toList(),
    };
  }
}