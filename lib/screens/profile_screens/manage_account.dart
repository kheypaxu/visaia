import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ManageAccountScreen extends StatelessWidget {
  const ManageAccountScreen({super.key});

  // Theme Colors
  static const Color bgColor = Color(0xFFF8F9F8);
  static const Color darkGreen = Color(0xFF1B3015);
  static const Color textGray = Color(0xFF43483E);
  static const Color inputBg = Color(0xFFF1F3F1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: darkGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Account Settings',
          style: GoogleFonts.epilogue(
            color: darkGreen,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage('https://ui-avatars.com/api/?background=1B3015&color=fff&name=AJ'),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Information Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Arthur Jensen: 173408, Extra Bold, size 24
                  _buildEditableField('FULL NAME', 'Arthur Jensen', const Color(0xFF173408), FontWeight.w900, 24),
                  const SizedBox(height: 28),
                  // Username: 43483E, Medium, size 16
                  _buildEditableField('USERNAME', 'arthur_jensen', const Color(0xFF43483E), FontWeight.w500, 16),
                  const SizedBox(height: 28),
                  // Email: 181C1A, Semi Bold, size 16
                  _buildEditableField('EMAIL ADDRESS', 'arthur.jensen@agrimail.com', const Color(0xFF181C1A), FontWeight.w600, 16),
                  const SizedBox(height: 28),
                  _buildIdNumberRow('RSBSA ID NUMBER', '12-345я-789-0'),
                ],
              ),
            ),

            const SizedBox(height: 36),
            Text(
              'Security & Password',
              style: GoogleFonts.epilogue(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: darkGreen,
              ),
            ),
            const SizedBox(height: 16),

            // Password Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputLabel('CURRENT PASSWORD'),
                  _buildPasswordField('••••••••••••'),
                  const SizedBox(height: 24),
                  _buildInputLabel('NEW PASSWORD'),
                  _buildTextField('Enter new password'),
                  const SizedBox(height: 24),
                  _buildInputLabel('CONFIRM NEW PASSWORD'),
                  _buildTextField('Re-type new password'),
                  const SizedBox(height: 32),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14290B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Update Password',
                        style: GoogleFonts.manrope(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0, left: 4),
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

  Widget _buildTextField(String hint) {
    return TextField(
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.manrope(
          color: Colors.grey.shade400, 
          fontSize: 15,
          fontWeight: FontWeight.w500
        ),
        filled: true,
        fillColor: inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // Updated to support dynamic styling
  Widget _buildEditableField(String label, String value, Color textColor, FontWeight fontWeight, double fontSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel(label),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: fontSize,
                fontWeight: fontWeight,
                color: textColor,
              ),
            ),
            const Icon(Icons.edit, size: 20, color: Color(0xFF173408)),
          ],
        ),
      ],
    );
  }

  // Updated to match the specific icon-to-text alignment in the UI
  Widget _buildIdNumberRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.badge_outlined, color: Color(0xFF4A633F), size: 24),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: textGray.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF181C1A),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPasswordField(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20, 
              letterSpacing: 3, 
              color: darkGreen,
              fontWeight: FontWeight.bold
            ),
          ),
          const Icon(Icons.lock_outline, color: Colors.grey, size: 22),
        ],
      ),
    );
  }
}