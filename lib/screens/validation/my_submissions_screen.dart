import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/beneficiary_model.dart';

class MySubmissionsScreen extends StatefulWidget {
  /// When true, loads all area submissions (midwife view).
  /// When false (default), loads only the current user's submissions (BHW view).
  final bool viewAll;
  const MySubmissionsScreen({super.key, this.viewAll = false});
  @override State<MySubmissionsScreen> createState() => _State();
}

class _State extends State<MySubmissionsScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabs;

  List<dynamic> _assessments    = [];
  List<dynamic> _beneficiaries  = [];
  List<dynamic> _dspMonitoring  = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        widget.viewAll ? _api.getAllAreaSubmissions() : _api.getMySubmissions(),
        widget.viewAll ? _api.getAllAreaBeneficiarySubmissions() : _api.getMyBeneficiarySubmissions(),
        _api.getMyDspMonitoring(),
      ]);
      if (!mounted) return;
      setState(() {
        _assessments   = results[0]['data']?['assessments']   ?? [];
        _beneficiaries = results[1]['data']?['beneficiaries'] ?? [];
        _dspMonitoring = results[2]['data']?['records']       ?? [];
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<dynamic> _byStatus(List<dynamic> list, String s) =>
      list.where((a) => a['validation_status'] == s).toList();

  @override
  Widget build(BuildContext context) {
    final aPending   = _byStatus(_assessments,   'pending').length;
    final bPending   = _byStatus(_beneficiaries, 'pending').length;
    final dPending   = _byStatus(_dspMonitoring, 'pending').length;
    final totalBadge = aPending + bPending + dPending;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.viewAll
            ? (totalBadge > 0 ? 'Track Records ($totalBadge pending)' : 'Track Records')
            : (totalBadge > 0 ? 'My Submissions ($totalBadge pending)' : 'My Submissions')),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(text: 'Assessments (${_assessments.length})'),
            Tab(text: 'Beneficiaries (${_beneficiaries.length})'),
            Tab(text: 'DSP Follow-ups (${_dspMonitoring.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.cloud_off_rounded, size: 56, color: Color(0xFF4A6080)),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFB0BEC5))),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ]),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: TabBarView(controller: _tabs, children: [
                    _AssessmentSubmissions(
                      items:    _assessments,
                      byStatus: _byStatus,
                      onReload: _load,
                    ),
                    _BeneficiarySubmissions(
                      items:    _beneficiaries,
                      byStatus: _byStatus,
                      onReload: _load,
                    ),
                    _DspMonitoringSubmissions(
                      items:    _dspMonitoring,
                      byStatus: _byStatus,
                    ),
                  ]),
                ),
    );
  }
}

// ── SHARED HELPERS ────────────────────────────────────────────────────────────

Color _statusColor(String s) => switch (s) {
  'validated' => const Color(0xFF2E7D32),
  'rejected'  => const Color(0xFFC62828),
  _           => const Color(0xFFE65100),
};

Color _statusBgColor(String s) => switch (s) {
  'validated' => const Color(0x334CAF50),
  'rejected'  => const Color(0x33FF4757),
  _           => const Color(0x33FF9100),
};

IconData _statusIcon(String s) => switch (s) {
  'validated' => Icons.check_circle_rounded,
  'rejected'  => Icons.cancel_rounded,
  _           => Icons.schedule_rounded,
};

String _statusLabel(String s) => switch (s) {
  'validated' => 'Validated',
  'rejected'  => 'Returned',
  _           => 'Pending',
};

String _fmtDate(String? raw) {
  if (raw == null || raw.length < 10) return '—';
  return raw.substring(0, 10);
}

Widget _statusChip(String status) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(
    color: _statusBgColor(status),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: _statusColor(status).withValues(alpha: 0.4)),
  ),
  child: Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(_statusIcon(status), size: 12, color: _statusColor(status)),
    const SizedBox(width: 4),
    Text(
      _statusLabel(status),
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor(status)),
    ),
  ]),
);

