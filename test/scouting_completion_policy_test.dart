import 'package:flutter_test/flutter_test.dart';
import 'package:visaia/utils/scouting_completion_policy.dart';

void main() {
  test('verified but unfinished stations remain available for assignment', () {
    expect(
      isScoutingStationCompleted({
        'completed': false,
        'verificationCompleted': true,
      }),
      isFalse,
    );
    expect(
      isScoutingStationCompleted({'verificationCompleted': true}),
      isFalse,
    );
    expect(isScoutingStationCompleted({'completed': true}), isTrue);
    expect(isScoutingStationCompleted(null), isFalse);
  });

  test('five verified stations do not finish a scouting week', () {
    final stations = List.generate(
      5,
      (_) => {'completed': false, 'verificationCompleted': true},
    );
    expect(
      isScoutingWeekCompleted({'stations': stations, 'completedStations': 0}),
      isFalse,
    );
    stations[0]['completed'] = true;
    expect(
      isScoutingWeekCompleted({'stations': stations, 'completedStations': 1}),
      isFalse,
    );
    for (final station in stations) {
      station['completed'] = true;
    }
    expect(isScoutingWeekCompleted({'stations': stations}), isTrue);
  });

  test(
    'explicit finished weeks stay locked and incomplete legacy data does not',
    () {
      for (final week in [
        {'status': 'completed'},
        {'isCompleted': true},
        {'completedStations': 5},
      ]) {
        expect(isScoutingWeekCompleted(week), isTrue);
      }
      for (final week in <Map<String, dynamic>>[
        {},
        {'stations': []},
        {
          'stations': [null],
        },
        {
          'completedStations': '5',
          'stations': [
            {'verificationCompleted': true},
          ],
        },
      ]) {
        expect(isScoutingWeekCompleted(week), isFalse);
      }
    },
  );

  test(
    'a new observation with enough photos still requires Monitoring review',
    () {
      final photos = ['photo1', 'photo2'];
      final scores = [
        {'plantNumber': 1, 'whorlScore': 2},
      ];
      final station = <String, dynamic>{
        'completed': false,
        'verificationCompleted': true,
        'verificationRequired': false,
        'larvae': 2,
        'capturedImages': {'larvae': photos},
        'damagePhotos': ['damage1'],
        'plantDamageScores': scores,
      };
      requireAssignedObservationVerification(station);
      expect(station['verificationRequired'], isTrue);
      expect(station['verificationCompleted'], isFalse);
      expect(isScoutingStationCompleted(station), isFalse);
      expect(station['larvae'], 2);
      expect((station['capturedImages'] as Map)['larvae'], same(photos));
      expect(station['damagePhotos'], ['damage1']);
      expect(station['plantDamageScores'], same(scores));
    },
  );

  test('assignment without a photo also requires review', () {
    final station = <String, dynamic>{'completed': false, 'moths': 1};
    requireAssignedObservationVerification(station);
    expect(station['verificationRequired'], isTrue);
    expect(station['verificationCompleted'], isFalse);
    expect(station['completed'], isFalse);
  });
}
