import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../services/local_db_service.dart';
import '../../widgets/status_badge.dart';

class ProgramsScreen extends StatefulWidget {
  const ProgramsScreen({super.key});
  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabs;

  List<dynamic> _customPrograms = [];
  bool _loadingPrograms = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this); // placeholder, rebuilt after load
    _loadPrograms();
  }

  Future<void> _loadPrograms() async {
    try {
      final res = await _api.getProgramsList();
      if (res['success'] == true) {
        final all = List<dynamic>.from(res['data']?['programs'] ?? []);
        final custom = all.where((p) =>
          !['OPT','DSP','MNS'].contains((p['code'] ?? '').toString().toUpperCase()) &&
          p['is_active'] == 1
        ).toList();
        if (mounted) {
          setState(() {
            _customPrograms = custom;
            _loadingPrograms = false;
          });
          final count = 3 + (custom.isNotEmpty ? 1 : 0);
          _tabs.dispose();
          _tabs = TabController(length: count, vsync: this);
          setState(() {});
        }
      } else {
        if (mounted) setState(() => _loadingPrograms = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPrograms = false);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasCustom = _customPrograms.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Programs'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          isScrollable: hasCustom,
          tabs: [
            const Tab(icon: Icon(Icons.monitor_weight_outlined), text: 'OPT'),
            const Tab(icon: Icon(Icons.restaurant_outlined),     text: 'DSP'),
            const Tab(icon: Icon(Icons.vaccines_outlined),       text: 'MNS'),
            if (hasCustom)
              const Tab(icon: Icon(Icons.apps_rounded), text: 'Others'),
          ],
        ),
      ),
      body: _loadingPrograms
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                const _OptTab(),
                const _DspTab(),
                const _MnsTab(),
                if (hasCustom) _OthersTab(programs: _customPrograms),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// OPT TAB
// ─────────────────────────────────────────────────────────
class _OptTab extends StatefulWidget {
  const _OptTab();
  @override
  State<_OptTab> createState() => _OptTabState();
}

class _OptTabState extends State<_OptTab> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  final _api = ApiService();
  int     _year   = DateTime.now().year;
  String? _period;
  bool    _loading = false;
  List<dynamic>        _items  = [];
  Map<String, dynamic> _counts = {};

  final _years = [DateTime.now().year, DateTime.now().year - 1, DateTime.now().year - 2];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = context.read<AuthProvider>().user;
    final brgy = user?.isScopedToBarangay == true ? user?.barangay : null;
    try {
      final result = await _api.getPrograms(type: 'opt', year: _year, period: _period, barangay: brgy);
      if (result['success'] == true && mounted) {
        final data = result['data'] as Map<String, dynamic>;
        setState(() {
          _items  = List.from(data['assessments'] ?? []);
          _counts = Map<String, dynamic>.from(data['counts'] ?? {});
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      Container(
        color: const Color(0xFF1565C0),
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Row(children: [
          Expanded(child: _DropdownFilter<int>(
            hint: 'Year', value: _year,
            items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
            onChanged: (v) { if (v != null) setState(() => _year = v); _load(); },
          )),
          const SizedBox(width: 8),
          Expanded(child: _DropdownFilter<String>(
            hint: 'All Periods', value: _period,
            items: const [
              DropdownMenuItem(value: 'January', child: Text('January')),
              DropdownMenuItem(value: 'July',    child: Text('July')),
            ],
            onChanged: (v) { setState(() => _period = v); _load(); },
          )),
        ]),
      ),
      if (_counts.isNotEmpty)
        Container(
          color: const Color(0xFF0B1527),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            _CountChip('SUW',    (_counts['SUW']    ?? 0).toString(), Colors.red),
            const SizedBox(width: 6),
            _CountChip('UW',     (_counts['UW']     ?? 0).toString(), Colors.orange),
            const SizedBox(width: 6),
            _CountChip('Normal', (_counts['Normal'] ?? 0).toString(), Colors.green),
            const SizedBox(width: 6),
            _CountChip('OW',     (_counts['OW']     ?? 0).toString(), Colors.amber.shade700),
            const SizedBox(width: 6),
            _CountChip('OB',     (_counts['OB']     ?? 0).toString(), Colors.purple),
          ]),
        ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? _emptyState(Icons.monitor_weight_outlined, 'No OPT assessments found')
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final a = _items[i];
                        final status = a['nutritional_status'] ?? 'Normal';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            dense: true,
                            title: Text('${a['last_name']}, ${a['first_name']}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            subtitle: Text(
                              '${a['barangay']}  •  ${a['period']} ${a['assessment_year']}  •  ${a['weight_kg']} kg',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: StatusBadge(status: status),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────
// DSP TAB
// ─────────────────────────────────────────────────────────
class _DspTab extends StatefulWidget {
  const _DspTab();
  @override State<_DspTab> createState() => _DspTabState();
}

class _DspTabState extends State<_DspTab> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  final _api  = ApiService();
  int     _year   = DateTime.now().year;
  String? _status; // null = All
  bool    _loading = false;
  List<dynamic>        _items  = [];
  Map<String, dynamic> _counts = {};

  final _years = [DateTime.now().year, DateTime.now().year - 1, DateTime.now().year - 2];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = context.read<AuthProvider>().user;
    final brgy = user?.isScopedToBarangay == true ? user?.barangay : null;
    try {
      final res = await _api.getDsp(year: _year, status: _status, barangay: brgy);
      if (res['success'] == true && mounted) {
        final data = res['data'] as Map<String, dynamic>;
        setState(() {
          _items  = List.from(data['enrollments'] ?? []);
          _counts = Map<String, dynamic>.from(data['counts'] ?? {});
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _showEnrollModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DspEnrollModal(onSaved: _load),
    );
  }

  void _showUpdateModal(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DspUpdateModal(item: item, onSaved: _load),
    );
  }

  void _showDischargeModal(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DspDischargeModal(item: item, onSaved: _load),
    );
  }

  Color _statusColor(String s) => switch (s) {
    'Active'    => Colors.blue.shade700,
    'Completed' => Colors.green.shade700,
    _           => const Color(0xFF90A4B8),
  };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(children: [
      Column(children: [
        // Filters
        Container(
          color: const Color(0xFF1565C0),
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(children: [
            Expanded(child: _DropdownFilter<int>(
              hint: 'Year', value: _year,
              items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
              onChanged: (v) { if (v != null) setState(() => _year = v); _load(); },
            )),
            const SizedBox(width: 8),
            Expanded(child: _DropdownFilter<String>(
              hint: 'All Status', value: _status,
              items: const [
                DropdownMenuItem(value: 'Active',    child: Text('Active')),
                DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                DropdownMenuItem(value: 'Dropped',   child: Text('Dropped')),
              ],
              onChanged: (v) { setState(() => _status = v); _load(); },
            )),
          ]),
        ),
        // Count chips
        if (_counts.isNotEmpty)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              _CountChip('Active',    (_counts['Active']    ?? 0).toString(), Colors.blue.shade700),
              const SizedBox(width: 6),
              _CountChip('Completed', (_counts['Completed'] ?? 0).toString(), Colors.green),
              const SizedBox(width: 6),
              _CountChip('Dropped',   (_counts['Dropped']   ?? 0).toString(), Colors.grey),
            ]),
          ),
        // List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? _emptyState(Icons.restaurant_outlined, 'No DSP enrollments for $_year')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final e      = _items[i];
                          final status = e['status'] ?? 'Active';
                          final isActive = status == 'Active';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: isActive
                                  ? BorderSide(color: Colors.blue.shade200)
                                  : BorderSide.none,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(child: Text(
                                    '${e['last_name']}, ${e['first_name']}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                  )),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _statusColor(status).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _statusColor(status).withValues(alpha: 0.4)),
                                    ),
                                    child: Text(status,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor(status))),
                                  ),
                                ]),
                                const SizedBox(height: 4),
                                Row(children: [
                                  Icon(Icons.location_on_outlined, size: 12, color: const Color(0xFF607896)),
                                  const SizedBox(width: 2),
                                  Text('${e['barangay'] ?? '—'}  •  ${e['sex'] ?? ''}',
                                      style: TextStyle(fontSize: 12, color: const Color(0xFF90A4B8))),
                                ]),
                                const SizedBox(height: 2),
                                Row(children: [
                                  Icon(Icons.calendar_today_rounded, size: 12, color: const Color(0xFF607896)),
                                  const SizedBox(width: 2),
                                  Text('Enrolled: ${(e['enrollment_date'] ?? '').toString().substring(0, 10.clamp(0, (e['enrollment_date'] ?? '').toString().length))}',
                                      style: TextStyle(fontSize: 12, color: const Color(0xFF90A4B8))),
                                ]),
                                if (e['pre_weight_kg'] != null || e['post_weight_kg'] != null) ...[
                                  const SizedBox(height: 2),
                                  Row(children: [
                                    Icon(Icons.monitor_weight_outlined, size: 12, color: const Color(0xFF607896)),
                                    const SizedBox(width: 2),
                                    Text(
                                      [
                                        if (e['pre_weight_kg'] != null) 'Pre: ${e['pre_weight_kg']} kg',
                                        if (e['post_weight_kg'] != null) 'Post: ${e['post_weight_kg']} kg',
                                      ].join('  →  '),
                                      style: TextStyle(fontSize: 12, color: const Color(0xFFB0BEC5), fontWeight: FontWeight.w500),
                                    ),
                                  ]),
                                ],
                                if (e['notes'] != null && e['notes'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(e['notes'], style: TextStyle(fontSize: 11, color: const Color(0xFF607896)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                                if (isActive) ...[
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    Expanded(child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.blue.shade700,
                                        side: BorderSide(color: Colors.blue.shade200),
                                        minimumSize: const Size(0, 34),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        padding: EdgeInsets.zero,
                                      ),
                                      icon: const Icon(Icons.monitor_weight_outlined, size: 15),
                                      label: const Text('Update', style: TextStyle(fontSize: 12)),
                                      onPressed: () => _showUpdateModal(e),
                                    )),
                                    const SizedBox(width: 8),
                                    Expanded(child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade600,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(0, 34),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        padding: EdgeInsets.zero,
                                      ),
                                      icon: const Icon(Icons.logout_rounded, size: 15),
                                      label: const Text('Discharge', style: TextStyle(fontSize: 12)),
                                      onPressed: () => _showDischargeModal(e),
                                    )),
                                  ]),
                                ],
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ]),
      Positioned(
        right: 16, bottom: 16,
        child: FloatingActionButton.extended(
          heroTag: 'fab_dsp_enroll',
          onPressed: _showEnrollModal,
          backgroundColor: Colors.blue.shade700,
          icon: const Icon(Icons.person_add_rounded, color: Colors.white),
          label: const Text('Enroll', style: TextStyle(color: Colors.white)),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────
// DSP MODALS
// ─────────────────────────────────────────────────────────
class _DspEnrollModal extends StatefulWidget {
  final VoidCallback onSaved;
  const _DspEnrollModal({required this.onSaved});
  @override State<_DspEnrollModal> createState() => _DspEnrollModalState();
}

class _DspEnrollModalState extends State<_DspEnrollModal> {
  final _api        = ApiService();
  final _local      = LocalDbService();
  final _searchCtrl = TextEditingController();
  final _dateCtrl   = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
  final _weightCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();

  Map<String, dynamic>?      _selected;
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _saving    = false;
  String _intervention = 'Supplementary Feeding';

  @override
  void dispose() {
    _searchCtrl.dispose(); _dateCtrl.dispose();
    _weightCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.length < 2) { setState(() => _results = []); return; }
    setState(() => _searching = true);
    try {
      final rows = await _local.getBeneficiaries(search: q, perPage: 10);
      if (rows.isEmpty) {
        final res = await _api.getBeneficiaries(search: q, perPage: 10);
        if (res['success'] == true) {
          setState(() => _results = List<Map<String, dynamic>>.from(res['data']['beneficiaries'] ?? []));
        }
      } else {
        setState(() => _results = rows);
      }
    } catch (_) {}
    if (mounted) setState(() => _searching = false);
  }

  Future<void> _save() async {
    if (_selected == null) { _snack('Select a beneficiary first', false); return; }
    setState(() => _saving = true);
    final res = await _api.dspEnroll({
      'beneficiary_id':    _selected!['id'],
      'enrollment_date':   _dateCtrl.text,
      'cycle_year':        int.tryParse(_dateCtrl.text.substring(0, 4)) ?? DateTime.now().year,
      'intervention_type': _intervention,
      if (_weightCtrl.text.isNotEmpty) 'pre_weight_kg': double.tryParse(_weightCtrl.text),
      'notes': _notesCtrl.text,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
    _snack(res['message'] ?? 'Done', res['success'] == true);
    if (res['success'] == true) widget.onSaved();
  }

  void _snack(String msg, bool ok) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: ok ? Colors.green : Colors.red, behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) => _ModalSheet(
    title: 'Enroll in DSP',
    saving: _saving,
    onSave: _save,
    saveLabel: 'Enroll',
    saveColor: Colors.blue.shade700,
    children: [
      _BeneficiarySearch(
        ctrl: _searchCtrl, selected: _selected, results: _results, searching: _searching,
        onSearch: _search,
        onSelect: (b) => setState(() { _selected = b; _results = []; }),
        onClear: () => setState(() { _selected = null; _searchCtrl.clear(); _results = []; }),
      ),
      const SizedBox(height: 12),
      _dateField(context, _dateCtrl, 'Enrollment Date'),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _intervention,
        decoration: const InputDecoration(labelText: 'Intervention Type', border: OutlineInputBorder()),
        items: const [
          DropdownMenuItem(value: 'Supplementary Feeding',  child: Text('Supplementary Feeding')),
          DropdownMenuItem(value: 'Therapeutic Feeding',    child: Text('Therapeutic Feeding')),
          DropdownMenuItem(value: 'Dietary Counseling',     child: Text('Dietary Counseling')),
        ],
        onChanged: (v) => setState(() => _intervention = v!),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _weightCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Pre-weight (kg)', border: OutlineInputBorder(), suffixText: 'kg'),
      ),
      const SizedBox(height: 12),
      TextField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()), maxLines: 2),
    ],
  );
}

