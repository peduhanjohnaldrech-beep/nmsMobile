import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/beneficiary_model.dart';

class MySubmissionsScreen extends StatefulWidget {
  const MySubmissionsScreen({super.key});
  @override State<MySubmissionsScreen> createState() => _State();
}

class _State extends State<MySubmissionsScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabs;

  List<dynamic> _assessments   = [];
  List<dynamic> _beneficiaries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.getMySubmissions(),
        _api.getMyBeneficiarySubmissions(),
      ]);
      if (!mounted) return;
      setState(() {
        _assessments   = results[0]['data']?['assessments']   ?? [];
        _beneficiaries = results[1]['data']?['beneficiaries'] ?? [];
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
    final aPending   = _byStatus(_assessments, 'pending').length;
    final bPending   = _byStatus(_beneficiaries, 'pending').length;
    final totalBadge = aPending + bPending;

    return Scaffold(
      appBar: AppBar(
        title: Text(totalBadge > 0 ? 'My Submissions ($totalBadge pending)' : 'My Submissions'),
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
                      Icon(Icons.cloud_off_rounded, size: 56, color: const Color(0xFF4A6080)),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center,
                          style: TextStyle(color: const Color(0xFFB0BEC5))),
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
                    ),
                    _BeneficiarySubmissions(
                      items:    _beneficiaries,
                      byStatus: _byStatus,
                      onReload: _load,
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
  'validated' => const Color(0xFFE8F5E9),
  'rejected'  => const Color(0xFFFFEBEE),
  _           => const Color(0xFFFFF3E0),
};

IconData _statusIcon(String s) => switch (s) {
  'validated' => Icons.check_circle_rounded,
  'rejected'  => Icons.cancel_rounded,
  _           => Icons.schedule_rounded,
};

String _statusLabel(String s) => switch (s) {
  'validated' => 'Validated',
  'rejected'  => 'Rejected',
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
    color: const Color(0xFFFFEBEE),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: const Color(0xFFEF9A9A)),
  ),
  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFC62828)),
    const SizedBox(width: 6),
    Expanded(
      child: Text(
        note,
        style: const TextStyle(fontSize: 12, color: Color(0xFFB71C1C)),
      ),
    ),
  ]),
);

Widget _nutritionBadge(String? status) {
  if (status == null || status.isEmpty) return const SizedBox.shrink();
  final Map<String, List<Color>> map = {
    'SUW':    [Color(0xFFFFEBEE), Color(0xFFB71C1C)],
    'UW':     [Color(0xFFFFF3E0), Color(0xFFE65100)],
    'Normal': [Color(0xFFE8F5E9), Color(0xFF1B5E20)],
    'OW':     [Color(0xFFFFFDE7), Color(0xFFF57F17)],
    'OB':     [Color(0xFFF3E5F5), Color(0xFF4A148C)],
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

  const _AssessmentSubmissions({required this.items, required this.byStatus});

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
            _subTab('Rejected', rejected.length, const Color(0xFFC62828)),
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
        'rejected':  [Icons.thumb_down_off_alt_rounded, Colors.red.shade300,   'No rejected assessments',  'Rejected records will show here.'],
      }[tabStatus]!;
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(cfg[0] as IconData, size: 56, color: cfg[1] as Color),
        const SizedBox(height: 12),
        Text(cfg[2] as String,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF8FA8BF))),
        const SizedBox(height: 4),
        Text(cfg[3] as String,
            style: TextStyle(fontSize: 12, color: const Color(0xFF607896))),
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
                Icon(Icons.location_on_outlined, size: 12, color: const Color(0xFF607896)),
                const SizedBox(width: 3),
                Text('${a['barangay'] ?? '—'}  •  ${a['period'] ?? ''} ${a['assessment_year'] ?? ''}',
                    style: TextStyle(fontSize: 12, color: const Color(0xFF90A4B8))),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Icon(Icons.monitor_weight_outlined, size: 12, color: const Color(0xFF607896)),
                const SizedBox(width: 3),
                Text('${a['weight_kg'] ?? '—'} kg',
                    style: TextStyle(fontSize: 12, color: const Color(0xFFB0BEC5))),
                const SizedBox(width: 8),
                _nutritionBadge(a['nutritional_status']?.toString()),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Icon(Icons.calendar_today_rounded, size: 12, color: const Color(0xFF607896)),
                const SizedBox(width: 3),
                Text('Assessment date: ${_fmtDate(a['assessment_date']?.toString())}',
                    style: TextStyle(fontSize: 12, color: const Color(0xFF90A4B8))),
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
            ]),
          ),
        );
      },
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
            _subTab('Rejected', rejected.length, const Color(0xFFC62828)),
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
        'rejected':  [Icons.person_off_outlined,       Colors.red.shade300,    'No rejected registrations',  'Rejected registrations will show here.'],
      }[tabStatus]!;
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(cfg[0] as IconData, size: 56, color: cfg[1] as Color),
        const SizedBox(height: 12),
        Text(cfg[2] as String,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF8FA8BF))),
        const SizedBox(height: 4),
        Text(cfg[3] as String,
            style: TextStyle(fontSize: 12, color: const Color(0xFF607896))),
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
                    Icon(Icons.location_on_outlined, size: 12, color: const Color(0xFF607896)),
                    const SizedBox(width: 2),
                    Expanded(child: Text(
                      '${b['barangay'] ?? '—'}${b['purok_zone'] != null ? ' • Purok ${b['purok_zone']}' : ''}',
                      style: TextStyle(fontSize: 12, color: const Color(0xFF90A4B8)),
                      overflow: TextOverflow.ellipsis,
                    )),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.cake_outlined, size: 12, color: const Color(0xFF607896)),
                    const SizedBox(width: 2),
                    Text('${b['date_of_birth'] ?? '—'}  •  ${b['sex'] ?? '—'}',
                        style: TextStyle(fontSize: 12, color: const Color(0xFF90A4B8))),
                  ]),
                ])),
                const SizedBox(width: 8),
                _statusChip(status),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.calendar_today_rounded, size: 12, color: const Color(0xFF607896)),
                const SizedBox(width: 3),
                Text('Submitted: ${_fmtDate(b['created_at']?.toString())}',
                    style: TextStyle(fontSize: 12, color: const Color(0xFF90A4B8))),
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
