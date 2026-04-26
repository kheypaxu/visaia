import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:visaia/core/models/cycle_model.dart';
import 'package:visaia/screens/cycle_screens/start_cycle.dart';
import 'package:visaia/screens/cycle_screens/record_previous_cycle.dart';
import 'package:visaia/screens/cycle_screens/cycle_details.dart';
import 'package:visaia/screens/cycle_screens/edit_cycle.dart';

class CroppingCyclesScreen extends StatefulWidget {
  const CroppingCyclesScreen({super.key});

  @override
  State<CroppingCyclesScreen> createState() => _CroppingCyclesScreenState();
}

class _CroppingCyclesScreenState extends State<CroppingCyclesScreen> {
  static const Color darkGreen = Color(0xFF0D4D33);
  static const Color textGray = Color(0xFF43483E);
  static const Color headingBlack = Color(0xFF1A1C18);

  bool isCompletedView = false;
  String searchQuery = '';

  final user = FirebaseAuth.instance.currentUser;

  // ================= HELPER METHODS =================

  /// Gets status information for active cycles using the Model
  Map<String, dynamic> _getCycleStatus(CycleModel cycle) {
    // Fallback if you later add a status string field to the model
    // switch (cycle.status) { ... }

    // Default status based on progress (Using Model's progress property)
    if (cycle.progress >= 0.8) {
      return {
        'text': 'Approaching Harvest',
        'color': const Color(0xFF7E5800),
        'bgColor': const Color(0xFFFFE0A8),
        'icon': Icons.agriculture,
      };
    } else if (cycle.progress >= 0.5) {
      return {
        'text': 'Mid-Season Growth',
        'color': const Color(0xFF173408),
        'bgColor': const Color(0xFFC5E1A5),
        'icon': Icons.trending_up,
      };
    } else {
      return {
        'text': 'Early Growth Stage',
        'color': darkGreen,
        'bgColor': const Color(0xFFE1E3E1),
        'icon': Icons.eco,
      };
    }
  }

  /// Gets crop icon based on crop variety using the Model
  IconData _getCropIcon(String cropVariety) {
    if (cropVariety.isEmpty) return Icons.grass;
    final lower = cropVariety.toLowerCase();
    if (lower.contains('corn') || lower.contains('maize')) return Icons.eco;
    if (lower.contains('soy')) return Icons.spa;
    if (lower.contains('wheat')) return Icons.grain;
    if (lower.contains('rice')) return Icons.rice_bowl;
    if (lower.contains('cotton')) return Icons.cloud;
    if (lower.contains('barley')) return Icons.grain;
    return Icons.grass;
  }

  /// Filters cycles based on search query using Model properties
  bool _matchesSearch(CycleModel cycle) {
    if (searchQuery.isEmpty) return true;
    final query = searchQuery.toLowerCase();
    return cycle.cycleName.toLowerCase().contains(query) ||
        cycle.fieldName.toLowerCase().contains(query) ||
        cycle.cropVariety.toLowerCase().contains(query);
  }