class _DspUpdateModal extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onSaved;
  const _DspUpdateModal({required this.item, required this.onSaved});
  @override State<_DspUpdateModal> createState() => _DspUpdateModalState();
}

class _DspUpdateModalState extends State<_DspUpdateModal> {
  final _api        = ApiService();
  final _weightCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _weightCtrl.text = widget.item['post_weight_kg']?.toString() ?? '';
    _notesCtrl.text  = widget.item['notes'] ?? '';
  }

  @override
  void dispose() { _weightCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() => _saving = true);
    final res = await _api.dspUpdate({
      'id': widget.item['id'],
      if (_weightCtrl.text.isNotEmpty) 'post_weight_kg': double.tryParse(_weightCtrl.text),
      'notes': _notesCtrl.text,
      'status': 'Active',
    });
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message'] ?? 'Done'),
      backgroundColor: res['success'] == true ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
    if (res['success'] == true) widget.onSaved();
  }

  @override
  Widget build(BuildContext context) => _ModalSheet(
    title: 'Update Weight — ${widget.item['last_name']}, ${widget.item['first_name']}',
    saving: _saving,
    onSave: _save,
    saveLabel: 'Update',
    saveColor: Colors.blue.shade700,
    children: [
      TextField(
        controller: _weightCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Current Weight (kg)', border: OutlineInputBorder(), suffixText: 'kg'),
      ),
      const SizedBox(height: 12),
      TextField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()), maxLines: 2),
    ],
  );
}

