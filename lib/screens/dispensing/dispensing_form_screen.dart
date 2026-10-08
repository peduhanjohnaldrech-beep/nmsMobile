import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/local_db_service.dart';

class DispensingFormScreen extends StatefulWidget {
  const DispensingFormScreen({super.key});
  @override
  State<DispensingFormScreen> createState() => _DispensingFormScreenState();
}

class _DispensingFormScreenState extends State<DispensingFormScreen> {
  final _api        = ApiService();
  final _local      = LocalDbService();
  final _formKey    = GlobalKey<FormState>();
  final _searchCtrl = TextEditingController();
  final _dateCtrl   = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
  final _qtyCtrl    = TextEditingController(text: '1');
  final _notesCtrl  = TextEditingController();

  Map<String, dynamic>?      _selectedBene;
  List<Map<String, dynamic>> _searchResults = [];
  bool   _searching = false;
  bool   _loading   = false;
  String _program   = 'DSP';
  String _supplementType = 'RUSF';
  String _unit      = 'sachet(s)';

  static const _supplementTypes = {
    'DSP': ['RUSF', 'RUTF', 'Ready-to-Use Food', 'Supplementary Food'],
    'MNS': ['Vitamin A', 'MNP Sachet', 'LNS-SQ', 'Iron Folic Acid'],
    'OPT': ['Vitamin A', 'Iron Supplement'],
  };

  @override
  void dispose() {
    _searchCtrl.dispose();
    _dateCtrl.dispose();
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.length < 2) { setState(() => _searchResults = []); return; }
    setState(() => _searching = true);
    try {
      final rows = await _local.getBeneficiaries(search: q, perPage: 10);
      if (rows.isEmpty) {
        final res = await _api.getBeneficiaries(search: q, perPage: 10);
        if (res['success'] == true) {
          setState(() => _searchResults =
              List<Map<String, dynamic>>.from(res['data']['beneficiaries'] ?? []));
        }
      } else {
        setState(() => _searchResults = rows);
      }
    } catch (_) {}
    if (mounted) setState(() => _searching = false);
  }

  Future<void> _submit() async {
    if (_selectedBene == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a beneficiary first')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final res = await _api.createDispensingRecord({
      'beneficiary_id':  _selectedBene!['id'],
      'program':         _program,
      'supplement_type': _supplementType,
      'quantity':        double.tryParse(_qtyCtrl.text) ?? 1,
      'unit':            _unit,
      'date_dispensed':  _dateCtrl.text,
      'notes':           _notesCtrl.text,
    });
    setState(() => _loading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message'] ?? 'Done'),
      backgroundColor: res['success'] == true ? Colors.green : Colors.red,
    ));
    if (res['success'] == true) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final types = _supplementTypes[_program] ?? [];
    if (!types.contains(_supplementType)) _supplementType = types.first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Dispensing'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [

          // ── Beneficiary search ────────────────────────────
          const Text('Beneficiary', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8FA8BF))),
          const SizedBox(height: 6),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search by last name or first name…',
              prefixIcon: _searching
                  ? const Padding(padding: EdgeInsets.all(12),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                  : const Icon(Icons.search),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              suffixIcon: _selectedBene != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() {
                        _selectedBene  = null;
                        _searchCtrl.clear();
                        _searchResults = [];
                      }),
                    )
                  : null,
            ),
            onChanged: (v) { if (_selectedBene != null) setState(() => _selectedBene = null); _search(v); },
          ),

          if (_selectedBene != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  '${_selectedBene!['last_name']}, ${_selectedBene!['first_name']} • ${_selectedBene!['barangay'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                )),
              ]),
            ),
          ],

          if (_searchResults.isNotEmpty && _selectedBene == null) ...[
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF1E3050)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView(
                shrinkWrap: true,
                children: _searchResults.map((b) => ListTile(
                  dense: true,
                  title: Text('${b['last_name']}, ${b['first_name']}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(b['barangay'] ?? '', style: const TextStyle(fontSize: 11)),
                  onTap: () => setState(() {
                    _selectedBene  = b;
                    _searchCtrl.text = '${b['last_name']}, ${b['first_name']}';
                    _searchResults = [];
                  }),
                )).toList(),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // ── Program ───────────────────────────────────────
          DropdownButtonFormField<String>(
            value: _program,
            decoration: const InputDecoration(labelText: 'Program', border: OutlineInputBorder()),
            items: ['DSP', 'MNS', 'OPT']
                .map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (v) => setState(() {
              _program = v!;
              _supplementType = (_supplementTypes[_program] ?? []).first;
            }),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: _supplementType,
            decoration: const InputDecoration(labelText: 'Supplement / Item', border: OutlineInputBorder()),
            items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => _supplementType = v!),
          ),
          const SizedBox(height: 12),

          // ── Quantity & unit ───────────────────────────────
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _qtyCtrl,
                decoration: const InputDecoration(labelText: 'Quantity *', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _unit,
                decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
                items: ['sachet(s)', 'bottle(s)', 'piece(s)', 'pack(s)', 'capsule(s)']
                    .map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (v) => setState(() => _unit = v!),
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // ── Date ─────────────────────────────────────────
          TextFormField(
            controller: _dateCtrl,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Date Dispensed *',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today_outlined),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _dateCtrl.text = picked.toIso8601String().substring(0, 10));
            },
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _notesCtrl,
            decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
            maxLines: 2,
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Record', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}
