import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/widgets/report_detail_tabs.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(375, 667),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
            expandedHeight: 200,
            header: const SliverAppBar(
              pinned: true,
              expandedHeight: 200,
              title: Text('Report'),
            ),
            sections: [
              ReportDetailSection('Overview', [
                for (var i = 0; i < 30; i++)
                  SizedBox(height: 70, child: Text('Overview item $i')),
              ]),
              const ReportDetailSection('Damage', [Text('Damage details')]),
              const ReportDetailSection('Pests', [Text('Pest details')]),
              const ReportDetailSection('Stations', [Text('Station details')]),
              const ReportDetailSection('Review', [
                Text('Validation and resolution actions'),
              ]),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tabs switch content directly and retain selection on rebuild', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text('Overview item 0'), findsOneWidget);
    expect(find.text('Damage details'), findsNothing);
    await tester.tap(find.text('Damage'));
    await tester.pumpAndSettle();
    expect(find.text('Damage details'), findsOneWidget);
    expect(find.text('Overview item 0'), findsNothing);
    tester.element(find.byType(ReportDetailTabs)).markNeedsBuild();
    await tester.pumpAndSettle();
    expect(find.text('Damage details'), findsOneWidget);
    await tester.drag(find.byType(TabBar), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('Validation and resolution actions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('section bar stays visible and switching exits a deep scroll', (
    tester,
  ) async {
    await mount(tester);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1100));
    await tester.pumpAndSettle();
    final tabRect = tester.getRect(find.byType(TabBar));
    expect(tabRect.top, greaterThanOrEqualTo(kToolbarHeight));
    expect(tabRect.bottom, lessThan(667));
    await tester.tap(find.text('Pests'));
    await tester.pumpAndSettle();
    expect(find.text('Pest details').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrollable tabs fit small, landscape and large-text layouts', (
    tester,
  ) async {
    for (final size in [const Size(375, 667), const Size(667, 375)]) {
      await tester.pumpWidget(const SizedBox());
      await mount(tester, size: size, scale: 2);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(TabBar), const Offset(-1000, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      expect(find.text('Validation and resolution actions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
