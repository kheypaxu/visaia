import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:visaia/screens/map/location_picker.dart';

class RecordCycleScreen extends StatefulWidget {
  final String userId;

  const RecordCycleScreen({
    super.key,
    required this.userId,
  });

  @override
  State<RecordCycleScreen> createState() => _RecordCycleScreenState();
}

class _RecordCycleScreenState extends State<RecordCycleScreen> {
  bool _isCycleInfo = true;
  bool _isSaving = false;

  // Form validation keys
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for form fields
  final TextEditingController _cycleNameController = TextEditingController();
  final TextEditingController _cropTypeController = TextEditingController();
  final TextEditingController _varietyController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  
  // Location data
  String _selectedLocation = '';
  double? _latitude;
  double? _longitude;
  
  // Date controllers
  DateTime? _plantingDate;
  DateTime? _harvestDate;
  
  // Production metrics
  final TextEditingController _totalYieldController = TextEditingController();
  final TextEditingController _pestLossController = TextEditingController();
  final TextEditingController _otherLossController = TextEditingController();
  
  // Financials
  final TextEditingController _grossIncomeController = TextEditingController();
  
  double _calculatedNetIncome = 0.0;
  double _totalYield = 0.0;
  double _pestLoss = 0.0;
  double _otherLoss = 0.0;
  double _grossIncome = 0.0;

  // Exact Hex Colors from Design
  static const Color primaryGreen = Color(0xFF134D37);
  static const Color backgroundColor = Color(0xFFF8FAF9);
  static const Color surfaceGrey = Color(0xFFF1F4F2);
  static const Color textPrimary = Color(0xFF1A1C1E);
  static const Color textSecondary = Color(0xFF44474E);
  static const Color accentLightGreen = Color(0xFFA6F78E);

  @override
  void initState() {
    super.initState();
    _addListeners();
  }

  void _addListeners() {
    _totalYieldController.addListener(_calculateNetIncome);
    _pestLossController.addListener(_calculateNetIncome);
    _otherLossController.addListener(_calculateNetIncome);
    _grossIncomeController.addListener(_calculateNetIncome);
  }

  void _calculateNetIncome() {
    _totalYield = double.tryParse(_totalYieldController.text) ?? 0.0;
    _pestLoss = double.tryParse(_pestLossController.text) ?? 0.0;
    _otherLoss = double.tryParse(_otherLossController.text) ?? 0.0;
    _grossIncome = double.tryParse(_grossIncomeController.text) ?? 0.0;
    
    final totalLossValue = (_totalYield * (_pestLoss / 100)) + _otherLoss;
    _calculatedNetIncome = _grossIncome - totalLossValue;
    
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _cycleNameController.dispose();
    _cropTypeController.dispose();
    _varietyController.dispose();
    _locationController.dispose();
    _areaController.dispose();
    _totalYieldController.dispose();
    _pestLossController.dispose();
    _otherLossController.dispose();
    _grossIncomeController.dispose();
    super.dispose();
  }

