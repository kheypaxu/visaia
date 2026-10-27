import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:visaia/screens/logging_screens/inspect_trap_screen.dart';
import 'package:visaia/screens/logging_screens/trap_lists.dart';
import 'package:visaia/services/firestore_safe_ext.dart';

/// Installed-trap management has its own presentation, separate from setup.
class InstalledTrapsScreen extends StatefulWidget {
  final String cycleId;
  final String userId;
  const InstalledTrapsScreen({
    super.key,
    required this.cycleId,
    required this.userId,
  });

  @override
  State<InstalledTrapsScreen> createState() => _InstalledTrapsScreenState();
}

class _InstalledTrapsScreenState extends State<InstalledTrapsScreen> {
  static const _green = Color(0xFF1A5C30);
  static const _darkGreen = Color(0xFF0C503C);
  static const _background = Color(0xFFF4F8F5);
  bool _loading = true;
  String? _error;
  String _cycleName = '';
  String _fieldName = '';
  List<TrapItem> _traps = [];
  List<LatLng> _boundaries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId);
      final cycle = await user
          .collection('cycles')
          .doc(widget.cycleId)
          .safeGet();
      final data = cycle.data();
      if (data == null) {
        throw StateError('This growth cycle could not be found.');
      }
      final boundaries = <LatLng>[];
      if (data['fieldId'] is String) {
        final field = await user
            .collection('fields')
            .doc(data['fieldId'] as String)
            .safeGet();
        for (final point in field.data()?['boundaries'] as List? ?? []) {
          if (point is Map && point['lat'] is num && point['lng'] is num) {
            boundaries.add(
              LatLng(
                (point['lat'] as num).toDouble(),
                (point['lng'] as num).toDouble(),
              ),
            );
          }
        }
      }
      final traps = <TrapItem>[];
      for (final entry in (data['traps'] as List? ?? []).asMap().entries) {
        if (entry.value is! Map) continue;
        final trap = Map<String, dynamic>.from(entry.value as Map);
        final position = trap['position'];
        if (position is! Map ||
            position['lat'] is! num ||
            position['lng'] is! num) {
          throw StateError(
            'A trap is missing its saved map position. Review trap setup.',
          );
        }
        DateTime? date(String key) =>
            trap[key] is Timestamp ? (trap[key] as Timestamp).toDate() : null;
        final installed = date('installationDate');
        if (installed == null) {
          throw StateError(
            'A trap is missing its installation date. Review trap setup.',
          );
        }
        traps.add(
          TrapItem(
            id: trap['id'] as String? ?? 'trap_${entry.key + 1}',
            name: trap['name'] as String? ?? 'Trap ${entry.key + 1}',
            zone: trap['zone'] as String? ?? 'Field location',
            position: LatLng(
              (position['lat'] as num).toDouble(),
              (position['lng'] as num).toDouble(),
            ),
            installationDate: installed,
            nextLureDate:
                date('nextLureDate') ?? installed.add(const Duration(days: 42)),
            notes: trap['notes'] as String? ?? '',
            lastInspectedAt: date('lastInspectedAt'),
            lastMothCount: (trap['lastMothCount'] as num?)?.toInt(),
            lastCondition: trap['lastCondition'] as String?,
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _cycleName = data['cycleName'] as String? ?? 'Current Cycle';
        _fieldName = data['fieldName'] as String? ?? '';
        _traps = traps;
        _boundaries = boundaries;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _inspect([TrapItem? trap]) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => InspectTrapScreen(
          cycleId: widget.cycleId,
          userId: widget.userId,
          initialTrapName: trap?.name,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _addTrap() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrapSetupScreen(
          cycleId: widget.cycleId,
          userId: widget.userId,
          initialStep: 0,
          addingTrap: true,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: _darkGreen,
            expandedHeight:
                168 + (MediaQuery.textScalerOf(context).scale(100) - 100) * 2,
            leading: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh traps',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/images/bg.png', fit: BoxFit.cover),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _darkGreen.withValues(alpha: 0.78),
                          _green.withValues(alpha: 0.72),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Installed Traps',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'View trap locations, review recent catches, and record inspections.',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator(color: _green)),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: _green, size: 40),
                    const SizedBox(height: 16),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDDEEE4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.agriculture, color: _green),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _cycleName,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  color: _darkGreen,
                                  fontSize: 15,
                                ),
                              ),
                              if (_fieldName.isNotEmpty)
                                Text(
                                  _fieldName,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF626E67),
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '${_traps.length} traps',
                          style: GoogleFonts.inter(
                            color: _green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _addTrap,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Another Trap'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _green,
                          minimumSize: const Size(0, 48),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _traps.isEmpty ? null : () => _inspect(),
                        icon: const Icon(Icons.add_chart_rounded),
                        label: const Text('Record Catch'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _green,
                          minimumSize: const Size(0, 48),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_traps.isNotEmpty) ...[
                    Text(
                      'TRAP LOCATIONS',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _darkGreen,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 280,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: InstalledTrapMap(
                          traps: _traps,
                          boundaries: _boundaries,
                          onInspect: _inspect,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Drag to explore, zoom with the controls, or tap a trap to inspect it.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF626E67),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No installed traps yet. Add a trap to begin monitoring.',
                      ),
                    ),
                  ..._traps.map(
                    (trap) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TrapCard(
                        key: ValueKey(trap.id),
                        trap: trap,
                        editableNotes: false,
                        onNotesChanged: (_) {},
                        onInspectTap: () => _inspect(trap),
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

/// Interactive map with its own controller for embedded and fullscreen views.
class InstalledTrapMap extends StatefulWidget {
  final List<TrapItem> traps;
  final List<LatLng> boundaries;
  final ValueChanged<TrapItem>? onInspect;
  final bool fullscreen;
  const InstalledTrapMap({
    super.key,
    required this.traps,
    required this.boundaries,
    this.onInspect,
    this.fullscreen = false,
  });

  @override
  State<InstalledTrapMap> createState() => _InstalledTrapMapState();
}

class _InstalledTrapMapState extends State<InstalledTrapMap> {
  final _controller = MapController();
  List<LatLng> get _points => [
    ...widget.boundaries,
    ...widget.traps.map((t) => t.position),
  ];
  CameraFit? get _fit => _points.toSet().length > 1
      ? CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(_points),
          padding: const EdgeInsets.all(48),
          maxZoom: 18,
        )
      : null;

  void _recenter() {
    final fit = _fit;
    if (fit != null) {
      _controller.fitCamera(fit);
    } else if (_points.isNotEmpty) {
      _controller.move(_points.first, 17);
    }
  }

  @override
  void didUpdateWidget(covariant InstalledTrapMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.traps != widget.traps ||
        oldWidget.boundaries != widget.boundaries) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _recenter();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: _points.isEmpty ? const LatLng(0, 0) : _points.first,
            initialZoom: 17,
            initialCameraFit: _fit,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
              userAgentPackageName: 'com.visaia.app',
            ),
            if (widget.boundaries.length >= 3)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: widget.boundaries,
                    color: const Color(0xFFFFBA27).withValues(alpha: 0.15),
                    borderColor: const Color(0xFFFFBA27),
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            MarkerLayer(
              markers: widget.traps
                  .asMap()
                  .entries
                  .map(
                    (entry) => Marker(
                      point: entry.value.position,
                      width: 48,
                      height: 48,
                      child: Tooltip(
                        message: widget.onInspect == null
                            ? entry.value.name
                            : 'Inspect ${entry.value.name}',
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: const CircleBorder(),
                            backgroundColor: const Color(0xFF0C503C),
                            disabledBackgroundColor: const Color(0xFF0C503C),
                            disabledForegroundColor: Colors.white,
                          ),
                          onPressed: widget.onInspect == null
                              ? null
                              : () => widget.onInspect!(entry.value),
                          child: Text('${entry.key + 1}'),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!widget.fullscreen)
                  IconButton(
                    tooltip: 'Open full map',
                    icon: const Icon(Icons.fullscreen),
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (mapContext) => Dialog.fullscreen(
                          child: Scaffold(
                            appBar: AppBar(
                              title: const Text('Trap Locations'),
                              leading: IconButton(
                                tooltip: 'Close map',
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(mapContext),
                              ),
                            ),
                            body: InstalledTrapMap(
                              traps: widget.traps,
                              boundaries: widget.boundaries,
                              onInspect: widget.onInspect == null
                                  ? null
                                  : (trap) {
                                      Navigator.pop(mapContext);
                                      widget.onInspect!(trap);
                                    },
                              fullscreen: true,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                IconButton(
                  tooltip: 'Zoom in',
                  icon: const Icon(Icons.add),
                  onPressed: () => _controller.move(
                    _controller.camera.center,
                    (_controller.camera.zoom + 1).clamp(2, 20),
                  ),
                ),
                IconButton(
                  tooltip: 'Zoom out',
                  icon: const Icon(Icons.remove),
                  onPressed: () => _controller.move(
                    _controller.camera.center,
                    (_controller.camera.zoom - 1).clamp(2, 20),
                  ),
                ),
                IconButton(
                  tooltip: 'Show all traps',
                  icon: const Icon(Icons.center_focus_strong),
                  onPressed: _recenter,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
