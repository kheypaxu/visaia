import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class HarvestRecordingScreen extends StatefulWidget {
  final String cycleId;
  final String userId;
  final bool isEarlyHarvest;
  final int? daysEarly;

  const HarvestRecordingScreen({
    super.key, 
    required this.cycleId,
    required this.userId,
    this.isEarlyHarvest = false,
    this.daysEarly,
  });

  @override
  State<HarvestRecordingScreen> createState() => _HarvestRecordingScreenState();
}

class _HarvestRecordingScreenState extends State<HarvestRecordingScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _cycleData;
  
  // Controllers
  final TextEditingController _actualYieldController = TextEditingController();
  final TextEditingController _damagedYieldController = TextEditingController();
  final TextEditingController _marketPriceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  double _calculatedValue = 0.0;
  double _lossRate = 0.0;
  
  // Early harvest reason
  String _earlyHarvestReason = '';

  @override
  void initState() {
    super.initState();
    _loadCycleData();
    _addListeners();
  }

  void _addListeners() {
    _actualYieldController.addListener(_calculateMetrics);
    _damagedYieldController.addListener(_calculateMetrics);
    _marketPriceController.addListener(_calculateMetrics);
  }

  void _calculateMetrics() {
    final actualYield = double.tryParse(_actualYieldController.text) ?? 0;
    final damagedYield = double.tryParse(_damagedYieldController.text) ?? 0;
    final marketPrice = double.tryParse(_marketPriceController.text) ?? 0;
    
    _calculatedValue = (actualYield - damagedYield) * marketPrice;
    _lossRate = actualYield > 0 ? (damagedYield / actualYield) * 100 : 0;
    
    setState(() {});
  }

  Future<void> _loadCycleData() async {
    try {
      DocumentSnapshot<Map<String, dynamic>> cycleDoc;
      try {
        cycleDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('cycles')
            .doc(widget.cycleId)
            .get();
      } catch (_) {
        cycleDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('cycles')
            .doc(widget.cycleId)
            .get(const GetOptions(source: Source.cache));
      }
      
      if (cycleDoc.exists) {
        final data = cycleDoc.data();
        
        // Check if already harvested
        if (data?['isCompleted'] == true) {
          if (mounted) {
            _showAlreadyHarvestedDialog();
          }
          return;
        }
        
        setState(() {
          _cycleData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading cycle: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showAlreadyHarvestedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Already Harvested'),
        content: const Text(
          'This cycle has already been harvested and completed.\n\n'
          'You cannot record another harvest for this cycle.'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Go Back', style: TextStyle(color: Color(0xFF1B5E37))),
          ),
        ],
      ),
    );
  }

  Future<void> _saveHarvestData() async {
    if (!_validateForm()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final actualYield = double.tryParse(_actualYieldController.text) ?? 0;
      final damagedYield = double.tryParse(_damagedYieldController.text) ?? 0;
      final marketPrice = double.tryParse(_marketPriceController.text) ?? 0;
      final goodYield = actualYield - damagedYield;
      final totalValue = goodYield * marketPrice;
      
      final harvestData = {
        'actualYield': actualYield,
        'damagedYield': damagedYield,
        'goodYield': goodYield,
        'marketPrice': marketPrice,
        'totalValue': totalValue,
        'lossRate': _lossRate,
        'harvestNotes': _notesController.text,
        'actualHarvestDate': FieldValue.serverTimestamp(),
        'expectedHarvestDate': _cycleData?['harvestDate'],
        'isEarlyHarvest': widget.isEarlyHarvest,
        if (widget.isEarlyHarvest && _earlyHarvestReason.isNotEmpty) 
          'earlyHarvestReason': _earlyHarvestReason,
        if (widget.isEarlyHarvest && widget.daysEarly != null)
          'daysEarly': widget.daysEarly,
        'harvestCompletedAt': FieldValue.serverTimestamp(),
        'status': 'harvested',
        'isCompleted': true,
        'completedAt': FieldValue.serverTimestamp(),
      };
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('cycles')
          .doc(widget.cycleId)
          .update(harvestData);
      
      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool _validateForm() {
    if (_actualYieldController.text.isEmpty) {
      _showSnackbar('Please enter actual yield');
      return false;
    }
    if (_damagedYieldController.text.isEmpty) {
      _showSnackbar('Please enter damaged yield');
      return false;
    }
    if (_marketPriceController.text.isEmpty) {
      _showSnackbar('Please enter market price');
      return false;
    }
    if (widget.isEarlyHarvest && _earlyHarvestReason.isEmpty) {
      _showSnackbar('Please select a reason for early harvest');
      return false;
    }
    return true;
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Harvest Recorded Successfully!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isEarlyHarvest)
              const Text(
                'Early harvest has been recorded.',
                style: TextStyle(color: Color(0xFFE65100)),
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('Total Value', '₱${_calculatedValue.toStringAsFixed(2)}'),
                  const SizedBox(height: 4),
                  _buildSummaryRow('Loss Rate', '${_lossRate.toStringAsFixed(1)}%'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, true); // Return to cycle details
            },
            child: const Text('Done', style: TextStyle(color: Color(0xFF1B5E37))),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text('Failed to save harvest data: $error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _actualYieldController.dispose();
    _damagedYieldController.dispose();
    _marketPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9F8),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF1B5E37))),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9F8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1B5E37)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'Harvest Recording',
          style: TextStyle(
            color: Color(0xFF1B5E37),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Record Harvest',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1C1E),
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Finalize ${_cycleData?['cycleName'] ?? 'cycle'} and log final yield metrics.',
              style: const TextStyle(color: Colors.black54, fontSize: 16),
            ),
            if (widget.isEarlyHarvest) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF9800)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Color(0xFFFF9800)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Early Harvest: You are harvesting before the expected date. Please provide a reason below.',
                        style: TextStyle(color: Color(0xFFE65100)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            _buildSummaryCard(),
            const SizedBox(height: 24),
            _buildFormSection(),
            if (widget.isEarlyHarvest) ...[
              const SizedBox(height: 16),
              _buildEarlyHarvestReasonSelector(),
            ],
            const SizedBox(height: 32),
            _buildSaveButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildEarlyHarvestReasonSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reason for Early Harvest *',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Color(0xFFE65100),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonFormField<String>(
              value: _earlyHarvestReason.isEmpty ? null : _earlyHarvestReason,
              hint: const Text('Select reason for early harvest'),
              decoration: const InputDecoration(
                border: InputBorder.none,
              ),
              items: const [
                DropdownMenuItem(value: 'Pest/Disease Outbreak', child: Text('Pest/Disease Outbreak')),
                DropdownMenuItem(value: 'Weather Damage', child: Text('Weather Damage')),
                DropdownMenuItem(value: 'Market Opportunity', child: Text('Market Opportunity')),
                DropdownMenuItem(value: 'Early Maturity', child: Text('Early Maturity')),
                DropdownMenuItem(value: 'Crop Failure', child: Text('Crop Failure')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (value) {
                setState(() {
                  _earlyHarvestReason = value ?? '';
                });
              },
            ),
          ),
          if (_earlyHarvestReason == 'Other')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Please specify',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  _earlyHarvestReason = value;
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final actualYield = double.tryParse(_actualYieldController.text) ?? 0;
    final damagedYield = double.tryParse(_damagedYieldController.text) ?? 0;
    final goodYield = actualYield - damagedYield;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Harvest Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetric('Good Yield', '${goodYield.toStringAsFixed(0)} kg', const Color(0xFF16A34A)),
              _buildMetric('Loss Rate', '${_lossRate.toStringAsFixed(1)}%', const Color(0xFFDC2626), alignEnd: true),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFF1F3F1)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Value', style: TextStyle(fontWeight: FontWeight.w600)),
              Text(
                '₱${_calculatedValue.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B5E37),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color valueColor, {bool alignEnd = false}) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey, 
            fontSize: 11, 
            fontWeight: FontWeight.w700, 
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20, 
            fontWeight: FontWeight.w900, 
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildFormSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFD1E8B9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputField('Actual Yield', _actualYieldController, 'kg'),
          const SizedBox(height: 16),
          _buildInputField('Damaged Yield', _damagedYieldController, 'kg'),
          const SizedBox(height: 16),
          _buildInputField('Market Price per Unit', _marketPriceController, '₱/kg'),
          const SizedBox(height: 24),
          const Text(
            'Harvest Notes (Optional)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _notesController,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: 'Add conditions, issues, or quality notes...',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Text(unit, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E37),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: _isSaving ? null : _saveHarvestData,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isSaving)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              else
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                _isSaving ? 'Saving...' : 'Save Harvest Data',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}