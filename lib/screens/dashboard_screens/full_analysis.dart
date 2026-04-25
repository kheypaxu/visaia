import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/screens/dashboard_screens/view_income.dart';

class IncomeEstimationScreen extends StatelessWidget {
  const IncomeEstimationScreen({super.key});

  // --- BRAND COLORS ---
  static const Color darkGreen = Color(0xFF0D4D33);
  static const Color textGray = Color(0xFF43483E);
  static const Color accentGreen = Color(0xFF7BC72E);
  static const Color softRed = Color(0xFFFFDADA);
  static const Color deepRed = Color(0xFFBA1A1A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: darkGreen),
          onPressed: () {},
        ),
        title: Text(
          'Income Estimation',
          style: GoogleFonts.epilogue(
            color: darkGreen,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text(
              'Income Estimate',
              style: GoogleFonts.epilogue(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: darkGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Financial summary and projections based on current yield estimates and market conditions.',
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: textGray,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            
            // Export PDF Button
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.file_download_outlined, size: 20),
              label: const Text('Export PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 240, 240, 240),
                foregroundColor: Colors.black,
                elevation: 5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
            
            const SizedBox(height: 30),

            // --- GROSS INCOME ESTIMATE CARD ---
            _buildGrossIncomeCard(),

            const SizedBox(height: 30),

            // --- ESTIMATED LOSSES CARD ---
            _buildLossesCard(),

            const SizedBox(height: 30),

            // --- MONTHLY INCOME PROJECTION ---
            Text(
              'Monthly Income Projection',
              style: GoogleFonts.epilogue(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Based on harvest schedules and forward contracts',
              style: GoogleFonts.manrope(color: textGray, fontSize: 14),
            ),
            const SizedBox(height: 15),
            
            // Toggle Switch
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE1E3E1).withOpacity(0.5),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildToggleItem("6 Months", true),
                  _buildToggleItem("1 Year", false),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            _buildRevenueChart(),

            const SizedBox(height: 30),

            // --- PLANTED CROPS SECTION ---
            Text(
              'Planted Crops',
              style: GoogleFonts.epilogue(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            _buildCropItem(context, "Glutinous Corn", "Plot 4B", "92% Mature", const Color(0xFFC5E1A5)),
            _buildCropItem(context, "Soybean", "East Ridge", "Early Growth", const Color(0xFFE1E3E1)),
            _buildCropItem(context, "Yellow Corn", "Section 2", "Mid Stage", const Color(0xFFC5E1A5)),
            
            const SizedBox(height: 40), 
          ],
        ),
      ),
    );
  }

  // --- COMPONENT HELPER METHODS ---

  Widget _buildGrossIncomeCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('GROSS INCOME ESTIMATE', 
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: textGray, letterSpacing: 1)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: accentGreen.withValues(alpha:0.2), shape: BoxShape.circle),
                child: const Icon(Icons.trending_up, color: Color.fromARGB(255, 76, 122, 29), size: 25),
              )
            ],
          ),
          const SizedBox(height: 10),
          Text('₱845,200', style: GoogleFonts.manrope(fontSize: 32, fontWeight: FontWeight.w800, color: darkGreen)),
          Text('↑ 12% vs last cycle', style: GoogleFonts.manrope(fontSize: 14, color: Colors.green[700], fontWeight: FontWeight.w700)),
          const Divider(height: 40, color: Color(0xFFF1F1F1)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniMetric("Projected Yield", "1,250 Tons"),
              _buildMiniMetric("Avg Market Price", "\$676/Ton"),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLossesCard() {
    return Container(
      padding: const EdgeInsets.all(27),
      decoration: BoxDecoration(
        color: softRed.withValues(alpha:0.6),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ESTIMATED LOSSES', 
                style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w900, color: deepRed, letterSpacing: 0.7)),
              const Icon(Icons.bug_report_outlined, color: deepRed, size: 20),
            ],
          ),
          Text('Primarily overall damage impact', 
            style: GoogleFonts.manrope(fontSize: 14, color: deepRed.withValues(alpha:0.7))),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 15),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: deepRed.withValues(alpha:0.1)),
            ),
            child: Text('-₱28,000', 
              style: GoogleFonts.manrope(fontSize: 26, fontWeight: FontWeight.w800, color: deepRed)),
          )
        ],
      ),
    );
  }

  Widget _buildCropItem(BuildContext context, String name, String plot, String stage, Color stageBg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: textGray,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        plot,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: textGray,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: stageBg,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  stage,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            ],
          ),

          const SizedBox(height: 30),

          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CropFinanceScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(25),
            child: Container(
              width: double.infinity,
              height: 45,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F5EE),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View Income',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w900,
                      color: darkGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: Color.fromARGB(255, 1, 39, 24),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Last 6 Months Revenue Flow', style: GoogleFonts.manrope(fontSize: 12, color: textGray)),
              Row(
                children: [
                  Text('Export', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.bold)),
                  const Icon(Icons.download, size: 15),
                ],
              )
            ],
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar("MAR", 0.4, 0.6),
              _buildBar("APR", 0.6, 0.4),
              _buildBar("MAY", 0.3, 0.8),
              _buildBar("JUN", 0.7, 0.2),
              _buildBar("JUL", 0.4, 0.5),
              _buildBar("AUG", 0.8, 0.3),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBar(String month, double darkLevel, double lightLevel) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 100 * (darkLevel + lightLevel),
              width: 25,
              decoration: BoxDecoration(color: const Color(0xFFE1E3E1), borderRadius: BorderRadius.circular(12.5)),
            ),
            Container(
              height: 100 * darkLevel,
              width: 25,
              decoration: BoxDecoration(color: darkGreen, borderRadius: BorderRadius.circular(12.5)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(month, style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMiniMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.manrope(fontSize: 13, color: textGray)),
        Text(value, style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
      ],
    );
  }

  Widget _buildToggleItem(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : null,
      ),
      child: Text(label, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.black : textGray)),
    );
  }
}