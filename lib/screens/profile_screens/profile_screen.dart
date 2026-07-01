import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:visaia/core/providers/farm_provider.dart';

import 'package:visaia/screens/profile_screens/manage_account.dart';
import 'package:visaia/screens/profile_screens/preferences.dart';
import 'package:visaia/screens/profile_screens/help_and_support.dart';
import 'package:visaia/screens/profile_screens/privacy_data_screen.dart';
import 'package:visaia/screens/onboarding/farm_area_setup.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const Color bgColor = Color(0xFFF8F9F8);
  static const Color darkGreen = Color(0xFF1B3015);
  static const Color accentGreen = Color(0xFF96D161);
  static const Color cardGray = Color(0xFFF3F5F3);
  static const Color textGray = Color(0xFF43483E);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _uploading = false;

  User? get currentUser => _auth.currentUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (currentUser != null) {
        await _migrateMissingFarmIds();
      }
    });
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: const Color(0xFFD32F2F), size: 28),
            const SizedBox(width: 12),
            Text(
              'Logout',
              style: GoogleFonts.epilogue(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFD32F2F),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.manrope(
            fontSize: 16,
            color: ProfileScreen.textGray,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                color: ProfileScreen.textGray,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= DELETE FARM =================
  void _showDeleteFarmDialog(String farmId, String farmName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: const Color(0xFFD32F2F), size: 28),
            const SizedBox(width: 12),
            Text(
              'Delete Farm',
              style: GoogleFonts.epilogue(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFD32F2F),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "$farmName"?',
              style: GoogleFonts.manrope(
                fontSize: 16,
                color: ProfileScreen.textGray,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This will also delete all fields and cycles associated with this farm. This action cannot be undone.',
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: ProfileScreen.textGray.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                color: ProfileScreen.textGray,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteFarm(farmId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFarm(String farmId) async {
    try {
      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      final uid = currentUser!.uid;

      // 1. Delete all cycles associated with this farm
      final cyclesSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('cycles')
          .where('farmId', isEqualTo: farmId)
          .get();

      final batch = _firestore.batch();
      for (final doc in cyclesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // 2. Delete all fields associated with this farm
      final fieldsSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('fields')
          .where('farmId', isEqualTo: farmId)
          .get();

      final fieldBatch = _firestore.batch();
      for (final doc in fieldsSnapshot.docs) {
        fieldBatch.delete(doc.reference);
      }
      await fieldBatch.commit();

      // 3. Delete the farm itself
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('farms')
          .doc(farmId)
          .delete();

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Check if this was the active farm
      final farmProvider = context.read<FarmProvider>();
      if (farmProvider.activeFarmId == farmId) {
        // Check if there are any remaining farms
        final remainingFarms = await _firestore
            .collection('users')
            .doc(uid)
            .collection('farms')
            .limit(1)
            .get();

        if (remainingFarms.docs.isNotEmpty) {
          // Switch to the first available farm
          final newFarmId = remainingFarms.docs.first.id;
          final newFarmName = remainingFarms.docs.first.data()['name'] ?? 'Farm';
          farmProvider.switchFarm(newFarmId, newFarmName);
        } else {
          // No farms left - clear the provider state
          farmProvider.clearFarm();
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Farm deleted successfully'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting farm: $e'),
            backgroundColor: const Color(0xFFD32F2F),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      await _auth.signOut();

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: const Color(0xFFD32F2F),
          ),
        );
      }
    }
  }

  void _addFarm() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FarmAreaSetup(
          onFinished: () => Navigator.pop(context),
        ),
      ),
    );
  }

  // ================= FARM STREAM =================
  Stream<QuerySnapshot<Map<String, dynamic>>> get farmsStream {
    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('farms')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ================= FIELD STREAM =================
  Stream<QuerySnapshot<Map<String, dynamic>>> fieldsStream(String? farmId) {
    final uid = currentUser?.uid;
    if (uid == null) return const Stream.empty();

    Query<Map<String, dynamic>> ref = _firestore
        .collection('users')
        .doc(uid)
        .collection('fields');

    if (farmId != null) {
      ref = ref.where('farmId', isEqualTo: farmId);
    }

    return ref.snapshots();
  }

  // ================= CYCLE STREAM =================
  Stream<QuerySnapshot<Map<String, dynamic>>> cyclesStream(String? farmId) {
    final uid = currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('cycles')
        .where('farmId', isEqualTo: farmId)
        .snapshots();
  }

  Future<void> _migrateMissingFarmIds() async {
    final uid = currentUser!.uid;

    final farmsSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('farms')
        .get();

    if (farmsSnapshot.docs.isEmpty) return;

    final defaultFarmId = farmsSnapshot.docs.first.id;

    final cyclesSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('cycles')
        .get();

    for (final doc in cyclesSnapshot.docs) {
      if (doc.data()['farmId'] == null) {
        await doc.reference.update({'farmId': defaultFarmId});
      }
    }

    final fieldsSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('fields')
        .get();

    for (final doc in fieldsSnapshot.docs) {
      if (doc.data()['farmId'] == null) {
        await doc.reference.update({'farmId': defaultFarmId});
      }
    }
  }

  // ================= PROFILE IMAGE =================
  Future<void> _pickAndUploadImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (picked == null) return;

      setState(() => _uploading = true);

      final compressed = await FlutterImageCompress.compressWithFile(
        picked.path,
        quality: 50,
        format: CompressFormat.jpeg,
      );
      if (compressed == null) return;

      final base64Image = base64Encode(compressed);

      await _firestore.collection('farmers').doc(currentUser!.uid).set(
        {'profileImage': base64Image},
        SetOptions(merge: true),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile image updated')),
        );
      }
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error uploading image: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ================= SWITCH FARM =================
  void _switchFarm(String farmId, String farmName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Switch Farm"),
        content: Text("Do you want to switch to \"$farmName\"?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Switch"),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      context.read<FarmProvider>().switchFarm(farmId, farmName);
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown Date';
    if (timestamp is Timestamp) {
      return DateFormat('MMMM yyyy').format(timestamp.toDate());
    }
    return 'Unknown Date';
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("No authenticated user.")),
      );
    }

    final farmProvider = context.watch<FarmProvider>();
    final activeFarmId = farmProvider.activeFarmId;

    return Scaffold(
      backgroundColor: ProfileScreen.bgColor,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('farmers')
            .doc(currentUser!.uid)
            .snapshots(),
        builder: (context, farmerSnapshot) {
          if (!farmerSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final farmerData = farmerSnapshot.data!.data() ?? {};
          final fullName = farmerData['fullName'] ?? 'Unknown User';
          final status = farmerData['status'] ?? 'Unverified';
          final profileImage = farmerData['profileImage'];

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ================= HEADER =================
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.white,
                              child: CircleAvatar(
                                radius: 56,
                                backgroundImage: profileImage != null
                                    ? MemoryImage(base64Decode(profileImage))
                                    : null,
                                child: profileImage == null
                                    ? Text(
                                        fullName.isNotEmpty
                                            ? fullName[0].toUpperCase()
                                            : "?",
                                        style: const TextStyle(
                                          fontSize: 40,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            Positioned(
                              bottom: 5,
                              right: 5,
                              child: GestureDetector(
                                onTap: _uploading ? null : _pickAndUploadImage,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2D4421),
                                    shape: BoxShape.circle,
                                  ),
                                  child: _uploading
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.edit,
                                          size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          fullName,
                          style: GoogleFonts.epilogue(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: ProfileScreen.darkGreen,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.verified,
                                size: 16, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              status.toString().toUpperCase(),
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w700,
                                color: ProfileScreen.textGray,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ================= STATS =================
                  Row(
                    children: [
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          key: ValueKey(activeFarmId),
                          stream: cyclesStream(activeFarmId),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const _StatCard(
                                title: 'ACTIVE CYCLES',
                                value: '--',
                                icon: Icons.eco_rounded,
                              );
                            }
                            final count = snapshot.data!.docs
                                .where((doc) =>
                                    doc.data()['isCompleted'] == false)
                                .length;
                            return _StatCard(
                              title: 'ACTIVE CYCLES',
                              value: count.toString().padLeft(2, '0'),
                              icon: Icons.eco_rounded,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          key: ValueKey(activeFarmId),
                          stream: fieldsStream(activeFarmId),
                          builder: (context, snapshot) {
                            final count = snapshot.data?.docs.length ?? 0;
                            return _StatCard(
                              title: 'FIELDS',
                              value: count.toString().padLeft(2, '0'),
                              icon: Icons.grid_view_rounded,
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // ================= FARMS =================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Farms',
                        style: GoogleFonts.epilogue(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: ProfileScreen.darkGreen,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline,
                            color: ProfileScreen.darkGreen),
                        onPressed: _addFarm,
                        tooltip: 'Add new farm',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: farmsStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final farms = snapshot.data!.docs;
                      if (farms.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.agriculture_outlined,
                                size: 64,
                                color: ProfileScreen.textGray.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No farms found',
                                style: GoogleFonts.manrope(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: ProfileScreen.textGray,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap the + button to add your first farm',
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  color: ProfileScreen.textGray.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: farms.map((farmDoc) {
                          final data = farmDoc.data();
                          final farmId = farmDoc.id;
                          final farmName = data['name'] ?? 'Unnamed Farm';
                          final acres = (data['acres'] ?? 0).toDouble();
                          final createdAt = data['createdAt'];
                          final isActive = farmId == activeFarmId;
                          final farmCount = farms.length;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _FarmCard(
                              title: farmName,
                              subtitle:
                                  'Created ${_formatTimestamp(createdAt)} • ${acres.toStringAsFixed(2)} Acres',
                              icon: Icons.agriculture_rounded,
                              isActive: isActive,
                              isDeletable: farmCount > 1 || !isActive,
                              onTap: () => _switchFarm(farmId, farmName),
                              onDelete: () => _showDeleteFarmDialog(farmId, farmName),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  _buildAccountSection(),

                  const SizedBox(height: 30),

                  // ================= FOOTER =================
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'VISAIÀ AGRICULTURE PLATFORM',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: ProfileScreen.textGray.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Version 2.4.0 (Stable Build)',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: ProfileScreen.textGray.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account & System',
          style: GoogleFonts.epilogue(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: ProfileScreen.darkGreen,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              _SystemTile(
                icon: Icons.person_outline_rounded,
                title: 'Manage Account',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ManageAccountScreen())),
              ),
              const Divider(height: 1),
              _SystemTile(
                icon: Icons.settings_outlined,
                title: 'Preferences',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PreferencesScreen())),
              ),
              const Divider(height: 1),
              _SystemTile(
                icon: Icons.headset_mic_outlined,
                title: 'Help & Support',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const HelpCenterScreen())),
              ),
              const Divider(height: 1),
              _SystemTile(
                icon: Icons.shield_outlined,
                title: 'Privacy & Data',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PrivacyDataScreen())),
              ),
              const Divider(height: 1),
              _SystemTile(
                icon: Icons.logout_rounded,
                title: 'Logout',
                isDestructive: true,
                onTap: _showLogoutDialog,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==================== SUB-WIDGETS ====================

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: ProfileScreen.textGray,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                value,
                style: GoogleFonts.epilogue(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: ProfileScreen.darkGreen,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: ProfileScreen.darkGreen, size: 26),
            ],
          ),
        ],
      ),
    );
  }
}

class _FarmCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isActive;
  final bool isDeletable;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _FarmCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isActive,
    this.isDeletable = true,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? ProfileScreen.accentGreen : const Color(0xFFE4E6E4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: isActive ? 0.4 : 0.7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: ProfileScreen.darkGreen, size: 28),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isActive)
                      Text(
                        'Active Farm',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: ProfileScreen.darkGreen.withValues(alpha: 0.8),
                        ),
                      ),
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: ProfileScreen.darkGreen,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: ProfileScreen.darkGreen.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          if (isDeletable && !isActive)
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red.shade700,
                  size: 22,
                ),
              ),
            ),
          if (!isDeletable && isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Can't delete active farm",
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: ProfileScreen.darkGreen.withValues(alpha: 0.6),
                ),
              ),
            ),
          if (!isActive && !isDeletable)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Only farm',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: ProfileScreen.darkGreen.withValues(alpha: 0.6),
                ),
              ),
            ),
          if (!isActive)
            const SizedBox(width: 8),
          if (!isActive && !isDeletable)
            const Icon(Icons.chevron_right, color: ProfileScreen.darkGreen),
        ],
      ),
    );
  }
}

class _SystemTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDestructive;
  final VoidCallback onTap;

  const _SystemTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? const Color(0xFFD32F2F) : ProfileScreen.darkGreen,
      ),
      title: Text(
        title,
        style: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: isDestructive ? const Color(0xFFD32F2F) : ProfileScreen.darkGreen,
        ),
      ),
      trailing: isDestructive
          ? null
          : const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      onTap: onTap,
    );
  }
}