  Future<void> _selectPlantingDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _plantingDate ?? DateTime.now().subtract(const Duration(days: 90)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _plantingDate = picked);
    }
  }

  Future<void> _selectHarvestDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _harvestDate ?? DateTime.now(),
      firstDate: _plantingDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _harvestDate = picked);
    }
  }

  Future<void> _openLocationPicker() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => LocationPickerModal(
        initialLocation: _selectedLocation,
        initialLatitude: _latitude,
        initialLongitude: _longitude,
      ),
    );
    
    if (result != null && mounted) {
      setState(() {
        _selectedLocation = result['location'] ?? '';
        _latitude = result['latitude'];
        _longitude = result['longitude'];
        _locationController.text = _selectedLocation;
      });
    }
  }

  String _generateCycleName() {
    if (_cycleNameController.text.isNotEmpty) {
      return _cycleNameController.text;
    }
    
    final crop = _cropTypeController.text.isNotEmpty 
        ? _cropTypeController.text 
        : 'Crop';
    final year = DateFormat('yyyy').format(_harvestDate ?? DateTime.now());
    return '$crop Cycle $year';
  }

  Future<void> _savePreviousCycle() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_plantingDate == null) {
      _showSnackbar('Please select planting date');
      return;
    }
    
    if (_harvestDate == null) {
      _showSnackbar('Please select harvest date');
      return;
    }
    
    if (_harvestDate!.isBefore(_plantingDate!)) {
      _showSnackbar('Harvest date must be after planting date');
      return;
    }
    
    if (_selectedLocation.isEmpty) {
      _showSnackbar('Please select a location');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final cycleName = _generateCycleName();
      
      final cycleData = {
        'cycleName': cycleName,
        'customName': _cycleNameController.text.isNotEmpty ? _cycleNameController.text : null,
        'cropType': _cropTypeController.text,
        'fieldName': _selectedLocation,
        'area': double.tryParse(_areaController.text) ?? 0.0,
        'cropVariety': _varietyController.text,
        'plantingDate': Timestamp.fromDate(_plantingDate!),
        'harvestDate': Timestamp.fromDate(_harvestDate!),
        'isCompleted': true,
        'isPreviousCycle': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'totalYield': _totalYield,
        'pestLoss': _pestLoss,
        'otherLoss': _otherLoss,
        'grossIncome': _grossIncome,
        'netIncome': _calculatedNetIncome,
        'status': 'completed',
        'location': _selectedLocation,
        'latitude': _latitude,
        'longitude': _longitude,
      };

      // Add to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('cycles')
          .add(cycleData);
      
      // Also create a completed weeks document for the cycle
      await _createCompletedWeekData(docRef.id);
      
      if (mounted) {
        _showSnackbar('Previous cycle "$cycleName" recorded successfully!', isError: false);
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showSnackbar('Error saving cycle: $e');
      debugPrint('Error saving cycle: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _createCompletedWeekData(String cycleId) async {
    try {
      // Calculate number of weeks between planting and harvest
      final totalDays = _harvestDate!.difference(_plantingDate!).inDays;
      final totalWeeks = (totalDays / 7).ceil().clamp(1, 52);
      
      // Create week data for all weeks
      for (int weekIndex = 0; weekIndex < totalWeeks; weekIndex++) {
        final weekId = 'week_${weekIndex + 1}';
        final weekData = {
          'stations': List.generate(5, (i) => {
            'title': 'Station ${i + 1}',
            'completed': true,
            'plantsInspected': 100,
            'damaged': 0,
            'fawObserved': false,
            'eggMasses': 0,
            'larvae': 0,
            'pupae': 0,
            'notes': 'Previous cycle - automatically completed',
          }),
          'totals': {
            'damaged': 0,
            'eggs': 0,
            'larvae': 0,
            'pupae': 0,
          },
          'completedStations': 5,
          'isCompleted': true,
          'lastUpdated': FieldValue.serverTimestamp(),
        };
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('cycles')
            .doc(cycleId)
            .collection('weeks')
            .doc(weekId)
            .set(weekData);
      }
      
      debugPrint('Created $totalWeeks weeks of completed data for cycle');
    } catch (e) {
      debugPrint('Error creating week data: $e');
      // Don't throw - this is not critical for the main save
    }
  }

  void _showSnackbar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : primaryGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Record Previous Cycle',
          style: TextStyle(
            color: primaryGreen,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              _buildTabSwitcher(),
              const SizedBox(height: 24),
              _isCycleInfo ? _buildScreen1Content() : _buildScreen2Content(),
            ],
          ),
        ),
      ),
    );
  }

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

  Widget _buildScreen1Content() {
    return Column(
      children: [
        _buildCycleNameInput(),
        const SizedBox(height: 16),
        _buildLocationCard(),
        const SizedBox(height: 16),
        _buildInfoTile('CROP TYPE', _cropTypeController, Icons.spa_outlined, 
            hint: 'e.g., Corn, Rice, Wheat', 
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter crop type';
              }
              return null;
            }),
        const SizedBox(height: 16),
        _buildInfoTile('VARIETY', _varietyController, Icons.verified_outlined,
            hint: 'e.g., Hybrid 101, Local Variety',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter crop variety';
              }
              return null;
            }),
        const SizedBox(height: 16),
        _buildAreaInput(),
        const SizedBox(height: 16),
        _buildTimelineSection(),
        const SizedBox(height: 24),
        _buildAIRefinementNote(),
        const SizedBox(height: 32),
        _buildContinueButton(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildCycleNameInput() {
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
          const Text('CYCLE NAME (OPTIONAL)', 
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
          const SizedBox(height: 8),
          Text(
            'Leave empty to auto-generate from crop type and year',
            style: TextStyle(fontSize: 10, color: textSecondary.withOpacity(0.7)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.edit_note, color: primaryGreen),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _cycleNameController,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'e.g., 2024 Main Season Corn',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
          const Text('LOCATION CONTEXT', 
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryGreen, letterSpacing: 0.5)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _openLocationPicker,
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: accentLightGreen,
                  child: Icon(Icons.map_outlined, color: primaryGreen),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedLocation.isEmpty ? 'Tap to select location' : _selectedLocation,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _selectedLocation.isEmpty ? textSecondary : textPrimary,
                        ),
                      ),
                      if (_latitude != null && _longitude != null)
                        Text(
                          'Lat: ${_latitude!.toStringAsFixed(6)}, Lng: ${_longitude!.toStringAsFixed(6)}',
                          style: const TextStyle(color: textSecondary, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: primaryGreen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaInput() {
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
          const Text('FARM AREA (Hectares)', 
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.straighten, color: primaryGreen),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _areaController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'Enter farm area in hectares',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter farm area';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    if (double.parse(value) <= 0) {
                      return 'Area must be greater than 0';
                    }
                    return null;
                  },
                ),
              ),
              const Text('ha', style: TextStyle(fontWeight: FontWeight.bold, color: primaryGreen)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, TextEditingController controller, IconData icon, 
      {String? hint, String? Function(String?)? validator}) {
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
          Text(label, 
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(icon, color: primaryGreen),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: hint ?? 'Enter $label',
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  validator: validator,
                ),
              ),
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
          _buildDateEntry('PLANTING DATE', _plantingDate, _selectPlantingDate, required: true),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: primaryGreen,
              child: const Icon(Icons.arrow_downward, color: Colors.white, size: 16),
            ),
          ),
          _buildDateEntry('HARVEST DATE', _harvestDate, _selectHarvestDate, required: true),
        ],
      ),
    );
  }

  Widget _buildDateEntry(String label, DateTime? date, VoidCallback onTap, {bool required = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: required && date == null 
              ? Border.all(color: Colors.red.shade300, width: 1) 
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(label, 
                        style: const TextStyle(fontSize: 10, color: textSecondary, fontWeight: FontWeight.bold)),
                    if (required && date == null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(' *Required', 
                            style: TextStyle(fontSize: 9, color: Colors.red.shade300)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  date == null ? 'Select date' : DateFormat('MMMM d, yyyy').format(date),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: date == null ? textSecondary : textPrimary,
                  ),
                ),
              ],
            ),
            const Icon(Icons.calendar_today, color: primaryGreen, size: 20),
          ],
        ),
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

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          if (_formKey.currentState!.validate() && _selectedLocation.isNotEmpty) {
            setState(() => _isCycleInfo = false);
          } else {
            if (_selectedLocation.isEmpty) {
              _showSnackbar('Please select a location');
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Continue to Earnings', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildScreen2Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CYCLE SUMMARY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryGreen)),
        const SizedBox(height: 4),
        const Text('Harvest Performance', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textPrimary)),
        const SizedBox(height: 8),
        const Text('Capture the final financial metrics to complete this cultivation record.', 
            style: TextStyle(color: textSecondary, fontSize: 15)),
        const SizedBox(height: 24),
        _buildProductionMetrics(),
        const SizedBox(height: 20),
        _buildFinancialSummary(),
        const SizedBox(height: 32),
        _buildSaveButton(),
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
              const CircleAvatar(backgroundColor: Color(0xFFC2E8D7), child: Icon(Icons.agriculture, color: primaryGreen)),
              const SizedBox(width: 12),
              const Text('Production Metrics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          const Text('TOTAL YIELD (Tons)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildInputBox(_totalYieldController, 'tons', 
              hint: 'Enter total harvest yield',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter total yield';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              }),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildColumnInput('PEST LOSS (%)', _pestLossController, 
                  hint: 'Percentage of yield lost to pests')),
              const SizedBox(width: 16),
              Expanded(child: _buildColumnInput('OTHER LOSS (Tons)', _otherLossController,
                  hint: 'Loss due to other factors')),
            ],
          )
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
          const Text('GROSS INCOME (₱)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildInputBox(_grossIncomeController, null, prefix: '₱ ',
              hint: 'Enter gross income',
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter gross income';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid amount';
                }
                return null;
              }),
          const SizedBox(height: 20),
          const Text('CALCULATED NET INCOME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: primaryGreen, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₱ ${_calculatedNetIncome.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Text('AUTOMATED', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBox(TextEditingController controller, String? suffix, 
      {String? prefix, String? hint, TextInputType? keyboardType, String? Function(String?)? validator}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: surfaceGrey, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          if (prefix != null) Text(prefix, style: const TextStyle(fontSize: 16, color: textSecondary)),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType ?? TextInputType.number,
              style: const TextStyle(fontSize: 18, color: textSecondary),
              decoration: InputDecoration(
                hintText: hint ?? '0.00',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              validator: validator,
            ),
          ),
          if (suffix != null) Text(suffix, style: const TextStyle(fontWeight: FontWeight.bold, color: primaryGreen)),
        ],
      ),
    );
  }

  Widget _buildColumnInput(String label, TextEditingController controller, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: surfaceGrey, borderRadius: BorderRadius.circular(8)),
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 18, color: textSecondary),
            decoration: InputDecoration(
              hintText: hint ?? '0',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          ElevatedButton(
            onPressed: _isSaving ? null : _savePreviousCycle,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              minimumSize: const Size(double.infinity, 56),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Save Previous Cycle',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'This cycle will appear in the Completed tab',
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}