import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CropFinanceScreen extends StatelessWidget {
  const CropFinanceScreen({super.key});

  // --- BRAND COLORS ---
  static const Color darkGreen = Color(0xFF0D4D33);
  static const Color textGray = Color(0xFF43483E);
  static const Color bgSoftGreen = Color(0xFFF3F5EE);
  static const Color accentGreen = Color(0xFF7BC72E);
  static const Color errorRed = Color(0xFFBA1A1A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: darkGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Crop Finance',
          style: GoogleFonts.epilogue(
            color: darkGreen,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text(
              'FINANCIAL ANALYTICS',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF4C7A1D),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Glutinous Corn Income\nCalculation',
              style: GoogleFonts.epilogue(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: darkGreen,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Enter your harvest data to calculate precise net income and assess seasonal performance.',
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: textGray,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 30),

            // --- INPUT SECTION CARD ---
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: bgSoftGreen.withOpacity(0.5),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                children: [
                  _buildInputField('Harvest Income (₱)', '12500'),
                  const SizedBox(height: 20),
                  _buildInputField('Damage Cost (₱)', '1200'),
                  const SizedBox(height: 20),
                  _buildInputField('Expenses Cost (₱)', '1200'),
                  const SizedBox(height: 30),
                  
                  // Calculate Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.calculate_outlined, color: Colors.white),
                      label: Text(
                        'Calculate Income',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- ESTIMATED NET INCOME RESULT CARD ---
            _buildResultCard(),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, String initialValue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: textGray,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextField(
            controller: TextEditingController(text: initialValue),
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
            decoration: const InputDecoration(
              prefixIcon: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text('₱', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: const Color(0xFFE1E3E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          // Top Section with subtle green gradient
          Container(
            padding: const EdgeInsets.only(top: 40, bottom: 50),
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
              gradient: RadialGradient(
                center: const Alignment(0.9, -0.9),
                radius: 1.2,
                colors: [
                  const Color.fromARGB(255, 72, 138, 7).withValues(alpha:0.35),
                  const Color.fromARGB(255, 173, 243, 81).withValues(alpha:0.0),
                ],
              ),
            ),
            child: Column(
              children: [
                Text(
                  'ESTIMATED NET INCOME',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textGray.withOpacity(0.6),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '₱11,300',
                      style: GoogleFonts.manrope(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: darkGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.trending_up, color: Colors.green, size: 32),
                  ],
                ),
              ],
            ),
          ),

          // Breakdown List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [
                _buildBreakdownRow('Harvest Income', '+₱12,500.00', const Color(0xFF0D4D33)),
                const Divider(height: 32, color: Color(0xFFF1F1F1)),
                _buildBreakdownRow('Damage Cost', '-\₱1,200.00', errorRed),
                const SizedBox(height: 24),
                
                // Performance Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: bgSoftGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total\nPerformance',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9E7CB),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '+90.4% PROFIT',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: const Color.fromARGB(246, 2, 117, 71),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Footer Metrics
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Row(
              children: [
                Expanded(child: _buildFooterMetric(Icons.bolt_outlined,'Income exceeds\naverage by 12%')),
                Expanded(child: _buildFooterMetric(Icons.verified_outlined, 'Resilience Score:\nHigh')),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Export PDF Button
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Export PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: darkGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600, color: textGray),
        ),
        Text(
          value,
          style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: valueColor),
        ),
      ],
    );
  }

  Widget _buildFooterMetric(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF6B4B00), size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textGray,
            ),
          ),
        ),
      ],
    );
  }
}