class _DspDischargeModal extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onSaved;
  const _DspDischargeModal({required this.item, required this.onSaved});
  @override State<_DspDischargeModal> createState() => _DspDischargeModalState();
}

class _DspDischargeModalState extends State<_DspDischargeModal> {
  final _api        = ApiService();
  final _dateCtrl   = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
  final _weightCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();
  String _status = 'Completed';
  bool   _saving = false;

  @override
  void dispose() { _dateCtrl.dispose(); _weightCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() => _saving = true);
    final res = await _api.dspDischarge({
      'id':       widget.item['id'],
      'status':   _status,
      'end_date': _dateCtrl.text,
      if (_weightCtrl.text.isNotEmpty) 'post_weight_kg': double.tryParse(_weightCtrl.text),
      'notes': _notesCtrl.text,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message'] ?? 'Done'),
      backgroundColor: res['success'] == true ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
    if (res['success'] == true) widget.onSaved();
  }

  @override
  Widget build(BuildContext context) => _ModalSheet(
    title: 'Discharge — ${widget.item['last_name']}, ${widget.item['first_name']}',
    saving: _saving,
    onSave: _save,
    saveLabel: 'Discharge',
    saveColor: Colors.green.shade700,
    children: [
      DropdownButtonFormField<String>(
        value: _status,
        decoration: const InputDecoration(labelText: 'Discharge Status', border: OutlineInputBorder()),
        items: const [
          DropdownMenuItem(value: 'Completed', child: Text('Completed — recovered')),
          DropdownMenuItem(value: 'Dropped',   child: Text('Dropped — did not complete')),
        ],
        onChanged: (v) => setState(() => _status = v!),
      ),
      const SizedBox(height: 12),
      _dateField(context, _dateCtrl, 'End Date'),
      const SizedBox(height: 12),
      TextField(
        controller: _weightCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Final Weight (kg)', border: OutlineInputBorder(), suffixText: 'kg'),
      ),
      const SizedBox(height: 12),
      TextField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()), maxLines: 2),
    ],
  );
}

