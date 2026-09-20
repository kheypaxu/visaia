import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visaia/screens/onboarding/splash_screen.dart';

void main() {
  Widget app({bool reducedMotion = false}) => MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
      child: child!,
    ),
    home: const SplashScreen(),
    routes: {'/get-started': (_) => const Scaffold(body: Text('Welcome back'))},
  );

  testWidgets('Intro reveals branding then replaces itself with welcome', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('VISAIA'), findsOneWidget);
    expect(find.byIcon(Icons.spa_outlined), findsNWidgets(2));
    expect(find.text('Welcome back'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced motion skips the long animated intro', (tester) async {
    await tester.pumpWidget(app(reducedMotion: true));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Compact viewport and early disposal are safe', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });
}
