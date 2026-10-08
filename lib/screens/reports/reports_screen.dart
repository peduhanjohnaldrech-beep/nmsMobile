import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _api = ApiService();
  int _year = DateTime.now().year;
  String? _period;
  bool _loading = false;

  int _totalBene     = 0;
  int _totalAssessed = 0;
  Map<String, dynamic> _statusCounts = {};
  List<dynamic> _byBarangay = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = context.read<AuthProvider>().user;
    final brgy = user?.isScopedToBarangay == true ? user?.barangay : null;
    try {
      final result = await _api.getReportSummary(year: _year, period: _period, barangay: brgy);
      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        if (mounted) setState(() {
          _totalBene     = (data['total_bene']     ?? 0) as int;
          _totalAssessed = (data['total_assessed'] ?? 0) as int;
          _statusCounts  = Map<String, dynamic>.from(data['status_counts'] ?? {});
          _byBarangay    = List.from(data['by_barangay'] ?? []);
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suw    = (_statusCounts['SUW']    ?? 0) as int;
    final uw     = (_statusCounts['UW']     ?? 0) as int;
    final normal = (_statusCounts['Normal'] ?? 0) as int;
    final ow     = (_statusCounts['OW']     ?? 0) as int;
    final ob     = (_statusCounts['OB']     ?? 0) as int;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(icon: const Icon(Icons.assessment_outlined), tooltip: 'All Reports',
              onPressed: () => Navigator.pushNamed(context, '/reports/full')),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          // Filter
          Container(
            color: const Color(0xFF1565C0),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(children: [
              Expanded(child: _filterBox<int>(
                value: _year,
                hint: 'Year',
                items: [DateTime.now().year, DateTime.now().year - 1, DateTime.now().year - 2]
                    .map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                onChanged: (v) { if (v != null) setState(() => _year = v); _load(); },
              )),
              const SizedBox(width: 8),
              Expanded(child: _filterBox<String>(
                value: _period,
                hint: 'All Periods',
                items: const [
                  DropdownMenuItem(value: 'January', child: Text('January')),
                  DropdownMenuItem(value: 'July',    child: Text('July')),
                ],
                onChanged: (v) { setState(() => _period = v); _load(); },
              )),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Summary cards row
                          Row(children: [
                            _StatBox(label: 'Beneficiaries', value: _totalBene.toString(),     color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            _StatBox(label: 'Assessed',      value: _totalAssessed.toString(), color: Colors.teal),
                          ]),
                          const SizedBox(height: 12),
                          // Status breakdown
                          _SectionTitle('Nutritional Status'),
                          const SizedBox(height: 8),
                          Row(children: [
                            _StatusBox('SUW',    suw.toString(),    Colors.red),
                            const SizedBox(width: 8),
                            _StatusBox('UW',     uw.toString(),     Colors.orange),
                            const SizedBox(width: 8),
                            _StatusBox('Normal', normal.toString(), Colors.green),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            _StatusBox('Overweight', ow.toString(), Colors.amber.shade700),
                            const SizedBox(width: 8),
                            _StatusBox('Obese',      ob.toString(), Colors.purple),
                            const SizedBox(width: 8),
                            const Expanded(child: SizedBox()),
                          ]),
                          const SizedBox(height: 20),
                          // By barangay table
                          if (_byBarangay.isNotEmpty) ...[
                            _SectionTitle('By Barangay'),
                            const SizedBox(height: 8),
                            Card(
                              child: Column(children: [
                                // Header
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                  ),
                                  child: const Row(children: [
                                    Expanded(flex: 3, child: Text('Barangay', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                    Expanded(flex: 1, child: Text('Total', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                    Expanded(flex: 1, child: Text('SUW',   textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.red))),
                                    Expanded(flex: 1, child: Text('UW',    textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.orange))),
                                    Expanded(flex: 1, child: Text('Nml',   textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.green))),
                                  ]),
                                ),
                                ..._byBarangay.asMap().entries.map((e) {
                                  final r = e.value;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: e.key < _byBarangay.length - 1
                                          ? const Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))
                                          : null,
                                    ),
                                    child: Row(children: [
                                      Expanded(flex: 3, child: Text(r['barangay'] ?? '', style: const TextStyle(fontSize: 12))),
                                      Expanded(flex: 1, child: Text('${r['total'] ?? 0}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                                      Expanded(flex: 1, child: Text('${r['suw'] ?? 0}',   textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.red))),
                                      Expanded(flex: 1, child: Text('${r['uw'] ?? 0}',    textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.orange))),
                                      Expanded(flex: 1, child: Text('${r['normal'] ?? 0}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.green))),
                                    ]),
                                  );
                                }),
                              ]),
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pushNamed(context, '/reports/full'),
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text('View All Reports'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1565C0),
                                side: const BorderSide(color: Color(0xFF1565C0)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterBox<T>({T? value, required String hint, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged}) =>
    Container(
      height: 40, padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
      child: DropdownButton<T>(
        value: value, hint: Text(hint, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        items: items, onChanged: onChanged, isExpanded: true,
        underline: const SizedBox.shrink(),
        style: const TextStyle(color: Color(0xFFE8F4FD), fontSize: 13),
        dropdownColor: const Color(0xFF0D1B2E),
        icon: const Icon(Icons.expand_more, color: Colors.white70, size: 18),
      ),
    );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFFE8F4FD)));
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: const Color(0xFF8FA8BF))),
      ]),
    ),
  ));
}

class _StatusBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatusBox(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
    ]),
  ));
}
