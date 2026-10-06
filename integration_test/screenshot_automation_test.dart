import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Brand & Design Colors
const Color kPrimaryGreen = Color(0xFF004D40);
const Color kActionGreen = Color(0xFF1B5E20);
const Color kLightGreenBg = Color(0xFFF1F8F1);
const Color kBorderColor = Color(0xFFE0E0E0);
const Color kTextDark = Color(0xFF212121);
const Color kTextGrey = Color(0xFF757575);
const Color kAccentRed = Color(0xFFC62828);
const Color kCreamBg = Color(0xFFF8F5EF);
const Color kForestGreen = Color(0xFF1B3015);

/// Helper to render a widget with a realistic mobile phone canvas and capture a high-res PNG.
Future<void> captureScreen({
  required WidgetTester tester,
  required Widget widget,
  required String filename,
  Size size = const Size(412, 915),
  double pixelRatio = 2.625,
}) async {
  tester.view.physicalSize = Size(size.width * pixelRatio, size.height * pixelRatio);
  tester.view.devicePixelRatio = pixelRatio;

  final key = GlobalKey();

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF004D40)),
        scaffoldBackgroundColor: const Color(0xFFF4F7F4),
      ),
      home: RepaintBoundary(
        key: key,
        child: Material(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: widget,
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();

  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      final bytes = byteData.buffer.asUint8List();
      final paths = [
        'screenshots/$filename',
        'c:/PROJECTS/visaia-dashboard/public/screenshots/$filename',
      ];
      for (final p in paths) {
        try {
          final file = File(p);
          if (!file.parent.existsSync()) {
            file.parent.createSync(recursive: true);
          }
          file.writeAsBytesSync(bytes);
          debugPrint('📸 Saved screenshot: ${file.path} (${(bytes.length / 1024).toStringAsFixed(1)} KB)');
        } catch (_) {}
      }
    }
  });
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Automated Mobile Screenshots Integration Suite', () {
    // ══════════════════════════════════════════════════════════════════════════
    // 1. MANAGEMENT / CONTROL METHOD INPUT (Chemical vs Biological)
    // ══════════════════════════════════════════════════════════════════════════

    testWidgets('01_control_method_options_selection', (tester) async {
      await captureScreen(
        tester: tester,
        filename: '01_control_method_options_selection.png',
        widget: Scaffold(
          backgroundColor: const Color(0xFFF4F8F5),
          appBar: AppBar(
            backgroundColor: kPrimaryGreen,
            leading: const Icon(Icons.arrow_back, color: Colors.white),
            title: const Text(
              'Pest Management Selection',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Field Damage: 12.0% (Threshold Exceeded)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFBF360C)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Plant damage is ≥ 10%. Please select a control method for this cycle.',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF5D4037)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Select Pest Control Strategy',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextDark),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Choose between targeted chemical application or biological/pheromone trap surveillance.',
                  style: TextStyle(fontSize: 12, color: kTextGrey),
                ),
                const SizedBox(height: 16),

                // Option A: Chemical Control
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFC62828).withValues(alpha: 0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFFC62828).withValues(alpha: 0.1),
                            radius: 20,
                            child: const Icon(Icons.science_outlined, color: Color(0xFFC62828), size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Option A: Chemical Control',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFC62828)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC62828),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'RECOMMENDED',
                              style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Targeted insecticide application when pest damage exceeds economic threshold (≥ 10%). Standard flow: Validated → Control Applied → Follow-up → Resolved.',
                        style: TextStyle(fontSize: 12, color: kTextGrey, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(Icons.check_circle, size: 14, color: Color(0xFFC62828)),
                          const SizedBox(width: 6),
                          const Text('Fast pest knockdown', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC62828),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Select Chemical', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Option B: Biological / Pheromone Trap Control
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                            radius: 20,
                            child: const Icon(Icons.bug_report, color: Color(0xFF2E7D32), size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Option B: Biological / Pheromone Trap Control',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF2E7D32)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Deploy pheromone traps & Trichogramma biocontrol. Traps serve as early surveillance (Pheromone Trap → Monitoring → Follow-up → Resolution). Note: Traps do not imply confirmed infestation.',
                        style: TextStyle(fontSize: 12, color: kTextGrey, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(Icons.check_circle, size: 14, color: Color(0xFF2E7D32)),
                          const SizedBox(width: 6),
                          const Text('Eco-friendly surveillance', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Select Biological', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });

    testWidgets('02_control_method_confirmation_dialog', (tester) async {
      await captureScreen(
        tester: tester,
        filename: '02_control_method_confirmation_dialog.png',
        widget: Scaffold(
          backgroundColor: Colors.black54,
          body: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFFFBFDFA),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                        radius: 20,
                        child: const Icon(Icons.bug_report_outlined, color: Color(0xFF2E7D32), size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Select Biological / Trap Control?',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1B3015)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'What happens when you select Biological & Trap Control:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1B3015)),
                  ),
                  const SizedBox(height: 12),
                  _confirmationBullet(
                    'Pheromone Trap Setup',
                    'You will be guided to set up and record pheromone traps across your field to monitor adult FAW moth population trends.',
                    const Color(0xFF2E7D32),
                  ),
                  const SizedBox(height: 10),
                  _confirmationBullet(
                    'Biocontrol Surveillance',
                    'Biological agents (e.g. Trichogramma chilonis) and non-chemical cultural practices will be encouraged to manage early pest pressure.',
                    const Color(0xFF2E7D32),
                  ),
                  const SizedBox(height: 10),
                  _confirmationBullet(
                    'Early Warning, Not Infestation',
                    'Pheromone trap catches provide early surveillance warnings and do not automatically indicate severe crop loss.',
                    const Color(0xFF2E7D32),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {},
                        child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        ),
                        child: const Text('Confirm Selection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });

    testWidgets('03_monitoring_active_control_methods', (tester) async {
      await captureScreen(
        tester: tester,
        filename: '03_monitoring_active_control_methods.png',
        widget: Scaffold(
          backgroundColor: const Color(0xFFF4F7F4),
          appBar: AppBar(
            backgroundColor: kPrimaryGreen,
            title: const Text('Field Monitoring', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            actions: const [Icon(Icons.calendar_month, color: Colors.white), SizedBox(width: 16)],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3), width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: Color(0xFF0F5234),
                              borderRadius: BorderRadius.all(Radius.circular(2)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Color(0xFFE8F0E8), shape: BoxShape.circle),
                            child: const Icon(Icons.pest_control_outlined, color: Color(0xFF0F5234), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Biological & Trap Control Active',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F5234)),
                                ),
                                Text(
                                  'Pheromone traps installed • Weekly surveillance',
                                  style: TextStyle(fontSize: 11, color: kTextGrey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.visibility, size: 16, color: Color(0xFF0F5234)),
                              label: const Text('View Traps', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F5234))),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFC8E6C9)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.add_chart_rounded, size: 16, color: Colors.white),
                              label: const Text('Record Catch', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F5234),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Scouting Weeks', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [1, 2, 3, 4, 5].map((w) {
                    final isCurrent = w == 3;
                    return Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: isCurrent ? kActionGreen : (w < 3 ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5)),
                        shape: BoxShape.circle,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Week', style: TextStyle(fontSize: 9, color: isCurrent ? Colors.white70 : kTextGrey)),
                          Text('$w', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isCurrent ? Colors.white : kTextDark)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kBorderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('5-Station Scouting Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(height: 10),
                        LinearProgressIndicator(value: 1.0, color: kActionGreen, backgroundColor: Color(0xFFEEEEEE)),
                        SizedBox(height: 8),
                        Text('5 of 5 Stations Completed (100 Plants Inspected)', style: TextStyle(fontSize: 11.5, color: kTextGrey)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });

    // ══════════════════════════════════════════════════════════════════════════
    // 2. PHEROMONE-TRAP MONITORING INPUT (Trap Data & Catch Input)
    // ══════════════════════════════════════════════════════════════════════════

    testWidgets('04_pheromone_traps_map_and_list', (tester) async {
      await captureScreen(
        tester: tester,
        filename: '04_pheromone_traps_map_and_list.png',
        widget: Scaffold(
          backgroundColor: const Color(0xFFF4F8F5),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1A5C30),
            leading: const Icon(Icons.arrow_back, color: Colors.white),
            title: const Text('Installed Pheromone Traps', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            actions: [
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add_chart_rounded, size: 16, color: Colors.white),
                label: const Text('Record Catch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                height: 180,
                width: double.infinity,
                color: const Color(0xFFC8E6C9),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.map_outlined, size: 42, color: Color(0xFF2E7D32)),
                          SizedBox(height: 4),
                          Text('Field Alpha • 3 Traps Active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 60,
                      top: 40,
                      child: _mapTrapPin('Trap 1', 'North Ridge', 4),
                    ),
                    Positioned(
                      right: 70,
                      top: 60,
                      child: _mapTrapPin('Trap 2', 'East Corner', 1),
                    ),
                    Positioned(
                      left: 140,
                      bottom: 30,
                      child: _mapTrapPin('Trap 3', 'West Boundary', 0),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _trapCard(
                      name: 'Trap 1 - North Ridge',
                      zone: 'Zone A',
                      lureDays: 14,
                      mothCount: 4,
                      condition: 'Good',
                      lastChecked: 'Oct 3, 2026',
                    ),
                    const SizedBox(height: 12),
                    _trapCard(
                      name: 'Trap 2 - East Corner',
                      zone: 'Zone B',
                      lureDays: 14,
                      mothCount: 1,
                      condition: 'Needs Cleaning',
                      lastChecked: 'Oct 3, 2026',
                    ),
                    const SizedBox(height: 12),
                    _trapCard(
                      name: 'Trap 3 - West Boundary',
                      zone: 'Zone C',
                      lureDays: 21,
                      mothCount: 0,
                      condition: 'Good',
                      lastChecked: 'Oct 1, 2026',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });

    testWidgets('05_inspect_trap_catch_input_screen', (tester) async {
      await captureScreen(
        tester: tester,
        filename: '05_inspect_trap_catch_input_screen.png',
        widget: Scaffold(
          backgroundColor: const Color(0xFFF4F8F5),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1A5C30),
            leading: const Icon(Icons.arrow_back, color: Colors.white),
            title: const Text('Record Trap Catch', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDDEEE4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select Trap to Inspect', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A5C30))),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F8F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDDEEE4)),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.gps_fixed, size: 18, color: Color(0xFF1A5C30)),
                            SizedBox(width: 10),
                            Text('Trap 1 - North Ridge (Zone A)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Spacer(),
                            Icon(Icons.arrow_drop_down, color: Color(0xFF1A5C30)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDDEEE4)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.pest_control_outlined, color: Color(0xFF1A5C30), size: 22),
                          SizedBox(width: 8),
                          Text('Adult FAW Moths Captured', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text('Count the number of adult fall armyworm moths on the sticky liner.', style: TextStyle(fontSize: 11.5, color: kTextGrey)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.filledTonal(
                            onPressed: () {},
                            icon: const Icon(Icons.remove),
                            style: IconButton.styleFrom(backgroundColor: const Color(0xFFE8F5E9), foregroundColor: const Color(0xFF1A5C30)),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF81C784), width: 1.5),
                            ),
                            child: const Text('4', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF1B5E20))),
                          ),
                          IconButton.filledTonal(
                            onPressed: () {},
                            icon: const Icon(Icons.add),
                            style: IconButton.styleFrom(backgroundColor: const Color(0xFFE8F5E9), foregroundColor: const Color(0xFF1A5C30)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDDEEE4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Trap Physical Condition', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _conditionPill('Good', Icons.check_circle_outline, true),
                          const SizedBox(width: 8),
                          _conditionPill('Needs Cleaning', Icons.cleaning_services_outlined, false),
                          const SizedBox(width: 8),
                          _conditionPill('Damaged', Icons.warning_amber_rounded, false),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDDEEE4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Inspection Notes & Observations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FBF9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDDEEE4)),
                        ),
                        child: const Text(
                          'Observed 4 adult male FAW moths on delta sticky liner. Lure intact and emitting standard pheromone scent. Replaced liner paper.',
                          style: TextStyle(fontSize: 12, color: kTextDark),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text('Save Inspection & Record Catch', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A5C30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });

    // ══════════════════════════════════════════════════════════════════════════
    // 3. FOLLOW-UP AND RESOLUTION INPUT (Resolution Workflow)
    // ══════════════════════════════════════════════════════════════════════════

    testWidgets('06_validated_report_ready_for_resolution', (tester) async {
      await captureScreen(
        tester: tester,
        filename: '06_validated_report_ready_for_resolution.png',
        widget: Scaffold(
          backgroundColor: kCreamBg,
          appBar: AppBar(
            backgroundColor: kForestGreen,
            leading: const Icon(Icons.arrow_back, color: Colors.white),
            title: const Text('Scouting Report Details', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('VALIDATED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFE0F2F1), Color(0xFFB2DFDB)]),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF80CBC4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.task_alt, color: Color(0xFF00695C), size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Report Validated by RCPC Officer',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF004D40)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Treatment completed? Click below to resolve this report.',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF004D40)),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00796B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        child: const Text('Resolve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2DDD3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('High-Level Scouting Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kForestGreen)),
                          Text('DAP 35 · Vegetative', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _metricTile('Larvae', '8', Icons.bug_report, Colors.red),
                          _metricTile('Moths', '4', Icons.flutter_dash, Colors.purple),
                          _metricTile('Damage %', '12.0%', Icons.pie_chart, Colors.red),
                          _metricTile('Threshold', 'EXCEEDED', Icons.warning_amber, Colors.red),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2DDD3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('RCPC Advisory Recommendation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kForestGreen)),
                      SizedBox(height: 8),
                      Text(
                        '• Economic threshold exceeded (12.0% damage ≥ 10%).\n• Apply targeted biological controls (Trichogramma chilonis) or approved selective insecticides.\n• Re-scout all stations in 5 days to verify knockdown.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF424242), height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });

    testWidgets('07_resolution_workflow_dialog', (tester) async {
      await captureScreen(
        tester: tester,
        filename: '07_resolution_workflow_dialog.png',
        widget: Scaffold(
          backgroundColor: Colors.black54,
          body: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: const [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF0D4D33), size: 24),
                        SizedBox(width: 8),
                        Text('Resolve Validated Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1B3015))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Follow DA-RCPC Resolution Guidelines to document field treatment.', style: TextStyle(fontSize: 11, color: kTextGrey)),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Category: High-Level Scouting-Based Report', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                    ),
                    const SizedBox(height: 14),
                    const Text('DA-RCPC Resolution Reason *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF2E7D32), width: 1.5),
                        borderRadius: BorderRadius.circular(10),
                        color: const Color(0xFFF1F8F1),
                      ),
                      child: Row(
                        children: const [
                          Expanded(
                            child: Text(
                              'Biological control applied and condition improved',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1B5E20)),
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, color: Color(0xFF2E7D32)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Management Action / Treatment Applied *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(10),
                        color: const Color(0xFFFAFAFA),
                      ),
                      child: const Text(
                        'Released 2 Trichogramma chilonis cards per station and sprayed Bt microbial solution.',
                        style: TextStyle(fontSize: 12, color: kTextDark),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Farmer Field Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(10),
                        color: const Color(0xFFFAFAFA),
                      ),
                      child: const Text(
                        'Pest knockdown verified. Damage ceased spreading across vegetative whorls.',
                        style: TextStyle(fontSize: 12, color: kTextDark),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: const [
                        Icon(Icons.event, size: 18, color: Color(0xFF0D4D33)),
                        SizedBox(width: 8),
                        Text('Scheduled Follow-Up: Oct 9, 2026', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D4D33))),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D4D33),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Confirm Resolution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });

    // ══════════════════════════════════════════════════════════════════════════
    // 4. RESOLVED-REPORT HISTORY OUTPUT (Full History Output & Details)
    // ══════════════════════════════════════════════════════════════════════════

    testWidgets('08_resolved_report_history_list', (tester) async {
      await captureScreen(
        tester: tester,
        filename: '08_resolved_report_history_list.png',
        widget: Scaffold(
          backgroundColor: const Color(0xFFF4F7F4),
          appBar: AppBar(
            backgroundColor: kPrimaryGreen,
            title: const Text('Report History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            actions: const [Icon(Icons.filter_list, color: Colors.white), SizedBox(width: 16)],
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.white,
                child: Row(
                  children: [
                    _filterChip('All Reports (8)', false),
                    const SizedBox(width: 8),
                    _filterChip('Resolved (3)', true),
                    const SizedBox(width: 8),
                    _filterChip('Validated (2)', false),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _historyReportCard(
                      title: 'High-Level Scouting Report',
                      subtitle: 'DAP 35 · 12.0% Damage · Fall Armyworm',
                      date: 'Oct 4, 2026',
                      time: '10:30 AM',
                      status: 'RESOLVED',
                      statusColor: const Color(0xFF00796B),
                      type: 'Clustered Scouting',
                      reason: 'Biological control applied and condition improved',
                    ),
                    const SizedBox(height: 12),
                    _historyReportCard(
                      title: 'Fall Armyworm (FAW) Larva',
                      subtitle: '3rd Instar Larva · Whorl Feeding',
                      date: 'Oct 2, 2026',
                      time: '02:15 PM',
                      status: 'RESOLVED',
                      statusColor: const Color(0xFF00796B),
                      type: 'Regular AI Report',
                      reason: 'RCPC-recommended management completed',
                    ),
                    const SizedBox(height: 12),
                    _historyReportCard(
                      title: 'Low-Level Scouting Report',
                      subtitle: 'DAP 21 · 4.0% Damage · Normal',
                      date: 'Sep 28, 2026',
                      time: '09:00 AM',
                      status: 'RESOLVED',
                      statusColor: const Color(0xFF00796B),
                      type: 'Clustered Scouting',
                      reason: 'Condition improved after routine/cultural management',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });

    testWidgets('09_resolved_report_details_view', (tester) async {
      await captureScreen(
        tester: tester,
        filename: '09_resolved_report_details_view.png',
        widget: Scaffold(
          backgroundColor: kCreamBg,
          appBar: AppBar(
            backgroundColor: kForestGreen,
            leading: const Icon(Icons.arrow_back, color: Colors.white),
            title: const Text('Resolved Report Record', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00796B),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('RESOLVED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF80CBC4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.verified, color: Color(0xFF00695C), size: 24),
                          SizedBox(width: 10),
                          Text('Farmer Resolution Record', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004D40))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text('Resolved by Axel John Nuqui • Oct 4, 2026 at 10:30 AM', style: TextStyle(fontSize: 11.5, color: Color(0xFF00695C))),
                      const Divider(height: 20),
                      const Text('Resolution Reason:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextGrey)),
                      const Text('Biological control applied and condition improved', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                      const SizedBox(height: 10),
                      const Text('Management Action Taken:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextGrey)),
                      const Text('Released 2 Trichogramma chilonis cards per station and applied Bt microbial spray.', style: TextStyle(fontSize: 12.5, color: Color(0xFF1B3015))),
                      const SizedBox(height: 10),
                      const Text('Scheduled Follow-Up Monitoring:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextGrey)),
                      const Text('Oct 9, 2026 (In 5 days)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF00796B))),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2DDD3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('High-Level Scouting Data (Week 5)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kForestGreen)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _metricTile('Larvae', '8', Icons.bug_report, Colors.green),
                          _metricTile('Moths', '4', Icons.flutter_dash, Colors.purple),
                          _metricTile('Damage %', '12.0%', Icons.pie_chart, Colors.green),
                          _metricTile('Status', 'RESOLVED', Icons.check_circle, const Color(0xFF00796B)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  });
}

// ─── Helper Widgets ──────────────────────────────────────────────────────────

Widget _confirmationBullet(String title, String description, Color color) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        margin: const EdgeInsets.only(top: 5),
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 12, color: Color(0xFF333333), height: 1.35),
            children: [
              TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B3015))),
              TextSpan(text: description),
            ],
          ),
        ),
      ),
    ],
  );
}

Widget _mapTrapPin(String name, String zone, int count) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF2E7D32)),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.location_on, size: 14, color: Color(0xFF2E7D32)),
        const SizedBox(width: 2),
        Text('$name ($count)', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
      ],
    ),
  );
}

Widget _trapCard({
  required String name,
  required String zone,
  required int lureDays,
  required int mothCount,
  required String condition,
  required String lastChecked,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFDDEEE4)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A5C30))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
              child: Text(zone, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFF9FBF9), borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text('Last Checked', style: TextStyle(fontSize: 10, color: kTextGrey)),
                  Text(lastChecked, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                children: [
                  const Text('Moths Caught', style: TextStyle(fontSize: 10, color: kTextGrey)),
                  Text('$mothCount Moths', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple)),
                ],
              ),
              Column(
                children: [
                  const Text('Condition', style: TextStyle(fontSize: 10, color: kTextGrey)),
                  Text(condition, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Next Lure: In $lureDays days', style: const TextStyle(fontSize: 11, color: kTextGrey)),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_chart_rounded, size: 14),
              label: const Text('Inspect / Record Catch', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A5C30),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _conditionPill(String label, IconData icon, bool isSelected) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFE8F5E9) : const Color(0xFFF9FBF9),
        border: Border.all(color: isSelected ? const Color(0xFF2E7D32) : const Color(0xFFDDEEE4), width: isSelected ? 1.5 : 1.0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: isSelected ? const Color(0xFF2E7D32) : kTextGrey),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? const Color(0xFF1B5E20) : kTextDark)),
        ],
      ),
    ),
  );
}

Widget _metricTile(String label, String value, IconData icon, Color color) {
  return Column(
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: kTextGrey)),
    ],
  );
}

Widget _filterChip(String label, bool isSelected) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: isSelected ? kPrimaryGreen : Colors.grey[100],
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
        color: isSelected ? Colors.white : Colors.grey[700],
      ),
    ),
  );
}

Widget _historyReportCard({
  required String title,
  required String subtitle,
  required String date,
  required String time,
  required String status,
  required Color statusColor,
  required String type,
  required String reason,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey[200]!),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(6)),
              child: Text(type, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kTextGrey)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(status, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: statusColor)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: kTextGrey)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFF1F8F5), borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              const Icon(Icons.check, size: 14, color: Color(0xFF00796B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Reason: $reason', style: const TextStyle(fontSize: 10.5, color: Color(0xFF004D40), fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$date · $time', style: const TextStyle(fontSize: 11, color: kTextGrey)),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ],
        ),
      ],
    ),
  );
}