Widget _rejectionBox(String note) => Container(
  margin: const EdgeInsets.only(top: 8),
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  decoration: BoxDecoration(
    color: const Color(0x33FF9100),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: const Color(0x7FFF9100)),
  ),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      const Icon(Icons.reply_rounded, size: 13, color: Color(0xFFFFB74D)),
      const SizedBox(width: 5),
      const Text('Midwife\'s note:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFFFB74D))),
    ]),
    const SizedBox(height: 4),
    Text(note, style: const TextStyle(fontSize: 12, color: Color(0xFFFFCC80))),
  ]),
);

Widget _nutritionBadge(String? status) {
  if (status == null || status.isEmpty) return const SizedBox.shrink();
  final Map<String, List<Color>> map = {
    'SUW':    [const Color(0x33B71C1C), const Color(0xFFEF5350)],
    'UW':     [const Color(0x33E65100), const Color(0xFFFFB74D)],
    'Normal': [const Color(0x334CAF50), const Color(0xFF69F0AE)],
    'OW':     [const Color(0x330288D1), const Color(0xFF4FC3F7)],
    'OB':     [const Color(0x337C3AED), const Color(0xFFB39DDB)],
  };
  final colors = map[status] ?? [const Color(0xFF0F1E35), const Color(0xFFCDD5DE)];
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: colors[0],
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(status,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: colors[1])),
  );
}

// ── ASSESSMENT SUBMISSIONS ────────────────────────────────────────────────────

class _AssessmentSubmissions extends StatefulWidget {
  final List<dynamic> items;
  final List<dynamic> Function(List<dynamic>, String) byStatus;
  final Future<void> Function() onReload;

  const _AssessmentSubmissions({required this.items, required this.byStatus, required this.onReload});

  @override
  State<_AssessmentSubmissions> createState() => _AssessmentSubmissionsState();
}

class _AssessmentSubmissionsState extends State<_AssessmentSubmissions>
    with SingleTickerProviderStateMixin {
  late TabController _sub;

  @override
  void initState() {
    super.initState();
    _sub = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _sub.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final pending   = widget.byStatus(widget.items, 'pending');
    final validated = widget.byStatus(widget.items, 'validated');
    final rejected  = widget.byStatus(widget.items, 'rejected');

    return Column(children: [
      Container(
        color: const Color(0xFF0B1527),
        child: TabBar(
          controller: _sub,
          labelColor: const Color(0xFF00C6FF),
          unselectedLabelColor: const Color(0xFF4A6080),
          indicatorColor: const Color(0xFF1565C0),
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: [
            _subTab('Pending', pending.length, Colors.orange.shade700),
            _subTab('Validated', validated.length, const Color(0xFF2E7D32)),
            _subTab('Returned', rejected.length, Colors.orange.shade700),
          ],
        ),
      ),
      const Divider(height: 1),
      Expanded(
        child: TabBarView(controller: _sub, children: [
          _list(pending,   'pending'),
          _list(validated, 'validated'),
          _list(rejected,  'rejected'),
        ]),
      ),
    ]);
  }

  Tab _subTab(String label, int count, Color color) => Tab(
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label),
      if (count > 0) ...[
        const SizedBox(width: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
          child: Text('$count', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    ]),
  );

  Widget _list(List<dynamic> items, String tabStatus) {
    if (items.isEmpty) {
      final cfg = <String, List<dynamic>>{
        'pending':   [Icons.hourglass_empty_rounded,  Colors.orange.shade300, 'No pending assessments',  'Your submitted assessments will appear here.'],
        'validated': [Icons.fact_check_rounded,        Colors.green.shade400,  'No validated assessments', 'Validated records will show here.'],
        'rejected':  [Icons.reply_rounded,             Colors.orange.shade300, 'No returned assessments',  'Assessments returned for correction will appear here.'],
      }[tabStatus]!;
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(cfg[0] as IconData, size: 56, color: cfg[1] as Color),
        const SizedBox(height: 12),
        Text(cfg[2] as String,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF8FA8BF))),
        const SizedBox(height: 4),
        Text(cfg[3] as String,
            style: const TextStyle(fontSize: 12, color: Color(0xFF607896))),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final a      = items[i];
        final status = a['validation_status'] ?? 'pending';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 1.5,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: status == 'rejected'
                ? BorderSide(color: Colors.red.shade200)
                : status == 'validated'
                    ? BorderSide(color: Colors.green.shade200)
                    : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(
                    '${a['last_name']}, ${a['first_name']}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                _statusChip(status),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF607896)),
                const SizedBox(width: 3),
                Text('${a['barangay'] ?? '—'}  •  ${a['period'] ?? ''} ${a['assessment_year'] ?? ''}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF90A4B8))),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.monitor_weight_outlined, size: 12, color: Color(0xFF607896)),
                const SizedBox(width: 3),
                Text('${a['weight_kg'] ?? '—'} kg',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFB0BEC5))),
                const SizedBox(width: 8),
                _nutritionBadge(a['nutritional_status']?.toString()),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF607896)),
                const SizedBox(width: 3),
                Text('Assessment date: ${_fmtDate(a['assessment_date']?.toString())}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF90A4B8))),
              ]),
              if (status == 'validated' && a['validated_at'] != null) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.verified_rounded, size: 13, color: Colors.green.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Validated on ${_fmtDate(a['validated_at']?.toString())}${a['validated_by_name'] != null ? ' by ${a['validated_by_name']}' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w500),
                  ),
                ]),
              ],
              if (status == 'rejected' && a['rejection_note'] != null)
                _rejectionBox(a['rejection_note']),
              if (status == 'rejected') ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Edit & Resubmit', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade700,
                      side: BorderSide(color: Colors.orange.shade400),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => _showEditSheet(a),
                  ),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }

  void _showEditSheet(Map<String, dynamic> a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssessmentEditSheet(
        assessment: a,
        onSaved: widget.onReload,
      ),
    );
  }
}

