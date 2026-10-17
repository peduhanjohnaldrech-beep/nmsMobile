import 'package:flutter/material.dart';
import '../../models/beneficiary_model.dart';
import '../../services/api_service.dart';
import '../beneficiaries/beneficiary_detail_screen.dart';
import '../beneficiaries/submit_to_admin_screen.dart';

class ValidationQueueScreen extends StatefulWidget {
  const ValidationQueueScreen({super.key});
  @override State<ValidationQueueScreen> createState() => _State();
}

class _State extends State<ValidationQueueScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabs;

  List<dynamic> _assessments    = [];
  List<dynamic> _beneficiaries  = [];
  List<dynamic> _dspMonitoring  = [];
  bool   _loading   = true;
  String? _error;

  // Selection state
  final Set<int> _selectedAssessments   = {};
  final Set<int> _selectedBeneficiaries = {};
  final Set<int> _selectedDsp           = {};
  bool _batchValidating = false;

  // Per-item loading
  final Set<int> _validatingAssessments   = {};
  final Set<int> _validatingBeneficiaries = {};
  final Set<int> _validatingDsp           = {};

  int _readyToSubmitCount = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this)
      ..addListener(() => setState(() {
        _selectedAssessments.clear();
        _selectedBeneficiaries.clear();
        _selectedDsp.clear();
      }));
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _selectedAssessments.clear(); _selectedBeneficiaries.clear(); _selectedDsp.clear(); });
    try {
      final results = await Future.wait([
        _api.getValidationPending(),
        _api.getBeneficiaryValidationPending(),
        _api.getDspMonitoringPending(),
      ]);
      if (!mounted) return;
      setState(() {
        _assessments   = results[0]['data']?['assessments']   ?? [];
        _beneficiaries = results[1]['data']?['beneficiaries'] ?? [];
        _dspMonitoring = results[2]['data']?['records']       ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
    _loadReadyToSubmitCount();
  }

  Future<void> _loadReadyToSubmitCount() async {
    try {
      final res = await _api.getReadyToSubmit();
      if (!mounted) return;
      final list = res['data']?['beneficiaries'] as List? ?? [];
      setState(() => _readyToSubmitCount = list.length);
    } catch (_) {}
  }

  // ── INDIVIDUAL ACTIONS ──────────────────────────────────

  Future<void> _rejectAssessment(Map<String, dynamic> item) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.reply_rounded, color: Colors.orange.shade700, size: 22),
          const SizedBox(width: 8),
          const Text('Return for Correction'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            '${item['last_name']}, ${item['first_name']}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            '${item['period']} ${item['assessment_year']}  •  ${item['nutritional_status'] ?? ''}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF90A4B8)),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0x33FF9100),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x7FFF9100)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 14, color: Color(0xFFFFB74D)),
              const SizedBox(width: 6),
              Expanded(child: Text(
                'This will be sent back to the BHW for correction.',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade300),
              )),
            ]),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteCtrl,
            decoration: InputDecoration(
              labelText: 'Note to BHW *',
              hintText: 'e.g. Weight seems incorrect, please re-measure',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(12),
            ),
            maxLines: 3,
            autofocus: true,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (noteCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            icon: const Icon(Icons.reply_rounded, size: 16),
            label: const Text('Return'),
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
          Icon(Icons.reply_rounded, color: Colors.orange.shade700, size: 22),
          const SizedBox(width: 8),
          const Text('Return for Correction'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            '${item['last_name']}, ${item['first_name']}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            '${item['barangay'] ?? ''}  •  ${item['sex'] ?? ''}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF90A4B8)),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0x33FF9100),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x7FFF9100)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 14, color: Color(0xFFFFB74D)),
              const SizedBox(width: 6),
              Expanded(child: Text(
                'This will be sent back to the BHW for correction.',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade300),
              )),
            ]),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteCtrl,
            decoration: InputDecoration(
              labelText: 'Note to BHW *',
              hintText: 'e.g. Date of birth does not match health card',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(12),
            ),
            maxLines: 3,
            autofocus: true,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (noteCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            icon: const Icon(Icons.reply_rounded, size: 16),
            label: const Text('Return'),
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

  Future<void> _rejectDspMonitoring(Map<String, dynamic> item) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.reply_rounded, color: Colors.orange.shade700, size: 22),
          const SizedBox(width: 8),
          const Text('Return for Correction'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            '${item['last_name']}, ${item['first_name']}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'DSP Follow-up  \u2022  ${(item['monitoring_date'] ?? '').toString().substring(0, 10)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF90A4B8)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteCtrl,
            decoration: InputDecoration(
              labelText: 'Note *',
              hintText: 'e.g. Weight seems incorrect, please re-measure',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(12),
            ),
            maxLines: 3,
            autofocus: true,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (noteCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            icon: const Icon(Icons.reply_rounded, size: 16),
            label: const Text('Return'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final res = await _api.rejectDspMonitoring(item['id'] as int, noteCtrl.text.trim());
    if (!mounted) return;
    _showSnack(res['message'] ?? 'Done', res['success'] == true);
    if (res['success'] == true) _load();
  }

  // ── BATCH VALIDATE ──────────────────────────────────────

  Future<void> _batchValidateSelected() async {
    final isDspTab    = _tabs.index == 2;
    final isAssessTab = _tabs.index == 0;
    final selected    = isAssessTab ? _selectedAssessments : isDspTab ? _selectedDsp : _selectedBeneficiaries;
    final label       = isAssessTab ? 'assessment' : isDspTab ? 'DSP follow-up' : 'beneficiary';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batch Validate'),
        content: Text(
          'Validate ${selected.length} selected $label${selected.length > 1 ? 's' : ''}?\n\n'
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

    if (isDspTab) {
      int ok = 0;
      for (final id in selected.toList()) {
        final res = await _api.validateDspMonitoring(id);
        if (res['success'] == true) ok++;
      }
      if (!mounted) return;
      setState(() => _batchValidating = false);
      _showSnack('Validated $ok DSP follow-up${ok != 1 ? 's' : ''}', ok > 0);
    } else {
      final type = isAssessTab ? 'assessment' : 'beneficiary';
      final res  = await _api.batchValidate(type: type, ids: selected.toList());
      if (!mounted) return;
      setState(() => _batchValidating = false);
      _showSnack(res['message'] ?? 'Done', res['success'] == true);
    }

    if (mounted) _load();
  }

  void _showSnack(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── DETAIL / EDIT ────────────────────────────────────────

  Future<void> _openBeneficiaryDetail(Map<String, dynamic> b) async {
    final model = BeneficiaryModel.fromJson(b);
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => BeneficiaryDetailScreen(beneficiary: model)),
    );
    if (result == true && mounted) _load();
  }

  /// Opens full child profile from an assessment map (fetches beneficiary by ID).
  Future<void> _openProfileFromAssessment(Map<String, dynamic> a) async {
    final beneficiaryId = int.tryParse(a['beneficiary_id'].toString());
    if (beneficiaryId == null) {
      _showSnack('Cannot open profile', false);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Loading profile...'),
      duration: Duration(seconds: 10),
      behavior: SnackBarBehavior.floating,
    ));
    try {
      final res = await _api.getBeneficiary(beneficiaryId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (res['success'] != true) {
        _showSnack(res['message'] ?? 'Failed to load profile', false);
        return;
      }
      final beneData = (res['data'] as Map<String, dynamic>?)?['beneficiary'] as Map<String, dynamic>?;
      if (beneData == null) {
        _showSnack('Beneficiary not found', false);
        return;
      }
      final model = BeneficiaryModel.fromJson(beneData);
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => BeneficiaryDetailScreen(beneficiary: model)),
      );
      if (result == true && mounted) _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showSnack('Error: $e', false);
      }
    }
  }

  // ── HELPERS ─────────────────────────────────────────────

  Widget _statusBadge(String? status) {
    if (status == null || status.isEmpty) return const SizedBox.shrink();
    final Map<String, List<Color>> map = {
      'SUW':    [const Color(0x33FF4757), const Color(0xFFFF6B7A)],
      'UW':     [const Color(0x33FF9100), const Color(0xFFFFB74D)],
      'Normal': [const Color(0x334CAF50), const Color(0xFF69F0AE)],
      'OW':     [const Color(0x33FFD740), const Color(0xFFFFD740)],
      'OB':     [const Color(0x337B61FF), const Color(0xFFCE93D8)],
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
    final dCount = _dspMonitoring.length;

    final isDspTab      = _tabs.index == 2;
    final isAssessTab   = _tabs.index == 0;
    final selectedCount = isAssessTab ? _selectedAssessments.length : isDspTab ? _selectedDsp.length : _selectedBeneficiaries.length;
    final totalCount    = isAssessTab ? aCount : isDspTab ? dCount : bCount;

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
                } else if (isDspTab) {
                  if (_selectedDsp.length == dCount) {
                    _selectedDsp.clear();
                  } else {
                    _selectedDsp.addAll(_dspMonitoring.map((d) => d['id'] as int));
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
                (isAssessTab ? _selectedAssessments.length == aCount
                    : isDspTab ? _selectedDsp.length == dCount
                    : _selectedBeneficiaries.length == bCount)
                    ? 'Deselect All' : 'Select All',
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
            Tab(text: 'DSP Follow-ups ($dCount)'),
          ],
        ),
      ),
      floatingActionButton: !_loading && _tabs.index == 1 && _readyToSubmitCount > 0
          ? FloatingActionButton.extended(
              heroTag: 'fab_submit_admin',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubmitToAdminScreen()),
              ).then((_) => _loadReadyToSubmitCount()),
              icon: const Icon(Icons.send_rounded),
              label: Text('Submit to Admin ($_readyToSubmitCount)'),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            )
          : null,
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
                    _buildAssessmentList(),
                    _buildBeneficiaryList(),
                    _buildDspMonitoringList(),
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
        const Text('No pending assessments to review.',
            style: TextStyle(fontSize: 13, color: Color(0xFF90A4B8))),
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
          color: isSelected ? const Color(0xFF0D2018) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: isSelected ? BorderSide(color: Colors.green.shade400, width: 1.5) : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _openProfileFromAssessment(a),
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
                      if (isSelected) {
                        _selectedAssessments.remove(id);
                      } else {
                        _selectedAssessments.add(id);
                      }
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
                        const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF607896)),
                        const SizedBox(width: 2),
                        Text('${a['barangay']}  •  ${a['sex'] ?? ''}  •  ${a['age_in_months'] ?? '—'} months',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF90A4B8))),
                      ]),
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.monitor_weight_outlined, size: 12, color: Color(0xFF607896)),
                        const SizedBox(width: 2),
                        Text('${a['weight_kg']} kg${a['height_cm'] != null ? '  •  ${a['height_cm']} cm' : ''}  •  ${a['period']} ${a['assessment_year']}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFFB0BEC5))),
                      ]),
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.person_outline, size: 12, color: Color(0xFF607896)),
                        const SizedBox(width: 2),
                        Text('By: ${a['submitted_by_name'] ?? a['assessed_by'] ?? '—'}  •  ${_formatDate(a['assessment_date']?.toString())}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF90A4B8))),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue.shade700,
                            side: BorderSide(color: Colors.blue.shade200),
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 15),
                          label: const Text('Edit', style: TextStyle(fontSize: 13)),
                          onPressed: () => _openProfileFromAssessment(a),
                        )),
                        const SizedBox(width: 6),
                        Expanded(child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade700,
                            side: BorderSide(color: Colors.orange.shade200),
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.reply_rounded, size: 15),
                          label: const Text('Return', style: TextStyle(fontSize: 13)),
                          onPressed: () => _rejectAssessment(a),
                        )),
                        const SizedBox(width: 6),
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
        const Text('No pending beneficiaries to review.',
            style: TextStyle(fontSize: 13, color: Color(0xFF90A4B8))),
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
          color: isSelected ? const Color(0xFF0D2018) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: isSelected ? BorderSide(color: Colors.green.shade400, width: 1.5) : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _openBeneficiaryDetail(b),
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
                      if (isSelected) {
                        _selectedBeneficiaries.remove(id);
                      } else {
                        _selectedBeneficiaries.add(id);
                      }
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
                        const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF607896)),
                        const SizedBox(width: 2),
                        Text(
                          '${b['barangay']}${b['purok_zone'] != null ? ' • Purok ${b['purok_zone']}' : ''}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF90A4B8)),
                        ),
                      ]),
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.cake_outlined, size: 12, color: Color(0xFF607896)),
                        const SizedBox(width: 2),
                        Text('${b['date_of_birth'] ?? '—'}  •  ${b['sex'] ?? '—'}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFFB0BEC5))),
                      ]),
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.person_outline, size: 12, color: Color(0xFF607896)),
                        const SizedBox(width: 2),
                        Text('Submitted by: ${b['submitted_by_name'] ?? '—'}  •  ${_formatDate(b['created_at']?.toString())}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF90A4B8))),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue.shade700,
                            side: BorderSide(color: Colors.blue.shade200),
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 15),
                          label: const Text('Edit', style: TextStyle(fontSize: 13)),
                          onPressed: () => _openBeneficiaryDetail(b),
                        )),
                        const SizedBox(width: 6),
                        Expanded(child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade700,
                            side: BorderSide(color: Colors.orange.shade200),
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.reply_rounded, size: 15),
                          label: const Text('Return', style: TextStyle(fontSize: 13)),
                          onPressed: () => _rejectBeneficiary(b),
                        )),
                        const SizedBox(width: 6),
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
          ),
        );
      },
    );
  }

  Widget _pendingBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: const Color(0x33FF9100), borderRadius: BorderRadius.circular(12)),
    child: const Text('Pending', style: TextStyle(color: Color(0xFFFFB74D), fontSize: 11, fontWeight: FontWeight.bold)),
  );

  Widget _buildDspMonitoringList() {
    if (_dspMonitoring.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.monitor_weight_outlined, size: 64, color: Colors.green.shade300),
        const SizedBox(height: 12),
        const Text('All follow-ups validated!',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF388E3C))),
        const SizedBox(height: 4),
        const Text('No pending DSP follow-up records.',
            style: TextStyle(fontSize: 13, color: Color(0xFF90A4B8))),
      ]));
    }

    return ListView.builder(
      itemCount: _dspMonitoring.length,
      padding: const EdgeInsets.only(bottom: 20),
      itemBuilder: (_, i) {
        final d          = _dspMonitoring[i];
        final id         = d['id'] as int;
        final isSelected = _selectedDsp.contains(id);
        final date       = (d['monitoring_date'] ?? '').toString();
        final dateShort  = date.length >= 10 ? date.substring(0, 10) : date;

        Color statusBg   = const Color(0xFF1A2A3A);
        Color statusFg   = const Color(0xFFB0BEC5);
        final ns = d['nutritional_status']?.toString() ?? '';
        if (ns == 'SUW')    { statusBg = const Color(0x33FF4757); statusFg = const Color(0xFFFF6B7A); }
        else if (ns == 'UW'){ statusBg = const Color(0x33FF9100); statusFg = const Color(0xFFFFB74D); }
        else if (ns == 'Normal') { statusBg = const Color(0x334CAF50); statusFg = const Color(0xFF69F0AE); }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          color: isSelected ? const Color(0xFF0D2018) : null,
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
                    if (isSelected) {
                      _selectedDsp.remove(id);
                    } else {
                      _selectedDsp.add(id);
                    }
                  }),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(
                        '${d['last_name']}, ${d['first_name']}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      )),
                      if (ns.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
                          child: Text(ns, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusFg)),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF607896)),
                      const SizedBox(width: 2),
                      Text('${d['barangay']}  \u2022  ${d['intervention_type'] ?? 'DSP'}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF90A4B8))),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.monitor_weight_outlined, size: 12, color: Color(0xFF607896)),
                      const SizedBox(width: 2),
                      Text(
                        '${d['weight_kg']} kg'
                        '${d['height_cm'] != null ? "  \u2022  ${d['height_cm']} cm" : ""}'
                        '${d['muac_cm'] != null ? "  \u2022  MUAC ${d['muac_cm']} cm" : ""}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFB0BEC5)),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.person_outline, size: 12, color: Color(0xFF607896)),
                      const SizedBox(width: 2),
                      Text('By: ${d['monitored_by'] ?? d['submitted_by_name'] ?? '\u2014'}  \u2022  $dateShort',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF90A4B8))),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange.shade700,
                          side: BorderSide(color: Colors.orange.shade200),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 36),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.reply_rounded, size: 15),
                        label: const Text('Return', style: TextStyle(fontSize: 13)),
                        onPressed: () => _rejectDspMonitoring(d),
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
                        icon: _validatingDsp.contains(id)
                            ? const SizedBox(width: 14, height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_rounded, size: 15),
                        label: const Text('Validate', style: TextStyle(fontSize: 13)),
                        onPressed: _validatingDsp.contains(id) ? null : () async {
                          setState(() => _validatingDsp.add(id));
                          final res = await _api.validateDspMonitoring(id);
                          if (!mounted) return;
                          setState(() => _validatingDsp.remove(id));
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

}