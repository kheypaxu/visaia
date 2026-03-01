import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:visaia/core/services/api_service.dart';
import 'package:visaia/widgets/loading_overlay.dart';
import 'package:visaia/screens/reporting/result_screen.dart';
import 'package:visaia/core/models/crop_type.dart';

class SubmitPestReportPage extends StatefulWidget {
  final FarmArea? targetArea;
  const SubmitPestReportPage({Key? key, this.targetArea}) : super(key: key);

  @override
  _SubmitPestReportPageState createState() => _SubmitPestReportPageState();
}

class _SubmitPestReportPageState extends State<SubmitPestReportPage> {
  final _locationController = TextEditingController();
  final _dateTimeController = TextEditingController();

  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _getCurrentDateTime();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _dateTimeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark place = placemarks[0];
      setState(() => _locationController.text = "${place.locality}, ${place.country}");
    } catch (e) {
      setState(() => _locationController.text = 'Location Detection Pending...');
    }
  }

  void _getCurrentDateTime() {
    final now = DateTime.now();
    setState(() => _dateTimeController.text = DateFormat('MMM d, y • h:mm a').format(now));
  }

  Future<void> _submitForAnalysis() async {
    if (_image == null) return;
    setState(() => _isAnalyzing = true);
    try {
      final result = await ApiService.sendImage(_image!);
      if (mounted) {
        setState(() => _isAnalyzing = false);
        Navigator.push(context, MaterialPageRoute(builder: (_) => ResultPage(
          image: _image!, 
          result: result,
          targetArea: widget.targetArea,
        )));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Analysis Link Error: $e"), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if we are being pushed (standalone) or displayed in RootLayout
    final bool isStandalone = ModalRoute.of(context)?.canPop ?? false;

    Widget content = Stack(
      children: [
        // Background Glows (For Standalone)
        if (isStandalone) ...[
          Positioned(top: -150, left: -100, child: _buildBlurCircle(300, const Color(0xFF8DBA60).withValues(alpha: 0.03))),
          Positioned(bottom: 50, right: -100, child: _buildBlurCircle(400, const Color(0xFF2E8B57).withValues(alpha: 0.05))),
        ],
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 20),
                  _buildUploadCard(),
                  const SizedBox(height: 32),
                  _buildMetadataSection(),
                  const SizedBox(height: 48),
                  if (_image != null) _buildControlPanel(),
                  const SizedBox(height: 60),
                ]),
              ),
            ),
          ],
        ),
        if (_isAnalyzing) const AnalysisLoadingOverlay(),
      ],
    );
    return content;
  }

  Widget _buildBlurCircle(double size, Color color) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }

  Widget _buildUploadCard() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 380,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1.5),
        ),
        child: _image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image.file(_image!, fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: const Color(0xFF8DBA60).withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.camera_enhance_rounded, size: 48, color: Color(0xFF8DBA60)),
                  ),
                  const SizedBox(height: 24),
                  Text('Capture Specimen', style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('High-resolution macro recommended', style: GoogleFonts.inter(color: Colors.white38, fontSize: 13)),
                ],
              ),
      ),
    );
  }

  Widget _buildMetadataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SCAN PARAMETERS', 
          style: GoogleFonts.inter(letterSpacing: 2, fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF8DBA60))),
        const SizedBox(height: 20),
        _buildMetadataTile(Icons.location_on_rounded, 'Geo-Coordinates', _locationController.text),
        const SizedBox(height: 16),
        _buildMetadataTile(Icons.calendar_month_rounded, 'Timestamp', _dateTimeController.text),
        const SizedBox(height: 24),
        _buildIntelligenceNotice(),
      ],
    );
  }

  Widget _buildMetadataTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8DBA60), size: 20),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(color: Colors.white24, fontSize: 11)),
              Text(value, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIntelligenceNotice() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF8DBA60).withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8DBA60).withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.psychology_rounded, color: Color(0xFF8DBA60), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Neural Engine active. Analysis integrates risk mapping and mitigation strategies.',
              style: GoogleFonts.inter(color: Colors.white60, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Column(
      children: [
        _buildPrimaryBtn('RUN DIAGNOSTIC', Icons.analytics_outlined, _submitForAnalysis, true),
        const SizedBox(height: 12),
        _buildPrimaryBtn('RETAKE SOURCE', Icons.refresh_rounded, _pickImage, false),
      ],
    );
  }

  Widget _buildPrimaryBtn(String label, IconData icon, VoidCallback tap, bool isMain) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: tap,
        icon: Icon(icon, size: 20),
        label: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
        style: ElevatedButton.styleFrom(
          backgroundColor: isMain ? const Color(0xFF8DBA60) : Colors.transparent,
          foregroundColor: isMain ? Colors.black : const Color(0xFF8DBA60),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: isMain ? BorderSide.none : const BorderSide(color: Color(0xFF8DBA60), width: 1.5)),
        ),
      ),
    );
  }
}