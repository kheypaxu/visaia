import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class PestVerificationScreen extends StatefulWidget {
  final String userId;
  final String cycleId;
  final int stationIndex;
  final Map<String, dynamic> station;
  final Function(Map<String, dynamic> updatedStation) onVerificationComplete;

  const PestVerificationScreen({
    super.key,
    required this.userId,
    required this.cycleId,
    required this.stationIndex,
    required this.station,
    required this.onVerificationComplete,
  });

  @override
  State<PestVerificationScreen> createState() => _PestVerificationScreenState();
}

class _PestVerificationScreenState extends State<PestVerificationScreen> {
  final ImagePicker _picker = ImagePicker();
  Map<String, List<String>> _capturedImages = {};
  Map<String, bool> _verificationStatus = {};
  Map<String, bool> _isProcessing = {};

  static const _green = Color(0xFF1A5C30);
  static const _lightGreen = Color(0xFFEAF3DE);
  static const _accentGreen = Color(0xFF4E9F3D);
  static const _bgColor = Color(0xFFF7F8F5);
  static const _cardWhite = Color(0xFFFFFFFF);
  static const _orange = Color(0xFFFF9800);

  final List<Map<String, dynamic>> _pestTypes = [
    {'key': 'eggMasses', 'label': 'Egg Masses', 'icon': Icons.circle, 'color': const Color(0xFFE91E63)},
    {'key': 'larvae', 'label': 'Larvae', 'icon': Icons.bug_report, 'color': const Color(0xFFFF9800)},
    {'key': 'pupae', 'label': 'Pupae', 'icon': Icons.coffee, 'color': const Color(0xFF9C27B0)},
    {'key': 'moths', 'label': 'Moths', 'icon': Icons.bug_report_outlined, 'color': const Color(0xFF2196F3)},
  ];

  @override
  void initState() {
    super.initState();
    _initializeVerificationData();
  }

  void _initializeVerificationData() {
    final capturedImages = widget.station['capturedImages'] as Map<String, dynamic>? ?? {};
    _capturedImages = {
      'eggMasses': List<String>.from(capturedImages['eggMasses'] ?? []),
      'larvae': List<String>.from(capturedImages['larvae'] ?? []),
      'pupae': List<String>.from(capturedImages['pupae'] ?? []),
      'moths': List<String>.from(capturedImages['moths'] ?? []),
    };

    for (var pest in _pestTypes) {
      final key = pest['key'] as String;
      final count = widget.station[key] as int? ?? 0;
      final hasCaptured = _capturedImages[key]?.isNotEmpty ?? false;
      _verificationStatus[key] = (count > 0 && hasCaptured) || count == 0;
    }
  }

