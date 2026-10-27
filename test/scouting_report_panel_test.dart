import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:visaia/services/scouting_map_data.dart';
import 'package:visaia/utils/scouting_week_comparison.dart';
import 'package:visaia/widgets/report_detail_tabs.dart';
import 'package:visaia/widgets/scouting_report_panel.dart';

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
    'totalInspected': 100,
    'totalDamaged': 5,
    'totals': {'eggs': 1, 'larvae': 3, 'pupae': 0, 'moths': 1},
  });
  final previous = ScoutingWeekReport('previous', {
    'weekNumber': 2,
    'dap': 7,
    'growthStage': 'Previous growth',
    'location': {'lat': 11, 'lng': 123},
    'damagePercentage': 20,
    'isHighLevel': true,
  });

  Future<void> mount(
    WidgetTester tester,
    ScoutingMapData data, {
    Future<ScoutingMapData> Function()? load,
    double scale = 1,
  }) async {
    final selection = ValueNotifier<bool>(false);
    addTearDown(selection.dispose);
    ScoutingReportPanel panel(ScoutingPanelMode mode) => ScoutingReportPanel(
      key: ValueKey(mode),
      report: data.current,
      mode: mode,
      selectedWeek: selection,
      load: load ?? () async => data,
      showTiles: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: ReportDetailTabs(
            expandedHeight: 160,
            header: const SliverAppBar(
              pinned: true,
              expandedHeight: 160,
              title: Text('Report'),
            ),
            sections: [
              ReportDetailSection('Overview', [
                panel(ScoutingPanelMode.overviewMap),
              ]),
              ReportDetailSection('Week analysis', [
                panel(ScoutingPanelMode.weekAnalysis),
              ]),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openAnalysis(WidgetTester tester) async {
    await tester.tap(find.text('Week analysis'));
    await tester.pumpAndSettle();
  }

  testWidgets('overview embeds the map; analysis owns the toggle and details', (
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
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Last Week (Week 2)'), findsNothing);
    expect(find.text('Current growth'), findsNothing);
    await openAnalysis(tester);
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text('Current growth'), findsOneWidget);
    expect(find.text('Week-over-week change'), findsOneWidget);
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ScoutingReportPanel),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
    await tester.tap(find.text('Last Week (Week 2)'));
    await tester.pumpAndSettle();
    expect(find.text('Previous growth'), findsOneWidget);
    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();
    final layer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
    expect(layer.markers.last.point, const LatLng(11, 123));
    expect(find.text('Scouting map · Week 2'), findsOneWidget);
    await openAnalysis(tester);
    expect(find.text('Previous growth'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending, validated and controlled reports never show deltas', (
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
      await openAnalysis(tester);
      expect(find.text('Week-over-week change'), findsNothing);
      await tester.tap(find.text('Last Week (Week 2)'));
      await tester.pumpAndSettle();
      expect(find.text('Previous growth'), findsOneWidget);
    }
  });

  testWidgets('legacy missing coordinates and week remain usable', (
    tester,
  ) async {
    final legacy = ScoutingWeekReport('legacy', {
      'dap': 0,
      'status': 'resolved',
      'stationsData': ['bad'],
    });
    await mount(tester, ScoutingMapData(current: legacy));
    expect(
      find.text(
        'No saved report or field coordinates are available. Open Week analysis for the report details.',
      ),
      findsOneWidget,
    );
    await openAnalysis(tester);
    expect(find.text('Week 1 has no previous week.'), findsOneWidget);
    expect(find.text('Week 1 report'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Last Week'),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('portrait and landscape with large text use the page scroll', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(375, 667), const Size(667, 375)]) {
      await tester.pumpWidget(const SizedBox());
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await mount(
        tester,
        ScoutingMapData(current: current, previous: previous),
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Week analysis'));
      await openAnalysis(tester);
      expect(find.text('Current growth'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('analysis uses existing pest image assets', (tester) async {
    await mount(tester, ScoutingMapData(current: current, previous: previous));
    await openAnalysis(tester);
    for (final name in ['egg', 'larva', 'pupa', 'moth']) {
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName ==
                  'assets/images/map/$name.png',
        ),
        findsWidgets,
      );
    }
  });

  testWidgets('failed read offers retry inside the page', (tester) async {
    var attempts = 0;
    await mount(
      tester,
      ScoutingMapData(current: current),
      load: () async {
        if (attempts++ == 0) throw Exception('offline');
        return ScoutingMapData(current: current);
      },
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(attempts, 2);
  });
}
