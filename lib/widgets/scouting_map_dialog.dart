import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:visaia/services/connectivity_service.dart';
import 'package:visaia/services/scouting_map_data.dart';
import 'package:visaia/utils/scouting_week_comparison.dart';

const _forestGreen = Color(0xFF1B3015);
const _gold = Color(0xFFC8A84B);
const _cream = Color(0xFFF8F5EF);

class ScoutingMapDialog extends StatefulWidget {
  final ScoutingWeekReport report;
  final Future<ScoutingMapData> Function()? load;
  final bool showTiles;
  const ScoutingMapDialog({
    super.key,
    required this.report,
    this.load,
    this.showTiles = true,
  });
  @override
  State<ScoutingMapDialog> createState() => _ScoutingMapDialogState();
}

class _ScoutingMapDialogState extends State<ScoutingMapDialog> {
  late Future<ScoutingMapData> _future;
  bool _previous = false;
  bool _tileError = false;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
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
  Widget build(BuildContext context) => Dialog(
    backgroundColor: _cream,
    insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 640,
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.map_outlined, color: _forestGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Scouting map',
                    style: GoogleFonts.epilogue(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: _forestGreen,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close scouting map',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: _forestGreen),
                ),
              ],
            ),
          ),
          Flexible(
            child: FutureBuilder<ScoutingMapData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _text(
                          'Could not load the scouting map. Saved reports are still available in report history.',
                        ),
                        const SizedBox(height: 12),
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
                    height: 240,
                    child: Center(
                      child: CircularProgressIndicator(color: _forestGreen),
                    ),
                  );
                }
                final data = snapshot.data!;
                final report = _previous ? data.previous! : data.current;
                final week = data.current.week;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _text(
                        (data.current.data['fieldName'] ??
                                data.current.data['farmName'] ??
                                'Scouting field')
                            .toString(),
                        bold: true,
                      ),
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
                              week == null
                                  ? 'Current Week'
                                  : 'Current Week (Week $week)',
                              false,
                              true,
                            ),
                          ),
                        ],
                      ),
                      if (data.previous == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _text(
                            week == 1
                                ? 'Week 1 has no previous week.'
                                : week == null
                                ? 'The report week is unavailable.'
                                : 'No report is available for Week ${week - 1} in this cycle. It may not be saved on this device.',
                          ),
                        ),
                      for (final notice in data.notices)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _text(notice),
                        ),
                      const SizedBox(height: 16),
                      _map(data, report),
                      const SizedBox(height: 16),
                      _details(report),
                      if (data.current.isResolved && data.previous != null) ...[
                        const SizedBox(height: 16),
                        _comparison(data.current, data.previous!),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

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
              _previous = previous;
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
              'No saved report or field coordinates are available. The weekly details remain available below.',
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
                          child: Icon(
                            Icons.location_pin,
                            size: 42,
                            color: report.level == 'High'
                                ? const Color(0xFFB42318)
                                : const Color(0xFF20653D),
                            semanticLabel: 'Selected week report',
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

  Widget _details(ScoutingWeekReport r) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _text('Week ${r.week ?? "—"} report', bold: true),
        const SizedBox(height: 12),
        _line('Growth stage', r.growthStage),
        _line('DAP', _number(r.dap)),
        _line(
          'Damage',
          r.damagePercentage == null
              ? 'Unavailable'
              : '${_number(r.damagePercentage)}%',
        ),
        _line(
          'Inspected / damaged',
          '${_number(r.inspected)} / ${_number(r.damaged)} plants',
        ),
        _line(
          'Report level',
          '${r.level ?? "Unavailable"}${r.levelIsEstimated && r.level != null ? " (10% fallback)" : ""}',
        ),
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
          'Egg masses / larvae',
          '${_number(r.count("eggs"))} / ${_number(r.count("larvae"))}',
        ),
        _line(
          'Pupae / moths',
          '${_number(r.count("pupae"))} / ${_number(r.count("moths"))}',
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
        const Divider(height: 24),
        _text('Station summary', bold: true),
        if (r.stations.isEmpty) _text('Station records are unavailable.'),
        for (var i = 0; i < r.stations.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 10),
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
        _line(
          'High / Low level',
          '${previous.level ?? "Unavailable"} → ${current.level ?? "Unavailable"}${previous.level == null || current.level == null
              ? ""
              : previous.level == current.level
              ? " · No change"
              : current.level == "High"
              ? " · ▲ worse"
              : " · ▼ better"}',
        ),
        for (final delta in scoutingDeltas(current, previous))
          _line(
            delta.label,
            delta.change == null
                ? 'Unavailable'
                : '${delta.change! > 0 ? "+" : ""}${_number(delta.change)}${delta.unit} · ${delta.direction}',
            color: delta.neutral || delta.change == null || delta.change == 0
                ? _forestGreen
                : delta.change! > 0
                ? const Color(0xFFB42318)
                : const Color(0xFF20653D),
          ),
        const SizedBox(height: 8),
        _text(
          'Changes compare recorded weeks; resolution alone does not establish when improvement occurred. Counts also depend on how many plants were inspected.',
        ),
      ],
    ),
  );

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(16),
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
