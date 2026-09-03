import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:visaia/core/models/cycle_model.dart';
import 'package:visaia/core/providers/farm_provider.dart';
import 'package:visaia/screens/cycle_screens/start_cycle.dart';
import 'package:visaia/screens/cycle_screens/record_previous_cycle.dart';
import 'package:visaia/screens/cycle_screens/cycle_details.dart';
import 'package:visaia/screens/cycle_screens/completed_cycle_details.dart';
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
  static const Color scaffoldBg = Color(0xFFF7F8F5);

  bool isCompletedView = false;
  String searchQuery = '';

  final user = FirebaseAuth.instance.currentUser;

  Map<String, dynamic> _getCycleStatus(CycleModel cycle) {
    if (cycle.progress >= 0.8) {
      return {
        'text': 'Approaching Harvest',
        'color': const Color(0xFF7E5800),
        'bgColor': const Color(0xFFFFF3DC),
        'icon': Icons.agriculture,
      };
    } else if (cycle.progress >= 0.5) {
      return {
        'text': 'Mid-Season Growth',
        'color': const Color(0xFF173408),
        'bgColor': const Color(0xFFEDF5E1),
        'icon': Icons.trending_up,
      };
    } else {
      return {
        'text': 'Early Growth Stage',
        'color': darkGreen,
        'bgColor': const Color(0xFFEEF0EC),
        'icon': Icons.eco,
      };
    }
  }

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

  bool _matchesSearch(CycleModel cycle) {
    if (searchQuery.isEmpty) return true;
    final query = searchQuery.toLowerCase();
    return cycle.cycleName.toLowerCase().contains(query) ||
        cycle.fieldName.toLowerCase().contains(query) ||
        cycle.cropVariety.toLowerCase().contains(query);
  }

  // Fallback stream without ordering (when index is missing)
  Widget _buildCycleListWithoutOrdering(String? farmId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cycles')
          .where('farmId', isEqualTo: farmId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }
        if (snapshot.hasError) {
          return _buildEmptyState('Error loading cycles');
        }

        final allCycles = snapshot.data?.docs
                .map((doc) => CycleModel.fromDoc(doc))
                .toList() ??
            [];

        allCycles.sort((a, b) {
          final dateA = a.createdAt ?? DateTime.now();
          final dateB = b.createdAt ?? DateTime.now();
          return dateB.compareTo(dateA);
        });

        final filteredCycles = allCycles.where(_matchesSearch).toList();
        final activeCycles =
            filteredCycles.where((c) => !c.shouldBeCompleted).toList();
        final completedCycles =
            filteredCycles.where((c) => c.shouldBeCompleted).toList();
        final displayCycles =
            isCompletedView ? completedCycles : activeCycles;

        if (displayCycles.isEmpty) {
          return _buildEmptyState(
            isCompletedView ? 'No completed cycles yet' : 'No active cycles found',
          );
        }

        return Column(
          children: displayCycles
              .map((cycle) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: isCompletedView
                        ? _buildCompletedCard(cycle)
                        : _buildActiveCard(cycle),
                  ))
              .toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider so this screen rebuilds when farm changes
    final farmId = context.watch<FarmProvider>().activeFarmId;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cropping Cycles',
                          style: GoogleFonts.epilogue(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: headingBlack,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSearchBar(),
                    const SizedBox(height: 20),
                    _buildFilterRow(farmId),
                    const SizedBox(height: 20),
                    _buildCycleList(farmId),
                    const SizedBox(height: 32),
                    _buildActionButtons(farmId),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCycleList(String? farmId) {
    if (user == null) {
      return _buildEmptyState('Please sign in to view cycles');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cycles')
          .where('farmId', isEqualTo: farmId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          if (snapshot.error.toString().contains('index')) {
            return _buildCycleListWithoutOrdering(farmId);
          }
          return _buildEmptyState('Error loading cycles');
        }

        final allCycles = snapshot.data?.docs
                .map((doc) => CycleModel.fromDoc(doc))
                .toList() ??
            [];

        final filteredCycles = allCycles.where(_matchesSearch).toList();
        final activeCycles =
            filteredCycles.where((c) => !c.shouldBeCompleted).toList();
        final completedCycles =
            filteredCycles.where((c) => c.shouldBeCompleted).toList();
        final displayCycles =
            isCompletedView ? completedCycles : activeCycles;

        if (displayCycles.isEmpty) {
          if (filteredCycles.isEmpty && searchQuery.isNotEmpty) {
            return _buildEmptyState('No cycles found for "$searchQuery"');
          }
          return _buildEmptyState(
            isCompletedView ? 'No completed cycles yet' : 'No active cycles found',
          );
        }

        return Column(
          children: displayCycles
              .map((cycle) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: isCompletedView
                        ? _buildCompletedCard(cycle)
                        : _buildActiveCard(cycle),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildActiveCard(CycleModel cycle) {
    final statusInfo = _getCycleStatus(cycle);
    final cropIcon = _getCropIcon(cycle.cropVariety);

    return CropCycleCard(
      title: cycle.cycleName,
      subtitle: cycle.fieldName,
      progress: cycle.progress.clamp(0.0, 1.0),
      harvestDate: cycle.formattedHarvestDateShort,
      statusText: statusInfo['text'] as String,
      statusColor: statusInfo['color'] as Color,
      statusBgColor: statusInfo['bgColor'] as Color,
      statusIcon: statusInfo['icon'] as IconData,
      progressColor: darkGreen,
      icon: cropIcon,
      iconColor: darkGreen,
      onMenuTap: () =>
          _showScreen2BottomSheet(context, cycle.cycleName, cycle.id),
      onViewDetailsTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CycleDetailsScreen(cycleId: cycle.id, uid: user!.uid),
          ),
        );
      },
    );
  }

  Widget _buildCompletedCard(CycleModel cycle) {
    return Screen2CompletedCard(
      title: cycle.cycleName,
      harvestDate: cycle.formattedHarvestDateLong,
      income: cycle.formattedIncome,
      hasIncome: cycle.displayIncome != null,
      onViewDetailsTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CompletedCycleScreen(cycleId: cycle.id, userId: user!.uid),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        _shimmerCard(),
        const SizedBox(height: 12),
        _shimmerCard(),
        const SizedBox(height: 12),
        _shimmerCard(),
      ],
    );
  }

  Widget _shimmerCard() {
    return Container(
      height: 170,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: darkGreen),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFE1E3E1).withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompletedView
                  ? Icons.check_circle_outline
                  : Icons.agriculture_outlined,
              size: 36,
              color: darkGreen.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: GoogleFonts.manrope(
              fontSize: 15,
              color: textGray,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (!isCompletedView && searchQuery.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Start your first cropping cycle to see it here',
              style: GoogleFonts.manrope(
                  fontSize: 13, color: textGray.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.search, color: textGray.withValues(alpha: 0.5), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search fields or crops...',
                hintStyle: GoogleFonts.manrope(
                  color: Colors.grey.shade400,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
              ),
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: headingBlack,
              ),
            ),
          ),
          if (searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => searchQuery = ''),
              child: Icon(Icons.close, color: Colors.grey.shade400, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(String? farmId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .collection('cycles')
          .where('farmId', isEqualTo: farmId)
          .snapshots(),
      builder: (context, snapshot) {
        int activeCount = 0;
        int completedCount = 0;

        if (snapshot.hasData) {
          final cycles = snapshot.data!.docs
              .map((doc) => CycleModel.fromDoc(doc))
              .toList();
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
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EAE5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => isCompletedView = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: !isCompletedView
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: !isCompletedView
                                ? [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Active ($activeCount)',
                            style: GoogleFonts.manrope(
                              color: !isCompletedView ? darkGreen : textGray,
                              fontWeight: !isCompletedView
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => isCompletedView = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: isCompletedView
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: isCompletedView
                                ? [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Completed ($completedCount)',
                            style: GoogleFonts.manrope(
                              color: isCompletedView ? darkGreen : textGray,
                              fontWeight: isCompletedView
                                  ? FontWeight.w800
                                  : FontWeight.w600,
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
            const SizedBox(width: 10),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons(String? farmId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Keep the info banner as informational only (optional)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFE9B0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.info_outline,
                    color: Color(0xFFD48806), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'You can start a new cycle or record a previous cycle. Both options are available.',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: const Color(0xFF9A6A00),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        _actionItem(
          icon: Icons.eco,
          title: 'Start New Cycle',
          subtitle: 'Begin a new cropping cycle',
          isPrimary: true,
          isEnabled: true, // Always enabled
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    StartCroppingCycleScreen(farmId: farmId),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _actionItem(
          icon: Icons.history,
          title: 'Record Previous Cycle',
          subtitle: 'Add historical cycle data',
          isPrimary: false,
          isEnabled: true,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    RecordCycleScreen(userId: user!.uid),
              ),
            ).then((_) => setState(() {}));
          },
        ),
        const SizedBox(height: 70),
      ],
    );
  }

  Widget _actionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isPrimary,
    required bool isEnabled,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isEnabled ? 1.0 : 0.45,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: isPrimary ? darkGreen : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isPrimary
                    ? darkGreen.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: isPrimary ? 12 : 4,
                offset:
                    isPrimary ? const Offset(0, 4) : const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isPrimary
                      ? Colors.white.withValues(alpha: 0.15)
                      : const Color(0xFFF0F1ED),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon,
                    color: isPrimary ? Colors.white : darkGreen, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        color: isPrimary ? Colors.white : darkGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.manrope(
                        color: isPrimary
                            ? Colors.white.withValues(alpha: 0.65)
                            : textGray.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isEnabled)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: isPrimary
                      ? Colors.white.withValues(alpha: 0.5)
                      : textGray.withValues(alpha: 0.4),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showScreen2BottomSheet(
      BuildContext context, String cropName, String cycleId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1E3E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                _sheetTile(Icons.edit_outlined, 'Edit Cycle', darkGreen, () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            EditCropCycleScreen(cycleId: cycleId)),
                  );
                }),
                _sheetTile(
                    Icons.share_outlined, 'Share Data', darkGreen, () {}),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child:
                      Container(height: 1, color: const Color(0xFFF0F1ED)),
                ),
                _sheetTile(
                    Icons.check_circle_outline, 'Mark as Completed', darkGreen,
                    () {
                  Navigator.pop(context);
                  _markCycleCompleted(cycleId);
                }),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child:
                      Container(height: 1, color: const Color(0xFFF0F1ED)),
                ),
                _sheetTile(Icons.delete_outline_rounded, 'Delete Cycle',
                    const Color(0xFFBA1A1A), () {
                  Navigator.pop(context);
                  _showScreen3DeleteOverlay(context, cropName, cycleId);
                }),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F5EE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel',
                        style: GoogleFonts.manrope(
                            color: textGray,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _markCycleCompleted(String cycleId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cycles')
          .doc(cycleId)
          .update({'isCompleted': true});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Cycle marked as completed',
              style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600, color: Colors.white)),
          backgroundColor: darkGreen,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to update cycle',
              style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600, color: Colors.white)),
          backgroundColor: const Color(0xFFBA1A1A),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ));
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
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Cycle deleted successfully',
              style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600, color: Colors.white)),
          backgroundColor: darkGreen,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to delete cycle',
              style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600, color: Colors.white)),
          backgroundColor: const Color(0xFFBA1A1A),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ));
      }
    }
  }

  Widget _sheetTile(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
          style: GoogleFonts.manrope(
              color: color, fontWeight: FontWeight.w700, fontSize: 15)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
    );
  }

  void _showScreen3DeleteOverlay(
      BuildContext context, String cropName, String cycleId) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28)),
          backgroundColor: Colors.white,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Color(0xFFBA1A1A), size: 40),
                ),
                const SizedBox(height: 28),
                Text('Delete Cropping Cycle?',
                    style: GoogleFonts.epilogue(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: headingBlack)),
                const SizedBox(height: 12),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.manrope(
                        fontSize: 14, color: textGray, height: 1.5),
                    children: [
                      const TextSpan(
                          text: 'Are you sure you want to delete '),
                      TextSpan(
                        text: cropName,
                        style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w800,
                            color: headingBlack),
                      ),
                      const TextSpan(text: '? This cannot be undone.'),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                _dialogBtn('Delete', const Color(0xFFBA1A1A), Colors.white,
                    () => _deleteCycle(cycleId)),
                const SizedBox(height: 10),
                _dialogBtn('Cancel', const Color(0xFFF3F5EE), headingBlack,
                    () => Navigator.pop(context)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dialogBtn(
      String label, Color bg, Color text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        onPressed: onTap,
        child: Text(label,
            style: GoogleFonts.manrope(
                color: text,
                fontWeight: FontWeight.w800,
                fontSize: 15)),
      ),
    );
  }
}