// ─────────────────────────────────────────────────────────
// MNS TAB
// ─────────────────────────────────────────────────────────
class _MnsTab extends StatefulWidget {
  const _MnsTab();
  @override State<_MnsTab> createState() => _MnsTabState();
}

class _MnsTabState extends State<_MnsTab>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override bool get wantKeepAlive => true;

  final _api = ApiService();
  late TabController _subTabs;

  int    _year    = DateTime.now().year;
  String _round   = 'February';
  bool   _loading = false;

  List<dynamic> _vitAItems  = [];
  List<dynamic> _mnpItems   = [];
  List<dynamic> _lnsSqItems = [];

  @override
  void initState() {
    super.initState();
    _subTabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _subTabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = context.read<AuthProvider>().user;
    final brgy = user?.isScopedToBarangay == true ? user?.barangay : null;
    try {
      final results = await Future.wait([
        _api.getPrograms(type: 'mns', year: _year, period: _round, barangay: brgy, tab: 'vitaminA'),
        _api.getPrograms(type: 'mns', year: _year, period: _round, barangay: brgy, tab: 'mnp'),
        _api.getPrograms(type: 'mns', year: _year, period: _round, barangay: brgy, tab: 'lnssq'),
      ]);
      if (mounted) setState(() {
        _vitAItems  = List.from(results[0]['data']?['records'] ?? []);
        _mnpItems   = List.from(results[1]['data']?['records'] ?? []);
        _lnsSqItems = List.from(results[2]['data']?['records'] ?? []);
      });
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deleteVitA(int id) async {
    final res = await _api.deleteVitaminA(id);
    if (!mounted) return;
    _snack(res['message'] ?? 'Done', res['success'] == true);
    if (res['success'] == true) _load();
  }

  Future<void> _markComplete(String type, int id) async {
    final res = type == 'mnp' ? await _api.mnpComplete(id) : await _api.lnsSqComplete(id);
    if (!mounted) return;
    _snack(res['message'] ?? 'Done', res['success'] == true);
    if (res['success'] == true) _load();
  }

  void _snack(String msg, bool ok) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: ok ? Colors.green : Colors.red, behavior: SnackBarBehavior.floating));

  void _showRecordModal(String type) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _MnsRecordModal(type: type, year: _year, round: _round, onSaved: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      Container(
        color: const Color(0xFF1565C0),
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Row(children: [
          Expanded(child: _DropdownFilter<int>(
            hint: 'Year', value: _year,
            items: [DateTime.now().year, DateTime.now().year - 1, DateTime.now().year - 2]
                .map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
            onChanged: (v) { if (v != null) setState(() => _year = v); _load(); },
          )),
          const SizedBox(width: 8),
          Expanded(child: _DropdownFilter<String>(
            hint: 'Round', value: _round,
            items: const [
              DropdownMenuItem(value: 'February', child: Text('February')),
              DropdownMenuItem(value: 'August',   child: Text('August')),
            ],
            onChanged: (v) { if (v != null) setState(() => _round = v); _load(); },
          )),
        ]),
      ),
      Container(
        color: const Color(0xFF0D47A1),
        child: TabBar(
          controller: _subTabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.amber,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Vitamin A'),
            Tab(text: 'MNP'),
            Tab(text: 'LNS-SQ'),
          ],
        ),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _subTabs,
                children: [
                  _MnsSubTab(
                    type: 'vitamina', items: _vitAItems, heroTag: 'fab_vita',
                    emptyMsg: 'No Vitamin A records for $_round $_year',
                    icon: Icons.vaccines, color: Colors.orange,
                    subtitle: (r) => '${r['barangay'] ?? ''}  •  ${r['dosage_iu'] ?? ''} IU',
                    trailing: (r) => r['distribution_date'] ?? '',
                    onRecord: () => _showRecordModal('vitamina'),
                    onRefresh: _load,
                    onDelete: _deleteVitA,
                  ),
                  _MnsSubTab(
                    type: 'mnp', items: _mnpItems, heroTag: 'fab_mnp',
                    emptyMsg: 'No MNP records for $_year',
                    icon: Icons.medication_outlined, color: Colors.purple,
                    subtitle: (r) => '${r['barangay'] ?? ''}  •  ${r['age_group'] ?? ''}',
                    trailing: (r) => r['date_given'] ?? '',
                    onRecord: () => _showRecordModal('mnp'),
                    onRefresh: _load,
                    onComplete: (id) => _markComplete('mnp', id),
                  ),
                  _MnsSubTab(
                    type: 'lnssq', items: _lnsSqItems, heroTag: 'fab_lnssq',
                    emptyMsg: 'No LNS-SQ records for $_year',
                    icon: Icons.local_dining_outlined, color: Colors.teal,
                    subtitle: (r) => '${r['barangay'] ?? ''}  •  ${r['age_group'] ?? ''}',
                    trailing: (r) => r['date_given'] ?? '',
                    onRecord: () => _showRecordModal('lnssq'),
                    onRefresh: _load,
                    onComplete: (id) => _markComplete('lnssq', id),
                  ),
                ],
              ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────
// MNS SUB-TAB
// ─────────────────────────────────────────────────────────
class _MnsSubTab extends StatelessWidget {
  final String                        type;
  final List<dynamic>                 items;
  final String                        emptyMsg;
  final IconData                      icon;
  final Color                         color;
  final String Function(dynamic)      subtitle;
  final String Function(dynamic)      trailing;
  final String                        heroTag;
  final VoidCallback                  onRecord;
  final Future<void> Function()       onRefresh;
  final Future<void> Function(int)?   onDelete;
  final Future<void> Function(int)?   onComplete;

  const _MnsSubTab({
    required this.type,
    required this.items,
    required this.emptyMsg,
    required this.icon,
    required this.color,
    required this.subtitle,
    required this.trailing,
    required this.heroTag,
    required this.onRecord,
    required this.onRefresh,
    this.onDelete,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      if (items.isEmpty)
        Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 56, color: const Color(0xFF1E3050)),
          const SizedBox(height: 12),
          Text(emptyMsg, style: TextStyle(color: const Color(0xFF90A4B8), fontSize: 14)),
        ]))
      else
        RefreshIndicator(
          onRefresh: onRefresh,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${items.length} records',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                ),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 90),
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final r    = items[i];
                  final id   = r['id'] as int? ?? 0;
                  final name = '${r['last_name'] ?? ''}, ${r['first_name'] ?? ''}';
                  final completed = (r['completed_routine'] == 1 || r['completed_routine'] == '1');

                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                      child: Row(children: [
                        CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.15),
                          radius: 18,
                          child: Icon(icon, color: color, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(subtitle(r), style: TextStyle(fontSize: 11, color: const Color(0xFF90A4B8))),
                          Text(trailing(r), style: TextStyle(fontSize: 11, color: const Color(0xFF607896))),
                        ])),
                        // Actions
                        if (type == 'vitamina' && onDelete != null)
                          IconButton(
                            icon: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red.shade400),
                            tooltip: 'Delete',
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: ctx,
                                builder: (c) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  title: const Text('Delete Record'),
                                  content: Text('Delete Vitamin A record for $name?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) onDelete!(id);
                            },
                          )
                        else if (type != 'vitamina' && onComplete != null)
                          completed
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.shade300),
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.check_rounded, size: 12, color: Colors.green.shade700),
                                    const SizedBox(width: 3),
                                    Text('Done', style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w700)),
                                  ]),
                                )
                              : TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: color,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    minimumSize: const Size(0, 32),
                                  ),
                                  onPressed: () => onComplete!(id),
                                  child: const Text('Complete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      Positioned(
        right: 16, bottom: 16,
        child: FloatingActionButton.extended(
          heroTag: heroTag,
          onPressed: onRecord,
          backgroundColor: color,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Record', style: TextStyle(color: Colors.white)),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────
// MNS RECORD MODAL (unchanged logic, cleaner UI)
// ─────────────────────────────────────────────────────────
class _MnsRecordModal extends StatefulWidget {
  final String type;
  final int    year;
  final String round;
  final VoidCallback onSaved;

  const _MnsRecordModal({required this.type, required this.year, required this.round, required this.onSaved});

  @override State<_MnsRecordModal> createState() => _MnsRecordModalState();
}

class _MnsRecordModalState extends State<_MnsRecordModal> {
  final _api        = ApiService();
  final _local      = LocalDbService();
  final _searchCtrl = TextEditingController();
  final _dateCtrl   = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
  final _notesCtrl  = TextEditingController();

  Map<String, dynamic>?      _selected;
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _saving    = false;

  String _dosageIu     = '100000';
  String _capsuleColor = 'Blue';
  String _ageGroup     = '6-11 months';
  bool   _completed    = false;

  @override
  void dispose() { _searchCtrl.dispose(); _dateCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  Future<void> _search(String q) async {
    if (q.length < 2) { setState(() => _results = []); return; }
    setState(() => _searching = true);
    try {
      final rows = await _local.getBeneficiaries(search: q, perPage: 10);
      if (rows.isEmpty) {
        final res = await _api.getBeneficiaries(search: q, perPage: 10);
        if (res['success'] == true) {
          setState(() => _results = List<Map<String, dynamic>>.from(res['data']['beneficiaries'] ?? []));
        }
      } else {
        setState(() => _results = rows);
      }
    } catch (_) {}
    if (mounted) setState(() => _searching = false);
  }

  Future<void> _save() async {
    if (_selected == null) { _snack('Select a beneficiary first', false); return; }
    setState(() => _saving = true);
    final Future<Map<String, dynamic>> call;
    if (widget.type == 'vitamina') {
      call = _api.recordVitaminA({
        'beneficiary_id': _selected!['id'], 'distribution_date': _dateCtrl.text,
        'round': widget.round, 'year': widget.year,
        'dosage_iu': int.tryParse(_dosageIu) ?? 100000, 'capsule_color': _capsuleColor,
      });
    } else if (widget.type == 'mnp') {
      call = _api.recordMnp({
        'beneficiary_id': _selected!['id'], 'date_given': _dateCtrl.text,
        'year': widget.year, 'age_group': _ageGroup,
        'completed_routine': _completed ? 1 : 0, 'notes': _notesCtrl.text,
      });
    } else {
      call = _api.recordLnsSq({
        'beneficiary_id': _selected!['id'], 'date_given': _dateCtrl.text,
        'year': widget.year, 'age_group': _ageGroup,
        'completed_routine': _completed ? 1 : 0, 'notes': _notesCtrl.text,
      });
    }
    final res = await call;
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
    _snack(res['message'] ?? 'Done', res['success'] == true);
    if (res['success'] == true) widget.onSaved();
  }

  void _snack(String msg, bool ok) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: ok ? Colors.green : Colors.red, behavior: SnackBarBehavior.floating));

  String get _title => switch (widget.type) { 'vitamina' => 'Record Vitamin A', 'mnp' => 'Record MNP', _ => 'Record LNS-SQ' };

  @override
  Widget build(BuildContext context) => _ModalSheet(
    title: _title, saving: _saving, onSave: _save, saveLabel: 'Save',
    saveColor: const Color(0xFF1565C0),
    children: [
      _BeneficiarySearch(
        ctrl: _searchCtrl, selected: _selected, results: _results, searching: _searching,
        onSearch: _search,
        onSelect: (b) => setState(() {
          _selected = b; _results = [];
          if (b['date_of_birth'] != null) {
            final dob    = DateTime.tryParse(b['date_of_birth'] as String);
            final months = dob != null ? (DateTime.now().year - dob.year) * 12 + (DateTime.now().month - dob.month) : 12;
            _ageGroup = months < 12 ? '6-11 months' : '12-23 months';
          }
        }),
        onClear: () => setState(() { _selected = null; _searchCtrl.clear(); _results = []; }),
      ),
      const SizedBox(height: 12),
      _dateField(context, _dateCtrl, widget.type == 'vitamina' ? 'Distribution Date' : 'Date Given'),
      const SizedBox(height: 12),
      if (widget.type == 'vitamina')
        DropdownButtonFormField<String>(
          value: _dosageIu,
          decoration: const InputDecoration(labelText: 'Dosage', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: '100000', child: Text('100,000 IU (Blue capsule)')),
            DropdownMenuItem(value: '200000', child: Text('200,000 IU (Red capsule)')),
          ],
          onChanged: (v) => setState(() { _dosageIu = v!; _capsuleColor = v == '100000' ? 'Blue' : 'Red'; }),
        )
      else ...[
        DropdownButtonFormField<String>(
          value: _ageGroup,
          decoration: const InputDecoration(labelText: 'Age Group', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: '6-11 months',  child: Text('6–11 months')),
            DropdownMenuItem(value: '12-23 months', child: Text('12–23 months')),
          ],
          onChanged: (v) => setState(() => _ageGroup = v!),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          value: _completed, onChanged: (v) => setState(() => _completed = v),
          title: const Text('Routine Completed', style: TextStyle(fontSize: 14)),
          contentPadding: EdgeInsets.zero,
        ),
        TextField(controller: _notesCtrl,
            decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()), maxLines: 2),
      ],
    ],
  );
}

