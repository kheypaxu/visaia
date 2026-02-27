import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:visaia/core/services/api_service.dart';
import 'package:visaia/core/models/crop_type.dart';

class ResultPage extends StatefulWidget {
  final File image;
  final AnalysisResult result;
  final FarmArea? targetArea;

  const ResultPage({
    Key? key,
    required this.image,
    required this.result,
    this.targetArea,
  }) : super(key: key);

  @override
  _ResultPageState createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
    
    // Auto-save to farm area history if context exists
    if (widget.targetArea != null) {
      widget.targetArea!.detectionHistory.add(PestDetection(
        id: DateTime.now().toString(),
        label: widget.result.pestName,
        confidence: widget.result.boxes.isNotEmpty ? widget.result.boxes.first.confidence : 0.9,
        timestamp: DateTime.now(),
        imageUrl: widget.image.path,
      ));
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF102216),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildImageSection(),
                    const SizedBox(height: 32),
                    _buildIdentityCard(),
                    const SizedBox(height: 24),
                    _buildRiskDashboard(),
                    const SizedBox(height: 24),
                    _buildAnalysisSummary(),
                    const SizedBox(height: 48),
                    _buildActionFooter(),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: const Color(0xFF102216),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_rounded, color: Color(0xFF8DBA60)),
          onPressed: () => Share.share('Diagnostic Report: ${widget.result.pestName} at ${widget.result.lifeStage} stage.'),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text('Diagnostic Report', 
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      height: 320,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 15))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.file(widget.image, fit: BoxFit.fill),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                      stops: const [0.6, 1.0],
                    ),
                  ),
                ),
                ...widget.result.boxes.map((box) => _buildBoundingBox(box, width, height)),
                _buildAnalyzedBadge(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBoundingBox(BoundingBox box, double cw, double ch) {
    final color = box.className.toLowerCase().contains('larva') ? Colors.redAccent : const Color(0xFF8DBA60);
    return Positioned(
      left: box.x * cw, top: box.y * ch, width: box.width * cw, height: box.height * ch,
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: color, width: 2), borderRadius: BorderRadius.circular(6)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -22, left: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  "${box.className} ${(box.confidence * 100).toStringAsFixed(0)}%",
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzedBadge() {
    return Positioned(
      top: 20, right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Icon(Icons.verified_rounded, color: Colors.green[700], size: 16),
            const SizedBox(width: 8),
            Text('Validated', style: GoogleFonts.inter(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityCard() {
    final isFAW = widget.result.pestName.toLowerCase().contains('fall army');
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isFAW ? Colors.redAccent : const Color(0xFF8DBA60)).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(isFAW ? Icons.warning_rounded : Icons.bug_report_rounded, 
              color: isFAW ? Colors.redAccent : const Color(0xFF8DBA60), size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IDENTIFIED SPECIES', 
                  style: GoogleFonts.inter(letterSpacing: 2, fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white38)),
                Text(widget.result.pestName, 
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                if (widget.result.lifeStage.isNotEmpty)
                  Text('Phase: ${widget.result.lifeStage}', 
                    style: GoogleFonts.inter(color: const Color(0xFF8DBA60), fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskDashboard() {
    final riskColor = _getRiskColor(widget.result.riskLevel);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('THREAT ASSESSMENT', 
          style: GoogleFonts.inter(letterSpacing: 2, fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white38)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: riskColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: riskColor.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Risk Index', style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                  Text(widget.result.riskLevel, 
                    style: GoogleFonts.inter(color: riskColor, fontWeight: FontWeight.w800, fontSize: 18)),
                ],
              ),
              const SizedBox(height: 16),
              Stack(
                children: [
                  Container(height: 8, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10))),
                  FractionallySizedBox(
                    widthFactor: _getRiskLevelFactor(widget.result.riskLevel),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [riskColor.withValues(alpha: 0.4), riskColor]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NEURAL INSIGHTS', 
          style: GoogleFonts.inter(letterSpacing: 2, fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white38)),
        const SizedBox(height: 16),
        Text(
          widget.result.explanation,
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 15, height: 1.6),
        ),
      ],
    );
  }

  Widget _buildActionFooter() {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8DBA60),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Text('DISMISS REPORT', 
          style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.5)),
      ),
    );
  }

  Color _getRiskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'high': return Colors.redAccent;
      case 'medium': return Colors.orangeAccent;
      case 'low': return const Color(0xFF8DBA60);
      default: return Colors.blueAccent;
    }
  }

  double _getRiskLevelFactor(String risk) {
    switch (risk.toLowerCase()) {
      case 'high': return 0.9;
      case 'medium': return 0.5;
      case 'low': return 0.25;
      default: return 0.1;
    }
  }
}