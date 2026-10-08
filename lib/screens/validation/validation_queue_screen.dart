import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class ValidationQueueScreen extends StatefulWidget {
  const ValidationQueueScreen({super.key});
  @override State<ValidationQueueScreen> createState() => _State();
}

class _State extends State<ValidationQueueScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabs;

  List<dynamic> _assessments   = [];
  List<dynamic> _beneficiaries = [];
  bool   _loading   = true;
  String? _error;

  // Selection state
  final Set<int> _selectedAssessments   = {};
  final Set<int> _selectedBeneficiaries = {};
  bool _batchValidating = false;

  // Per-item loading
  final Set<int> _validatingAssessments   = {};
  final Set<int> _validatingBeneficiaries = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {
        _selectedAssessments.clear();
        _selectedBeneficiaries.clear();
      }));
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _selectedAssessments.clear(); _selectedBeneficiaries.clear(); });
    try {
      final results = await Future.wait([
        _api.getValidationPending(),
        _api.getBeneficiaryValidationPending(),
      ]);
      if (!mounted) return;
      setState(() {
        _assessments   = results[0]['data']?['assessments']   ?? [];
        _beneficiaries = results[1]['data']?['beneficiaries'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── INDIVIDUAL ACTIONS ──────────────────────────────────

  Future<void> _rejectAssessment(Map<String, dynamic> item) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.cancel_outlined, color: Colors.red.shade600, size: 22),
          const SizedBox(width: 8),
          const Text('Reject Assessment'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            '${item['last_name']}, ${item['first_name']}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            '${item['period']} ${item['assessment_year']}  •  ${item['nutritional_status'] ?? ''}',
            style: TextStyle(fontSize: 12, color: const Color(0xFF90A4B8)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: noteCtrl,
            decoration: InputDecoration(
              labelText: 'Reason for rejection *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(12),
            ),
            maxLines: 3,
            autofocus: true,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (noteCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final res = await _api.rejectAssessment(item['id'] as int, noteCtrl.text.trim());
    if (!mounted) return;
    _showSnack(res['message'] ?? 'Done', res['success'] == true);
    if (res['success'] == true) _load();
  }

  Future<void> _rejectBeneficiary(Map<String, dynamic> item) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.person_off_outlined, color: Colors.red.shade600, size: 22),
          const SizedBox(width: 8),
          const Text('Reject Registration'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            '${item['last_name']}, ${item['first_name']}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            '${item['barangay'] ?? ''}  •  ${item['sex'] ?? ''}',
            style: TextStyle(fontSize: 12, color: const Color(0xFF90A4B8)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: noteCtrl,
            decoration: InputDecoration(
              labelText: 'Reason for rejection *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(12),
            ),
            maxLines: 3,
            autofocus: true,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (noteCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final res = await _api.rejectBeneficiaryRecord(item['id'] as int, noteCtrl.text.trim());
    if (!mounted) return;
    _showSnack(res['message'] ?? 'Done', res['success'] == true);
    if (res['success'] == true) _load();
  }

  // ── BATCH VALIDATE ──────────────────────────────────────

  Future<void> _batchValidateSelected() async {
    final isAssessTab = _tabs.index == 0;
    final selected    = isAssessTab ? _selectedAssessments : _selectedBeneficiaries;
    final type        = isAssessTab ? 'assessment' : 'beneficiary';
    final label       = isAssessTab ? 'assessment' : 'beneficiary';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batch Validate'),
        content: Text(
          'Validate ${selected.length} selected ${label}${selected.length > 1 ? 's' : ''}?\n\n'
          'This will approve all selected records.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(80, 40)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Validate ${selected.length}'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _batchValidating = true);
    final res = await _api.batchValidate(type: type, ids: selected.toList());
    if (!mounted) return;
    setState(() => _batchValidating = false);

    _showSnack(res['message'] ?? 'Done', res['success'] == true);
    if (res['success'] == true) _load();
  }

  void _showSnack(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── HELPERS ─────────────────────────────────────────────

  Widget _statusBadge(String? status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors[0],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(status,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors[1])),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.length < 10) return '—';
    return raw.substring(0, 10);
  }

  // ── BUILD ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final aCount = _assessments.length;
    final bCount = _beneficiaries.length;

    final isAssessTab   = _tabs.index == 0;
    final selectedCount = isAssessTab ? _selectedAssessments.length : _selectedBeneficiaries.length;
    final totalCount    = isAssessTab ? aCount : bCount;

    return Scaffold(
      appBar: AppBar(
        title: selectedCount > 0
            ? Text('$selectedCount selected')
            : const Text('Validation Queue'),
        backgroundColor: selectedCount > 0 ? Colors.green.shade700 : const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          if (selectedCount > 0) ...[
            TextButton.icon(
              onPressed: _batchValidating ? null : _batchValidateSelected,
              icon: _batchValidating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              label: Text(
                'Validate $selectedCount',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 4),
          ] else if (totalCount > 0) ...[
            TextButton(
              onPressed: () => setState(() {
                if (isAssessTab) {
                  if (_selectedAssessments.length == aCount) {
                    _selectedAssessments.clear();
                  } else {
                    _selectedAssessments.addAll(_assessments.map((a) => a['id'] as int));
                  }
                } else {
                  if (_selectedBeneficiaries.length == bCount) {
                    _selectedBeneficiaries.clear();
                  } else {
                    _selectedBeneficiaries.addAll(_beneficiaries.map((b) => b['id'] as int));
                  }
                }
              }),
              child: Text(
                (isAssessTab ? _selectedAssessments.length == aCount : _selectedBeneficiaries.length == bCount)
                    ? 'Deselect All'
                    : 'Select All',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'Assessments ($aCount)'),
            Tab(text: 'Beneficiaries ($bCount)'),
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
                    _buildAssessmentList(),
                    _buildBeneficiaryList(),
                  ]),
                ),
    );
  }

  Widget _buildAssessmentList() {
    if (_assessments.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.fact_check_rounded, size: 64, color: Colors.green.shade300),
        const SizedBox(height: 12),
        const Text('All assessments validated!',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF388E3C))),
        const SizedBox(height: 4),
        Text('No pending assessments to review.',
            style: TextStyle(fontSize: 13, color: const Color(0xFF90A4B8))),
      ]));
    }

    return ListView.builder(
      itemCount: _assessments.length,
      padding: const EdgeInsets.only(bottom: 20),
      itemBuilder: (_, i) {
        final a          = _assessments[i];
        final id         = a['id'] as int;
        final isSelected = _selectedAssessments.contains(id);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          color: isSelected ? Colors.green.shade50 : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: isSelected ? BorderSide(color: Colors.green.shade400, width: 1.5) : BorderSide.none,
          ),
          child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: isSelected,
                    activeColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (_) => setState(() {
                      if (isSelected) _selectedAssessments.remove(id);
                      else _selectedAssessments.add(id);
                    }),
                  ),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(
                          '${a['last_name']}, ${a['first_name']}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        )),
                        _statusBadge(a['nutritional_status']?.toString()),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.location_on_outlined, size: 12, color: const Color(0xFF607896)),
                        const SizedBox(width: 2),
                        Text('${a['barangay']}  •  ${a['sex'] ?? ''}  •  ${a['age_in_months'] ?? '—'} months',
                            style: TextStyle(fontSize: 12, color: const Color(0xFF90A4B8))),
                      ]),
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.monitor_weight_outlined, size: 12, color: const Color(0xFF607896)),
                        const SizedBox(width: 2),
                        Text('${a['weight_kg']} kg${a['height_cm'] != null ? '  •  ${a['height_cm']} cm' : ''}  •  ${a['period']} ${a['assessment_year']}',
                            style: TextStyle(fontSize: 12, color: const Color(0xFFB0BEC5))),
                      ]),
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.person_outline, size: 12, color: const Color(0xFF607896)),
                        const SizedBox(width: 2),
                        Text('By: ${a['submitted_by_name'] ?? a['assessed_by'] ?? '—'}  •  ${_formatDate(a['assessment_date']?.toString())}',
                            style: TextStyle(fontSize: 12, color: const Color(0xFF90A4B8))),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade200),
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 15),
                          label: const Text('Reject', style: TextStyle(fontSize: 13)),
                          onPressed: () => _rejectAssessment(a),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: _validatingAssessments.contains(id)
                              ? const SizedBox(width: 14, height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_rounded, size: 15),
                          label: const Text('Validate', style: TextStyle(fontSize: 13)),
                          onPressed: _validatingAssessments.contains(id) ? null : () async {
                            setState(() => _validatingAssessments.add(id));
                            final res = await _api.validateAssessment(id);
                            if (!mounted) return;
                            setState(() => _validatingAssessments.remove(id));
                            _showSnack(res['message'] ?? 'Done', res['success'] == true);
                            if (res['success'] == true) _load();
                          },
                        )),
                      ]),
                    ]),
                  ),
                ],
              ),
            ),
        );
      },
    );
  }

  Widget _buildBeneficiaryList() {
    if (_beneficiaries.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.how_to_reg_rounded, size: 64, color: Colors.green.shade300),
        const SizedBox(height: 12),
        const Text('All registrations validated!',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF388E3C))),
        const SizedBox(height: 4),
        Text('No pending beneficiaries to review.',
            style: TextStyle(fontSize: 13, color: const Color(0xFF90A4B8))),
      ]));
    }

    return ListView.builder(
      itemCount: _beneficiaries.length,
      padding: const EdgeInsets.only(bottom: 20),
      itemBuilder: (_, i) {
        final b          = _beneficiaries[i];
        final id         = b['id'] as int;
        final isSelected = _selectedBeneficiaries.contains(id);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          color: isSelected ? Colors.green.shade50 : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: isSelected ? BorderSide(color: Colors.green.shade400, width: 1.5) : BorderSide.none,
          ),
          child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: isSelected,
                    activeColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (_) => setState(() {
                      if (isSelected) _selectedBeneficiaries.remove(id);
                      else _selectedBeneficiaries.add(id);
                    }),
                  ),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(
                          '${b['last_name']}, ${b['first_name']}${b['middle_name'] != null && b['middle_name'].toString().isNotEmpty ? ' ${b['middle_name'][0]}.' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        )),
                        _pendingBadge(),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.location_on_outlined, size: 12, color: const Color(0xFF607896)),
                        const SizedBox(width: 2),
                        Text(
                          '${b['barangay']}${b['purok_zone'] != null ? ' • Purok ${b['purok_zone']}' : ''}',
                          style: TextStyle(fontSize: 12, color: const Color(0xFF90A4B8)),
                        ),
                      ]),
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.cake_outlined, size: 12, color: const Color(0xFF607896)),
                        const SizedBox(width: 2),
                        Text('${b['date_of_birth'] ?? '—'}  •  ${b['sex'] ?? '—'}',
                            style: TextStyle(fontSize: 12, color: const Color(0xFFB0BEC5))),
                      ]),
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.person_outline, size: 12, color: const Color(0xFF607896)),
                        const SizedBox(width: 2),
                        Text('Submitted by: ${b['submitted_by_name'] ?? '—'}  •  ${_formatDate(b['created_at']?.toString())}',
                            style: TextStyle(fontSize: 12, color: const Color(0xFF90A4B8))),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade200),
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 15),
                          label: const Text('Reject', style: TextStyle(fontSize: 13)),
                          onPressed: () => _rejectBeneficiary(b),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: _validatingBeneficiaries.contains(id)
                              ? const SizedBox(width: 14, height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_rounded, size: 15),
                          label: const Text('Validate', style: TextStyle(fontSize: 13)),
                          onPressed: _validatingBeneficiaries.contains(id) ? null : () async {
                            setState(() => _validatingBeneficiaries.add(id));
                            final res = await _api.validateBeneficiaryRecord(id);
                            if (!mounted) return;
                            setState(() => _validatingBeneficiaries.remove(id));
                            _showSnack(res['message'] ?? 'Done', res['success'] == true);
                            if (res['success'] == true) _load();
                          },
                        )),
                      ]),
                    ]),
                  ),
                ],
              ),
            ),
        );
      },
    );
  }

  Widget _pendingBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(12)),
    child: const Text('Pending', style: TextStyle(color: Color(0xFFE65100), fontSize: 11, fontWeight: FontWeight.bold)),
  );
}
