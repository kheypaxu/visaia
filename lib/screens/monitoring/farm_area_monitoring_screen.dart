import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:visaia/core/models/crop_type.dart';
import 'package:visaia/screens/reporting/pest_report_submission_screen.dart';
import 'package:visaia/screens/monitoring/detection_history_list_screen.dart';
import 'package:visaia/screens/monitoring/detection_history_details_screen.dart';

class FarmAreaMonitoringScreen extends StatefulWidget {
  final FarmArea farmArea;
  final VoidCallback onDelete;

  const FarmAreaMonitoringScreen({
    Key? key,
    required this.farmArea,
    required this.onDelete,
  }) : super(key: key);

  @override
  _FarmAreaMonitoringScreenState createState() => _FarmAreaMonitoringScreenState();
}

class _FarmAreaMonitoringScreenState extends State<FarmAreaMonitoringScreen> {
  @override
  Widget build(BuildContext context) {
    final area = widget.farmArea;
    
    return Scaffold(
      backgroundColor: const Color(0xFF102216),
      body: Stack(
        children: [
          // Background Glows
          Positioned(top: -150, left: -100, child: _buildBlurCircle(300, const Color(0xFF8DBA60).withValues(alpha: 0.03))),
          Positioned(bottom: 50, right: -100, child: _buildBlurCircle(400, const Color(0xFF2E8B57).withValues(alpha: 0.05))),
          
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildHeader(area),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 24),
                      _buildMetricsGrid(area),
                      const SizedBox(height: 32),
                      
                      // Detection History Section
                      _buildDetectionHistorySection(area),
                      const SizedBox(height: 32),
                      
                      // Tasks Section
                      _buildTasksSection(area),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
        decoration: BoxDecoration(
          color: const Color(0xFF102216).withValues(alpha: 0.8),
          border: const Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildActionButton('INITIATE PEST SCAN', Icons.bug_report_rounded, Colors.redAccent, () {
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (context) => SubmitPestReportPage(targetArea: area)
                )
              ).then((_) => setState(() {}));
            }),
            const SizedBox(height: 12),
            _buildActionButton('DECOMMISSION AREA', Icons.archive_outlined, Colors.white12, () {
              widget.onDelete();
              Navigator.pop(context);
            }, isOutlined: true),
          ],
        ),
      ),
    );
  }

  Widget _buildBlurCircle(double size, Color color) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }

  Widget _buildHeader(FarmArea area) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      expandedHeight: 120,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: const EdgeInsets.fromLTRB(28, 48, 28, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(area.crop.name.toUpperCase(), 
                      style: GoogleFonts.inter(letterSpacing: 2, fontSize: 10, fontWeight: FontWeight.w900, color: area.crop.color)),
                    Text(area.name, 
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                    if (area.plantingDate != null)
                      Text('Planted ${DateFormat('MMM dd, yyyy').format(area.plantingDate!)}', 
                        style: GoogleFonts.inter(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: area.crop.color.withValues(alpha: 0.1), 
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: area.crop.color.withValues(alpha: 0.2)),
                ),
                child: Icon(area.crop.icon, color: area.crop.color, size: 36),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(FarmArea area) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.6,
      children: [
        _buildMetricCard('Status', 'Optimal', const Color(0xFF8DBA60)),
        _buildMetricCard('Health', '${(area.health * 100).toInt()}%', area.crop.color),
        _buildMetricCard('Growth', '${(area.growthProgress * 100).toInt()}%', Colors.blueAccent),
        _buildMetricCard('Age', '${DateTime.now().difference(area.plantingDate ?? DateTime.now()).inDays} Days', Colors.orangeAccent),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: GoogleFonts.inter(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildDetectionHistorySection(FarmArea area) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('DETECTION HISTORY', 
              style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w900, color: const Color(0xFF8DBA60))),
            if (area.detectionHistory.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetectionHistoryListScreen(farmArea: area))),
                child: Text('VIEW ALL', style: GoogleFonts.inter(color: const Color(0xFF8DBA60), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (area.detectionHistory.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(Icons.history_rounded, color: Colors.white.withValues(alpha: 0.05), size: 32),
                const SizedBox(height: 12),
                Text('No recent infestations recorded', 
                  style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
              ],
            ),
          )
        else
          ...area.detectionHistory.reversed.take(2).map((detection) => _buildDetectionCard(detection)).toList(),
      ],
    );
  }

  Widget _buildDetectionCard(PestDetection detection) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetectionHistoryDetailsScreen(detection: detection))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bug_report, color: Colors.redAccent, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(detection.label, 
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  Text('${(detection.confidence * 100).toInt()}% Confidence • ${DateFormat('MMM dd, hh:mm a').format(detection.timestamp)}', 
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white10),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksSection(FarmArea area) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('FARM DIRECTIVES', 
              style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w900, color: const Color(0xFF8DBA60))),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF8DBA60), size: 20),
              onPressed: () => _showAddTaskDialog(area),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: area.tasks.length,
          itemBuilder: (context, index) => _buildSimpleTaskEntry(area.tasks[index], area),
        ),
      ],
    );
  }

  Widget _buildSimpleTaskEntry(MonitoringTask task, FarmArea area) {
    final bool isCompleted = task.status == TaskStatus.completed;
    final bool isActive = task.status == TaskStatus.active;
    final Color statusColor = isCompleted ? const Color(0xFF8DBA60) : isActive ? Colors.orangeAccent : Colors.white24;

    return GestureDetector(
      onTap: () {
        setState(() {
          task.status = isCompleted ? TaskStatus.active : TaskStatus.completed;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title, 
                    style: GoogleFonts.inter(
                      color: isCompleted ? Colors.white24 : Colors.white, 
                      fontSize: 15, 
                      fontWeight: FontWeight.w700,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    )),
                  if (task.dueDate != null && !isCompleted)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Scheduled for ${DateFormat('MMM dd').format(task.dueDate!)}', 
                        style: GoogleFonts.inter(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.w500)),
                    ),
                ],
              ),
            ),
            if (!isCompleted)
              IconButton(
                onPressed: () => _showTaskOptions(task),
                icon: const Icon(Icons.more_horiz, color: Colors.white12),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  void _showTaskOptions(MonitoringTask task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF162A1D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bolt, color: Color(0xFF8DBA60)),
              title: Text('Set as Active', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
              onTap: () {
                setState(() => task.status = TaskStatus.active);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule, color: Colors.blueAccent),
              title: Text('Schedule for Later', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
              onTap: () {
                setState(() => task.status = TaskStatus.future);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTaskDialog(FarmArea area) {
    final taskController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF162A1D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: const BorderSide(color: Colors.white10)),
        title: Text('New Strategy', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: taskController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Task description...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white38))),
          ElevatedButton(
            onPressed: () {
              if (taskController.text.isNotEmpty) {
                setState(() {
                  area.tasks.add(MonitoringTask(id: DateTime.now().toString(), title: taskController.text, status: TaskStatus.active));
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8DBA60), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Initialize'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap, {bool isOutlined = false}) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
        style: ElevatedButton.styleFrom(
          backgroundColor: isOutlined ? Colors.transparent : color,
          foregroundColor: isOutlined ? Colors.white38 : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: isOutlined ? BorderSide(color: Colors.white.withValues(alpha: 0.1)) : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