  /// Fallback method to fetch cycles without ordering (if Firestore index doesn't exist)
  Widget _buildCycleListWithoutOrdering() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cycles')
          .snapshots(), // No ordering
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildEmptyState('Error loading cycles');
        }

        // Convert raw docs directly to CycleModel list and sort locally
        final allCycles = snapshot.data?.docs
            .map((doc) => CycleModel.fromDoc(doc))
            .toList() ?? [];
        
        // Sort locally by createdAt (newest first)
        allCycles.sort((a, b) {
          final dateA = a.createdAt ?? DateTime.now();
          final dateB = b.createdAt ?? DateTime.now();
          return dateB.compareTo(dateA);
        });

        // Filter using Model method
        final filteredCycles = allCycles.where(_matchesSearch).toList();

        // Separate using Model's shouldBeCompleted property
        final activeCycles = filteredCycles.where((c) => !c.shouldBeCompleted).toList();
        final completedCycles = filteredCycles.where((c) => c.shouldBeCompleted).toList();

        final displayCycles = isCompletedView ? completedCycles : activeCycles;

        if (displayCycles.isEmpty) {
          if (filteredCycles.isEmpty && searchQuery.isNotEmpty) {
            return _buildEmptyState('No cycles found for "$searchQuery"');
          }
          return _buildEmptyState(
            isCompletedView ? 'No completed cycles yet' : 'No active cycles found',
          );
        }

        return Column(
          children: displayCycles.map((cycle) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: isCompletedView 
                  ? _buildCompletedCard(cycle) 
                  : _buildActiveCard(cycle),
            );
          }).toList(),
        );
      },
    );
  }

  // ================= BUILD METHOD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      'Cropping Cycles',
                      style: GoogleFonts.epilogue(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: headingBlack,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSearchBar(),
                    const SizedBox(height: 24),
                    _buildFilterRow(),
                    const SizedBox(height: 24),
                    _buildCycleList(),
                    const SizedBox(height: 40),
                    _buildActionButtons(),
                    const SizedBox(height: 55),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= CYCLE LIST FROM FIREBASE =================
  Widget _buildCycleList() {
    if (user == null) {
      return _buildEmptyState('Please sign in to view cycles');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cycles')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          // If index error, try fallback without ordering
          if (snapshot.error.toString().contains('index')) {
            return _buildCycleListWithoutOrdering();
          }
          return _buildEmptyState('Error loading cycles');
        }

        // Convert raw docs directly to CycleModel list
        final allCycles = snapshot.data?.docs
            .map((doc) => CycleModel.fromDoc(doc))
            .toList() ?? [];

        // Filter using Model method
        final filteredCycles = allCycles.where(_matchesSearch).toList();

        // Separate using Model's shouldBeCompleted property
        final activeCycles = filteredCycles.where((c) => !c.shouldBeCompleted).toList();
        final completedCycles = filteredCycles.where((c) => c.shouldBeCompleted).toList();

        final displayCycles = isCompletedView ? completedCycles : activeCycles;

        if (displayCycles.isEmpty) {
          if (filteredCycles.isEmpty && searchQuery.isNotEmpty) {
            return _buildEmptyState('No cycles found for "$searchQuery"');
          }
          return _buildEmptyState(
            isCompletedView ? 'No completed cycles yet' : 'No active cycles found',
          );
        }

        return Column(
          children: displayCycles.map((cycle) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: isCompletedView 
                  ? _buildCompletedCard(cycle) 
                  : _buildActiveCard(cycle),
            );
          }).toList(),
        );
      },
    );
  }

  // ================= BUILD ACTIVE CARD =================
  Widget _buildActiveCard(CycleModel cycle) {
    final statusInfo = _getCycleStatus(cycle);
    final cropIcon = _getCropIcon(cycle.cropVariety);

    return CropCycleCard(
      title: cycle.cycleName,
      subtitle: cycle.fieldName,
      // Use Model's progress property directly
      progress: cycle.progress.clamp(0.0, 1.0),
      // Use Model's formatted dates directly
      harvestDate: cycle.formattedHarvestDateShort,
      statusText: statusInfo['text'] as String,
      statusColor: statusInfo['color'] as Color,
      statusBgColor: statusInfo['bgColor'] as Color,
      statusIcon: statusInfo['icon'] as IconData,
      progressColor: darkGreen,
      icon: cropIcon,
      iconColor: darkGreen,
      onMenuTap: () => _showScreen2BottomSheet(context, cycle.cycleName, cycle.id),
      onViewDetailsTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CycleDetailsScreen(cycleId: cycle.id)),
        );
      },
    );
  }

  // ================= BUILD COMPLETED CARD =================
  Widget _buildCompletedCard(CycleModel cycle) {
    return Screen2CompletedCard(
      title: cycle.cycleName,
      // Use Model's formatted dates directly
      harvestDate: cycle.formattedHarvestDateLong,
      income: cycle.formattedIncome,
      hasIncome: cycle.income != null,
      onViewDetailsTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CycleDetailsScreen(cycleId: cycle.id)),
        );
      },
    );
  }

  // ================= UI STATES =================
  Widget _buildLoadingState() {
    return Column(
      children: [
        _shimmerCard(),
        const SizedBox(height: 16),
        _shimmerCard(),
        const SizedBox(height: 16),
        _shimmerCard(),
      ],
    );
  }

  Widget _shimmerCard() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(32),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5EE),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFFE1E3E1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompletedView ? Icons.check_circle_outline : Icons.agriculture_outlined,
              size: 40,
              color: darkGreen,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: GoogleFonts.manrope(
              fontSize: 16,
              color: textGray,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (!isCompletedView && searchQuery.isEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Start your first cropping cycle to see it here',
              style: GoogleFonts.manrope(fontSize: 14, color: textGray),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  // ================= MAIN SCREEN UI COMPONENTS =================
  Widget _buildSearchBar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const Icon(Icons.search, color: textGray, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search fields or crops...',
                hintStyle: GoogleFonts.manrope(
                  color: Colors.grey.shade400,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
              ),
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: headingBlack,
              ),
            ),
          ),
          if (searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => searchQuery = ''),
              child: Icon(Icons.close, color: Colors.grey.shade400, size: 20),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .collection('cycles')
          .snapshots(),
      builder: (context, snapshot) {
        int activeCount = 0;
        int completedCount = 0;

        if (snapshot.hasData && snapshot.data != null) {
          // Map directly to CycleModel to check status
          final cycles = snapshot.data!.docs.map((doc) => CycleModel.fromDoc(doc)).toList();
          for (var cycle in cycles) {
            if (cycle.shouldBeCompleted) {
              completedCount++;
            } else {
              activeCount++;
            }
          }
        }

        return Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE1E3E1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => isCompletedView = false),
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: !isCompletedView ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Active ($activeCount)',
                            style: GoogleFonts.manrope(
                              color: !isCompletedView ? darkGreen : textGray,
                              fontWeight: !isCompletedView ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => isCompletedView = true),
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isCompletedView ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Completed ($completedCount)',
                            style: GoogleFonts.manrope(
                              color: isCompletedView ? darkGreen : textGray,
                              fontWeight: isCompletedView ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune, size: 20, color: headingBlack),
                  const SizedBox(width: 8),
                  Text(
                    'Filters',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: headingBlack,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _actionItem(
          icon: Icons.eco,
          title: 'Start New Cycle',
          subtitle: 'Monitor new cropping cycle',
          isPrimary: true,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => StartCroppingCycleScreen()));
          },
        ),
        const SizedBox(height: 16),
        _actionItem(
          icon: Icons.shopping_basket_outlined,
          title: 'Record Previous Cycle',
          subtitle: 'Record yield and losses',
          isPrimary: false,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => RecordCycleScreen()));
          },
        ),
        const SizedBox(height: 55),
      ],
    );
  }

  Widget _actionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isPrimary ? darkGreen : Colors.white,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isPrimary
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0xFFE1E3E1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isPrimary ? Colors.white : darkGreen),
            ),
            const SizedBox(width: 16),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    color: isPrimary ? Colors.white : darkGreen,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    color: isPrimary
                        ? Colors.white.withValues(alpha: 0.7)
                        : textGray,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================= OVERLAY AND LOGIC COMPONENTS =================
  void _showScreen2BottomSheet(BuildContext context, String cropName, String cycleId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE1E3E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              _sheetTile(
                Icons.edit_outlined,
                'Edit Cycle',
                darkGreen,
                () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => EditCropCycleScreen(cycleId: cycleId)),
                  );
                },
              ),
              _sheetTile(Icons.share_outlined, 'Share Data', darkGreen, () {}),
              const Divider(height: 32, color: Color(0xFFE1E3E1)),
              _sheetTile(
                Icons.check_circle_outline,
                'Mark as Completed',
                darkGreen,
                () {
                  Navigator.pop(context);
                  _markCycleCompleted(cycleId);
                },
              ),
              const Divider(height: 32, color: Color(0xFFE1E3E1)),
              _sheetTile(
                Icons.delete_outline_rounded,
                'Delete Cycle',
                const Color(0xFFBA1A1A),
                () {
                  Navigator.pop(context);
                  _showScreen3DeleteOverlay(context, cropName, cycleId);
                },
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.manrope(color: textGray, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _markCycleCompleted(String cycleId) async {
    try {
      // Using update map instead of setting full model to prevent overwriting server timestamps
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cycles')
          .doc(cycleId)
          .update({'isCompleted': true});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cycle marked as completed'),
            backgroundColor: darkGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update cycle'),
            backgroundColor: Color(0xFFBA1A1A),
          ),
        );
      }
    }
  }

  Future<void> _deleteCycle(String cycleId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cycles')
          .doc(cycleId)
          .delete();

      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cycle deleted successfully'),
            backgroundColor: darkGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete cycle'),
            backgroundColor: Color(0xFFBA1A1A),
          ),
        );
      }
    }
  }

  Widget _sheetTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: GoogleFonts.manrope(color: color, fontWeight: FontWeight.w700, fontSize: 16),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  void _showScreen3DeleteOverlay(BuildContext context, String cropName, String cycleId) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          backgroundColor: const Color(0xFFF3F5EE),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFDADA),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFBA1A1A),
                    size: 44,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Delete Cropping Cycle?',
                  style: GoogleFonts.epilogue(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: headingBlack,
                  ),
                ),
                const SizedBox(height: 16),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.manrope(fontSize: 15, color: textGray, height: 1.5),
                    children: [
                      const TextSpan(text: 'Are you sure you want to delete\n'),
                      TextSpan(
                        text: cropName,
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: headingBlack),
                      ),
                      const TextSpan(text: '? This action cannot be undone.'),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                _dialogBtn(
                  'Delete',
                  const Color(0xFFBA1A1A),
                  Colors.white,
                  () => _deleteCycle(cycleId),
                ),
                const SizedBox(height: 12),
                _dialogBtn(
                  'Cancel',
                  const Color(0xFFE1E3E1),
                  headingBlack,
                  () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dialogBtn(String label, Color bg, Color text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          elevation: 0,
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: GoogleFonts.manrope(color: text, fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
    );
  }
}

