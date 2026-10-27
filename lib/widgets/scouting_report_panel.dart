import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:visaia/services/connectivity_service.dart';
import 'package:visaia/services/scouting_map_data.dart';
import 'package:visaia/utils/scouting_week_comparison.dart';

const _forestGreen = Color(0xFF1B3015);
const _gold = Color(0xFFC8A84B);
const _cream = Color(0xFFF8F5EF);

enum ScoutingPanelMode { overviewMap, weekAnalysis }

class ScoutingReportPanel extends StatefulWidget {
  final ScoutingWeekReport report;
  final Future<ScoutingMapData> Function()? load;
  final bool showTiles;
  final ScoutingPanelMode mode;
  final ValueNotifier<bool>? selectedWeek;
  const ScoutingReportPanel({
    super.key,
    required this.report,
    this.load,
    this.showTiles = true,
    required this.mode,
    this.selectedWeek,
  });
  @override
  State<ScoutingReportPanel> createState() => _ScoutingReportPanelState();
}

class _ScoutingReportPanelState extends State<ScoutingReportPanel> {
  late Future<ScoutingMapData> _future;
  bool _localPrevious = false;
  bool get _previous => widget.selectedWeek?.value ?? _localPrevious;
  bool _tileError = false;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
    widget.selectedWeek?.addListener(_selectionChanged);
  }

  void _selectionChanged() {
    if (mounted) setState(() => _tileError = false);
  }

  @override
  void didUpdateWidget(covariant ScoutingReportPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedWeek != widget.selectedWeek) {
      oldWidget.selectedWeek?.removeListener(_selectionChanged);
      widget.selectedWeek?.addListener(_selectionChanged);
    }
    if (oldWidget.report.id != widget.report.id ||
        !mapEquals(oldWidget.report.data, widget.report.data)) {
      _future = _load();
    }
  }

  @override
  void dispose() {
    widget.selectedWeek?.removeListener(_selectionChanged);
    super.dispose();
  }

  Future<ScoutingMapData> _load() async {
    final result =
        await (widget.load?.call() ?? loadScoutingMapData(widget.report));
    if (result.notices.isNotEmpty && !_notified) {
      _notified = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(result.notices.first),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ScoutingMapData>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _text(
                'Could not load scouting information. Check your connection or retry.',
              ),
              OutlinedButton(
                onPressed: () => setState(() {
                  _notified = false;
                  _future = _load();
                }),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
      if (!snapshot.hasData) {
        return const SizedBox(
          height: 180,
          child: Center(child: CircularProgressIndicator(color: _forestGreen)),
        );
      }
      final data = snapshot.data!;
      final report = _previous && data.previous != null
          ? data.previous!
          : data.current;
      if (widget.mode == ScoutingPanelMode.overviewMap) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _text('Scouting map · Week ${report.week ?? "—"}', bold: true),
            const SizedBox(height: 10),
            _map(data, report),
            ..._notices(data),
          ],
        );
      }
      final week = data.current.week;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _text('Past & current week analysis', bold: true),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _weekButton(
                  week != null && week > 1
                      ? 'Last Week (Week ${week - 1})'
                      : 'Last Week',
                  true,
                  data.previous != null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _weekButton(
                  week == null ? 'Current Week' : 'Current Week (Week $week)',
                  false,
                  true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (data.previous == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _text(
                week == 1
                    ? 'Week 1 has no previous week.'
                    : week == null
                    ? 'The report week is unavailable.'
                    : 'No report is available for Week ${week - 1} in this cycle. It may not be saved on this device.',
              ),
            ),
          _details(report),
          if (data.current.isResolved && data.previous != null) ...[
            const SizedBox(height: 16),
            _comparison(data.current, data.previous!),
          ],
          ..._notices(data),
        ],
      );
    },
  );

  List<Widget> _notices(ScoutingMapData data) => [
    for (final notice in data.notices)
      Padding(padding: const EdgeInsets.only(top: 8), child: _text(notice)),
  ];

  Widget _weekButton(String label, bool previous, bool enabled) => Semantics(
    selected: _previous == previous,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        backgroundColor: _previous == previous ? _forestGreen : Colors.white,
        foregroundColor: _previous == previous ? Colors.white : _forestGreen,
        side: BorderSide(
          color: _previous == previous ? _gold : const Color(0xFFD8DDD4),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: enabled
          ? () => setState(() {
              _localPrevious = previous;
              widget.selectedWeek?.value = previous;
              _tileError = false;
            })
          : null,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
  );

  Widget _map(ScoutingMapData data, ScoutingWeekReport report) {
    final own = ScoutingMapData.reportPoint(report);
    final marker = own ?? data.fieldPoint;
    final points = [
      if (data.fieldPoint != null) data.fieldPoint!,
      if (marker != null) marker,
      ...data.boundary,
    ];
    if (points.isEmpty) {
      return _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_off_outlined, color: _forestGreen),
            const SizedBox(height: 8),
            _text(
              'No saved report or field coordinates are available. Open Week analysis for the report details.',
            ),
          ],
        ),
      );
    }
    final fit = CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: const EdgeInsets.all(40),
      maxZoom: 17,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 260,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: FlutterMap(
              key: ValueKey('scouting-map-${report.id}'),
              options: MapOptions(
                initialCameraFit: fit,
                backgroundColor: const Color(0xFFE3E9DD),
              ),
              children: [
                if (widget.showTiles)
                  TileLayer(
                    urlTemplate:
                        'https://mt1.google.com/vt/lyrs=s,h&x={x}&y={y}&z={z}',
                    userAgentPackageName: 'com.visaia.app',
                    errorTileCallback: (_, error, stack) {
                      if (_tileError) return;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && !_tileError) {
                          setState(() => _tileError = true);
                        }
                      });
                    },
                  ),
                if (data.boundary.isNotEmpty)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: data.boundary,
                        color: _forestGreen.withValues(alpha: .15),
                        borderColor: _forestGreen,
                        borderStrokeWidth: 3,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (data.fieldPoint != null)
                      Marker(
                        point: data.fieldPoint!,
                        width: 48,
                        height: 48,
                        child: Tooltip(
                          message: '${data.siteLabel} center',
                          child: const Align(
                            alignment: Alignment.bottomCenter,
                            child: Icon(
                              Icons.crop_square,
                              color: _forestGreen,
                              size: 42,
                              semanticLabel: 'Saved site center',
                            ),
                          ),
                        ),
                      ),
                    if (marker != null)
                      Marker(
                        point: marker,
                        width: 48,
                        height: 48,
                        child: Tooltip(
                          message:
                              'Week ${report.week ?? "?"} report${own == null ? " (site fallback)" : ""}',
                          child: Image.asset(
                            'assets/images/map/clustered_report.png',
                            width: 44,
                            height: 48,
                            semanticLabel: 'Selected week clustered report',
                          ),
                        ),
                      ),
                  ],
                ),
                Builder(
                  builder: (mapContext) => Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Zoom in',
                              icon: const Icon(Icons.add, color: _forestGreen),
                              onPressed: () {
                                final controller = MapController.of(mapContext);
                                controller.move(
                                  controller.camera.center,
                                  (controller.camera.zoom + 1).clamp(2, 20),
                                );
                              },
                            ),
                            IconButton(
                              tooltip: 'Zoom out',
                              icon: const Icon(
                                Icons.remove,
                                color: _forestGreen,
                              ),
                              onPressed: () {
                                final controller = MapController.of(mapContext);
                                controller.move(
                                  controller.camera.center,
                                  (controller.camera.zoom - 1).clamp(2, 20),
                                );
                              },
                            ),
                            IconButton(
                              tooltip: 'Show field and report',
                              icon: const Icon(
                                Icons.center_focus_strong,
                                color: _forestGreen,
                              ),
                              onPressed: () =>
                                  MapController.of(mapContext).fitCamera(fit),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                RichAttributionWidget(
                  attributions: [TextSourceAttribution('Google Maps')],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _text(
          'Outline / square: ${data.siteLabel.toLowerCase()} · Pin: selected week report',
        ),
        _text(
          own == null
              ? 'Report pin uses the saved ${data.siteLabel.toLowerCase()} location.'
              : 'Report pin uses the location saved with this report; it may be the field center.',
        ),
        if (data.fieldPoint == null)
          _text(
            'The linked field location is unavailable; showing the saved report location.',
          ),
        if (_tileError || !ConnectivityService().isOnline)
          _text(
            'Map imagery is unavailable offline or could not load. Saved markers and weekly details are still shown.',
          ),
      ],
    );
  }

  static const _pestAssets = {
    'eggs': 'assets/images/map/egg.png',
    'larvae': 'assets/images/map/larva.png',
    'pupae': 'assets/images/map/pupa.png',
    'moths': 'assets/images/map/moth.png',
  };

  Widget _details(ScoutingWeekReport r) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _text('Week ${r.week ?? "—"} report', bold: true),
                _badge('DAP ${r.dap ?? "—"}'),
                _badge('${r.level ?? "Unknown"} level'),
              ],
            ),
            const SizedBox(height: 6),
            _text(r.growthStage),
            if (r.data['fieldName'] != null || r.data['farmName'] != null)
              _text((r.data['fieldName'] ?? r.data['farmName']).toString()),
            const SizedBox(height: 12),
            _metricGrid([
              (
                'Damage',
                r.damagePercentage == null
                    ? 'Unavailable'
                    : '${_number(r.damagePercentage)}%',
              ),
              ('Inspected', _number(r.inspected)),
              ('Damaged', _number(r.damaged)),
            ]),
            const SizedBox(height: 12),
            _pestCounts(r),
          ],
        ),
      ),
      const SizedBox(height: 10),
      _expansion(
        'Station summary (${r.stations.length})',
        [
          if (r.stations.isEmpty) _text('Station records are unavailable.'),
          for (var i = 0; i < r.stations.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _text(
                    (r.stations[i]['title'] ?? 'Station ${i + 1}').toString(),
                    bold: true,
                  ),
                  _text(
                    '${_number(scoutingInt(r.stations[i]["plantsInspected"]))} inspected · ${_number(scoutingInt(r.stations[i]["damaged"]))} damaged',
                  ),
                  _text(
                    'Egg masses ${_number(scoutingInt(r.stations[i]["eggMasses"]))} · Larvae ${_number(scoutingInt(r.stations[i]["larvae"]))} · Pupae ${_number(scoutingInt(r.stations[i]["pupae"]))} · Moths ${_number(scoutingInt(r.stations[i]["moths"]))}',
                  ),
                ],
              ),
            ),
        ],
        key: ValueKey('stations-${r.id}'),
      ),
      const SizedBox(height: 10),
      _expansion('Report details', [
        _line('Severity', r.severity),
        _line(
          'Threshold',
          r.level == null
              ? 'Unavailable'
              : r.levelIsEstimated
              ? '10% damage fallback · ${r.level == "High" ? "exceeded" : "below threshold"}'
              : '${r.level == "High" ? "Exceeded" : "Below threshold"} · saved classification; numeric cutoff not recorded',
        ),
        _line(
          'Report date',
          r.reportDate == null
              ? 'Unavailable'
              : DateFormat('MMM d, yyyy · h:mm a').format(r.reportDate!),
        ),
        if (r.submittedAt != null)
          _line(
            'Submitted',
            DateFormat('MMM d, yyyy · h:mm a').format(r.submittedAt!),
          ),
        _line('Status', (r.data['status'] ?? 'Unavailable').toString()),
      ], key: ValueKey('metadata-${r.id}')),
    ],
  );

  Widget _badge(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: _cream,
      borderRadius: BorderRadius.circular(8),
    ),
    child: _text(label),
  );

  Widget _metricGrid(List<(String, String)> metrics) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = MediaQuery.textScalerOf(context).scale(13) > 19 ? 2 : 3;
      final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final metric in metrics)
            Container(
              width: width,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _cream,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.$1,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: _forestGreen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    metric.$2,
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _forestGreen,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );

  Widget _pestCounts(ScoutingWeekReport report) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = MediaQuery.textScalerOf(context).scale(13) > 19 ? 2 : 4;
      final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in _pestAssets.entries)
            SizedBox(
              width: width,
              child: Column(
                children: [
                  Image.asset(
                    entry.value,
                    width: 30,
                    height: 36,
                    excludeFromSemantics: true,
                  ),
                  _text(_number(report.count(entry.key)), bold: true),
                  Text(
                    entry.key == 'eggs'
                        ? 'Egg masses'
                        : '${entry.key[0].toUpperCase()}${entry.key.substring(1)}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: _forestGreen,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );

  Widget _expansion(String title, List<Widget> children, {required Key key}) =>
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: key,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          shape: const Border(),
          collapsedShape: const Border(),
          title: _text(title, bold: true),
          children: children,
        ),
      );

  Widget _comparison(
    ScoutingWeekReport current,
    ScoutingWeekReport previous,
  ) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _text('Week-over-week change', bold: true),
        _text('Week ${previous.week} → Week ${current.week} · Report resolved'),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final largeText = MediaQuery.textScalerOf(context).scale(13) > 19;
            final deltas = scoutingDeltas(current, previous);
            if (largeText) {
              return Column(
                children: [
                  _line(
                    'High / Low level',
                    '${previous.level ?? "Unavailable"} → ${current.level ?? "Unavailable"}',
                  ),
                  for (final delta in deltas)
                    _line(
                      delta.label,
                      '${_number(delta.previous)} → ${_number(delta.current)} · ${_deltaText(delta)}',
                    ),
                ],
              );
            }
            return Table(
              columnWidths: const {
                0: FlexColumnWidth(1.7),
                1: FlexColumnWidth(.8),
                2: FlexColumnWidth(.8),
                3: FlexColumnWidth(1.5),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                _comparisonRow([
                  'Metric',
                  'W${previous.week}',
                  'W${current.week}',
                  'Change',
                ], heading: true),
                _comparisonRow([
                  'Level',
                  previous.level ?? '—',
                  current.level ?? '—',
                  previous.level == null || current.level == null
                      ? 'Unavailable'
                      : previous.level == current.level
                      ? 'No change'
                      : current.level == 'High'
                      ? '▲ worse'
                      : '▼ better',
                ]),
                for (final delta in deltas)
                  _comparisonRow(
                    [
                      delta.label,
                      _number(delta.previous),
                      _number(delta.current),
                      _deltaText(delta),
                    ],
                    asset: _pestAssets[delta.label.toLowerCase()],
                    color:
                        delta.neutral ||
                            delta.change == null ||
                            delta.change == 0
                        ? _forestGreen
                        : delta.change! > 0
                        ? const Color(0xFFB42318)
                        : const Color(0xFF20653D),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        _text(
          'Damage change is in percentage points (pp). Inspected-count changes are neutral.',
        ),
        _expansion('About this comparison', [
          _text(
            'Changes compare recorded weeks; resolution alone does not establish when improvement occurred. Counts also depend on how many plants were inspected.',
          ),
        ], key: const ValueKey('comparison-explanation')),
      ],
    ),
  );

  TableRow _comparisonRow(
    List<String> cells, {
    bool heading = false,
    String? asset,
    Color color = _forestGreen,
  }) => TableRow(
    decoration: BoxDecoration(
      color: heading ? _cream : Colors.white,
      border: const Border(bottom: BorderSide(color: Color(0xFFEEEFE9))),
    ),
    children: [
      for (var i = 0; i < cells.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
          child: Row(
            children: [
              if (i == 0 && asset != null) ...[
                Image.asset(
                  asset,
                  width: 18,
                  height: 24,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  cells[i],
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: heading || i == 3
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: i == 3 ? color : _forestGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );

  String _deltaText(ScoutingDelta delta) => delta.change == null
      ? 'Unavailable'
      : '${delta.change! > 0 ? "+" : ""}${_number(delta.change)}${delta.unit}\n${delta.direction}';

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _gold.withValues(alpha: .35)),
    ),
    child: child,
  );
  Widget _text(String text, {bool bold = false, Color color = _forestGreen}) =>
      Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: 13,
          height: 1.5,
          color: color,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      );
  Widget _line(String label, String value, {Color color = _forestGreen}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _text(label, bold: true),
            _text(value, color: color),
          ],
        ),
      );
  String _number(num? value) => value == null
      ? 'Unavailable'
      : value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
}