// ─────────────────────────────────────────────────────────
// OTHERS TAB (Custom Programs)
// ─────────────────────────────────────────────────────────
class _OthersTab extends StatelessWidget {
  final List<dynamic> programs;
  const _OthersTab({required this.programs});

  Color _parseColor(String? hex) {
    if (hex == null) return Colors.indigo;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) { return Colors.indigo; }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: programs.length,
      itemBuilder: (_, i) {
        final p     = programs[i];
        final color = _parseColor(p['color']?.toString());
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => _GenericProgramScreen(program: p),
            )),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.apps_rounded, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['name'] ?? p['code'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  if (p['description'] != null && p['description'].toString().isNotEmpty)
                    Text(p['description'], style: TextStyle(fontSize: 12, color: const Color(0xFF90A4B8)), maxLines: 2),
                  Text('Code: ${p['code'] ?? ''}',
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                ])),
                Icon(Icons.chevron_right_rounded, color: const Color(0xFF4A6080)),
              ]),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// GENERIC PROGRAM SCREEN
// ─────────────────────────────────────────────────────────
class _GenericProgramScreen extends StatefulWidget {
  final Map<String, dynamic> program;
  const _GenericProgramScreen({required this.program});
  @override State<_GenericProgramScreen> createState() => _GenericProgramScreenState();
}

