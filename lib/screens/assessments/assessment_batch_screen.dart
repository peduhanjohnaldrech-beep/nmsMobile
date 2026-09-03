import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';

class AssessmentBatchScreen extends StatefulWidget {
  const AssessmentBatchScreen({super.key});
  @override State<AssessmentBatchScreen> createState() => _State();
}

class _State extends State<AssessmentBatchScreen> {
  final _api = ApiService();

  List<Map<String, dynamic>> _beneficiaries = [];
  // Controllers keyed by beneficiary id
  final Map<int, TextEditingController> _weightCtrl  = {};
  final Map<int, TextEditingController> _heightCtrl  = {};
  final Map<int, TextEditingController> _muacCtrl    = {};

  bool   _loading   = false;
  bool   _submitting = false;
  String _barangay  = '';

  // Auto-detect period from current month
  late String _period;
  late int    _year;
  late String _date;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _period = now.month <= 6 ? 'January' : 'July';
    _year   = now.year;
    _date   = now.toIso8601String().substring(0, 10);
    _loadBeneficiaries();
  }

  @override
  void dispose() {
    for (final c in _weightCtrl.values) c.dispose();
    for (final c in _heightCtrl.values) c.dispose();
    for (final c in _muacCtrl.values)   c.dispose();
    super.dispose();
  }

  Future<void> _loadBeneficiaries() async {
    setState(() => _loading = true);
    try {
      final user = context.read<AuthProvider>().user;
      _barangay  = user?.barangay ?? '';
      final res  = await _api.getBeneficiaries(
        barangay: _barangay,
        perPage: 500,
        validatedOnly: true,
      );
      if (res['success'] == true) {
        final list = List<Map<String, dynamic>>.from(
            res['data']['beneficiaries'] ?? []);
        setState(() {
          _beneficiaries = list;
          for (final b in list) {
            final id = b['id'] as int;
            _weightCtrl[id] = TextEditingController();
            _heightCtrl[id] = TextEditingController();
            _muacCtrl[id]   = TextEditingController();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load: $e'), backgroundColor: Colors.red));
      }
    }
    setState(() => _loading = false);
  }

  int get _filledCount =>
      _weightCtrl.values.where((c) => c.text.trim().isNotEmpty).length;

  Future<void> _submit() async {
    final entries = <Map<String, dynamic>>[];
    for (final b in _beneficiaries) {
      final id = b['id'] as int;
      final w  = double.tryParse(_weightCtrl[id]?.text.trim() ?? '');
      if (w == null || w <= 0) continue;
      entries.add({
        'beneficiary_id':   id,
        'assessment_date':  _date,
        'weight_kg':        w,
        if ((_heightCtrl[id]?.text.trim() ?? '').isNotEmpty)
          'height_cm': double.tryParse(_heightCtrl[id]!.text.trim()),
        if ((_muacCtrl[id]?.text.trim() ?? '').isNotEmpty)
          'muac_cm': double.tryParse(_muacCtrl[id]!.text.trim()),
        'period':           _period,
        'assessment_year':  _year,
      });
    }

    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter at least one weight')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Assessments'),
        content: Text(
            'Submit ${entries.length} weight record(s) for $_period $_year?\n\nThey will be sent to the midwife for validation.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
            child: const Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _submitting = true);
    final res = await _api.batchAssessments(entries);
    setState(() => _submitting = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Done'),
          backgroundColor: res['success'] == true ? Colors.green : Colors.red,
        ));
    if (res['success'] == true) {
      // Clear all entries
      for (final c in _weightCtrl.values) c.clear();
      for (final c in _heightCtrl.values) c.clear();
      for (final c in _muacCtrl.values)   c.clear();
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('OPT Batch Weighing'),
          Text('$_period $_year • $_barangay',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
        ]),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          if (_submitting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _submit,
              child: Text(
                'SUBMIT${_filledCount > 0 ? ' ($_filledCount)' : ''}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      resizeToAvoidBottomInset: false,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _beneficiaries.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('No beneficiaries found'),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _loadBeneficiaries, child: const Text('Retry')),
                  ]),
                )
              : Column(children: [
                  // Period selector bar
                  Container(
                    color: const Color(0xFFE3F2FD),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(children: [
                      const Icon(Icons.calendar_month, size: 16, color: Color(0xFF1565C0)),
                      const SizedBox(width: 8),
                      const Text('Period: ', style: TextStyle(fontWeight: FontWeight.w600)),
                      DropdownButton<String>(
                        value: _period,
                        underline: const SizedBox(),
                        isDense: true,
                        items: ['January', 'July'].map((p) =>
                            DropdownMenuItem(value: p, child: Text(p))).toList(),
                        onChanged: (v) => setState(() => _period = v!),
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<int>(
                        value: _year,
                        underline: const SizedBox(),
                        isDense: true,
                        items: List.generate(4, (i) => DateTime.now().year - i).map((y) =>
                            DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                        onChanged: (v) => setState(() => _year = v!),
                      ),
                      const Spacer(),
                      Text('${_beneficiaries.length} children',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ]),
                  ),
                  // Progress bar
                  if (_filledCount > 0)
                    LinearProgressIndicator(
                      value: _filledCount / _beneficiaries.length,
                      backgroundColor: Colors.grey[200],
                      color: const Color(0xFF1565C0),
                    ),
                  // List
                  Expanded(
                    child: ListView.builder(
                      itemCount: _beneficiaries.length,
                      itemBuilder: (_, i) {
                        final b  = _beneficiaries[i];
                        final id = b['id'] as int;
                        final hasWeight = _weightCtrl[id]?.text.trim().isNotEmpty ?? false;
                        final ageMonths = _calcAge(b['date_of_birth']);

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          elevation: hasWeight ? 2 : 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: hasWeight ? const Color(0xFF1565C0) : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: hasWeight
                                      ? const Color(0xFF1565C0)
                                      : Colors.grey[300],
                                  child: Text(
                                    hasWeight ? '✓' : '${i + 1}',
                                    style: TextStyle(
                                      color: hasWeight ? Colors.white : Colors.grey[600],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${b['last_name']}, ${b['first_name']}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '$ageMonths months • ${b['sex'] ?? ''} • ${b['barangay'] ?? ''}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  ],
                                )),
                              ]),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _weightCtrl[id],
                                    decoration: const InputDecoration(
                                      labelText: 'Weight (kg) *',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _heightCtrl[id],
                                    decoration: const InputDecoration(
                                      labelText: 'Height (cm)',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _muacCtrl[id],
                                    decoration: const InputDecoration(
                                      labelText: 'MUAC',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                  ),
                                ),
                              ]),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                ]),
      // FAB to submit
      floatingActionButton: _filledCount > 0
          ? FloatingActionButton.extended(
              onPressed: _submit,
              backgroundColor: const Color(0xFF1565C0),
              icon: const Icon(Icons.send, color: Colors.white),
              label: Text(
                'Submit $_filledCount record${_filledCount != 1 ? 's' : ''}',
                style: const TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }

  int _calcAge(String? dob) {
    if (dob == null) return 0;
    try {
      final birth = DateTime.parse(dob);
      final now   = DateTime.now();
      return (now.year - birth.year) * 12 + now.month - birth.month;
    } catch (_) { return 0; }
  }
}
