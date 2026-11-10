import 'package:flutter/material.dart';
import '../../models/beneficiary_model.dart';
import '../../services/api_service.dart';
import '../beneficiaries/beneficiary_detail_screen.dart';


class ValidationQueueScreen extends StatefulWidget {
  const ValidationQueueScreen({super.key});
  @override State<ValidationQueueScreen> createState() => _State();
}

class _State extends State<ValidationQueueScreen> {
  final _api = ApiService();

  List<dynamic> _beneficiaries = [];
  bool   _loading = true;
  String? _error;

  final Set<int> _selectedBeneficiaries = {};
  bool _batchValidating = false;
  final Set<int> _validatingBeneficiaries = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _selectedBeneficiaries.clear(); });
    try {
      final res = await _api.getBeneficiaryValidationPending();
      if (!mounted) return;
      setState(() {
        _beneficiaries = res['data']?['beneficiaries'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── REJECT ───────────────────────────────────────────────

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

  // ── BATCH VALIDATE ──────────────────────────────────────

  Future<void> _batchValidateSelected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batch Validate'),
        content: Text(
          'Validate ${_selectedBeneficiaries.length} selected '
          'beneficiar${_selectedBeneficiaries.length > 1 ? 'ies' : 'y'}?\n\n'
          'This will approve all selected registrations.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(80, 40)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Validate ${_selectedBeneficiaries.length}'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _batchValidating = true);
    final res = await _api.batchValidate(type: 'beneficiary', ids: _selectedBeneficiaries.toList());
    if (!mounted) return;
    setState(() => _batchValidating = false);
    _showSnack(res['message'] ?? 'Done', res['success'] == true);
    if (mounted) _load();
  }

  void _showSnack(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _openBeneficiaryDetail(Map<String, dynamic> b) async {
    final model = BeneficiaryModel.fromJson(b);
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => BeneficiaryDetailScreen(beneficiary: model)),
    );
    if (result == true && mounted) _load();
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.length < 10) return '—';
    return raw.substring(0, 10);
  }

  // ── BUILD ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bCount       = _beneficiaries.length;
    final selectedCount = _selectedBeneficiaries.length;

    return Scaffold(
      appBar: AppBar(
        title: selectedCount > 0
            ? Text('$selectedCount selected')
            : Text('Validation Queue${bCount > 0 ? ' ($bCount)' : ''}'),
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
          ] else if (bCount > 0) ...[
            TextButton(
              onPressed: () => setState(() {
                if (_selectedBeneficiaries.length == bCount) {
                  _selectedBeneficiaries.clear();
                } else {
                  _selectedBeneficiaries.addAll(_beneficiaries.map((b) => b['id'] as int));
                }
              }),
              child: Text(
                _selectedBeneficiaries.length == bCount ? 'Deselect All' : 'Select All',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ],
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
                  child: _buildBeneficiaryList(),
                ),
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
}
