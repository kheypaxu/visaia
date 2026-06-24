import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/screens/dashboard_screens/threat_details.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  // Brand Colors
  static const Color darkGreen = Color(0xFF0D4D33);
  static const Color textGray = Color(0xFF43483E);
  static const Color headingBlack = Color(0xFF1A1C18);

  @override
  Widget build(BuildContext context) {
    // Get current user ID from your auth system
    // Replace with your actual auth method
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    // Safety check in case they aren't logged in
    if (currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view alerts.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5EE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: darkGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications & Alerts',
          style: GoogleFonts.epilogue(
            color: darkGreen,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header Section ---
            Text(
              'Alerts & Intel',
              style: GoogleFonts.epilogue(
                fontSize: 35,
                fontWeight: FontWeight.w700,
                color: darkGreen,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Real-time agricultural intelligence and actionable\nnotifications for your managed zones.',
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: textGray,
                height: 1.9,
              ),
            ),
            const SizedBox(height: 32),

            // --- Firestore Alerts Stream ---
            StreamBuilder<QuerySnapshot>(
              // REMOVED .orderBy('createdAt', descending: true) to avoid composite index requirement
              stream: FirebaseFirestore.instance
                  .collection('alerts')
                  .where('farmerId', isEqualTo: currentUserId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading alerts: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No alerts yet',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textGray,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'When pests are detected near your farm,\nyou\'ll see them here.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // --- CLIENT-SIDE SORTING ---
                // We sort the documents in Dart by 'createdAt' descending.
                // This completely avoids the need for a Firestore composite index.
                final alerts = snapshot.data!.docs;
                alerts.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  
                  final aTimestamp = aData['createdAt'] as Timestamp?;
                  final bTimestamp = bData['createdAt'] as Timestamp?;
                  
                  final aTime = aTimestamp?.toDate() ?? DateTime(1970);
                  final bTime = bTimestamp?.toDate() ?? DateTime(1970);
                  
                  // Descending order (newest first)
                  return bTime.compareTo(aTime); 
                });

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    final doc = alerts[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    // Format time
                    String timeString = '';
                    if (data['createdAt'] != null) {
                      final timestamp = data['createdAt'] as Timestamp;
                      final date = timestamp.toDate();
                      final now = DateTime.now();
                      final diff = now.difference(date);
                      
                      if (diff.inDays > 0) {
                        timeString = '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
                      } else if (diff.inHours > 0) {
                        timeString = '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
                      } else if (diff.inMinutes > 0) {
                        timeString = '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
                      } else {
                        timeString = 'Just now';
                      }
                    }

                    // Determine category based on risk level
                    String category = 'ALERT';
                    IconData alertIcon = Icons.info_outline;
                    Color accentColor = darkGreen;
                    
                    final risk = (data['risk'] ?? 'Moderate').toString().toLowerCase();
                    if (risk == 'high') {
                      category = 'CRITICAL THREAT';
                      alertIcon = Icons.warning_amber_rounded;
                      accentColor = const Color(0xFFBA1A1A);
                    } else if (risk == 'moderate') {
                      category = 'NEARBY OUTBREAK';
                      alertIcon = Icons.bug_report;
                      accentColor = const Color(0xFFE2A000);
                    } else {
                      category = 'ADVISORY';
                      alertIcon = Icons.agriculture_rounded;
                      accentColor = darkGreen;
                    }

                    return AlertCard(
                      alertId: doc.id,
                      category: category,
                      title: data['title'] ?? 'Pest Alert',
                      description: data['message'] ?? 'No additional details',
                      time: timeString,
                      icon: alertIcon,
                      accentColor: accentColor,
                      isNew: data['status'] == 'unread',
                      onTap: () async {
                        // Mark as read
                        await doc.reference.update({'status': 'read'});
                        
                        // Navigate to details screen
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ThreatDetailsScreen(alertId: doc.id),
                            ),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// --- THE ALERT CARD COMPONENT ---
class AlertCard extends StatelessWidget {
  final String alertId;
  final String category;
  final String title;
  final String description;
  final String time;
  final IconData icon;
  final Color accentColor;
  final bool isNew;
  final VoidCallback onTap;

  const AlertCard({
    super.key,
    required this.alertId,
    required this.category,
    required this.title,
    required this.description,
    required this.time,
    required this.icon,
    required this.accentColor,
    this.isNew = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Accent Border
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
              ),
              // Content Area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Circular Icon background
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: accentColor, size: 24),
                          ),
                          const SizedBox(width: 16),
                          // Category and Time
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      category,
                                      style: GoogleFonts.manrope(
                                        color: accentColor,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      time,
                                      style: GoogleFonts.manrope(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // Title with New Indicator
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: GoogleFonts.manrope(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF1A1C18),
                                        ),
                                      ),
                                    ),
                                    if (isNew)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Description Text
                      Padding(
                        padding: const EdgeInsets.only(left: 60),
                        child: Text(
                          description,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: const Color(0xFF43483E),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}