// ── BENEFICIARY SUBMISSIONS ───────────────────────────────────────────────────

class _BeneficiarySubmissions extends StatefulWidget {
  final List<dynamic> items;
  final List<dynamic> Function(List<dynamic>, String) byStatus;
  final Future<void> Function() onReload;

  const _BeneficiarySubmissions({
    required this.items,
    required this.byStatus,
    required this.onReload,
  });

  @override
  State<_BeneficiarySubmissions> createState() => _BeneficiarySubmissionsState();
}

class _BeneficiarySubmissionsState extends State<_BeneficiarySubmissions>
    with SingleTickerProviderStateMixin {
  late TabController _sub;

  @override
  void initState() {
    super.initState();
    _sub = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _sub.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final pending   = widget.byStatus(widget.items, 'pending');
    final validated = widget.byStatus(widget.items, 'validated');
    final rejected  = widget.byStatus(widget.items, 'rejected');

    return Column(children: [
      Container(
        color: const Color(0xFF0B1527),
        child: TabBar(
          controller: _sub,
          labelColor: const Color(0xFF00C6FF),
          unselectedLabelColor: const Color(0xFF4A6080),
          indicatorColor: const Color(0xFF1565C0),
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: [
            _subTab('Pending', pending.length, Colors.orange.shade700),
            _subTab('Validated', validated.length, const Color(0xFF2E7D32)),
            _subTab('Returned', rejected.length, Colors.orange.shade700),
          ],
        ),
      ),
      const Divider(height: 1),
      Expanded(
        child: TabBarView(controller: _sub, children: [
          _list(pending,   'pending'),
          _list(validated, 'validated'),
          _list(rejected,  'rejected'),
        ]),
      ),
    ]);
  }

  Tab _subTab(String label, int count, Color color) => Tab(
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label),
      if (count > 0) ...[
        const SizedBox(width: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
          child: Text('$count', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    ]),
  );

  Widget _list(List<dynamic> items, String tabStatus) {
    if (items.isEmpty) {
      final cfg = <String, List<dynamic>>{
        'pending':   [Icons.hourglass_empty_rounded,  Colors.orange.shade300, 'No pending registrations',  'Submitted registrations awaiting review.'],
        'validated': [Icons.how_to_reg_rounded,        Colors.green.shade400,  'No validated registrations', 'Approved registrations will show here.'],
        'rejected':  [Icons.reply_rounded,             Colors.orange.shade300, 'No returned registrations',  'Registrations returned for correction will appear here.'],
      }[tabStatus]!;
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(cfg[0] as IconData, size: 56, color: cfg[1] as Color),
        const SizedBox(height: 12),
        Text(cfg[2] as String,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF8FA8BF))),
        const SizedBox(height: 4),
        Text(cfg[3] as String,
            style: const TextStyle(fontSize: 12, color: Color(0xFF607896))),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final b      = items[i];
        final status = b['validation_status'] ?? 'pending';
        final isMale = (b['sex'] ?? '') == 'Male';
        final initials = _initials(b['first_name'], b['last_name']);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 1.5,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: status == 'rejected'
                ? BorderSide(color: Colors.red.shade200)
                : status == 'validated'
                    ? BorderSide(color: Colors.green.shade200)
                    : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isMale ? Colors.blue.shade100 : Colors.pink.shade100,
                  child: Text(initials,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isMale ? Colors.blue.shade800 : Colors.pink.shade800,
                    )),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    '${b['last_name']}, ${b['first_name']}${_middleInitial(b['middle_name'])}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF607896)),
                    const SizedBox(width: 2),
                    Expanded(child: Text(
                      '${b['barangay'] ?? '—'}${b['purok_zone'] != null ? ' • Purok ${b['purok_zone']}' : ''}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF90A4B8)),
                      overflow: TextOverflow.ellipsis,
                    )),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.cake_outlined, size: 12, color: Color(0xFF607896)),
                    const SizedBox(width: 2),
                    Text('${b['date_of_birth'] ?? '—'}  •  ${b['sex'] ?? '—'}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF90A4B8))),
                  ]),
                ])),
                const SizedBox(width: 8),
                _statusChip(status),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF607896)),
                const SizedBox(width: 3),
                Text('Submitted: ${_fmtDate(b['created_at']?.toString())}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF90A4B8))),
              ]),
              if (status == 'validated' && b['validated_at'] != null) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.verified_rounded, size: 13, color: Colors.green.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Validated on ${_fmtDate(b['validated_at']?.toString())}${b['validated_by_name'] != null ? ' by ${b['validated_by_name']}' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w500),
                  ),
                ]),
              ],
              if (status == 'rejected') ...[
                if (b['rejection_note'] != null) _rejectionBox(b['rejection_note']),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Edit & Resubmit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => _editAndResubmit(context, b),
                  ),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }

  void _editAndResubmit(BuildContext ctx, Map<String, dynamic> b) async {
    final bene = BeneficiaryModel.fromJson(b);
    await Navigator.of(ctx).pushNamed('/beneficiaries/edit', arguments: bene);
    await widget.onReload();
  }

  String _initials(dynamic first, dynamic last) {
    final f = (first?.toString() ?? '').trim();
    final l = (last?.toString()  ?? '').trim();
    return '${l.isNotEmpty ? l[0] : ''}${f.isNotEmpty ? f[0] : ''}'.toUpperCase();
  }

  String _middleInitial(dynamic middle) {
    final m = middle?.toString().trim() ?? '';
    return m.isNotEmpty ? ' ${m[0]}.' : '';
  }
}

