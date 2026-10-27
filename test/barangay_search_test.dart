import 'package:flutter_test/flutter_test.dart';
import 'package:visaia/utils/barangay_search.dart';
import 'package:visaia/utils/location_constants.dart';
import 'package:visaia/data/cabatuan_barangay_areas.dart';

void main() {
  test('every registration barangay is searchable and has a verified area', () {
    expect(
      cabatuanBarangayAreas.keys.toSet(),
      LocationConstants.cabatuanBarangays.toSet(),
    );
    expect(cabatuanBarangayAreas.length, 68);
    expect(
      cabatuanBarangayAreas.values.map((area) => area.psgc).toSet().length,
      68,
    );
    for (final name in LocationConstants.cabatuanBarangays) {
      expect(searchCabatuanBarangays(name), contains(name), reason: name);
      final area = cabatuanBarangayAreas[name]!;
      expect(area.south, lessThan(area.north));
      expect(area.west, lessThan(area.east));
      expect(area.center.latitude, inInclusiveRange(10.7, 11.1));
      expect(area.center.longitude, inInclusiveRange(122.2, 122.7));
      expect(cabatuanMunicipalityArea.bounds.contains(area.center), isTrue);
    }
  });

  test('search accepts prefixes, punctuation and full local addresses', () {
    for (final query in [
      'acao',
      'ACAO',
      'Brgy. Acao',
      'Acao, Cabatuan, Iloilo',
    ]) {
      expect(searchCabatuanBarangays(query), ['Acao']);
    }
    expect(searchCabatuanBarangays('inac'), ['Inaca']);
    expect(searchCabatuanBarangays('lagan'), ['Lag-an']);
    expect(searchCabatuanBarangays('duyanduyan'), ['Duyan-Duyan']);
    expect(searchCabatuanBarangays('pamul ogan'), ['Pamul-ogan']);
    expect(searchCabatuanBarangays('gines'), ['Gines Interior', 'Gines Patag']);
    expect(searchCabatuanBarangays('cabatuan').length, 68);
    expect(searchCabatuanBarangays('barangay').length, 68);
  });

  test('numeric and Roman zones do not confuse Barangay 1 with 10 or 11', () {
    for (final query in ['Zone 1', 'Zone1', 'Barangay 1', 'Zone I']) {
      expect(searchCabatuanBarangays(query), ['Zone I Pob. (Barangay 1)']);
    }
    expect(searchCabatuanBarangays('barangay 10'), [
      'Zone X Pob. (Barangay 10)',
    ]);
    expect(searchCabatuanBarangays('Zone XI'), ['Zone XI Pob. (Barangay 11)']);
    expect(searchCabatuanBarangays('Poblacion').length, 11);
  });

  test('empty and unknown places never produce guessed barangay locations', () {
    expect(searchCabatuanBarangays('  '), isEmpty);
    expect(searchCabatuanBarangays('not a barangay'), isEmpty);
    expect(searchCabatuanBarangays('Acao, Isabela'), isEmpty);
    expect(searchCabatuanBarangays('Agdayao'), isEmpty);
  });
}
