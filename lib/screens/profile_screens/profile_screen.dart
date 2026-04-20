import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/screens/profile_screens/manage_account.dart';
import 'package:visaia/screens/profile_screens/preferences.dart';
import 'package:visaia/screens/profile_screens/help_and_support.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // Precise Colors from the Design
  static const Color bgColor = Color(0xFFF8F9F8);
  static const Color darkGreen = Color(0xFF1B3015);
  static const Color accentGreen = Color(0xFF96D161);
  static const Color cardGray = Color(0xFFF3F5F3);
  static const Color textGray = Color(0xFF43483E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderSection(),
              const SizedBox(height: 24),
              _buildStatisticsRow(),
              const SizedBox(height: 32),
              _buildMyFarmsSection(),
              const SizedBox(height: 32),
              _buildAccountSystemSection(context),
              const SizedBox(height: 32),
              _buildFooter(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 56,
                  backgroundImage: NetworkImage(
                    'https://ui-avatars.com/api/?background=1B3015&color=fff&size=110&name=Arthur+Jensen',
                  ),
                ),
              ),
              Positioned(
                bottom: 5,
                right: 5,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2D4421),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Arthur Jensen',
          style: GoogleFonts.epilogue(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: darkGreen,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_outlined, size: 14, color: textGray),
            const SizedBox(width: 4),
            Text(
              'Senior Agronomist',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textGray,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text('•', style: TextStyle(color: textGray, fontWeight: FontWeight.bold)),
            ),
            Text(
              'Premium Plan',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textGray,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatisticsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'ACTIVE FARMS',
            value: '03',
            icon: Icons.agriculture_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: 'TOTAL FIELDS',
            value: '14',
            icon: Icons.eco_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildMyFarmsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Farms',
              style: GoogleFonts.epilogue(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: darkGreen,
              ),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_circle_outline, size: 18, color: darkGreen),
              label: Text(
                'Add Farm',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: darkGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _FarmCard(
          title: 'Green Valley Estate',
          subtitle: 'Iloilo, Philippines • 450 Acres',
          icon: Icons.home_work_rounded,
          isActive: true,
        ),
        const SizedBox(height: 12),
        _FarmCard(
          title: 'River North Plots',
          subtitle: 'Iloilo, Philippines • 120 Acres',
          icon: Icons.apartment_rounded,
          isActive: false,
        ),
      ],
    );
  }

  Widget _buildAccountSystemSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account & System',
          style: GoogleFonts.epilogue(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: darkGreen,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            children: [
              _SystemTile(icon: Icons.person_outline_rounded, title: 'Manage Account', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageAccountScreen()))),
              const Divider(height: 1, indent: 56, endIndent: 20),
              _SystemTile(icon: Icons.settings_outlined, title: 'Preferences', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PreferencesScreen()))),
              const Divider(height: 1, indent: 56, endIndent: 20),
              _SystemTile(icon: Icons.headset_mic_outlined, title: 'Help & Support', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpCenterScreen()))),
              const Divider(height: 1, indent: 56, endIndent: 20),
              _SystemTile(icon: Icons.shield_outlined, title: 'Privacy & Data', onTap: () => {}),
              const Divider(height: 1, indent: 56, endIndent: 20),
              _SystemTile(
                icon: Icons.logout_rounded,
                title: 'Logout',
                isDestructive: true,
                onTap: () => {}
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          Text(
            'VISAIÀ AGRICULTURE PLATFORM',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: textGray.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Version 2.4.0 (Stable Build)',
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: textGray.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({required this.title, required this.value, required this.icon});

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
            crossAxisAlignment: CrossAxisAlignment.center,
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

  const _FarmCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isActive,
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(isActive ? 0.4 : 0.7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: ProfileScreen.darkGreen, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isActive)
                  Text(
                    'Your Active Farm',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: ProfileScreen.darkGreen.withOpacity(0.8),
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
                    color: ProfileScreen.darkGreen.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          if (!isActive)
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
        size: 26,
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
          : const Icon(Icons.chevron_right_rounded, size: 22, color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      onTap: onTap,
    );
  }
}