import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:visaia/services/report_map_location_resolver.dart';

void main() {
  Map<String, dynamic> site(double lat, double lng) => {
    'boundaries': [
      {'lat': lat - 1, 'lng': lng - 1},
      {'lat': lat - 1, 'lng': lng + 1},
      {'lat': lat + 1, 'lng': lng + 1},
      {'lat': lat + 1, 'lng': lng - 1},
    ],
  };

  test('Linked field overrides remote upload GPS and linked farm', () async {
    final docs = {
      'users/owner/fields/field': site(10, 122),
      'users/owner/farms/farm': site(20, 120),
    };
    final resolver = ReportMapLocationResolver(
      read: (path) async => docs[path],
    );
    expect(
      await resolver.resolve({
        'farmerId': 'owner',
        'fieldId': 'field',
        'farmId': 'farm',
        'location': {'lat': 14, 'lng': 121},
      }),
      const LatLng(10, 122),
    );
  });

  test('Legacy cycle-linked reports resolve to farm and reuse reads', () async {
    final reads = <String>[];
    final docs = <String, Map<String, dynamic>>{
      'users/owner/cycles/cycle': {'farmId': 'farm'},
      'users/owner/farms/farm': site(10, 122),
    };
    final resolver = ReportMapLocationResolver(
      read: (path) async {
        reads.add(path);
        return docs[path];
      },
    );
    final report = {'cycleId': 'cycle', 'lat': 14, 'lng': 121};
    expect(
      await resolver.resolve(report, fallbackOwnerId: 'owner'),
      const LatLng(10, 122),
    );
    await resolver.resolve(report, fallbackOwnerId: 'owner');
    expect(reads.length, 2);
  });

  test(
    'Missing field falls back to linked farm, never upload coordinates',
    () async {
      final resolver = ReportMapLocationResolver(
        read: (path) async =>
            path == 'users/owner/farms/farm' ? site(10, 122) : null,
      );
      expect(
        await resolver.resolve({
          'userId': 'owner',
          'field_id': 'missing',
          'farm_id': 'farm',
        }),
        const LatLng(10, 122),
      );
      expect(
        await resolver.resolve({
          'userId': 'owner',
          'fieldId': 'missing',
          'location': {'lat': 14, 'lng': 121},
        }),
        isNull,
      );
    },
  );

  test(
    'Valid geographic zero coordinates are retained; invalid sites are skipped',
    () {
      expect(
        ReportMapLocationResolver.siteLocation({
          'location': {'lat': 0, 'lng': 122},
        }),
        const LatLng(0, 122),
      );
      expect(
        ReportMapLocationResolver.siteLocation({
          'location': {'lat': 100, 'lng': 122},
        }),
        isNull,
      );
    },
  );
}
