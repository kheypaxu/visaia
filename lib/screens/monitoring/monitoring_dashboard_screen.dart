import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/screens/monitoring/farm_area_monitoring_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Import the models from the core directory
import 'package:visaia/core/models/crop_type.dart';

class MonitoringDashboard extends StatefulWidget {
  final int cols;

  const MonitoringDashboard({
    super.key,
    this.cols = 4,
  });

  @override
  MonitoringDashboardState createState() => MonitoringDashboardState();
}

class MonitoringDashboardState extends State<MonitoringDashboard> {
  final List<FarmArea> _farmAreas = [];
  final List<Crop> _myCrops = [
    const Crop(name: 'Corn', color: Color(0xFF8DBA60), icon: Icons.grass),
  ];
  final TextEditingController _newCropController = TextEditingController();

  // Firestore farm limit
  double _totalFarmLimit = 0;
  bool _isLoadingLimit = true;

  @override
  void initState() {
    super.initState();
    _fetchFarmLimit();
  }

  Future<void> _fetchFarmLimit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('farmers').doc(uid).get();
      final farmSize = doc.data()?['farmSize'] as num?;
      setState(() {
        _totalFarmLimit = farmSize?.toDouble() ?? 0;
        _isLoadingLimit = false;
      });
    } catch (e) {
      setState(() => _isLoadingLimit = false);
      debugPrint('Error fetching farm size: $e');
    }
  }

  double get _usedHectares => _farmAreas.fold(0, (previousValue, area) => previousValue + area.hectares);
  double get _remainingHectares => (_totalFarmLimit - _usedHectares).clamp(0, double.infinity);

  @override
  void dispose() {
    _newCropController.dispose();
    super.dispose();
  }

  void _addNewCrop() {
    if (_newCropController.text.trim().isNotEmpty) {
      setState(() {
        final newCrop = Crop(
          name: _newCropController.text.trim(),
          color: _getNextCropColor(),
        );
        _myCrops.add(newCrop);
        _newCropController.clear();
      });
    }
  }

  Color _getNextCropColor() {
    final colors = [
      const Color(0xFF8DBA60),
      const Color(0xFFFFD700),
      const Color(0xFF2E8B57),
      const Color(0xFFFFA500),
      const Color(0xFF7FFF00),
      const Color(0xFFDAA520),
    ];
    return colors[_myCrops.length % colors.length];
  }

  void _showAddAreaDialog() {
    if (_myCrops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one crop type first!')),
      );
      return;
    }

    final nameController = TextEditingController();
    final hectaresController = TextEditingController();
    Crop selectedCrop = _myCrops.first;
    DateTime selectedDate = DateTime.now();
    String? hectaresError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF162A1D),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          title: Text('New Farm Area',
              style: GoogleFonts.inter(
                  color: Colors.white, fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Area Name',
                    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                    hintText: 'e.g. North Plot A',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF8DBA60))),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: hectaresController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) {
                    if (value.isNotEmpty && double.tryParse(value) == null) {
                      setDialogState(() {
                        hectaresError = 'Please enter a valid number';
                      });
                    } else {
                      setDialogState(() {
                        hectaresError = null;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Hectares',
                    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                    hintText: 'e.g. 1.5',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF8DBA60))),
                    errorText: hectaresError,
                    errorStyle: const TextStyle(color: Colors.red),
                    suffixText: 'ha',
                    suffixStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  ),
                ),
                const SizedBox(height: 20),
                Theme(
                  data: Theme.of(context).copyWith(canvasColor: const Color(0xFF162A1D)),
                  child: DropdownButtonFormField<Crop>(
                    value: selectedCrop,
                    decoration: InputDecoration(
                      labelText: 'Crop Type',
                      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none),
                    ),
                    items: _myCrops
                        .map((crop) => DropdownMenuItem(
                              value: crop,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                      radius: 12, backgroundColor: crop.color, child: Icon(crop.icon, color: Colors.white, size: 12)),
                                  const SizedBox(width: 12),
                                  Text(crop.name, style: const TextStyle(color: Colors.white)),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (val) => setDialogState(() => selectedCrop = val!),
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2101),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Color(0xFF8DBA60),
                              onPrimary: Colors.black,
                              surface: Color(0xFF162A1D),
                              onSurface: Colors.white,
                            ),
                            dialogBackgroundColor: const Color(0xFF162A1D),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null && picked != selectedDate) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Planting Date', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
                        Text(DateFormat('MMM dd, yyyy').format(selectedDate), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white.withValues(alpha: 0.5), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Areas > 2.0 ha will be displayed as large',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white38)),
            ),
            ElevatedButton(
              onPressed: () {
                final input = double.tryParse(hectaresController.text);
                if (input == null) {
                  setDialogState(() => hectaresError = 'Please enter a valid number');
                  return;
                }

                if (input > _remainingHectares) {
                  setDialogState(() => hectaresError = 'Exceeds remaining farm limit (${_remainingHectares.toStringAsFixed(1)} ha)');
                  return;
                }

                if (nameController.text.isNotEmpty) {
                  setState(() {
                    final newArea = FarmArea(
                      id: _farmAreas.length,
                      name: nameController.text,
                      crop: selectedCrop,
                      hectares: input,
                      plantingDate: selectedDate,
                    );
                    newArea.tasks = [
                      MonitoringTask(id: '1', title: 'Soil PH Test', status: TaskStatus.active),
                      MonitoringTask(id: '2', title: 'Nitrogen Level Check', status: TaskStatus.future),
                      MonitoringTask(id: '3', title: 'Initial Hydration', status: TaskStatus.completed),
                    ];
                    _farmAreas.add(newArea);
                  });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8DBA60),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Initialize'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildCropSetupSection()),
        SliverToBoxAdapter(child: _buildActionBar()),
        SliverToBoxAdapter(child: _buildFarmUsageBar()), // Progress bar added
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          sliver: _buildFarmIllustration(),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildFarmUsageBar() {
    if (_isLoadingLimit) return const LinearProgressIndicator();

    final usageRatio = _totalFarmLimit == 0 ? 0.0 : _usedHectares / _totalFarmLimit;
    final barColor = usageRatio > 0.9 ? Colors.red : const Color(0xFF8DBA60);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Farm Usage: ${_usedHectares.toStringAsFixed(1)} / $_totalFarmLimit ha', style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: usageRatio,
            color: barColor,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            minHeight: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildCropSetupSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CROP LIBRARY', 
            style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w900, color: const Color(0xFF8DBA60))),
          const SizedBox(height: 16),
          TextField(
            controller: _newCropController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Add cultivar...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.03),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              suffixIcon: IconButton(
                icon: const Icon(Icons.add_circle, color: Color(0xFF8DBA60)),
                onPressed: _addNewCrop,
              ),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white10)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF8DBA60))),
            ),
            onSubmitted: (_) => _addNewCrop(),
          ),
          if (_myCrops.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _myCrops.map((crop) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: crop.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: crop.color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(crop.icon, size: 12, color: crop.color),
                    const SizedBox(width: 8),
                    Text(crop.name, style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Farm Layout', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
          ElevatedButton.icon(
            onPressed: _showAddAreaDialog,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Area'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8DBA60),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmIllustration() {
    if (_farmAreas.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(48),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.01),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.02)),
          ),
          child: Column(
            children: [
              Icon(Icons.grid_view_rounded, color: Colors.white10, size: 48),
              const SizedBox(height: 16),
              Text('No areas mapped yet', style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.3,
                child: CustomPaint(painter: GridBlueprintPainter(color: Colors.white10, spacing: 20)),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;
                const double spacing = 12;
                final double unitSize = (width - (spacing * (widget.cols - 1))) / widget.cols;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: _farmAreas.map((area) {
                    final double size = area.isLarge 
                        ? (unitSize * 2) + spacing 
                        : unitSize;
                    
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context, 
                          MaterialPageRoute(
                            builder: (context) => FarmAreaMonitoringScreen(
                              farmArea: area,
                              onDelete: () => setState(() => _farmAreas.remove(area)),
                            )
                          )
                        ).then((_) => setState(() {})); // Refresh on return
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutQuart,
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              area.crop.color.withValues(alpha: 0.2),
                              area.crop.color.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(area.isLarge ? 28 : 16),
                          border: Border.all(color: area.crop.color.withValues(alpha: 0.3), width: 1.5),
                          boxShadow: [
                            BoxShadow(color: area.crop.color.withValues(alpha: 0.1), blurRadius: 20, spreadRadius: -5)
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(painter: GridBlueprintPainter(color: area.crop.color.withValues(alpha: 0.05), spacing: 10)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(area.isLarge ? 24 : 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.1), 
                                      shape: BoxShape.circle,
                                      border: Border.all(color: area.crop.color.withValues(alpha: 0.3)),
                                    ),
                                    child: Icon(area.crop.icon, color: Colors.white, size: area.isLarge ? 28 : 14),
                                  ),
                                  const Spacer(),
                                  Text(
                                    area.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      color: Colors.white, 
                                      fontSize: area.isLarge ? 18 : 10, 
                                      fontWeight: FontWeight.w700
                                    ),
                                  ),
                                  if (area.isLarge)
                                    Text('PRIMARY PLOT', 
                                      style: GoogleFonts.inter(color: area.crop.color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class GridBlueprintPainter extends CustomPainter {
  final Color color;
  final double spacing;

  GridBlueprintPainter({required this.color, this.spacing = 20});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}