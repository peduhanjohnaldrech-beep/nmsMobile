import 'package:flutter/material.dart';
import '../../models/beneficiary_model.dart';
import '../../services/api_service.dart';
import '../../widgets/status_badge.dart';

class BeneficiaryFollowupScreen extends StatefulWidget {
  const BeneficiaryFollowupScreen({super.key});
  @override State<BeneficiaryFollowupScreen> createState() => _State();
}

class _State extends State<BeneficiaryFollowupScreen> {
  final _api = ApiService();
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;
  int _year = DateTime.now().year;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.getFollowupBeneficiaries(year: _year);
      if (res['success'] == true) {
        setState(() { _items = res['data']['beneficiaries'] ?? []; _loading = false; });
      } else {
        setState(() { _error = res['message']; _loading = false; });
      }
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Follow-up List'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          DropdownButton<int>(
            value: _year,
            dropdownColor: const Color(0xFF1565C0),
            style: const TextStyle(color: Colors.white),
            underline: const SizedBox(),
            items: List.generate(5, (i) => DateTime.now().year - i)
                .map((y) => DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(color: Colors.white))))
                .toList(),
            onChanged: (v) { if (v != null) { setState(() => _year = v); _load(); } },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : Column(children: [
                  Container(
                    color: Colors.orange[50],
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      const Icon(Icons.warning_amber, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text('${_items.length} beneficiaries need follow-up', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  Expanded(
                    child: _items.isEmpty
                        ? const Center(child: Text('No follow-up needed'))
                        : ListView.builder(
                            itemCount: _items.length,
                            itemBuilder: (_, i) {
                              final b = _items[i];
                              return ListTile(
                                leading: StatusBadge(status: b['nutritional_status'] ?? ''),
                                title: Text('${b['last_name']}, ${b['first_name']}'),
                                subtitle: Text('${b['barangay']} • ${b['assessment_date'] ?? ''} • ${b['weight_kg'] ?? ''} kg'),
                                trailing: b['contact_number'] != null
                                    ? const Icon(Icons.phone, color: Colors.green)
                                    : const Icon(Icons.chevron_right, color: Color(0xFF616161)),
                                onTap: () async {
                                  // fetch full beneficiary then navigate to detail
                                  final res = await _api.getBeneficiary(b['id'] as int);
                                  if (!mounted) return;
                                  if (res['success'] == true) {
                                    final bene = BeneficiaryModel.fromJson(
                                      (res['data']['beneficiary'] as Map<String, dynamic>));
                                    Navigator.pushNamed(context, '/beneficiaries/detail', arguments: bene);
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ]),
    );
  }
}
