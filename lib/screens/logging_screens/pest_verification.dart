import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:visaia/services/firestore_image_service.dart';
import 'package:visaia/widgets/database_image.dart';

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
  Map<String, bool> _isProcessing = {};
  
  // Damage verification state
  List<String> _damagePhotos = [];
  bool _isDamageProcessing = false;

  static const _green = Color(0xFF1A5C30);
  static const _lightGreen = Color(0xFFEAF3DE);
  static const _accentGreen = Color(0xFF4E9F3D);
  static const _bgColor = Color(0xFFF7F8F5);
  static const _cardWhite = Color(0xFFFFFFFF);
  static const _orange = Color(0xFFFF9800);
  static const _purple = Color(0xFF7B1FA2);
  static const _textDark = Color(0xFF1A1A1A);
  static const _textGrey = Color(0xFF666666);

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
    // Initialize pest images
    final capturedImages = widget.station['capturedImages'] as Map<String, dynamic>? ?? {};
    _capturedImages = {
      'eggMasses': List<String>.from(capturedImages['eggMasses'] ?? []),
      'larvae': List<String>.from(capturedImages['larvae'] ?? []),
      'pupae': List<String>.from(capturedImages['pupae'] ?? []),
      'moths': List<String>.from(capturedImages['moths'] ?? []),
    };

    // Initialize damage photos
    _damagePhotos = List<String>.from(widget.station['damagePhotos'] ?? []);
  }

  bool _hasFAWPresence() {
    final eggs = widget.station['eggMasses'] as int? ?? 0;
    final larvae = widget.station['larvae'] as int? ?? 0;
    final pupae = widget.station['pupae'] as int? ?? 0;
    final moths = widget.station['moths'] as int? ?? 0;
    final fawObserved = widget.station['fawObserved'] as bool? ?? false;
    return eggs > 0 || larvae > 0 || pupae > 0 || moths > 0 || fawObserved;
  }

  Widget _buildImage(String imageData) {
    return DatabaseImage(source: imageData);
  }

  /// Compresses the image to reduce file size while maintaining clarity,
  /// then stores it in its own Firestore document and returns its reference.
  Future<String?> _compressAndUploadImage(File imageFile, String typePrefix) async {
    try {
      Uint8List? compressedBytes;
      try {
        compressedBytes = await FlutterImageCompress.compressWithFile(
          imageFile.path,
          minWidth: 640,
          minHeight: 640,
          quality: 45,
          format: CompressFormat.jpeg,
        );
      } catch (e) {
        debugPrint('FlutterImageCompress error, using raw bytes: $e');
        compressedBytes = await imageFile.readAsBytes();
      }

      compressedBytes ??= await imageFile.readAsBytes();

      return FirestoreImageService.upload(
        bytes: compressedBytes,
        userId: widget.userId,
        cycleId: widget.cycleId,
        category: typePrefix,
        stationIndex: widget.stationIndex,
      );
    } catch (e) {
      debugPrint('Error uploading image to Firestore: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  // ==================== PEST VERIFICATION METHODS ====================
  Future<void> _capturePestImage(String pestType) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
    );
    
    if (image != null && mounted) {
      setState(() => _isProcessing[pestType] = true);
      
      final downloadUrl = await _compressAndUploadImage(File(image.path), pestType);
      
      if (mounted) {
        setState(() {
          if (downloadUrl != null) {
            _capturedImages[pestType]!.add(downloadUrl);
          }
          _isProcessing[pestType] = false;
        });
        
        if (downloadUrl != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_getPestLabel(pestType)} image captured and uploaded'),
              backgroundColor: _accentGreen,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    }
  }

  Future<void> _pickPestImageFromGallery(String pestType) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    
    if (image != null && mounted) {
      setState(() => _isProcessing[pestType] = true);
      
      final downloadUrl = await _compressAndUploadImage(File(image.path), pestType);
      
      if (mounted) {
        setState(() {
          if (downloadUrl != null) {
            _capturedImages[pestType]!.add(downloadUrl);
          }
          _isProcessing[pestType] = false;
        });
        
        if (downloadUrl != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_getPestLabel(pestType)} image uploaded from gallery'),
              backgroundColor: _accentGreen,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    }
  }

  void _removePestImage(String pestType, int index) {
    final reference = _capturedImages[pestType]![index];
    setState(() {
      _capturedImages[pestType]!.removeAt(index);
    });
    FirestoreImageService.delete(reference).catchError((Object e) {
      debugPrint('Could not delete image record: $e');
    });
  }

  String _getPestLabel(String pestType) {
    final pest = _pestTypes.firstWhere((p) => p['key'] == pestType);
    return pest['label'] as String;
  }

  // ==================== DAMAGE VERIFICATION METHODS ====================
  Future<void> _captureDamagePhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
    );
    
    if (image != null && mounted) {
      setState(() => _isDamageProcessing = true);
      
      final downloadUrl = await _compressAndUploadImage(File(image.path), 'damage');
      
      if (mounted) {
        setState(() {
          if (downloadUrl != null) {
            _damagePhotos.add(downloadUrl);
          }
          _isDamageProcessing = false;
        });
        
        if (downloadUrl != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Damage photo captured and uploaded'),
              backgroundColor: _accentGreen,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    }
  }

  Future<void> _pickDamagePhotoFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    
    if (image != null && mounted) {
      setState(() => _isDamageProcessing = true);
      
      final downloadUrl = await _compressAndUploadImage(File(image.path), 'damage');
      
      if (mounted) {
        setState(() {
          if (downloadUrl != null) {
            _damagePhotos.add(downloadUrl);
          }
          _isDamageProcessing = false;
        });
        
        if (downloadUrl != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Damage photo uploaded from gallery'),
              backgroundColor: _accentGreen,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    }
  }

  void _removeDamagePhoto(int index) {
    final reference = _damagePhotos[index];
    setState(() {
      _damagePhotos.removeAt(index);
    });
    FirestoreImageService.delete(reference).catchError((Object e) {
      debugPrint('Could not delete image record: $e');
    });
  }

  // ==================== SAVE ====================
  void _saveAndComplete() {
    final incompletePests = <String>[];
    
    for (var pest in _pestTypes) {
      final key = pest['key'] as String;
      final count = widget.station[key] as int? ?? 0;
      
      if (count > 0 && (_capturedImages[key]?.isEmpty ?? true)) {
        incompletePests.add(pest['label'] as String);
      }
    }

    // Check damage verification
    final damaged = widget.station['damaged'] as int? ?? 0;
    final hasFAW = _hasFAWPresence();
    bool damageIncomplete = hasFAW && damaged > 0 && _damagePhotos.isEmpty;

    if (incompletePests.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please capture images for: ${incompletePests.join(", ")}',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (damageIncomplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture damage photos for verification'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final updatedStation = Map<String, dynamic>.from(widget.station);
    updatedStation['capturedImages'] = _capturedImages;
    updatedStation['damagePhotos'] = _damagePhotos;
    updatedStation['verificationCompleted'] = true;
    updatedStation['verificationRequired'] = false;

    widget.onVerificationComplete(updatedStation);
    Navigator.pop(context);
  }

  // ==================== UI ====================
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
            const SizedBox(height: 24),
            Text(
              'Pest Verification',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 16),
            ..._buildPestVerificationCards(),
            if (_hasFAWPresence() && (widget.station['damaged'] as int? ?? 0) > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Damage Verification',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 16),
              _buildDamageVerificationCard(),
            ],
            const SizedBox(height: 30),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    int totalPestRequired = 0;
    int totalPestVerified = 0;
    
    for (var pest in _pestTypes) {
      final key = pest['key'] as String;
      final count = widget.station[key] as int? ?? 0;
      if (count > 0) {
        totalPestRequired++;
        if (_capturedImages[key]?.isNotEmpty ?? false) totalPestVerified++;
      }
    }

    final damaged = widget.station['damaged'] as int? ?? 0;
    final hasFAW = _hasFAWPresence();
    final damageRequired = hasFAW && damaged > 0;
    final damageVerified = damageRequired ? _damagePhotos.isNotEmpty : true;

    final totalRequired = (damageRequired ? 1 : 0) + totalPestRequired;
    final totalVerified = (damageVerified ? 1 : 0) + totalPestVerified;

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
              value: totalVerified / totalRequired,
              backgroundColor: _lightGreen,
              valueColor: const AlwaysStoppedAnimation<Color>(_accentGreen),
              borderRadius: BorderRadius.circular(8),
              minHeight: 6,
            ),
            const SizedBox(height: 8),
            Text(
              '$totalVerified of $totalRequired items verified',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _textGrey,
              ),
            ),
          ] else
            Text(
              'No verification required',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _textGrey,
              ),
            ),
        ],
      ),
    );
  }

  // ==================== PEST VERIFICATION CARDS ====================
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
          padding: const EdgeInsets.all(16),
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
              Row(
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
                            color: _textGrey,
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
              
              // Image thumbnails
              if (hasImages && _capturedImages[key]!.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
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
                              onTap: () => _removePestImage(key, imgIndex),
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
              ],
              
              if (isProcessing)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                ),
              
              const SizedBox(height: 12),
              Row(
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
                      onPressed: isProcessing ? null : () => _pickPestImageFromGallery(key),
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
            ],
          ),
        ),
      );
    }
    
    return cards;
  }

  // ==================== DAMAGE VERIFICATION CARD ====================
  Widget _buildDamageVerificationCard() {
    final damaged = widget.station['damaged'] as int? ?? 0;
    final hasImages = _damagePhotos.isNotEmpty;
    final isProcessing = _isDamageProcessing;

    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.image_outlined,
                  color: _purple,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plant Damage',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Count: $damaged',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _textGrey,
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
          
          // Damage image thumbnails
          if (hasImages) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _damagePhotos.length,
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
                          child: _buildImage(_damagePhotos[imgIndex]),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 12,
                        child: GestureDetector(
                          onTap: () => _removeDamagePhoto(imgIndex),
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
          ],
          
          if (isProcessing)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            ),
          
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isProcessing ? null : _captureDamagePhoto,
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Capture'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: _purple.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isProcessing ? null : _pickDamagePhotoFromGallery,
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: _purple.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    // Check if all required verifications are complete
    bool allComplete = true;
    
    // Check pests
    for (var pest in _pestTypes) {
      final key = pest['key'] as String;
      final count = widget.station[key] as int? ?? 0;
      if (count > 0 && (_capturedImages[key]?.isEmpty ?? true)) {
        allComplete = false;
        break;
      }
    }
    
    // Check damage
    if (allComplete) {
      final damaged = widget.station['damaged'] as int? ?? 0;
      final hasFAW = _hasFAWPresence();
      if (hasFAW && damaged > 0 && _damagePhotos.isEmpty) {
        allComplete = false;
      }
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: allComplete ? _saveAndComplete : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: allComplete ? _accentGreen : Colors.grey.shade300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          allComplete ? 'Complete Verification ✓' : 'Complete All Verifications First',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: allComplete ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}