// ==========================================
// SCREEN 1: ACTIVE CROP CARD
// ==========================================
class CropCycleCard extends StatelessWidget {
  final String title, subtitle, harvestDate, statusText;
  final double progress;
  final Color statusColor, statusBgColor, progressColor, iconColor;
  final IconData statusIcon, icon;
  final VoidCallback onMenuTap;
  final VoidCallback? onViewDetailsTap;

  const CropCycleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.harvestDate,
    required this.statusText,
    required this.statusColor,
    required this.statusBgColor,
    required this.statusIcon,
    required this.progressColor,
    required this.icon,
    required this.iconColor,
    required this.onMenuTap,
    this.onViewDetailsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: onViewDetailsTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE1E3E1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: iconColor, size: 26),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.manrope(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1A1C18),
                                ),
                              ),
                              Text(
                                subtitle,
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  color: const Color(0xFF43483E),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert, color: Color(0xFF43483E)),
                          onPressed: onMenuTap,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE1E3E1),
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Est. Harvest: $harvestDate',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: const Color(0xFF43483E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: progressColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      statusText,
                      style: GoogleFonts.manrope(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SCREEN 2: COMPLETED CROP CARD
// ==========================================
class Screen2CompletedCard extends StatelessWidget {
  final String title, harvestDate, income;
  final bool hasIncome;
  final VoidCallback? onViewDetailsTap;

  const Screen2CompletedCard({
    super.key,
    required this.title,
    required this.harvestDate,
    required this.income,
    this.hasIncome = true,
    this.onViewDetailsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0D4D33),
                  ),
                ),
              ),
              _badge(),
            ],
          ),
          const SizedBox(height: 20),
          _infoRow(Icons.calendar_today_outlined, 'Harvested: $harvestDate'),
          const SizedBox(height: 10),
          _infoRow(
            Icons.payments_outlined,
            'Income: $income',
            isBold: hasIncome,
            textColor: hasIncome ? const Color(0xFF173408) : const Color(0xFF43483E),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onViewDetailsTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'VIEW DETAILS',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      color: const Color(0xFF0D4D33),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFC5E1A5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'COMPLETED',
          style: GoogleFonts.manrope(
            fontSize: 11,
            color: const Color(0xFF173408),
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _infoRow(
    IconData icon,
    String text, {
    bool isBold = false,
    Color textColor = const Color(0xFF1A1C18),
  }) =>
      Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF43483E)),
          const SizedBox(width: 10),
          Text(
            text,
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      );
}