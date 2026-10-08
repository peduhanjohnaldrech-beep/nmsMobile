import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class BeneficiaryTrashScreen extends StatefulWidget {
  const BeneficiaryTrashScreen({super.key});
  @override State<BeneficiaryTrashScreen> createState() => _State();
}

class _State extends State<BeneficiaryTrashScreen> {
  final _api = ApiService();
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.getTrashedBeneficiaries();
      if (res['success'] == true) {
        setState(() { _items = res['data']['beneficiaries'] ?? []; _loading = false; });
      } else {
        setState(() { _error = res['message']; _loading = false; });
      }
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  Future<void> _restore(int id) async {
    final res = await _api.restoreBeneficiary(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Done')));
    if (res['success'] == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trash'), backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _items.isEmpty
                  ? const Center(child: Text('Trash is empty'))
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final b = _items[i];
                        return ListTile(
                          leading: const Icon(Icons.delete_outline, color: Colors.red),
                          title: Text('${b['last_name']}, ${b['first_name']}'),
                          subtitle: Text('${b['barangay']} • Deleted: ${(b['deleted_at'] ?? '').toString().substring(0, 10)}'),
                          trailing: TextButton(
                            onPressed: () => _restore(b['id']),
                            child: const Text('Restore'),
                          ),
                        );
                      },
                    ),
    );
  }
}
