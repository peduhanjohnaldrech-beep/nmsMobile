import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';

class ReportsFullScreen extends StatefulWidget {
  const ReportsFullScreen({super.key});
  @override State<ReportsFullScreen> createState() => _State();
}

class _State extends State<ReportsFullScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabs;

  int    _year    = DateTime.now().year;
  String _period  = '';
  int    _year1   = DateTime.now().year - 1;
  int    _year2   = DateTime.now().year;

  Map<String, dynamic> _opt        = {};
  Map<String, dynamic> _dsp        = {};
  Map<String, dynamic> _mns        = {};
  Map<String, dynamic> _outcome    = {};
  Map<String, dynamic> _comparison = {};
  bool _loading = false;

  static const _blue     = Color(0xFF1565C0);
  static const _darkBg   = Color(0xFF060D1F);
  static const _cardBg   = Color(0xFF0B1527);
  static const _textMain = Color(0xFFE8F4FD);
  static const _textSub  = Color(0xFF8FA8BF);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _loadAll();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final user = context.read<AuthProvider>().user;
    final brgy = user?.isScopedToBarangay == true ? user?.barangay : null;
    final results = await Future.wait([
      _safe(_api.getReportOpt(year: _year, period: _period.isEmpty ? null : _period, barangay: brgy)),
      _safe(_api.getReportDsp(year: _year, barangay: brgy)),
      _safe(_api.getReportMns(year: _year, barangay: brgy)),
      _safe(_api.getReportOutcome(year: _year, barangay: brgy)),
      _safe(_api.getReportComparison(year1: _year1, year2: _year2, barangay: brgy)),
    ]);
    if (mounted) setState(() {
      _opt        = results[0]['data'] as Map<String, dynamic>? ?? {};
      _dsp        = results[1]['data'] as Map<String, dynamic>? ?? {};
      _mns        = results[2]['data'] as Map<String, dynamic>? ?? {};
      _outcome    = results[3]['data'] as Map<String, dynamic>? ?? {};
      _comparison = results[4]['data'] as Map<String, dynamic>? ?? {};
      _loading = false;
    });
  }

  Future<Map<String, dynamic>> _safe(Future<Map<String, dynamic>> f) async {
    try { return await f; } catch (_) { return {'success': false, 'data': {}}; }
  }

  // ── Export ──────────────────────────────────────────────────────────────────
  Future<void> _export(String type, String format) async {
    final user = context.read<AuthProvider>().user;
    final brgy = user?.isScopedToBarangay == true ? user?.barangay : null;

    _showSnack('Preparing export…', Colors.blue.shade700);

    final bytes = await _api.downloadReportExport(
      type:      type,
      format:    format,
      year:      _year,
      period:    _period.isEmpty ? null : _period,
      barangay:  brgy,
    );

    if (!mounted) return;
    if (bytes == null) { _showSnack('Export failed', Colors.red.shade700); return; }

    final ext      = format == 'excel' ? 'xlsx' : 'csv';
    final tmpDir   = await getTemporaryDirectory();
    final filename = '${type}_report_$_year.$ext';
    final file     = File('${tmpDir.path}/$filename');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: format == 'excel' ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' : 'text/csv')],
      subject: '${type.toUpperCase()} Report $_year',
    );
  }

  void _showExportSheet(List<_ExportOption> options) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Export Report', style: TextStyle(color: _textMain, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          ...options.map((o) => ListTile(
            leading: Icon(o.icon, color: o.color),
            title: Text(o.label, style: const TextStyle(color: _textMain)),
            subtitle: Text(o.sub, style: const TextStyle(color: _textSub, fontSize: 12)),
            onTap: () { Navigator.pop(context); _export(o.type, o.format); },
          )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final years = List.generate(5, (i) => DateTime.now().year - i);
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        title: const Text('Full Reports'),
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        actions: [
          DropdownButton<int>(
            value: _year,
            dropdownColor: _blue,
            underline: const SizedBox(),
            style: const TextStyle(color: Colors.white),
            items: years.map((y) => DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(color: Colors.white)))).toList(),
            onChanged: (v) { if (v != null) { setState(() => _year = v); _loadAll(); } },
          ),
          DropdownButton<String>(
            value: _period.isEmpty ? 'All' : _period,
            dropdownColor: _blue,
            underline: const SizedBox(),
            style: const TextStyle(color: Colors.white),
            items: ['All', 'January', 'July'].map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(color: Colors.white)))).toList(),
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
              _optTab(),
              _dspTab(),
              _mnsTab(),
              _outcomeTab(),
              _comparisonTab(),
            ]),
    );
  }

  // ── OPT Tab ──────────────────────────────────────────────────────────────────
  Widget _optTab() {
    final counts = Map<String, dynamic>.from(_opt['counts'] ?? {});
    final bySex  = Map<String, dynamic>.from(_opt['by_sex'] ?? {});
    final total  = (_opt['total'] ?? 0) as int;

    return ListView(padding: const EdgeInsets.all(16), children: [
      _exportBar('OPT Report', [
        _ExportOption('opt', 'csv',   Icons.table_chart_outlined, Colors.green, 'OPT (CSV)', 'Opens in Excel/Sheets'),
        _ExportOption('opt', 'excel', Icons.description_outlined, Colors.green.shade700, 'OPT (Excel)', 'Formatted .xlsx file'),
      ]),
      const SizedBox(height: 12),

      _sectionTitle('OPT Summary — $_year${_period.isNotEmpty ? ' · $_period' : ''}'),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 3, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.0,
        children: [
          _statBox('Total',      total,                    Colors.blue),
          _statBox('Normal',     counts['Normal'] ?? 0,    Colors.green),
          _statBox('UW',         counts['UW'] ?? 0,        Colors.orange),
          _statBox('SUW',        counts['SUW'] ?? 0,       Colors.red),
          _statBox('Overweight', counts['OW'] ?? 0,        Colors.purple),
          _statBox('Obese',      counts['OB'] ?? 0,        Colors.deepPurple),
        ],
      ),

      if (total > 0) ...[
        const SizedBox(height: 4),
        _malnutRate(counts, total),
      ],

      const SizedBox(height: 16),
      _sectionTitle('By Sex'),
      const SizedBox(height: 8),
      Row(children: ['Male', 'Female'].map((sex) {
        final s = Map<String, dynamic>.from((bySex[sex] ?? {}) as Map);
        final t = s.values.fold(0, (a, b) => a + (b as int));
        return Expanded(child: _infoCard(
          sex,
          sex == 'Male' ? Colors.blue : Colors.pink,
          sex == 'Male' ? Icons.male_rounded : Icons.female_rounded,
          children: ['Normal','UW','SUW','OW','OB'].map((st) => _statusRow(st, s[st] ?? 0, t)).toList(),
        ));
      }).toList()),

      const SizedBox(height: 80),
    ]);
  }

  Widget _malnutRate(Map counts, int total) {
    final malnut = (counts['SUW'] ?? 0) + (counts['UW'] ?? 0);
    final rate   = total > 0 ? (malnut / total * 100) : 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.withValues(alpha: 0.3))),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
        const SizedBox(width: 8),
        Text('Malnutrition Rate: ${rate.toStringAsFixed(1)}%  ($malnut of $total assessed)',
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }

  // ── DSP Tab ──────────────────────────────────────────────────────────────────
  Widget _dspTab() {
    final totals  = Map<String, dynamic>.from(_dsp['totals'] ?? {});
    final byBrgy  = List.from(_dsp['by_barangay'] ?? []);
    final byInter = Map<String, dynamic>.from(_dsp['by_intervention'] ?? {});
    final avgGain = _dsp['avg_weight_gain'];

    return ListView(padding: const EdgeInsets.all(16), children: [
      _exportBar('DSP Report', [
        _ExportOption('dsp', 'csv',   Icons.table_chart_outlined,  Colors.blue, 'DSP Enrollments (CSV)', 'Full enrollment list'),
        _ExportOption('dsp', 'excel', Icons.description_outlined,  Colors.blue.shade700, 'DSP Enrollments (Excel)', 'Formatted .xlsx file'),
      ]),
      const SizedBox(height: 12),

      _sectionTitle('DSP Summary — $_year'),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _statBox2('Total',     totals['total']     ?? 0, Colors.blue)),
        const SizedBox(width: 8),
        Expanded(child: _statBox2('Active',    totals['active']    ?? 0, Colors.green)),
        const SizedBox(width: 8),
        Expanded(child: _statBox2('Completed', totals['completed'] ?? 0, Colors.teal)),
        const SizedBox(width: 8),
        Expanded(child: _statBox2('Dropped',   totals['dropped']   ?? 0, Colors.red)),
      ]),

      if (avgGain != null) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.teal.withValues(alpha: 0.3))),
          child: Row(children: [
            const Icon(Icons.trending_up_rounded, color: Colors.teal, size: 18),
            const SizedBox(width: 8),
            Text('Avg. Weight Gain (Completed): +${avgGain} kg',
                style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
        ),
      ],

      if (byInter.isNotEmpty) ...[
        const SizedBox(height: 16),
        _sectionTitle('By Intervention Type'),
        const SizedBox(height: 8),
        ...byInter.entries.map((e) => _barRow(e.key, e.value as int, totals['total'] ?? 1, _interventionColor(e.key))),
      ],

      if (byBrgy.isNotEmpty) ...[
        const SizedBox(height: 16),
        _sectionTitle('By Barangay'),
        const SizedBox(height: 8),
        _tableCard(
          headers: const ['Barangay', 'Active', 'Completed', 'Dropped', 'Total'],
          rows: byBrgy.map((r) => [
            r['barangay'] ?? '',
            '${r['active'] ?? 0}',
            '${r['completed'] ?? 0}',
            '${r['dropped'] ?? 0}',
            '${r['total'] ?? 0}',
          ]).toList(),
          colors: [null, Colors.green, Colors.teal, Colors.red, Colors.blue],
        ),
      ],

      const SizedBox(height: 80),
    ]);
  }

  Color _interventionColor(String key) {
    if (key.toUpperCase().contains('RUTF')) return Colors.red;
    if (key.toLowerCase().contains('supplementary')) return Colors.orange;
    return Colors.blue;
  }

  // ── MNS Tab ──────────────────────────────────────────────────────────────────
  Widget _mnsTab() {
    final vitaTotal   = (_mns['vitamin_a'] ?? 0) as int;
    final mnpTotal    = (_mns['mnp'] ?? 0) as int;
    final lnsTotal    = (_mns['lns_sq'] ?? 0) as int;
    final vitaByRound = Map<String, dynamic>.from(_mns['vita_by_round'] ?? {});
    final vitaByBrgy  = List.from(_mns['vita_by_barangay'] ?? []);
    final mnpByBrgy   = List.from(_mns['mnp_by_barangay'] ?? []);
    final lnsByBrgy   = List.from(_mns['lns_by_barangay'] ?? []);

    return ListView(padding: const EdgeInsets.all(16), children: [
      // Export options for all 3 MNS types
      _exportBar('MNS Report', [
        _ExportOption('mns_vita', 'csv',   Icons.vaccines_outlined,  Colors.orange, 'Vitamin A (CSV)', 'Full distribution list'),
        _ExportOption('mns_vita', 'excel', Icons.description_outlined, Colors.orange.shade700, 'Vitamin A (Excel)', '.xlsx file'),
        _ExportOption('mns_mnp',  'csv',   Icons.medication_outlined,  Colors.purple, 'MNP (CSV)', 'Micronutrient powder list'),
        _ExportOption('mns_lns',  'csv',   Icons.local_dining_outlined, Colors.teal, 'LNS-SQ (CSV)', 'Lipid-based supplement list'),
      ]),
      const SizedBox(height: 12),

      // Vitamin A
      _sectionTitle('Vitamin A — $_year'),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _statBox2('Total Doses', vitaTotal, Colors.orange)),
        const SizedBox(width: 8),
        Expanded(child: _statBox2('February', vitaByRound['February'] ?? 0, Colors.orange.shade300)),
        const SizedBox(width: 8),
        Expanded(child: _statBox2('August', vitaByRound['August'] ?? 0, Colors.orange.shade700)),
      ]),
      if (vitaByBrgy.isNotEmpty) ...[
        const SizedBox(height: 10),
        _tableCard(
          headers: const ['Barangay', 'Feb', 'Aug', 'Total'],
          rows: vitaByBrgy.map((r) => [r['barangay'] ?? '', '${r['february'] ?? 0}', '${r['august'] ?? 0}', '${r['total'] ?? 0}']).toList(),
          colors: [null, Colors.orange.shade300, Colors.orange.shade700, Colors.orange],
        ),
      ],

      // MNP
      const SizedBox(height: 16),
      _sectionTitle('MNP (Micronutrient Powder) — $_year'),
      const SizedBox(height: 8),
      _statBox2Wide('Total MNP Records', mnpTotal, Colors.purple),
      if (mnpByBrgy.isNotEmpty) ...[
        const SizedBox(height: 8),
        _tableCard(
          headers: const ['Barangay', 'Count'],
          rows: mnpByBrgy.map((r) => [r['barangay'] ?? '', '${r['cnt'] ?? 0}']).toList(),
          colors: [null, Colors.purple],
        ),
      ],

      // LNS-SQ
      const SizedBox(height: 16),
      _sectionTitle('LNS-SQ (Lipid-Based Supplement) — $_year'),
      const SizedBox(height: 8),
      _statBox2Wide('Total LNS-SQ Records', lnsTotal, Colors.teal),
      if (lnsByBrgy.isNotEmpty) ...[
        const SizedBox(height: 8),
        _tableCard(
          headers: const ['Barangay', 'Count'],
          rows: lnsByBrgy.map((r) => [r['barangay'] ?? '', '${r['cnt'] ?? 0}']).toList(),
          colors: [null, Colors.teal],
        ),
      ],

      const SizedBox(height: 80),
    ]);
  }

  // ── Outcome Tab ───────────────────────────────────────────────────────────────
  Widget _outcomeTab() {
    final byPeriod = Map<String, dynamic>.from(_outcome['by_period'] ?? {});
    const statuses = ['Normal', 'UW', 'SUW', 'OW', 'OB'];
    const colors   = [Colors.green, Colors.orange, Colors.red, Colors.purple, Colors.deepPurple];

    return ListView(padding: const EdgeInsets.all(16), children: [
      _sectionTitle('Period Outcome Summary — $_year'),
      const SizedBox(height: 12),
      if (byPeriod.isEmpty)
        _emptyState('No outcome data for $_year')
      else
        ...byPeriod.entries.map((entry) {
          final counts = Map<String, dynamic>.from(entry.value ?? {});
          final total  = counts.values.fold(0, (a, b) => a + (b as int));
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1E3050))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 4, height: 16, decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Text(entry.key, style: const TextStyle(color: _textMain, fontWeight: FontWeight.w700, fontSize: 14)),
                const Spacer(),
                Text('$total assessed', style: const TextStyle(color: _textSub, fontSize: 12)),
              ]),
              const SizedBox(height: 10),
              ...List.generate(statuses.length, (i) {
                final val = (counts[statuses[i]] ?? 0) as int;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    SizedBox(width: 64, child: Text(statuses[i], style: TextStyle(color: colors[i], fontSize: 12, fontWeight: FontWeight.w600))),
                    Expanded(child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total > 0 ? val / total : 0,
                        backgroundColor: colors[i].withValues(alpha: 0.1),
                        color: colors[i],
                        minHeight: 10,
                      ),
                    )),
                    const SizedBox(width: 8),
                    SizedBox(width: 36, child: Text('$val', style: TextStyle(color: colors[i], fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                    if (total > 0)
                      SizedBox(width: 44, child: Text(' ${(val/total*100).toStringAsFixed(0)}%', style: const TextStyle(color: _textSub, fontSize: 11), textAlign: TextAlign.right)),
                  ]),
                );
              }),
            ]),
          );
        }),
      const SizedBox(height: 80),
    ]);
  }

  // ── Comparison Tab ────────────────────────────────────────────────────────────
  Widget _comparisonTab() {
    final data     = Map<String, dynamic>.from(_comparison['data'] ?? {});
    final y1Data   = Map<String, dynamic>.from(data['$_year1'] ?? {});
    final y2Data   = Map<String, dynamic>.from(data['$_year2'] ?? {});
    const statuses = ['Normal', 'UW', 'SUW', 'OW', 'OB'];
    const colors   = [Colors.green, Colors.orange, Colors.red, Colors.purple, Colors.deepPurple];

    return ListView(padding: const EdgeInsets.all(16), children: [
      // Year selectors
      Row(children: [
        Expanded(child: _yearPicker('Year 1', _year1, (v) { setState(() => _year1 = v); _loadAll(); })),
        const SizedBox(width: 8),
        Expanded(child: _yearPicker('Year 2', _year2, (v) { setState(() => _year2 = v); _loadAll(); })),
      ]),
      const SizedBox(height: 16),

      _sectionTitle('Period Comparison: $_year1  →  $_year2'),
      const SizedBox(height: 8),

      // Summary totals
      Row(children: [
        Expanded(child: _statBox2('$_year1 Total', y1Data.values.fold(0, (a,b) => a+(b as int)), Colors.blue.shade300)),
        const SizedBox(width: 8),
        Expanded(child: _statBox2('$_year2 Total', y2Data.values.fold(0, (a,b) => a+(b as int)), Colors.blue)),
      ]),
      const SizedBox(height: 12),

      // Comparison table
      Container(
        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1E3050))),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: _blue.withValues(alpha: 0.2), borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
            child: Row(children: [
              const Expanded(flex: 2, child: Text('Status', style: TextStyle(color: _textMain, fontWeight: FontWeight.w700, fontSize: 12))),
              Expanded(flex: 2, child: Text('$_year1', textAlign: TextAlign.center, style: const TextStyle(color: _textMain, fontWeight: FontWeight.w700, fontSize: 12))),
              Expanded(flex: 2, child: Text('$_year2', textAlign: TextAlign.center, style: const TextStyle(color: _textMain, fontWeight: FontWeight.w700, fontSize: 12))),
              const Expanded(flex: 1, child: Text('±', textAlign: TextAlign.center, style: TextStyle(color: _textMain, fontWeight: FontWeight.w700, fontSize: 12))),
            ]),
          ),
          ...List.generate(statuses.length, (i) {
            final s    = statuses[i];
            final v1   = (y1Data[s] ?? 0) as int;
            final v2   = (y2Data[s] ?? 0) as int;
            final diff = v2 - v1;
            final isImprove = (s == 'Normal') ? diff > 0 : diff < 0;
            final diffColor = diff == 0 ? _textSub : (isImprove ? Colors.green : Colors.red);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                border: i < statuses.length - 1 ? const Border(bottom: BorderSide(color: Color(0xFF1E3050))) : null,
              ),
              child: Row(children: [
                Expanded(flex: 2, child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(s, style: TextStyle(color: colors[i], fontWeight: FontWeight.w600, fontSize: 13)),
                ])),
                Expanded(flex: 2, child: Text('$v1', textAlign: TextAlign.center, style: const TextStyle(color: _textMain, fontSize: 13))),
                Expanded(flex: 2, child: Text('$v2', textAlign: TextAlign.center, style: const TextStyle(color: _textMain, fontSize: 13))),
                Expanded(flex: 1, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(diff == 0 ? Icons.remove : (diff > 0 ? Icons.arrow_upward : Icons.arrow_downward), color: diffColor, size: 13),
                  Text('${diff.abs()}', style: TextStyle(color: diffColor, fontSize: 11, fontWeight: FontWeight.w700)),
                ])),
              ]),
            );
          }),
        ]),
      ),

      const SizedBox(height: 80),
    ]);
  }

  // ── Shared helpers ────────────────────────────────────────────────────────────

  Widget _exportBar(String title, List<_ExportOption> options) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: _blue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: _blue.withValues(alpha: 0.3))),
    child: Row(children: [
      const Icon(Icons.download_rounded, color: _blue, size: 18),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(color: _textMain, fontWeight: FontWeight.w600, fontSize: 13)),
      const Spacer(),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: _blue,
          side: const BorderSide(color: _blue),
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.ios_share_rounded, size: 15),
        label: const Text('Export', style: TextStyle(fontSize: 12)),
        onPressed: () => _showExportSheet(options),
      ),
    ]),
  );

  Widget _sectionTitle(String text) => Text(text,
    style: const TextStyle(color: _textMain, fontWeight: FontWeight.w700, fontSize: 14));

  Widget _statBox(String label, dynamic value, Color color) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 10, color: color), textAlign: TextAlign.center),
    ]),
  );

  Widget _statBox2(String label, dynamic value, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Column(children: [
      Text('$value', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
    ]),
  );

  Widget _statBox2Wide(String label, dynamic value, Color color) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Row(children: [
      Text('$value', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(width: 12),
      Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _infoCard(String title, Color color, IconData icon, {required List<Widget> children}) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
      const SizedBox(height: 8),
      ...children,
    ]),
  );

  Widget _statusRow(String status, int value, int total) {
    final pct = total > 0 ? (value / total * 100).toStringAsFixed(0) : '0';
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        SizedBox(width: 44, child: Text(status, style: const TextStyle(color: _textSub, fontSize: 11))),
        SizedBox(width: 28, child: Text('$value', style: const TextStyle(color: _textMain, fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
        Text(' ($pct%)', style: const TextStyle(color: _textSub, fontSize: 10)),
      ]),
    );
  }

  Widget _barRow(String label, int value, dynamic total, Color color) {
    final t   = (total is int ? total : 1);
    final pct = t > 0 ? value / t : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(width: 140, child: Text(label, style: const TextStyle(color: _textMain, fontSize: 12))),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: pct.clamp(0.0, 1.0), backgroundColor: color.withValues(alpha: 0.1), color: color, minHeight: 10),
        )),
        const SizedBox(width: 8),
        Text('$value', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _tableCard({required List<String> headers, required List<List<String>> rows, List<Color?>? colors}) {
    return Container(
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1E3050))),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: _blue.withValues(alpha: 0.15), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
          child: Row(children: List.generate(headers.length, (i) => Expanded(
            child: Text(headers[i], textAlign: i == 0 ? TextAlign.left : TextAlign.center,
                style: const TextStyle(color: _textMain, fontWeight: FontWeight.w700, fontSize: 11)),
          ))),
        ),
        ...rows.asMap().entries.map((entry) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: entry.key % 2 == 0 ? Colors.transparent : Colors.white.withValues(alpha: 0.02),
            border: entry.key < rows.length - 1 ? const Border(bottom: BorderSide(color: Color(0xFF1A2740), width: 0.5)) : null,
          ),
          child: Row(children: List.generate(headers.length, (i) {
            final col = (colors != null && i < colors.length) ? colors[i] : null;
            return Expanded(child: Text(entry.value[i],
              textAlign: i == 0 ? TextAlign.left : TextAlign.center,
              style: TextStyle(color: col ?? _textMain, fontSize: 12, fontWeight: i > 0 ? FontWeight.w600 : FontWeight.normal),
            ));
          })),
        )),
      ]),
    );
  }

  Widget _yearPicker(String label, int value, ValueChanged<int> onChanged) =>
    DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: _textSub), border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
      dropdownColor: _cardBg,
      style: const TextStyle(color: _textMain),
      items: List.generate(5, (i) => DateTime.now().year - i)
          .map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
      onChanged: (v) { if (v != null) onChanged(v); },
    );

  Widget _emptyState(String msg) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(msg, style: const TextStyle(color: _textSub, fontSize: 14)),
    ),
  );
}

class _ExportOption {
  final String type, format, label, sub;
  final IconData icon;
  final Color color;
  const _ExportOption(this.type, this.format, this.icon, this.color, this.label, this.sub);
}
