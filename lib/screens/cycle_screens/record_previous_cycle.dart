import 'package:flutter/material.dart';

class RecordCycleScreen extends StatefulWidget {
  const RecordCycleScreen({super.key});

  @override
  State<RecordCycleScreen> createState() => _RecordCycleScreenState();
}

class _RecordCycleScreenState extends State<RecordCycleScreen> {
  bool _isCycleInfo = true;

  // Exact Hex Colors from Design
  static const Color primaryGreen = Color(0xFF134D37);
  static const Color backgroundColor = Color(0xFFF8FAF9);
  static const Color surfaceGrey = Color(0xFFF1F4F2);
  static const Color textPrimary = Color(0xFF1A1C1E);
  static const Color textSecondary = Color(0xFF44474E);
  static const Color accentLightGreen = Color(0xFFA6F78E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryGreen),
          onPressed: () {},
        ),
        title: const Text(
          'Record Cycle',
          style: TextStyle(
            color: primaryGreen,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            _buildTabSwitcher(),
            const SizedBox(height: 24),
            // Switch between Screen 1 and Screen 2 content
            _isCycleInfo ? _buildScreen1Content() : _buildScreen2Content(),
          ],
        ),
      ),
    );
  }

  // --- Common Components ---

  Widget _buildTabSwitcher() {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surfaceGrey,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isCycleInfo = true),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _isCycleInfo ? primaryGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  'Cycle Info',
                  style: TextStyle(
                    color: _isCycleInfo ? Colors.white : textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isCycleInfo = false),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: !_isCycleInfo ? primaryGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  'Earnings',
                  style: TextStyle(
                    color: !_isCycleInfo ? Colors.white : textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required String label, required bool showArrow, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            if (showArrow) ...[
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
            ]
          ],
        ),
      ),
    );
  }

  // --- Screen 1: Cycle Info Components ---

  Widget _buildScreen1Content() {
    return Column(
      children: [
        _buildLocationCard(),
        const SizedBox(height: 16),
        _buildInfoTile('CROP TYPE', 'Sweet Corn', Icons.spa_outlined),
        const SizedBox(height: 16),
        _buildInfoTile('VARIETY', 'Alpha Hybrid', Icons.verified_outlined),
        const SizedBox(height: 16),
        _buildTimelineSection(),
        const SizedBox(height: 24),
        _buildAIRefinementNote(),
        const SizedBox(height: 32),
        _buildActionButton(
          label: 'Earnings',
          showArrow: true,
          onTap: () => setState(() => _isCycleInfo = false),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LOCATION CONTEXT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryGreen, letterSpacing: 0.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: accentLightGreen,
                child: Icon(Icons.map_outlined, color: primaryGreen),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Green Valley Estate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('North Field • Sector B-12', style: TextStyle(color: textSecondary, fontSize: 14)),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, color: textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceGrey,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(icon, color: primaryGreen),
              const SizedBox(width: 12),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceGrey,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Timeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Icon(Icons.calendar_today_outlined, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          _buildDateEntry('PLANTING DATE', 'May 14, 2023'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: primaryGreen,
              child: const Icon(Icons.arrow_downward, color: Colors.white, size: 16),
            ),
          ),
          _buildDateEntry('HARVEST DATE', 'August 28, 2023'),
        ],
      ),
    );
  }

  Widget _buildDateEntry(String label, String date) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: textSecondary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const Icon(Icons.edit_outlined, color: Color(0xFFC4C7C5), size: 20),
        ],
      ),
    );
  }

  Widget _buildAIRefinementNote() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 5, height: 45, color: const Color.fromARGB(255, 1, 141, 87)),
        const SizedBox(width: 16),
        const Expanded(
          child: Text(
            'Recording previous cycles helps our AI refine yield predictions for the upcoming season by up to 22%.',
            style: TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
          ),
        ),
      ],
    );
  }

  // --- Screen 2: Earnings Components ---

  Widget _buildScreen2Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CYCLE 2023-B OUTCOME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryGreen)),
        const SizedBox(height: 4),
        const Text('Harvest Performance', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textPrimary)),
        const SizedBox(height: 8),
        const Text('Capture the final financial metrics to complete this cultivation record.', style: TextStyle(color: textSecondary, fontSize: 15)),
        const SizedBox(height: 24),
        _buildProductionMetrics(),
        const SizedBox(height: 20),
        _buildFinancialSummary(),
        const SizedBox(height: 20),
        _buildDataIntegrityCard(),
        const SizedBox(height: 32),
        _buildActionButton(label: 'Save Previous Cycle', showArrow: false, onTap: () {}),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'This action will archive the current cycle and lock editing.',
            style: TextStyle(fontSize: 12, color: textSecondary),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildProductionMetrics() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(backgroundColor: Color.fromARGB(255, 188, 255, 167), child: Icon(Icons.agriculture, color: Color.fromARGB(255, 6, 138, 56))),
              const SizedBox(width: 12),
              const Text('Production Metrics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          const Text('TOTAL YIELD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildInputBox('0.00', 'Tons'),
          const SizedBox(height: 16),
          _buildWarningNote(),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildColumnInput('PEST LOSS (%)', '0')),
              const SizedBox(width: 16),
              Expanded(child: _buildColumnInput('OTHER LOSS', '0')),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildWarningNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.error_outline, color: Color(0xFF6E4D0E), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: 'Note: ',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6E4D0E), fontSize: 12),
                children: [
                  TextSpan(
                    text: 'Yield loss calculations must include documented impacts from Fall Armyworm and other invasive pests identified during monitoring.',
                    style: TextStyle(fontWeight: FontWeight.normal),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(backgroundColor: Color(0xFFC2E8D7), child: Icon(Icons.payments_outlined, color: primaryGreen)),
              const SizedBox(width: 12),
              const Text('Financial Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          const Text('GROSS INCOME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildInputBox('0.00', null, prefix: '\₱ '),
          const SizedBox(height: 20),
          const Text('CALCULATED NET INCOME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: primaryGreen, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('\₱ 0.00', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text('AUTOMATED', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('Final calculation accounts for gross income minus all recorded losses and operational overhead.', style: TextStyle(fontSize: 11, color: textSecondary)),
        ],
      ),
    );
  }

  Widget _buildDataIntegrityCard() {
    return Container(
      height: 110,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        image: const DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&q=80&w=1000'), 
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(colors: [Colors.black.withOpacity(0.7), Colors.transparent], begin: Alignment.bottomLeft),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: const [
            Text('DATA INTEGRITY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('Ensuring sustainable growth through\naccurate intelligence.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBox(String val, String? suffix, {String? prefix}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: surfaceGrey, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          if (prefix != null) Text(prefix, style: const TextStyle(fontSize: 16, color: textSecondary)),
          Text(val, style: const TextStyle(fontSize: 18, color: textSecondary)),
          const Spacer(),
          if (suffix != null) Text(suffix, style: const TextStyle(fontWeight: FontWeight.bold, color: primaryGreen)),
        ],
      ),
    );
  }

  Widget _buildColumnInput(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: surfaceGrey, borderRadius: BorderRadius.circular(8)),
          child: Text(val, style: const TextStyle(fontSize: 18, color: textSecondary)),
        ),
      ],
    );
  }
}