// ── DSP MONITORING SUBMISSIONS ────────────────────────────────────────────────

class _DspMonitoringSubmissions extends StatefulWidget {
  final List<dynamic> items;
  final List<dynamic> Function(List<dynamic>, String) byStatus;

  const _DspMonitoringSubmissions({
    required this.items,
    required this.byStatus,
  });

  @override
  State<_DspMonitoringSubmissions> createState() => _DspMonitoringSubmissionsState();
}

class _DspMonitoringSubmissionsState extends State<_DspMonitoringSubmissions>
    with SingleTickerProviderStateMixin {
  late TabController _sub;

  @override
  void initState() {
    super.initState();
    _sub = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _sub.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final pending   = widget.byStatus(widget.items, 'pending');
    final validated = widget.byStatus(widget.items, 'validated');
    final rejected  = widget.byStatus(widget.items, 'rejected');

    return Column(children: [
      Container(
        color: const Color(0xFF0B1527),
        child: TabBar(
          controller: _sub,
          labelColor: const Color(0xFF00C6FF),
          unselectedLabelColor: const Color(0xFF4A6080),
          indicatorColor: const Color(0xFF1565C0),
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: [
            _subTab('Pending',   pending.length,   Colors.orange.shade700),
            _subTab('Validated', validated.length, const Color(0xFF2E7D32)),
            _subTab('Returned',  rejected.length,  Colors.red.shade700),
          ],
        ),
      ),
      const Divider(height: 1),
      Expanded(
        child: TabBarView(controller: _sub, children: [
          _list(pending,   'pending'),
          _list(validated, 'validated'),
          _list(rejected,  'rejected'),
        ]),
      ),
    ]);
  }

  Tab _subTab(String label, int count, Color color) => Tab(
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label),
      if (count > 0) ...[
        const SizedBox(width: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
          child: Text('$count', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    ]),
  );

  Widget _list(List<dynamic> items, String tabStatus) {
    if (items.isEmpty) {
      final cfg = <String, List<dynamic>>{
        'pending':   [Icons.hourglass_empty_rounded,  Colors.orange.shade300, 'No pending follow-ups',   'Submitted follow-up records awaiting review.'],
        'validated': [Icons.check_circle_rounded,      Colors.green.shade400,  'No validated follow-ups', 'Approved follow-ups will show here.'],
        'rejected':  [Icons.reply_rounded,             Colors.red.shade300,    'No returned follow-ups',  'Follow-ups returned for correction will appear here.'],
      }[tabStatus]!;
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(cfg[0] as IconData, size: 56, color: cfg[1] as Color),
        const SizedBox(height: 12),
        Text(cfg[2] as String,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF8FA8BF))),
        const SizedBox(height: 4),
        Text(cfg[3] as String,
            style: const TextStyle(fontSize: 12, color: Color(0xFF607896))),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final r      = items[i];
        final status = r['validation_status'] ?? 'pending';
        return Card(
          margin:      const EdgeInsets.only(bottom: 10),
          elevation:   2,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: status == 'rejected'
                ? BorderSide(color: Colors.red.shade200)
                : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.monitor_weight_outlined, size: 14, color: Color(0xFF607896)),
                const SizedBox(width: 6),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    '${r['last_name'] ?? '—'}, ${r['first_name'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  Text(
                    '${r['barangay'] ?? '—'}  •  ${r['intervention_type'] ?? 'DSP'}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF90A4B8)),
                  ),
                ])),
                const SizedBox(width: 8),
                _statusChip(status),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF607896)),
                const SizedBox(width: 3),
                Text('Follow-up date: ${_fmtDate(r['monitoring_date']?.toString())}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF90A4B8))),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.scale_outlined, size: 12, color: Color(0xFF607896)),
                const SizedBox(width: 3),
                Text(
                  [
                    if (r['weight_kg'] != null) '${r['weight_kg']} kg',
                    if (r['muac_cm']   != null) 'MUAC ${r['muac_cm']} cm',
                    if (r['nutritional_status'] != null) r['nutritional_status'],
                  ].join('  •  '),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF607896)),
                ),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.upload_rounded, size: 12, color: Color(0xFF607896)),
                const SizedBox(width: 3),
                Text('Submitted: ${_fmtDate(r['created_at']?.toString())}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF90A4B8))),
              ]),
              if (status == 'validated' && r['validated_at'] != null) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.verified_rounded, size: 13, color: Colors.green.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Validated on ${_fmtDate(r['validated_at']?.toString())}${r['validated_by_name'] != null ? ' by ${r['validated_by_name']}' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w500),
                  ),
                ]),
              ],
              if (status == 'rejected' && r['rejection_note'] != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0x33FF4757),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x7FFF4757)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFFF6B7A)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      r['rejection_note'],
                      style: const TextStyle(fontSize: 12, color: Color(0xFFFF6B7A)),
                    )),
                  ]),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }
}

