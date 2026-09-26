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

      return await FirestoreImageService.upload(
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

  // ==================== IMAGE PICKING & UPLOADING ====================
  bool get _isUploading =>
      _isDamageProcessing || _isProcessing.values.any((value) => value);

  // Pick single image via Camera
  Future<void> _captureImageWithCamera(String category) async {
    if (_isUploading) return;
    final isDamage = category == 'damage';
    setState(() {
      if (isDamage) {
        _isDamageProcessing = true;
      } else {
        _isProcessing[category] = true;
      }
    });

    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
      );
      if (image == null || !mounted) return;

      final reference = await _compressAndUploadImage(File(image.path), category);
      if (reference == null || !mounted) return;

      setState(() {
        if (isDamage) {
          _damagePhotos.add(reference);
        } else {
          _capturedImages[category]!.add(reference);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${isDamage ? 'Damage photo' : '${_getPestLabel(category)} image'} uploaded successfully',
            ),
            backgroundColor: _accentGreen,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error capturing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not capture photo. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isDamage) {
            _isDamageProcessing = false;
          } else {
            _isProcessing[category] = false;
          }
        });
      }
    }
  }

  // Pick multiple images via Gallery (Multi-select)
  Future<void> _pickImagesFromGallery(String category) async {
    if (_isUploading) return;
    final isDamage = category == 'damage';
    setState(() {
      if (isDamage) {
        _isDamageProcessing = true;
      } else {
        _isProcessing[category] = true;
      }
    });

    try {
      final List<XFile> pickedImages = await _picker.pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
      );

      if (pickedImages.isEmpty || !mounted) return;

      int successCount = 0;
      for (final xFile in pickedImages) {
        final reference = await _compressAndUploadImage(File(xFile.path), category);
        if (reference != null && mounted) {
          setState(() {
            if (isDamage) {
              _damagePhotos.add(reference);
            } else {
              _capturedImages[category]!.add(reference);
            }
          });
          successCount++;
        }
      }

      if (mounted && successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Uploaded $successCount ${isDamage ? 'damage' : _getPestLabel(category)} photo(s)',
            ),
            backgroundColor: _accentGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error selecting multiple images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not select photos. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isDamage) {
            _isDamageProcessing = false;
          } else {
            _isProcessing[category] = false;
          }
        });
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

  void _removeDamagePhoto(int index) {
    final reference = _damagePhotos[index];
    setState(() {
      _damagePhotos.removeAt(index);
    });
    FirestoreImageService.delete(reference).catchError((Object e) {
      debugPrint('Could not delete image record: $e');
    });
  }

  String _getPestLabel(String pestType) {
    final pest = _pestTypes.firstWhere(
      (p) => p['key'] == pestType,
      orElse: () => {'label': pestType},
    );
    return pest['label'] as String;
  }

  // ==================== SAVE ====================
  void _saveAndComplete() {
    if (_isUploading) return;
    final missingErrors = <String>[];
    
    // 1. Check all pest categories
    for (var pest in _pestTypes) {
      final key = pest['key'] as String;
      final count = widget.station[key] as int? ?? 0;
      final uploadedCount = _capturedImages[key]?.length ?? 0;
      
      if (count > 0 && uploadedCount < count) {
        final missing = count - uploadedCount;
        missingErrors.add(
          '${pest['label']}: needs $missing more photo${missing > 1 ? 's' : ''} ($uploadedCount/$count uploaded)',
        );
      }
    }

    // 2. Check damage verification
    final damaged = widget.station['damaged'] as int? ?? 0;
    if (damaged > 0) {
      final uploadedDamage = _damagePhotos.length;
      if (uploadedDamage < damaged) {
        final missing = damaged - uploadedDamage;
        missingErrors.add(
          'Plant Damage: needs $missing more photo${missing > 1 ? 's' : ''} ($uploadedDamage/$damaged uploaded)',
        );
      }
    }

    if (missingErrors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please complete all required photo verifications:\n• ${missingErrors.join("\n• ")}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
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
    final damaged = widget.station['damaged'] as int? ?? 0;
    final hasPests = _pestTypes.any((p) => (widget.station[p['key']] as int? ?? 0) > 0);

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
          'Station ${widget.stationIndex + 1} Verification',
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
            
            if (hasPests) ...[
              Text(
                'Pest Sightings Verification',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 12),
              ..._buildPestVerificationCards(),
              const SizedBox(height: 12),
            ],

            if (damaged > 0) ...[
              Text(
                'Plant Damage Verification',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 12),
              _buildDamageVerificationCard(),
              const SizedBox(height: 16),
            ],

            if (!hasPests && damaged == 0) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, color: _accentGreen, size: 40),
                    const SizedBox(height: 10),
                    Text(
                      'No Pests or Damage Recorded',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This station has 0 pests and 0 damaged plants. No photo verification is required.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 13, color: _textGrey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 16),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    int totalRequiredPhotos = 0;
    int totalUploadedPhotos = 0;
    
    for (var pest in _pestTypes) {
      final key = pest['key'] as String;
      final count = widget.station[key] as int? ?? 0;
      if (count > 0) {
        totalRequiredPhotos += count;
        final uploaded = _capturedImages[key]?.length ?? 0;
        totalUploadedPhotos += uploaded > count ? count : uploaded;
      }
    }

    final damaged = widget.station['damaged'] as int? ?? 0;
    if (damaged > 0) {
      totalRequiredPhotos += damaged;
      final uploaded = _damagePhotos.length;
      totalUploadedPhotos += uploaded > damaged ? damaged : uploaded;
    }

    final progress = totalRequiredPhotos > 0
        ? (totalUploadedPhotos / totalRequiredPhotos).clamp(0.0, 1.0)
        : 1.0;

    final isAllComplete = totalRequiredPhotos == 0 || totalUploadedPhotos >= totalRequiredPhotos;

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
              Icon(
                isAllComplete ? Icons.check_circle : Icons.verified_outlined,
                color: isAllComplete ? _accentGreen : _orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Evidence Verification Requirement',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _green,
                      ),
                    ),
                    Text(
                      '1 photo required per recorded sighting / damaged plant',
                      style: GoogleFonts.inter(fontSize: 12, color: _textGrey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (totalRequiredPhotos > 0) ...[
            LinearProgressIndicator(
              value: progress,
              backgroundColor: _lightGreen,
              valueColor: AlwaysStoppedAnimation<Color>(
                isAllComplete ? _accentGreen : _orange,
              ),
              borderRadius: BorderRadius.circular(8),
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$totalUploadedPhotos of $totalRequiredPhotos photo(s) uploaded',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isAllComplete ? _accentGreen : _textDark,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isAllComplete ? _accentGreen : _textGrey,
                  ),
                ),
              ],
            ),
          ] else
            Text(
              'No photo verification required for this station',
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
      if (count <= 0) continue;

      final images = _capturedImages[key] ?? [];
      final uploadedCount = images.length;
      final isVerified = uploadedCount >= count;
      final isProcessing = _isProcessing[key] ?? false;
      
      cards.add(
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isVerified ? _accentGreen : Colors.orange.shade300,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
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
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: (pest['color'] as Color).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      pest['icon'] as IconData,
                      color: pest['color'] as Color,
                      size: 24,
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
                            color: _textDark,
                          ),
                        ),
                        Text(
                          'Observed: $count sighting${count > 1 ? 's' : ''} ($count photo${count > 1 ? 's' : ''} required)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isVerified ? _accentGreen : Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isVerified ? _lightGreen : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isVerified ? _accentGreen.withValues(alpha: 0.4) : Colors.orange.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isVerified ? Icons.check_circle : Icons.warning_amber_rounded,
                          color: isVerified ? _accentGreen : Colors.orange.shade800,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isVerified ? 'Verified ($uploadedCount/$count)' : 'Required ($uploadedCount/$count)',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isVerified ? _accentGreen : Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Image thumbnails list
              if (images.isNotEmpty) ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 84,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    itemBuilder: (context, imgIndex) {
                      return Stack(
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: _buildImage(images[imgIndex]),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 14,
                            child: GestureDetector(
                              onTap: () => _removePestImage(key, imgIndex),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.black87,
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
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '#${imgIndex + 1}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
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
              
              if (isProcessing) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(),
              ],
              
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUploading ? null : () => _captureImageWithCamera(key),
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: const Text('Camera'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        foregroundColor: _green,
                        side: BorderSide(color: _green.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : () => _pickImagesFromGallery(key),
                      icon: const Icon(Icons.photo_library, size: 18),
                      label: const Text('Gallery (Multi)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _lightGreen,
                        foregroundColor: _green,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
    final uploadedCount = _damagePhotos.length;
    final isVerified = uploadedCount >= damaged;
    final isProcessing = _isDamageProcessing;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVerified ? _accentGreen : Colors.orange.shade300,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  color: _purple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Damaged Plants Evidence',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    Text(
                      'Recorded: $damaged damaged plant${damaged > 1 ? 's' : ''} ($damaged photo${damaged > 1 ? 's' : ''} required)',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isVerified ? _accentGreen : Colors.orange.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isVerified ? _lightGreen : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isVerified ? _accentGreen.withValues(alpha: 0.4) : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVerified ? Icons.check_circle : Icons.warning_amber_rounded,
                      color: isVerified ? _accentGreen : Colors.orange.shade800,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isVerified ? 'Verified ($uploadedCount/$damaged)' : 'Required ($uploadedCount/$damaged)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isVerified ? _accentGreen : Colors.orange.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Damage image thumbnails
          if (_damagePhotos.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 84,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _damagePhotos.length,
                itemBuilder: (context, imgIndex) {
                  return Stack(
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _buildImage(_damagePhotos[imgIndex]),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 14,
                        child: GestureDetector(
                          onTap: () => _removeDamagePhoto(imgIndex),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.black87,
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
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Plant #${imgIndex + 1}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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
          
          if (isProcessing) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
          
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isUploading ? null : () => _captureImageWithCamera('damage'),
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Camera'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: _purple,
                    side: BorderSide(color: _purple.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : () => _pickImagesFromGallery('damage'),
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: const Text('Gallery (Multi)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purple.withValues(alpha: 0.1),
                    foregroundColor: _purple,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
    bool allComplete = true;
    
    // Check pests
    for (var pest in _pestTypes) {
      final key = pest['key'] as String;
      final count = widget.station[key] as int? ?? 0;
      final uploaded = _capturedImages[key]?.length ?? 0;
      if (count > 0 && uploaded < count) {
        allComplete = false;
        break;
      }
    }
    
    // Check damage
    if (allComplete) {
      final damaged = widget.station['damaged'] as int? ?? 0;
      final uploadedDamage = _damagePhotos.length;
      if (damaged > 0 && uploadedDamage < damaged) {
        allComplete = false;
      }
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: allComplete && !_isUploading ? _saveAndComplete : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: allComplete ? _accentGreen : Colors.grey.shade300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          allComplete ? 'Complete Verification ✓' : 'Upload All Required Photos First',
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
