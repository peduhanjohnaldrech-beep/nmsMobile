import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';

class DispensingScreen extends StatefulWidget {
  const DispensingScreen({super.key});
  @override
  State<DispensingScreen> createState() => _DispensingScreenState();
}

class _DispensingScreenState extends State<DispensingScreen> {
  final _api = ApiService();
  int _year = DateTime.now().year;
  bool _loading = false;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = context.read<AuthProvider>().user;
    final brgy = user?.isScopedToBarangay == true ? user?.barangay : null;
    try {
      final result = await _api.getDispensingRecords(year: _year, barangay: brgy);
      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        if (mounted) setState(() => _items = List.from(data['records'] ?? []));
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispensing'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.pushNamed(context, '/dispensing/create');
          _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Record Dispensing'),
        backgroundColor: const Color(0xFF1565C0),
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF1565C0),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(children: [
              Expanded(child: Container(
                height: 40, padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: DropdownButton<int>(
                  value: _year,
                  items: [DateTime.now().year, DateTime.now().year - 1, DateTime.now().year - 2]
                      .map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                  onChanged: (v) { if (v != null) setState(() => _year = v); _load(); },
                  isExpanded: true, underline: const SizedBox.shrink(),
                  style: const TextStyle(color: Color(0xFFE8F4FD), fontSize: 13),
                  dropdownColor: const Color(0xFF0D1B2E),
                  icon: const Icon(Icons.expand_more, color: Colors.white70, size: 18),
                ),
              )),
            ]),
          ),
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${_items.length} records',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1565C0))),
                ),
              ]),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.medical_services_outlined, size: 64, color: const Color(0xFF2A4060)),
                        const SizedBox(height: 12),
                        Text('No dispensing records for $_year',
                          style: TextStyle(color: const Color(0xFF90A4B8), fontSize: 14)),
                      ]))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final r = _items[i];
                            final name = '${r['last_name'] ?? ''}, ${r['first_name'] ?? ''}';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: ListTile(
                                dense: true,
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.teal,
                                  radius: 18,
                                  child: Icon(Icons.medication_outlined, color: Colors.white, size: 16),
                                ),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                subtitle: Text('${r['supplement_type'] ?? r['program'] ?? 'Supplement'} • Qty: ${r['quantity'] ?? 1}',
                                  style: const TextStyle(fontSize: 11)),
                                trailing: Text(r['date_dispensed'] ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF8FA8BF))),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
