import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class ProgramManagerScreen extends StatefulWidget {
  const ProgramManagerScreen({super.key});
  @override State<ProgramManagerScreen> createState() => _State();
}

class _State extends State<ProgramManagerScreen> {
  final _api = ApiService();
  List<dynamic> _programs = [];
  bool _loading = true;
  String? _error;

  static const _builtIn = ['OPT', 'DSP', 'MNS'];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.getProgramsAdmin();
      if (res['success'] == true) {
        setState(() { _programs = res['data']['programs'] ?? []; _loading = false; });
      } else {
        setState(() { _error = res['message']; _loading = false; });
      }
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  Future<void> _toggle(Map<String, dynamic> p) async {
    final res = await _api.toggleProgram(p['id'] as int);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Done')));
      if (res['success'] == true) _load();
    }
  }

  void _showForm({Map<String, dynamic>? prog}) {
    final codeCtrl  = TextEditingController(text: prog?['code'] ?? '');
    final nameCtrl  = TextEditingController(text: prog?['name'] ?? '');
    final descCtrl  = TextEditingController(text: prog?['description'] ?? '');
    final orderCtrl = TextEditingController(text: prog?['sort_order']?.toString() ?? '0');
    bool isActive   = (prog?['is_active'] ?? 1) == 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => StatefulBuilder(
          builder: (ctx2, ss) => Column(children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
                Text(prog == null ? 'Create Program' : 'Edit Program',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(child: ListView(
              controller: scrollCtrl,
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 12,
                bottom: MediaQuery.of(ctx2).viewInsets.bottom + 24,
              ),
              children: [
                if (prog == null) ...[
                  TextField(controller: codeCtrl,
                      decoration: const InputDecoration(labelText: 'Code * (e.g. IRON)', border: OutlineInputBorder()),
                      textCapitalization: TextCapitalization.characters),
                  const SizedBox(height: 8),
                ],
                TextField(controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextField(controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                    maxLines: 2),
                const SizedBox(height: 8),
                TextField(controller: orderCtrl,
                    decoration: const InputDecoration(labelText: 'Sort Order', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number),
                if (prog != null) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (v) => ss(() => isActive = v),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final data = {
                        if (prog == null) 'code': codeCtrl.text.trim().toUpperCase(),
                        'name':        nameCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'sort_order':  int.tryParse(orderCtrl.text) ?? 0,
                        if (prog != null) 'is_active': isActive ? 1 : 0,
                      };
                      final res = prog == null
                          ? await _api.createProgram(data)
                          : await _api.updateProgram(prog['id'] as int, data);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Done')));
                        if (res['success'] == true) _load();
                      }
                    },
                    child: Text(prog == null ? 'Create' : 'Save',
                        style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            )),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Program Manager'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _programs.length,
                    itemBuilder: (_, i) {
                      final p       = _programs[i];
                      final builtIn = _builtIn.contains(p['code']);
                      final active  = p['is_active'] == 1;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: active
                                ? const Color(0xFF1565C0).withValues(alpha: 0.12)
                                : const Color(0xFF0F1E35),
                            child: Icon(Icons.grid_view_rounded,
                                color: active ? const Color(0xFF1565C0) : Colors.grey, size: 20),
                          ),
                          title: Row(children: [
                            Text(p['name'] ?? p['code'],
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(width: 6),
                            if (builtIn)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('Built-in',
                                    style: TextStyle(fontSize: 10, color: Colors.blue.shade700)),
                              ),
                          ]),
                          subtitle: Text(
                            '${p['code']} • ${active ? 'Active' : 'Inactive'}${p['description'] != null && p['description'].toString().isNotEmpty ? '\n${p['description']}' : ''}',
                            style: TextStyle(fontSize: 12, color: active ? Colors.grey[600] : Colors.grey[400]),
                          ),
                          isThreeLine: p['description'] != null && p['description'].toString().isNotEmpty,
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (!builtIn)
                              IconButton(
                                icon: Icon(
                                  active ? Icons.toggle_on : Icons.toggle_off,
                                  color: active ? Colors.green : Colors.grey,
                                  size: 28,
                                ),
                                tooltip: active ? 'Deactivate' : 'Activate',
                                onPressed: () => _toggle(p),
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: builtIn ? null : () => _showForm(prog: p),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        backgroundColor: const Color(0xFF1565C0),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