  Widget _buildImage(String imageData) {
    try {
      // If it's a network URL
      if (imageData.startsWith('http')) {
        return Image.network(
          imageData,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) {
            return const Center(
              child: Icon(Icons.broken_image),
            );
          },
        );
      }

      // If it's base64
      final pureBase64 = imageData.contains(',')
          ? imageData.split(',').last
          : imageData;

      final bytes = base64Decode(pureBase64);

      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) {
          return const Center(
            child: Icon(Icons.broken_image),
          );
        },
      );
    } catch (e) {
      debugPrint('Image decode error: $e');

      return Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(
            Icons.broken_image,
            color: Colors.grey,
          ),
        ),
      );
    }
  }

  Future<String> _convertImageToBase64(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64String = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64String';
  }

  Future<void> _capturePestImage(String pestType) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70, // Reduced quality for base64 size
    );
    
    if (image != null && mounted) {
      setState(() {
        _isProcessing[pestType] = true;
      });
      
      // Convert image to base64
      final base64Image = await _convertImageToBase64(File(image.path));
      
      if (mounted) {
        setState(() {
          _capturedImages[pestType]!.add(base64Image);
          _verificationStatus[pestType] = true;
          _isProcessing[pestType] = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_getPestLabel(pestType)} image captured and saved'),
            backgroundColor: _accentGreen,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery(String pestType) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // Reduced quality for base64 size
    );
    
    if (image != null && mounted) {
      setState(() {
        _isProcessing[pestType] = true;
      });
      
      // Convert image to base64
      final base64Image = await _convertImageToBase64(File(image.path));
      
      if (mounted) {
        setState(() {
          _capturedImages[pestType]!.add(base64Image);
          _verificationStatus[pestType] = true;
          _isProcessing[pestType] = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_getPestLabel(pestType)} image added from gallery'),
            backgroundColor: _accentGreen,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  String _getPestLabel(String pestType) {
    final pest = _pestTypes.firstWhere((p) => p['key'] == pestType);
    return pest['label'] as String;
  }

  void _removeImage(String pestType, int index) {
    setState(() {
      _capturedImages[pestType]!.removeAt(index);
      final count = widget.station[pestType] as int? ?? 0;
      if (count > 0 && _capturedImages[pestType]!.isEmpty) {
        _verificationStatus[pestType] = false;
      }
    });
  }

  void _saveAndComplete() {
    final incompleteVerifications = <String>[];
    
    for (var pest in _pestTypes) {
      final key = pest['key'] as String;
      final count = widget.station[key] as int? ?? 0;
      
      if (count > 0 && (_capturedImages[key]?.isEmpty ?? true)) {
        incompleteVerifications.add(pest['label'] as String);
      }
    }

    if (incompleteVerifications.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please capture images for: ${incompleteVerifications.join(", ")}',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final updatedStation = Map<String, dynamic>.from(widget.station);
    updatedStation['capturedImages'] = _capturedImages;
    updatedStation['verificationCompleted'] = true;
    updatedStation['verificationRequired'] = false;

    widget.onVerificationComplete(updatedStation);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _green),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Pest Verification',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: _green,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            ..._buildPestVerificationCards(),
            const SizedBox(height: 30),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    int totalRequired = 0;
    int totalCaptured = 0;
    
    for (var pest in _pestTypes) {
      final key = pest['key'] as String;
      final count = widget.station[key] as int? ?? 0;
      if (count > 0) {
        totalRequired++;
        if (_capturedImages[key]?.isNotEmpty ?? false) totalCaptured++;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_outlined, color: _orange, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Station ${widget.stationIndex + 1} Verification',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (totalRequired > 0) ...[
            LinearProgressIndicator(
              value: totalCaptured / totalRequired,
              backgroundColor: _lightGreen,
              valueColor: const AlwaysStoppedAnimation<Color>(_accentGreen),
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 8),
            Text(
              '$totalCaptured of $totalRequired pest types verified',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ] else
            Text(
              'No pests to verify',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildPestVerificationCards() {
    final cards = <Widget>[];
    
    for (var pest in _pestTypes) {
      final key = pest['key'] as String;
      final count = widget.station[key] as int? ?? 0;
      final hasImages = (_capturedImages[key]?.isNotEmpty ?? false);
      final needsVerification = count > 0;
      final isProcessing = _isProcessing[key] ?? false;
      
      if (!needsVerification) continue;
      
      cards.add(
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: _cardWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasImages ? _accentGreen : Colors.grey.shade200,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (pest['color'] as Color).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        pest['icon'] as IconData,
                        color: pest['color'] as Color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pest['label'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Count: $count',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: hasImages ? _lightGreen : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasImages ? Icons.check_circle : Icons.warning_amber,
                            color: hasImages ? _accentGreen : Colors.orange,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasImages ? 'Verified' : 'Required',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: hasImages ? _accentGreen : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              if (hasImages && _capturedImages[key]!.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _capturedImages[key]!.length,
                      itemBuilder: (context, imgIndex) {
                        return Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _buildImage(_capturedImages[key]![imgIndex]),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 12,
                              child: GestureDetector(
                                onTap: () => _removeImage(key, imgIndex),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              if (isProcessing)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: LinearProgressIndicator(),
                ),
              
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isProcessing ? null : () => _capturePestImage(key),
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text('Capture'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: _green.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isProcessing ? null : () => _pickFromGallery(key),
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: const Text('Gallery'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: _green.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return cards;
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _saveAndComplete,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          'Complete Verification ✓',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}