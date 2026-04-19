import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;
import 'package:visaia/core/services/api_service.dart';
import 'package:visaia/core/models/crop_type.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResultPage extends StatefulWidget {
  final File image;
  final AnalysisResult result;
  final FarmArea? targetArea;
  final double latitude;
  final double longitude;

  const ResultPage({
    Key? key,
    required this.image,
    required this.result,
    required this.latitude,
    required this.longitude,
    this.targetArea,
  }) : super(key: key);

  @override
  _ResultPageState createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  static const Color bgDark = Color(0xFF102216);
  static const Color errorRed = Color(0xFFE32525);
  static const Color successGreen = Color(0xFF76CA22);
  static const Color cardBg = Color(0xFF232C26);
  static const Color greyText = Color(0xFF878787);
  static const Color white = Color(0xFFFFFFFF);
  static const Color primaryBtn = Color(0xFF8DBA60);

  late LatLng detectionLocation;

  @override
  void initState() {
    super.initState();
    // Initialize map position from passed coordinates
    detectionLocation = LatLng(widget.latitude, widget.longitude);
    
    // Log detection to local history if target area exists
    if (widget.targetArea != null) {
      widget.targetArea!.detectionHistory.add(PestDetection(
        id: DateTime.now().toIso8601String(),
        label: widget.result.pestName,
        confidence: widget.result.boxes.isNotEmpty ? widget.result.boxes.first.confidence : 0.9,
        timestamp: DateTime.now(),
        imageUrl: widget.image.path,
      ));
    }
  }

  Future<void> _submitReportToExpert() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: primaryBtn),
        ),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final farmerDoc = await FirebaseFirestore.instance.collection('farmers').doc(user.uid).get();
      final String fullName = farmerDoc.data()?['fullName'] ?? "Unknown Farmer";

      // 1. Process and Compress Image for Firestore compatibility
      final bytes = await widget.image.readAsBytes();
      img.Image? decoded = img.decodeImage(bytes);
      
      if (decoded == null) throw Exception("Image processing failed");

      // Resize to 500px width and use 50% quality to ensure stay well under 1MB
      img.Image resized = img.copyResize(decoded, width: 500);
      String base64Image = base64Encode(img.encodeJpg(resized, quality: 50));

      // Update your reportData in Flutter to be consistent
      Map<String, dynamic> reportData = {
        'farmerId': user.uid,
        'farmerName': fullName,
        'detection': widget.result.pestName, // Rename from 'pestName' to 'detection'
        'scientificName': "Spodoptera frugiperda",
        'lifeStage': widget.result.lifeStage.isNotEmpty ? widget.result.lifeStage : "N/A",
        'risk': widget.result.riskLevel,    
        'explanation': widget.result.explanation,
        'imageBase64': base64Image,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'location': {
          'lat': widget.latitude,
          'lng': widget.longitude,
          'areaName': widget.targetArea?.name ?? "General Field",
        },
        'confidence': widget.result.boxes.isNotEmpty ? widget.result.boxes.first.confidence : 0.0,
      };

      // 3. Save to Cloud Firestore
      await FirebaseFirestore.instance.collection('reports').add(reportData);

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _showSuccessNotification();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cloud Sync Failed: $e"), backgroundColor: errorRed),
      );
    }
  }

  void _showSuccessNotification() {
    // 1. Just pop once to get out of the ResultPage back to the SubmitPestReportPage
    Navigator.of(context).pop();

    // 2. Show the Success Snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 12),
            Text("Report successfully sent to DA!"),
          ],
        ),
        backgroundColor: const Color(0xFF76CA22),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
      ),
    );
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
                'Visaia Report: ${widget.result.pestName} detected at ${widget.latitude}, ${widget.longitude}'),
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
                    "Spodoptera frugiperda",
                    style: TextStyle(color: greyText, fontStyle: FontStyle.italic, fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: bgDark, shape: BoxShape.circle),
                child: const Icon(Icons.biotech_rounded, color: primaryBtn, size: 28),
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
                          width: 10, height: 10,
                          decoration: BoxDecoration(color: isHighRisk ? errorRed : successGreen, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.result.riskLevel,
                          style: TextStyle(color: isHighRisk ? errorRed : successGreen, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: primaryBtn, size: 18),
              const SizedBox(width: 8),
              Text("NEURAL INSIGHT", style: GoogleFonts.inter(color: primaryBtn, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.result.explanation,
            style: const TextStyle(color: greyText, fontSize: 14, height: 1.5),
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
                  const Icon(Icons.share_location_rounded, color: white),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("GIS Telemetry", style: TextStyle(color: greyText, fontSize: 12)),
                      Text(
                        widget.targetArea?.name ?? "Field Coordinate",
                        style: const TextStyle(color: white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                "${widget.latitude.toStringAsFixed(4)}, ${widget.longitude.toStringAsFixed(4)}",
                style: const TextStyle(color: greyText, fontSize: 10),
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
                  initialZoom: 15.0,
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
            height: 58,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBtn,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _submitReportToExpert,
              child: Text(
                "Submit to DA",
                style: GoogleFonts.inter(color: bgDark, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).pop(), // This takes you back to SubmitPestReportPage
            child: const Text("Dismiss and Retake", style: TextStyle(color: greyText, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}