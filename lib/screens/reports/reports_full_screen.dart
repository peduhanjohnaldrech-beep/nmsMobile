import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class ReportsFullScreen extends StatefulWidget {
  const ReportsFullScreen({super.key});
  @override State<ReportsFullScreen> createState() => _State();
}

class _State extends State<ReportsFullScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabs;
  int _year = DateTime.now().year;
  String _period = '';
  int _year1 = DateTime.now().year - 1;
  int _year2 = DateTime.now().year;

  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _opt = {};
  Map<String, dynamic> _dsp = {};
  Map<String, dynamic> _mns = {};
  Map<String, dynamic> _outcome = {};
  Map<String, dynamic> _comparison = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _safe(Future<Map<String, dynamic>> f) async {
    try {
      return await f;
    } catch (_) {
      return {'success': false, 'data': {}};
    }
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _safe(_api.getReportSummary(year: _year, period: _period.isEmpty ? null : _period)),
      _safe(_api.getReportOpt(year: _year, period: _period.isEmpty ? null : _period)),
      _safe(_api.getReportDsp(year: _year)),
      _safe(_api.getReportMns(year: _year)),
      _safe(_api.getReportOutcome(year: _year)),
      _safe(_api.getReportComparison(year1: _year1, year2: _year2)),
    ]);
    if (mounted) setState(() {
      _summary    = results[0]['data'] ?? {};
      _opt        = results[1]['data'] ?? {};
      _dsp        = results[2]['data'] ?? {};
      _mns        = results[3]['data'] ?? {};
      _outcome    = results[4]['data'] ?? {};
      _comparison = results[5]['data'] ?? {};
      _loading = false;
    });
  }

  Widget _statBox(String label, dynamic value, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Column(children: [
      Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[700]), textAlign: TextAlign.center),
    ]),
  );

  // ── Summary ──────────────────────────────────────────────
  Widget _summaryTab() {
    final counts = Map<String, dynamic>.from(_summary['status_counts'] ?? {});
    final byBrgy = List.from(_summary['by_barangay'] ?? []);
    return ListView(padding: const EdgeInsets.all(16), children: [
      GridView.count(
        crossAxisCount: 3, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.1,
        children: [
          _statBox('Total\nBeneficiaries', _summary['total_bene'] ?? 0, Colors.blue),
          _statBox('Total\nAssessed',      _summary['total_assessed'] ?? 0, Colors.teal),
          _statBox('Normal',               counts['Normal'] ?? 0, Colors.green),
          _statBox('Underweight',          counts['UW'] ?? 0, Colors.orange),
          _statBox('Severely UW',          counts['SUW'] ?? 0, Colors.red),
          _statBox('Overweight',           counts['OW'] ?? 0, Colors.purple),
        ],
      ),
      const SizedBox(height: 16),
      const Text('By Barangay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 8),
      ...byBrgy.map((r) => Card(
        child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r['barangay'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total: ${r['total']}'),
            Text('Normal: ${r['normal']}', style: const TextStyle(color: Colors.green)),
            Text('UW: ${r['uw']}', style: const TextStyle(color: Colors.orange)),
            Text('SUW: ${r['suw']}', style: const TextStyle(color: Colors.red)),
          ]),
        ])),
      )).toList(),
    ]);
  }

  // ── OPT ──────────────────────────────────────────────────
  Widget _optTab() {
    final counts = Map<String, dynamic>.from(_opt['counts'] ?? {});
    final bySex  = Map<String, dynamic>.from(_opt['by_sex'] ?? {});
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('OPT Report $_year${_period.isNotEmpty ? ' – $_period' : ''}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 3, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.1,
        children: [
          _statBox('Total',       _opt['total'] ?? 0,    Colors.blue),
          _statBox('Normal',      counts['Normal'] ?? 0, Colors.green),
          _statBox('UW',          counts['UW'] ?? 0,     Colors.orange),
          _statBox('SUW',         counts['SUW'] ?? 0,    Colors.red),
          _statBox('Overweight',  counts['OW'] ?? 0,     Colors.purple),
          _statBox('Obese',       counts['OB'] ?? 0,     Colors.deepPurple),
        ],
      ),
      const SizedBox(height: 16),
      const Text('By Sex', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Row(children: ['Male', 'Female'].map((sex) => Expanded(
        child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sex, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            ...['Normal','UW','SUW','OW','OB'].map((s) =>
              Text('$s: ${(bySex[sex] ?? {})[s] ?? 0}')).toList(),
          ],
        ))),
      )).toList()),
    ]);
  }

  // ── DSP ──────────────────────────────────────────────────
  Widget _dspTab() {
    final totals = Map<String, dynamic>.from(_dsp['totals'] ?? {});
    final byBrgy = List.from(_dsp['by_barangay'] ?? []);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('DSP Report $_year', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _statBox('Total',     totals['total'] ?? 0,     Colors.blue)),
        const SizedBox(width: 8),
        Expanded(child: _statBox('Active',    totals['active'] ?? 0,    Colors.green)),
        const SizedBox(width: 8),
        Expanded(child: _statBox('Completed', totals['completed'] ?? 0, Colors.teal)),
        const SizedBox(width: 8),
        Expanded(child: _statBox('Dropped',   totals['dropped'] ?? 0,   Colors.red)),
      ]),
      const SizedBox(height: 16),
      ...byBrgy.map((r) => ListTile(
        title: Text(r['barangay'] ?? ''),
        trailing: Text('${r['status']}: ${r['cnt']}'),
      )).toList(),
    ]);
  }

  // ── MNS ──────────────────────────────────────────────────
  Widget _mnsTab() => ListView(padding: const EdgeInsets.all(16), children: [
    Text('MNS Report $_year', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: _statBox('Vitamin A\nDoses',  _mns['vitamin_a'] ?? 0, Colors.orange)),
      const SizedBox(width: 8),
      Expanded(child: _statBox('MNP\nRecords',      _mns['mnp'] ?? 0,       Colors.purple)),
      const SizedBox(width: 8),
      Expanded(child: _statBox('LNS-SQ\nRecords',   _mns['lns_sq'] ?? 0,    Colors.teal)),
    ]),
  ]);

  // ── Outcome ───────────────────────────────────────────────
  Widget _outcomeTab() {
    final byPeriod = Map<String, dynamic>.from(_outcome['by_period'] ?? {});
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Outcome Report $_year', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 12),
      ...byPeriod.entries.map((entry) => Card(
        child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ...['Normal','UW','SUW','OW','OB'].map((s) {
              final val = ((entry.value ?? {}) as Map)[s] ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  SizedBox(width: 70, child: Text(s)),
                  Expanded(child: LinearProgressIndicator(
                    value: val > 0 ? (val / 200.0).clamp(0.0, 1.0) : 0,
                    backgroundColor: Colors.grey[200],
                  )),
                  const SizedBox(width: 8),
                  Text('$val', style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
              );
            }).toList(),
          ],
        )),
      )).toList(),
    ]);
  }

  // ── Comparison ────────────────────────────────────────────
  Widget _comparisonTab() {
    final data = Map<String, dynamic>.from(_comparison['data'] ?? {});
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Expanded(child: DropdownButtonFormField<int>(
          value: _year1,
          decoration: const InputDecoration(labelText: 'Year 1', border: OutlineInputBorder()),
          items: List.generate(5, (i) => DateTime.now().year - i)
              .map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
          onChanged: (v) { if (v != null) setState(() => _year1 = v); },
        )),
        const SizedBox(width: 8),
        Expanded(child: DropdownButtonFormField<int>(
          value: _year2,
          decoration: const InputDecoration(labelText: 'Year 2', border: OutlineInputBorder()),
          items: List.generate(5, (i) => DateTime.now().year - i)
              .map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
          onChanged: (v) { if (v != null) setState(() => _year2 = v); },
        )),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _loadAll,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), minimumSize: const Size(50, 48)),
          child: const Text('Go', style: TextStyle(color: Colors.white)),
        ),
      ]),
      const SizedBox(height: 16),
      Table(
        border: TableBorder.all(color: const Color(0xFF1E3050)),
        columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1)},
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFF1565C0)),
            children: [
              _tableCell('Status', header: true),
              _tableCell('$_year1', header: true),
              _tableCell('$_year2', header: true),
            ],
          ),
          ...['Normal','UW','SUW','OW','OB'].map((s) => TableRow(children: [
            _tableCell(s),
            _tableCell('${(data['$_year1'] ?? {})[s] ?? 0}'),
            _tableCell('${(data['$_year2'] ?? {})[s] ?? 0}'),
          ])).toList(),
        ],
      ),
    ]);
  }

  Widget _tableCell(String text, {bool header = false}) => Padding(
    padding: const EdgeInsets.all(10),
    child: Text(text, style: TextStyle(
      color: header ? Colors.white : const Color(0xFFE8F4FD),
      fontWeight: header ? FontWeight.bold : FontWeight.normal,
    )),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
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
            onChanged: (v) { if (v != null) { setState(() => _year = v); _loadAll(); } },
          ),
          DropdownButton<String>(
            value: _period.isEmpty ? 'All' : _period,
            dropdownColor: const Color(0xFF1565C0),
            style: const TextStyle(color: Colors.white),
            underline: const SizedBox(),
            items: ['All','January','July'].map((p) => DropdownMenuItem(
              value: p,
              child: Text(p, style: const TextStyle(color: Colors.white)),
            )).toList(),
            onChanged: (v) { setState(() => _period = v == 'All' ? '' : v!); _loadAll(); },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'OPT'),
            Tab(text: 'DSP'),
            Tab(text: 'MNS'),
            Tab(text: 'Outcome'),
            Tab(text: 'Comparison'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabs, children: [
              _summaryTab(),
              _optTab(),
              _dspTab(),
              _mnsTab(),
              _outcomeTab(),
              _comparisonTab(),
            ]),
    );
  }
}
