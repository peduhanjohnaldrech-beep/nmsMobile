import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class SubmitToAdminScreen extends StatefulWidget {
  const SubmitToAdminScreen({super.key});
  @override
  State<SubmitToAdminScreen> createState() => _State();
}

class _State extends State<SubmitToAdminScreen> {
  final _api = ApiService();

  List<dynamic> _items    = [];
  bool          _loading  = true;
  String?       _error;
  final Set<int> _selected = {};
  bool          _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _selected.clear(); });
    try {
      final res = await _api.getReadyToSubmit();
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() {
          _items   = res['data']?['beneficiaries'] ?? [];
          _loading = false;
        });
      } else {
        setState(() { _error = res['message'] ?? 'Failed to load'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _toggleAll() {
    setState(() {
      if (_selected.length == _items.length) {
        _selected.clear();
      } else {
        _selected.addAll(_items.map((e) => e['id'] as int));
      }
    });
  }

  Future<void> _submitSelected() async {
    if (_selected.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit to Admin'),
        content: Text(
          'Submit ${_selected.length} beneficiar${_selected.length == 1 ? 'y' : 'ies'} to admin?\n\n'
          'They will appear in the admin\'s beneficiary list.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 40),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Submit ${_selected.length}'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    final res = await _api.batchSubmitToAdmin(_selected.toList());
    if (!mounted) return;
    setState(() => _submitting = false);

    final ok = res['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message'] ?? 'Done'),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));

    if (ok) _load();
  }

  String _ageLabel(String? dob) {
    if (dob == null || dob.isEmpty) return '';
    final birth = DateTime.tryParse(dob);
    if (birth == null) return '';
    final months = DateTime.now().difference(birth).inDays ~/ 30;
    if (months < 12) return '${months}mo';
    return '${months ~/ 12}y ${months % 12}mo';
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _items.isNotEmpty && _selected.length == _items.length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _selected.isNotEmpty ? Colors.green.shade700 : null,
        foregroundColor: _selected.isNotEmpty ? Colors.white : null,
        title: _selected.isEmpty
            ? const Text('Submit to Admin')
            : Text('${_selected.length} selected'),
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: _toggleAll,
              child: Text(
                allSelected ? 'Deselect All' : 'Select All',
                style: TextStyle(
                  color: _selected.isNotEmpty ? Colors.white : Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (_selected.isNotEmpty)
            _submitting
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  )
                : IconButton(
                    icon: const Icon(Icons.send_rounded),
                    tooltip: 'Submit selected',
                    onPressed: _submitSelected,
                  ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
                  ]),
                )
              : _items.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.green.shade300),
                        const SizedBox(height: 16),
                        const Text('All done!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          'No validated beneficiaries\nwaiting to be submitted.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: const Color(0xFF90A4B8)),
                        ),
                      ]),
                    )
                  : Column(
                      children: [
                        // Summary banner
                        Container(
                          width: double.infinity,
                          color: const Color(0xFF0A2010),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: Colors.green.shade400),
                            const SizedBox(width: 8),
                            Text(
                              '${_items.length} beneficiar${_items.length == 1 ? 'y' : 'ies'} validated and ready to submit',
                              style: TextStyle(color: Colors.green.shade300, fontSize: 13),
                            ),
                          ]),
                        ),
                        // List
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(12),
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemCount: _items.length,
                            itemBuilder: (ctx, i) {
                              final item     = _items[i];
                              final id       = item['id'] as int;
                              final selected = _selected.contains(id);
                              return GestureDetector(
                                onTap: () => setState(() {
                                  if (selected) _selected.remove(id); else _selected.add(id);
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  decoration: BoxDecoration(
                                    color: selected ? const Color(0xFF0D2A1A) : const Color(0xFF0D1B2E),
                                    border: Border.all(
                                      color: selected ? Colors.green.shade400 : const Color(0xFF1E3A5F),
                                      width: selected ? 1.5 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ListTile(
                                    leading: Checkbox(
                                      value:         selected,
                                      activeColor:   Colors.green,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      onChanged: (_) => setState(() {
                                        if (selected) _selected.remove(id); else _selected.add(id);
                                      }),
                                    ),
                                    title: Text(
                                      '${item['last_name']}, ${item['first_name']}${item['middle_name'] != null && item['middle_name'].toString().isNotEmpty ? ' ${item['middle_name'][0]}.' : ''}',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFFE8F4FD)),
                                    ),
                                    subtitle: Text(
                                      '${item['sex'] ?? ''} · ${_ageLabel(item['date_of_birth'])} · ${item['barangay'] ?? ''}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF90A4B8)),
                                    ),
                                    trailing: selected
                                        ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                                        : Icon(Icons.circle_outlined, color: const Color(0xFF2A4060)),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Bottom action bar
                        if (_selected.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0B1527),
                              border: Border(top: BorderSide(color: Color(0xFF1E3A5F))),
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _submitting ? null : _submitSelected,
                                icon: _submitting
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.send_rounded),
                                label: Text('Submit ${_selected.length} to Admin'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
    );
  }
}