class _GenericProgramScreenState extends State<_GenericProgramScreen> {
  final _api = ApiService();
  int     _year    = DateTime.now().year;
  String? _status;
  bool    _loading = false;
  List<dynamic>        _items  = [];
  Map<String, dynamic> _counts = {};

  String get _code => (widget.program['code'] ?? '').toString().toUpperCase();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = context.read<AuthProvider>().user;
    final brgy = user?.isScopedToBarangay == true ? user?.barangay : null;
    try {
      final res = await _api.getGenericProgram(_code, year: _year, status: _status, barangay: brgy);
      if (res['success'] == true && mounted) {
        final data = res['data'] as Map<String, dynamic>;
        setState(() {
          _items  = List.from(data['enrollments'] ?? []);
          _counts = Map<String, dynamic>.from(data['counts'] ?? {});
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _discharge(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Discharge'),
        content: Text('Discharge ${item['last_name']}, ${item['first_name']} from $_code?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discharge'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final res = await _api.genericDischarge(_code, {
      'id': item['id'], 'status': 'Completed', 'end_date': DateTime.now().toIso8601String().substring(0, 10),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message'] ?? 'Done'),
      backgroundColor: res['success'] == true ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
    if (res['success'] == true) _load();
  }

  void _showEnrollModal() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _GenericEnrollModal(code: _code, year: _year, onSaved: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Colors.indigo;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.program['name'] ?? _code),
        backgroundColor: color,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: Column(children: [
        Container(
          color: color,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(children: [
            Expanded(child: _DropdownFilter<int>(
              hint: 'Year', value: _year,
              items: [DateTime.now().year, DateTime.now().year - 1, DateTime.now().year - 2]
                  .map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
              onChanged: (v) { if (v != null) setState(() => _year = v); _load(); },
            )),
            const SizedBox(width: 8),
            Expanded(child: _DropdownFilter<String>(
              hint: 'All Status', value: _status,
              items: const [
                DropdownMenuItem(value: 'Active',    child: Text('Active')),
                DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                DropdownMenuItem(value: 'Dropped',   child: Text('Dropped')),
              ],
              onChanged: (v) { setState(() => _status = v); _load(); },
            )),
          ]),
        ),
        if (_counts.isNotEmpty)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              _CountChip('Active',    (_counts['Active']    ?? 0).toString(), Colors.blue.shade700),
              const SizedBox(width: 6),
              _CountChip('Completed', (_counts['Completed'] ?? 0).toString(), Colors.green),
              const SizedBox(width: 6),
              _CountChip('Dropped',   (_counts['Dropped']   ?? 0).toString(), Colors.grey),
            ]),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? _emptyState(Icons.apps_rounded, 'No enrollments for $_year')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final e      = _items[i];
                          final status = e['status'] ?? 'Active';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              title: Text('${e['last_name']}, ${e['first_name']}',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('${e['barangay'] ?? ''}  •  Enrolled: ${(e['enrollment_date'] ?? '').toString().substring(0, 10.clamp(0, (e['enrollment_date'] ?? '').toString().length))}'),
                              trailing: status == 'Active'
                                  ? TextButton(
                                      onPressed: () => _discharge(e),
                                      child: const Text('Discharge'),
                                    )
                                  : Text(status, style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600,
                                      color: status == 'Completed' ? Colors.green : Colors.grey)),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showEnrollModal,
        backgroundColor: color,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Enroll', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _GenericEnrollModal extends StatefulWidget {
  final String code;
  final int    year;
  final VoidCallback onSaved;
  const _GenericEnrollModal({required this.code, required this.year, required this.onSaved});
  @override State<_GenericEnrollModal> createState() => _GenericEnrollModalState();
}

class _GenericEnrollModalState extends State<_GenericEnrollModal> {
  final _api        = ApiService();
  final _local      = LocalDbService();
  final _searchCtrl = TextEditingController();
  final _dateCtrl   = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
  final _notesCtrl  = TextEditingController();

  Map<String, dynamic>?      _selected;
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _saving    = false;

  @override
  void dispose() { _searchCtrl.dispose(); _dateCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  Future<void> _search(String q) async {
    if (q.length < 2) { setState(() => _results = []); return; }
    setState(() => _searching = true);
    try {
      final rows = await _local.getBeneficiaries(search: q, perPage: 10);
      if (rows.isEmpty) {
        final res = await _api.getBeneficiaries(search: q, perPage: 10);
        if (res['success'] == true) setState(() => _results = List<Map<String, dynamic>>.from(res['data']['beneficiaries'] ?? []));
      } else { setState(() => _results = rows); }
    } catch (_) {}
    if (mounted) setState(() => _searching = false);
  }

  Future<void> _save() async {
    if (_selected == null) { _snack('Select a beneficiary first', false); return; }
    setState(() => _saving = true);
    final res = await _api.genericEnroll(widget.code, {
      'beneficiary_id': _selected!['id'],
      'enrollment_date': _dateCtrl.text,
      'cycle_year': widget.year,
      'notes': _notesCtrl.text,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
    _snack(res['message'] ?? 'Done', res['success'] == true);
    if (res['success'] == true) widget.onSaved();
  }

  void _snack(String msg, bool ok) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: ok ? Colors.green : Colors.red, behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) => _ModalSheet(
    title: 'Enroll in ${widget.code}',
    saving: _saving, onSave: _save, saveLabel: 'Enroll', saveColor: Colors.indigo,
    children: [
      _BeneficiarySearch(
        ctrl: _searchCtrl, selected: _selected, results: _results, searching: _searching,
        onSearch: _search,
        onSelect: (b) => setState(() { _selected = b; _results = []; }),
        onClear: () => setState(() { _selected = null; _searchCtrl.clear(); _results = []; }),
      ),
      const SizedBox(height: 12),
      _dateField(context, _dateCtrl, 'Enrollment Date'),
      const SizedBox(height: 12),
      TextField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()), maxLines: 2),
    ],
  );
}

// ─────────────────────────────────────────────────────────
// SHARED WIDGETS & HELPERS
// ─────────────────────────────────────────────────────────

Widget _emptyState(IconData icon, String msg) => Center(child: Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Icon(icon, size: 56, color: const Color(0xFF1E3050)),
    const SizedBox(height: 12),
    Text(msg, style: TextStyle(color: const Color(0xFF90A4B8), fontSize: 14)),
  ],
));

Widget _dateField(BuildContext context, TextEditingController ctrl, String label) {
  return TextField(
    controller: ctrl,
    readOnly: true,
    decoration: InputDecoration(
      labelText: label, border: const OutlineInputBorder(),
      suffixIcon: const Icon(Icons.calendar_today_outlined),
    ),
    onTap: () async {
      final picked = await showDatePicker(
        context: context, initialDate: DateTime.now(),
        firstDate: DateTime(2020), lastDate: DateTime.now(),
      );
      if (picked != null) ctrl.text = picked.toIso8601String().substring(0, 10);
    },
  );
}

class _BeneficiarySearch extends StatelessWidget {
  final TextEditingController              ctrl;
  final Map<String, dynamic>?             selected;
  final List<Map<String, dynamic>>        results;
  final bool                              searching;
  final void Function(String)             onSearch;
  final void Function(Map<String, dynamic>) onSelect;
  final VoidCallback                      onClear;

  const _BeneficiarySearch({
    required this.ctrl, required this.selected, required this.results,
    required this.searching, required this.onSearch, required this.onSelect, required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: 'Search Beneficiary',
          hintText: 'Type name…',
          border: const OutlineInputBorder(),
          prefixIcon: searching
              ? const Padding(padding: EdgeInsets.all(12),
                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
              : const Icon(Icons.search),
          suffixIcon: selected != null
              ? IconButton(icon: const Icon(Icons.clear), onPressed: onClear)
              : null,
        ),
        onChanged: (v) { if (selected != null) onClear(); onSearch(v); },
      ),
      if (selected != null) ...[
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            border: Border.all(color: Colors.green.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(
              '${selected!['last_name']}, ${selected!['first_name']}  •  ${selected!['barangay'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            )),
          ]),
        ),
      ],
      if (results.isNotEmpty && selected == null) ...[
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF1E3050)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView(
            shrinkWrap: true,
            children: results.map((b) => ListTile(
              dense: true,
              title: Text('${b['last_name']}, ${b['first_name']}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(b['barangay'] ?? '', style: const TextStyle(fontSize: 11)),
              onTap: () => onSelect(b),
            )).toList(),
          ),
        ),
      ],
    ]);
  }
}

/// Generic bottom-sheet modal wrapper
class _ModalSheet extends StatelessWidget {
  final String       title;
  final bool         saving;
  final VoidCallback onSave;
  final String       saveLabel;
  final Color        saveColor;
  final List<Widget> children;

  const _ModalSheet({
    required this.title, required this.saving, required this.onSave,
    required this.saveLabel, required this.saveColor, required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: const Color(0xFF0B1527),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16, right: 16, top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFF1E3050), borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...children,
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: saveColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: saving ? null : onSave,
              child: saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(saveLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _CountChip(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
      Text(label,  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _DropdownFilter<T> extends StatelessWidget {
  final String hint;
  final T?     value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  const _DropdownFilter({required this.hint, required this.value, required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
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
