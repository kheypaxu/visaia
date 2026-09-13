import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  String? selectedCycle;
  List<Map<String, dynamic>> cycles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Fetch cycles with offline cache fallback
      QuerySnapshot<Map<String, dynamic>> cyclesSnapshot;
      try {
        cyclesSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('cycles')
            .get();
      } catch (_) {
        cyclesSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('cycles')
            .get(const GetOptions(source: Source.cache));
      }

      cycles = cyclesSnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'name': doc['cycleName'] ?? 'Unknown Cycle',
          'fieldName': doc['fieldName'] ?? '',
        };
      }).toList();

      // Only pre-select if widget.cycleId is not empty AND exists in cycles
      String? preSelected;
      if (widget.cycleId.isNotEmpty) {
        final exists = cycles.any((c) => c['id'] == widget.cycleId);
        if (exists) {
          preSelected = widget.cycleId;
        }
      }
      
      setState(() {
        selectedCycle = preSelected;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      height: screenHeight * 0.95,
      decoration: const BoxDecoration(
        color: Color(0xFFF9FBF7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Padding(
            padding: EdgeInsets.only(top: topPadding > 0 ? 12 : 20, bottom: 8),
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFF162B0D).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Scrollable Content Area
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(color: Color(0xFF162B0D)),
                    )
                  : cycles.isEmpty
                      ? _buildEmptyState()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 24),

                            // ── Header ──
                            Text(
                              'Assign Log',
                              style: GoogleFonts.epilogue(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF162B0D),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Select where this record belongs',
                              style: GoogleFonts.manrope(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF8E9A88),
                              ),
                            ),
                            const SizedBox(height: 40),

                            // ── Report Card ──
                            _buildReportCard(),
                            const SizedBox(height: 44),

                            // ── Active Cropping Cycle Dropdown ──
                            _buildDropdownLabel('ACTIVE CROPPING CYCLE'),
                            const SizedBox(height: 12),
                            _buildDropdown(
                              value: selectedCycle,
                              hint: 'Select active cycle',
                              items: cycles
                                  .map((c) => {'id': c['id'], 'name': c['name']})
                                  .toList(),
                              onChanged: (val) => setState(() => selectedCycle = val),
                            ),
                            const SizedBox(height: 100),
                          ],
                        ),
            ),
          ),

          // ── Pinned Save Button at very bottom ──
          if (!_isLoading && cycles.isNotEmpty)
            Container(
              width: double.infinity,
              color: const Color(0xFFF9FBF7),
              padding: EdgeInsets.fromLTRB(28, 16, 28, 24 + MediaQuery.of(context).padding.bottom),
              child: _buildSaveButton(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 100),
        const Icon(Icons.agriculture_outlined, size: 80, color: Color(0xFFBDBDBD)),
        const SizedBox(height: 20),
        Text(
          'No Cropping Cycles Found',
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF162B0D),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Please create a cropping cycle first',
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: const Color(0xFF8E9A88),
          ),
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF162B0D),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildReportCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8DE), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF162B0D).withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFC6F097),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.description_outlined, size: 26, color: Color(0xFF162B0D)),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC6F097),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'NEW DRAFT',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF162B0D),
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Daily Activity Log',
                  style: GoogleFonts.manrope(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF162B0D),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Recorded: Today',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF8E9A88),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF162B0D),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<Map<String, dynamic>> items,
    required ValueChanged<String?> onChanged,
  }) {
    // Validate that the value exists in items to avoid the "exactly one item" error
    final isValidValue = value != null && items.any((item) => item['id'] == value);
    final effectiveValue = isValidValue ? value : null;
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: effectiveValue != null
              ? const Color(0xFF162B0D).withOpacity(0.3)
              : const Color(0xFFE2E8DE),
          width: 1.5,
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: effectiveValue,  // Use validated value
        hint: Text(hint,
            style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF8E9A88))),
        icon: const Icon(Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF162B0D), size: 24),
        isExpanded: true,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(14),
        style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF162B0D)),
        items: items
            .map<DropdownMenuItem<String>>((item) {
              return DropdownMenuItem<String>(
                value: item['id'] as String,
                child: Text(item['name'] as String),
              );
            })
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSaveButton() {
    final isEnabled = selectedCycle != null && selectedCycle!.isNotEmpty;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled
            ? () {
                widget.onCycleSelected(selectedCycle!);
                Navigator.pop(context);
              }
            : null,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: double.infinity,
          height: 64,
          decoration: BoxDecoration(
            color: isEnabled
                ? const Color(0xFF162B0D)
                : const Color(0xFFBDBDBD),
            borderRadius: BorderRadius.circular(50),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF162B0D).withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.save_outlined, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Text(
                'Continue',
                style: GoogleFonts.manrope(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}