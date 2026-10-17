import 'package:flutter/material.dart';
import '../../models/beneficiary_model.dart';
import '../../services/api_service.dart';
import '../../widgets/status_badge.dart';

class BeneficiaryFollowupScreen extends StatefulWidget {
  const BeneficiaryFollowupScreen({super.key});
  @override State<BeneficiaryFollowupScreen> createState() => _State();
}

class _State extends State<BeneficiaryFollowupScreen> {
  final _api = ApiService();
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;
  int _year = DateTime.now().year;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.getFollowupBeneficiaries(year: _year);
      if (res['success'] == true) {
        setState(() { _items = res['data']['beneficiaries'] ?? []; _loading = false; });
      } else {
        setState(() { _error = res['message']; _loading = false; });
      }
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  /// Returns overdue status for DSP children:
  /// 'overdue'   — 30+ days since last assessment (or never assessed since enrollment)
  /// 'due_soon'  — 25–29 days
  /// null        — not DSP or assessed recently
  String? _dspOverdueStatus(Map<String, dynamic> b) {
    if ((b['is_dsp'] as int? ?? 0) != 1) return null;
    final days = b['days_since_assessment'];
    if (days == null) {
      // Never assessed — check days since enrollment
      final enrolled = b['dsp_enrollment_date'] as String?;
      if (enrolled == null) return 'overdue';
      final enrollDate = DateTime.tryParse(enrolled);
      if (enrollDate == null) return null;
      final daysSince = DateTime.now().difference(enrollDate).inDays;
      if (daysSince >= 30) return 'overdue';
      if (daysSince >= 25) return 'due_soon';
      return null;
    }
    final d = int.tryParse(days.toString()) ?? 0;
    if (d >= 30) return 'overdue';
    if (d >= 25) return 'due_soon';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final overdueCount = _items.where((b) => _dspOverdueStatus(b) == 'overdue').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Follow-up List'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          DropdownButton<int>(
            value: _year,
            dropdownColor: const Color(0xFF1565C0),
            style: const TextStyle(color: Colors.white),
            underline: const SizedBox(),
            items: List.generate(5, (i) => DateTime.now().year - i)
                .map((y) => DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(color: Colors.white))))
                .toList(),
            onChanged: (v) { if (v != null) { setState(() => _year = v); _load(); } },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : Column(children: [
                  Container(
                    color: const Color(0x33FF9800),
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      const Icon(Icons.warning_amber, color: Color(0xFFFFB74D)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_items.length} beneficiaries need follow-up'
                          '${overdueCount > 0 ? ' • $overdueCount DSP overdue' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFCC80)),
                        ),
                      ),
                    ]),
                  ),
                  Expanded(
                    child: _items.isEmpty
                        ? const Center(child: Text('No follow-up needed'))
                        : ListView.builder(
                            itemCount: _items.length,
                            itemBuilder: (_, i) {
                              final b = _items[i];
                              final wfa  = b['nutritional_status'] as String? ?? '';
                              final wflh = b['wflh_status']       as String? ?? '';
                              final isDsp = (b['is_dsp'] as int? ?? 0) == 1;
                              final overdueStatus = _dspOverdueStatus(b);

                              return ListTile(
                                leading: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (wfa.isNotEmpty) StatusBadge(status: wfa),
                                    if (wflh.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      StatusBadge(status: wflh),
                                    ],
                                  ],
                                ),
                                title: Row(
                                  children: [
                                    Expanded(child: Text('${b['last_name']}, ${b['first_name']}')),
                                    if (isDsp) ...[
                                      const SizedBox(width: 4),
                                      _dspBadge(overdueStatus),
                                    ],
                                  ],
                                ),
                                subtitle: Text('${b['barangay']} • ${b['assessment_date'] ?? 'No assessment'} • ${b['weight_kg'] ?? '—'} kg'),
                                trailing: b['contact_number'] != null
                                    ? const Icon(Icons.phone, color: Colors.green)
                                    : const Icon(Icons.chevron_right, color: Color(0xFF616161)),
                                onTap: () async {
                                  final nav = Navigator.of(context);
                                  final res = await _api.getBeneficiary(b['id'] as int);
                                  if (!mounted) return;
                                  if (res['success'] == true) {
                                    final bene = BeneficiaryModel.fromJson(
                                      (res['data']['beneficiary'] as Map<String, dynamic>));
                                    nav.pushNamed('/beneficiaries/detail', arguments: bene);
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ]),
    );
  }

  Widget _dspBadge(String? overdueStatus) {
    if (overdueStatus == 'overdue') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
        child: const Text('DSP Overdue', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      );
    }
    if (overdueStatus == 'due_soon') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
        child: const Text('DSP Due Soon', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.blue[700], borderRadius: BorderRadius.circular(4)),
      child: const Text('DSP', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
