import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:visaia/services/auth_cache_service.dart';

void showAssignLogSheet(
  BuildContext context, {
  required String userId,
  required String cycleId,
  required Function(String selectedCycleId) onCycleSelected,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AssignLogSheetContent(
      userId: userId,
      cycleId: cycleId,
      onCycleSelected: onCycleSelected,
    ),
  );
}

class AssignLogSheetContent extends StatefulWidget {
  final String userId;
  final String cycleId;
  final Function(String selectedCycleId) onCycleSelected;

  const AssignLogSheetContent({
    super.key,
    required this.userId,
    required this.cycleId,
    required this.onCycleSelected,
  });

  @override
  State<AssignLogSheetContent> createState() => _AssignLogSheetContentState();
}

class _AssignLogSheetContentState extends State<AssignLogSheetContent> {
  String? _selectedCycleId;
  List<Map<String, dynamic>> _cycles = [];
  bool _isLoading = true;

  static const Color _green = Color(0xFF1A5C30);
  static const Color _darkGreen = Color(0xFF0C503C);
  static const Color _textGray = Color(0xFF616161);

  @override
  void initState() {
    super.initState();
    _loadCycles();
  }

  String get _effectiveUid {
    if (widget.userId.isNotEmpty) return widget.userId;
    return FirebaseAuth.instance.currentUser?.uid ??
        AuthCacheService().cachedUid ??
        '';
  }

  Future<void> _loadCycles() async {
    final uid = _effectiveUid;
    if (uid.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('cycles')
            .get();
      } catch (_) {
        snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('cycles')
            .get(const GetOptions(source: Source.cache));
      }

      // Filter active (non-completed) cycles safely
      final activeCycles = snapshot.docs.where((doc) {
        final data = doc.data();
        final isCompleted = data['isCompleted'] == true;
        final isPrevious = data['isPreviousCycle'] == true;
        final statusCompleted = data['status'] == 'completed';
        return !isCompleted && !isPrevious && !statusCompleted;
      }).map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['cycleName'] ?? data['name'] ?? 'Untitled Cycle',
          'fieldName': data['fieldName'] ?? 'Main Field',
          'cropVariety': data['cropVariety'] ?? '',
          'farmId': data['farmId'] ?? '',
        };
      }).toList();

      // Determine pre-selected cycle
      String? preSelected;
      if (widget.cycleId.isNotEmpty &&
          activeCycles.any((c) => c['id'] == widget.cycleId)) {
        preSelected = widget.cycleId;
      } else if (activeCycles.length == 1) {
        preSelected = activeCycles.first['id'] as String;
      }

      if (mounted) {
        setState(() {
          _cycles = activeCycles;
          _selectedCycleId = preSelected;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading cycles for assign log modal: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getCropIcon(String variety) {
    final lower = variety.toLowerCase();
    if (lower.contains('corn') || lower.contains('maize')) return Icons.eco_rounded;
    if (lower.contains('rice')) return Icons.rice_bowl_rounded;
    if (lower.contains('wheat') || lower.contains('grain')) return Icons.grain_rounded;
    if (lower.contains('soy')) return Icons.spa_rounded;
    return Icons.agriculture_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.assignment_turned_in_rounded, color: _green, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assign to Cycle',
                      style: GoogleFonts.inter(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: _darkGreen,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose an active cropping cycle for this log',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _textGray,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 16),

          // Body Content
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(color: _green),
              ),
            )
          else if (_cycles.isEmpty)
            _buildEmptyState()
          else
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACTIVE CROPPING CYCLES (${_cycles.length})',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: _textGray,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _cycles.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final cycle = _cycles[index];
                        final cycleId = cycle['id'] as String;
                        final isSelected = _selectedCycleId == cycleId;
                        final cycleName = cycle['name'] as String;
                        final fieldName = cycle['fieldName'] as String;
                        final cropVariety = cycle['cropVariety'] as String;

                        return GestureDetector(
                          onTap: () => setState(() => _selectedCycleId = cycleId),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFF1F8F4) : const Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? _green : const Color(0xFFE8E8E8),
                                width: isSelected ? 1.8 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: _green.withValues(alpha: 0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isSelected ? _green : const Color(0xFFEFEFEF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getCropIcon(cropVariety),
                                    color: isSelected ? Colors.white : const Color(0xFF757575),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cycleName,
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? _darkGreen : const Color(0xFF212121),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        cropVariety.isNotEmpty
                                            ? '$fieldName • $cropVariety'
                                            : fieldName,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isSelected
                                              ? _green.withValues(alpha: 0.8)
                                              : _textGray,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  isSelected
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: isSelected ? _green : const Color(0xFFBDBDBD),
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

          // Pinned Action Button
          if (!_isLoading && _cycles.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _selectedCycleId != null
                    ? () {
                        widget.onCycleSelected(_selectedCycleId!);
                        Navigator.pop(context);
                      }
                    : null,
                icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                label: Text(
                  'Confirm & Save Log',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  disabledBackgroundColor: const Color(0xFFCCCCCC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.agriculture_rounded, size: 32, color: _green),
          ),
          const SizedBox(height: 16),
          Text(
            'No Active Cropping Cycles',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _darkGreen,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You do not have any active cropping cycles. Please start a cycle first to record daily activities.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: _textGray,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCCCCCC)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Close',
                style: GoogleFonts.inter(color: const Color(0xFF424242), fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}