// ========== CARD WIDGETS (unchanged) ==========

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
        borderRadius: BorderRadius.circular(24),
        onTap: onViewDetailsTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 12, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF0F1ED),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: iconColor, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: GoogleFonts.manrope(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1A1C18))),
                              const SizedBox(height: 2),
                              Text(subtitle,
                                  style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      color: const Color(0xFF43483E)
                                          .withValues(alpha: 0.7),
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF3F5EE),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.more_horiz,
                                color: Color(0xFF43483E), size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: onMenuTap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE8EAE5),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(progressColor),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Est. Harvest: $harvestDate',
                            style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: const Color(0xFF43483E)
                                    .withValues(alpha: 0.7),
                                fontWeight: FontWeight.w500)),
                        Text('${(progress * 100).toInt()}%',
                            style: GoogleFonts.manrope(
                                fontSize: 13,
                                color: progressColor,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 16),
                    const SizedBox(width: 8),
                    Text(statusText,
                        style: GoogleFonts.manrope(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(title,
                      style: GoogleFonts.manrope(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0D4D33))),
                ),
                _badge(),
              ],
            ),
            const SizedBox(height: 18),
            _infoRow(
                Icons.calendar_today_outlined, 'Harvested: $harvestDate'),
            const SizedBox(height: 10),
            _infoRow(
              Icons.payments_outlined,
              'Income: $income',
              isBold: hasIncome,
              textColor: hasIncome
                  ? const Color(0xFF173408)
                  : const Color(0xFF43483E),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onViewDetailsTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('VIEW DETAILS',
                            style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: const Color(0xFF0D4D33))),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward,
                            size: 14, color: Color(0xFF0D4D33)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFEDF5E1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('COMPLETED',
            style: GoogleFonts.manrope(
                fontSize: 10,
                color: const Color(0xFF173408),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5)),
      );

  Widget _infoRow(IconData icon, String text,
          {bool isBold = false,
          Color textColor = const Color(0xFF1A1C18)}) =>
      Row(
        children: [
          Icon(icon,
              size: 16,
              color: const Color(0xFF43483E).withValues(alpha: 0.6)),
          const SizedBox(width: 10),
          Text(text,
              style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
                  color: textColor)),
        ],
      );
}
