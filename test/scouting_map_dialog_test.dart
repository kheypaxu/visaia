import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:visaia/services/scouting_map_data.dart';
import 'package:visaia/utils/scouting_week_comparison.dart';
import 'package:visaia/widgets/scouting_map_dialog.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  final current = ScoutingWeekReport('current', {
    'userId': 'owner',
    'cycleId': 'cycle',
    'weekNumber': 3,
    'dap': 14,
    'status': 'resolved',
    'growthStage': 'Current growth',
    'location': {'lat': 10, 'lng': 122},
    'damagePercentage': 5,
    'isHighLevel': false,
  });
  final previous = ScoutingWeekReport('previous', {
    'weekNumber': 2,
    'dap': 7,
    'growthStage': 'Previous growth',
    'location': {'lat': 11, 'lng': 123},
    'damagePercentage': 20,
    'isHighLevel': true,
  });

  Future<void> mount(WidgetTester tester, ScoutingMapData data) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScoutingMapDialog(
            report: data.current,
            load: () async => data,
            showTiles: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('week toggle switches report details and map marker', (
    tester,
  ) async {
    await mount(
      tester,
      ScoutingMapData(
        current: current,
        previous: previous,
        fieldPoint: const LatLng(10, 122),
      ),
    );
    expect(find.text('Current growth'), findsOneWidget);
    expect(find.text('Week-over-week change'), findsOneWidget);
    MarkerLayer layer() => tester.widget<MarkerLayer>(find.byType(MarkerLayer));
    expect(layer().markers.last.point, const LatLng(10, 122));
    await tester.tap(find.text('Last Week (Week 2)'));
    await tester.pumpAndSettle();
    expect(find.text('Previous growth'), findsOneWidget);
    expect(layer().markers.last.point, const LatLng(11, 123));
    await tester.tap(find.text('Current Week (Week 3)'));
    await tester.pumpAndSettle();
    expect(find.text('Current growth'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending and validated reports never display deltas', (
    tester,
  ) async {
    for (final status in ['pending', 'validated', 'controlled']) {
      await tester.pumpWidget(const SizedBox());
      await mount(
        tester,
        ScoutingMapData(
          current: ScoutingWeekReport('current', {
            ...current.data,
            'status': status,
          }),
          previous: previous,
        ),
      );
      expect(find.text('Week-over-week change'), findsNothing);
      await tester.tap(find.text('Last Week (Week 2)'));
      await tester.pumpAndSettle();
      expect(find.text('Previous growth'), findsOneWidget);
    }
  });

  testWidgets('missing week disables its side and missing GPS keeps details', (
    tester,
  ) async {
    final legacy = ScoutingWeekReport('legacy', {
      'dap': 0,
      'status': 'resolved',
      'stationsData': ['bad'],
    });
    await mount(tester, ScoutingMapData(current: legacy));
    expect(find.text('Week 1 has no previous week.'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Last Week'),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.text(
        'No saved report or field coordinates are available. The weekly details remain available below.',
      ),
      findsOneWidget,
    );
    expect(find.text('Week-over-week change'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'small and landscape screens with enlarged text do not overflow',
    (tester) async {
      for (final size in [const Size(375, 667), const Size(667, 375)]) {
        await tester.pumpWidget(const SizedBox());
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: ScoutingMapDialog(
                report: current,
                load: () async =>
                    ScoutingMapData(current: current, previous: previous),
                showTiles: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  testWidgets('failed load offers retry without dismissing the modal', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScoutingMapDialog(
            report: current,
            showTiles: false,
            load: () async {
              if (attempts++ == 0) throw Exception('offline');
              return ScoutingMapData(current: current);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Current growth'), findsOneWidget);
    expect(attempts, 2);
  });
}
