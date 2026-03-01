import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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

class _ResultPageState extends State<ResultPage> {
  // Constants from your new layout style
  static const Color bgDark = Color(0xFF102216);
  static const Color errorRed = Color(0xFFE32525);
  static const Color successGreen = Color(0xFF76CA22);
  static const Color cardBg = Color(0xFF232C26);
  static const Color greyText = Color(0xFF878787);
  static const Color white = Color(0xFFFFFFFF);
  static const Color primaryBtn = Color(0xFF8DBA60);

  // Default location (Can be updated if your targetArea has coordinates)
  final LatLng detectionLocation = const LatLng(14.5995, 120.9842);

  @override
  void initState() {
    super.initState();
    // Auto-save to history logic
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Analysis Result",
          style: GoogleFonts.inter(color: white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: white),
            onPressed: () => Share.share(
                'Diagnostic Report: ${widget.result.pestName} identified with ${widget.result.riskLevel} risk.'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildImageSection(),
            _buildIdentifiedPestCard(),
            _buildMapSection(),
            _buildActionButtons(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Container(
          height: 250,
          width: double.infinity,
          color: cardBg,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(widget.image, fit: BoxFit.cover),
              // Render AI Bounding Boxes over the image
              LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: widget.result.boxes.map((box) {
                      final color = box.className.toLowerCase().contains('larva') ? errorRed : successGreen;
                      return Positioned(
                        left: box.x * constraints.maxWidth,
                        top: box.y * constraints.maxHeight,
                        width: box.width * constraints.maxWidth,
                        height: box.height * constraints.maxHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: color, width: 2),
                            borderRadius: BorderRadius.circular(4),
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
      ),
    );
  }

  Widget _buildIdentifiedPestCard() {
    final bool isHighRisk = widget.result.riskLevel.toLowerCase() == 'high';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Identified Pest", style: TextStyle(color: greyText, fontSize: 14)),
                  Text(
                    widget.result.pestName,
                    style: const TextStyle(color: white, fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    "Spodoptera frugiperda", // Scientific name placeholder
                    style: TextStyle(color: greyText, fontStyle: FontStyle.italic, fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: bgDark, shape: BoxShape.circle),
                child: const Icon(Icons.pest_control, color: primaryBtn, size: 28),
              )
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10, thickness: 1),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Life Stage", style: TextStyle(color: greyText)),
                    Text(
                      widget.result.lifeStage.isEmpty ? "Larvae" : widget.result.lifeStage,
                      style: const TextStyle(color: white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Risk Level", style: TextStyle(color: greyText)),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: isHighRisk ? errorRed : successGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.result.riskLevel,
                          style: TextStyle(
                            color: isHighRisk ? errorRed : successGreen,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          const Row(
            children: [
              Icon(Icons.grid_view_rounded, color: successGreen, size: 20),
              SizedBox(width: 8),
              Text("Analysis Content", style: TextStyle(color: white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.result.explanation,
            style: const TextStyle(color: greyText, fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.map_outlined, color: white),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("GIS Location", style: TextStyle(color: greyText, fontSize: 12)),
                      Text(
                        widget.targetArea?.name ?? "Current Field Location",
                        style: const TextStyle(color: white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              TextButton(
                onPressed: () {},
                child: const Text("View Map", style: TextStyle(color: greyText)),
              )
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: detectionLocation,
                  initialZoom: 14.0,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.visaia.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: detectionLocation,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_on, color: errorRed, size: 40),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBtn,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                // Logic for risk mapping
              },
              child: const Text(
                "Proceed Risk Mapping",
                style: TextStyle(color: bgDark, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Dismiss Report", style: TextStyle(color: greyText, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}