// ── ASSESSMENT EDIT SHEET ─────────────────────────────────────────────────────

class _AssessmentEditSheet extends StatefulWidget {
  final Map<String, dynamic> assessment;
  final Future<void> Function() onSaved;
  const _AssessmentEditSheet({required this.assessment, required this.onSaved});
  @override State<_AssessmentEditSheet> createState() => _AssessmentEditSheetState();
}

class _AssessmentEditSheetState extends State<_AssessmentEditSheet> {
  final _api        = ApiService();
  final _formKey    = GlobalKey<FormState>();
  late final TextEditingController _weightCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _muacCtrl;
  late final TextEditingController _remarksCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.assessment;
    _weightCtrl  = TextEditingController(text: a['weight_kg']?.toString() ?? '');
    _heightCtrl  = TextEditingController(text: a['height_cm']?.toString() ?? '');
    _muacCtrl    = TextEditingController(text: a['muac_cm']?.toString()   ?? '');
    _remarksCtrl = TextEditingController(text: a['remarks']?.toString()   ?? '');
  }

  @override
  void dispose() {
    _weightCtrl.dispose(); _heightCtrl.dispose();
    _muacCtrl.dispose();   _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final res = await _api.updateAssessment(
      widget.assessment['id'] as int,
      {
        'weight_kg': double.tryParse(_weightCtrl.text.trim()),
        if (_heightCtrl.text.trim().isNotEmpty)
          'height_cm': double.tryParse(_heightCtrl.text.trim()),
        if (_muacCtrl.text.trim().isNotEmpty)
          'muac_cm': double.tryParse(_muacCtrl.text.trim()),
        if (_remarksCtrl.text.trim().isNotEmpty)
          'remarks': _remarksCtrl.text.trim(),
      },
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['success'] == true) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Assessment resubmitted for validation'),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ));
      await widget.onSaved();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message']?.toString() ?? 'Failed to update'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final a    = widget.assessment;
    final name = '${a['last_name']}, ${a['first_name']}';
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0B1527),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.edit_rounded, color: Color(0xFF00C6FF), size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('Edit Assessment — $name',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFFC8DFF0)))),
            IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF4A6080)),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
          Text('${a['period']} ${a['assessment_year']} · ${a['barangay'] ?? ''}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF4A6080))),
          const SizedBox(height: 16),
          _field(_weightCtrl, 'Weight (kg) *', required: true),
          const SizedBox(height: 10),
          _field(_heightCtrl, 'Height (cm)'),
          const SizedBox(height: 10),
          _field(_muacCtrl, 'MUAC (cm)'),
          const SizedBox(height: 10),
          TextFormField(
            controller: _remarksCtrl,
            maxLines: 2,
            style: const TextStyle(color: Color(0xFFC8DFF0)),
            decoration: _dec('Remarks (optional)'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, size: 18),
              label: const Text('Resubmit for Validation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {bool required = false}) =>
      TextFormField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: Color(0xFFC8DFF0)),
        decoration: _dec(label),
        validator: required
            ? (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if ((double.tryParse(v.trim()) ?? 0) <= 0) return 'Enter a valid value';
                return null;
              }
            : (v) {
                if (v != null && v.trim().isNotEmpty &&
                    (double.tryParse(v.trim()) ?? 0) <= 0) return 'Enter a valid value';
                return null;
              },
      );

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Color(0xFF4A6080)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF1A3050)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF00C6FF)),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.red),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.red),
    ),
    filled: true,
    fillColor: const Color(0xFF0D1A35),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}
