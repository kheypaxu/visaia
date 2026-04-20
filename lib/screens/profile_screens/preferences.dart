import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  // Updated Colors based on your request
  static const Color customGreen = Color(0xFF173408); // #173408
  static const Color lightBlueBackground = Color(0xFFE3F2FD); // Light blue for buttons
  static const Color accentGreen = Color(0xFFE8F5E9);
  static const Color textGray = Color(0xFF43483E);
  static const Color blueAccent = Color(0xFF2962FF);

  bool pushAlerts = true;
  bool emailReports = true;
  String selectedLanguage = 'English (United Kingdom)';
  String mapMode = 'Satellite View';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: customGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Preferences',
          style: GoogleFonts.epilogue(
            color: customGreen,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                'VISAIA',
                style: GoogleFonts.epilogue(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: customGreen,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, accentGreen.withOpacity(0.3)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ACCOUNT CONTROLS',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: customGreen,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tailor your\nagricultural\necosystem\nexperience.',
                style: GoogleFonts.epilogue(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: customGreen,
                  height: 1.1,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 40),

              // Notifications Section
              _buildSectionHeader(Icons.notifications_none_outlined, 'Notifications'),
              const SizedBox(height: 16),
              _buildSwitchTile(
                'Push Alerts',
                'Real-time sensor and crop updates',
                pushAlerts,
                (val) => setState(() => pushAlerts = val),
              ),
              const SizedBox(height: 16), 
              _buildSwitchTile(
                'Email Reports',
                'Weekly yield summaries',
                emailReports,
                (val) => setState(() => emailReports = val),
              ),
              const SizedBox(height: 40),

              // Localization Section
              _buildSectionHeader(Icons.language_outlined, 'Localization'),
              const SizedBox(height: 24),
              _buildDropdownLabel('PRIMARY LANGUAGE'),
              _buildDropdownField(selectedLanguage),
              const SizedBox(height: 24),
              _buildDropdownLabel('MAP DISPLAY MODE'),
              _buildDropdownField(mapMode),

              const SizedBox(height: 60),
              Center(
                child: Column(
                  children: [
                    Text(
                      'Last synced today at 04:22 PM',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: textGray.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.sync, size: 18),
                      label: const Text('Restore Defaults'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: lightBlueBackground, 
                        foregroundColor: customGreen, 
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        side: const BorderSide(color: customGreen, width: 1.5), 
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        textStyle: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: customGreen, size: 24),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.epilogue(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: customGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Re-added the light line after the header
        Divider(color: customGreen.withOpacity(0.1), thickness: 1),
      ],
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: customGreen,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: textGray.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: customGreen,
          activeColor: blueAccent,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: customGreen.withOpacity(0.1),
          thumbIcon: WidgetStateProperty.resolveWith<Icon?>((Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return const Icon(Icons.check, color: Colors.white, size: 18);
            }
            return null;
          }),
        ),
      ],
    );
  }

  Widget _buildDropdownLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: textGray.withOpacity(0.6),
        ),
      ),
    );
  }

  Widget _buildDropdownField(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: customGreen,
            ),
          ),
          const Icon(Icons.keyboard_arrow_down, color: textGray),
        ],
      ),
    );
  }
}