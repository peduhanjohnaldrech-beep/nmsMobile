import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _api = ApiService();
  bool _loading = false;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await _api.getActivity();
      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        if (mounted) setState(() => _items = List.from(data['logs'] ?? []));
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _formatDate(String? d) {
    if (d == null) return '';
    final dt = DateTime.tryParse(d);
    if (dt == null) return d;
    return DateFormat('MMM d, yyyy h:mm a').format(dt.toLocal());
  }

  IconData _actionIcon(String? action) {
    final a = (action ?? '').toLowerCase();
    if (a.contains('login'))  return Icons.login_rounded;
    if (a.contains('logout')) return Icons.logout_rounded;
    if (a.contains('create') || a.contains('add')) return Icons.add_circle_outline_rounded;
    if (a.contains('update') || a.contains('edit')) return Icons.edit_outlined;
    if (a.contains('delete')) return Icons.delete_outline_rounded;
    if (a.contains('sync'))   return Icons.sync_rounded;
    return Icons.circle_outlined;
  }

  Color _actionColor(String? action) {
    final a = (action ?? '').toLowerCase();
    if (a.contains('login'))  return Colors.green;
    if (a.contains('logout')) return Colors.grey;
    if (a.contains('create') || a.contains('add')) return Colors.blue;
    if (a.contains('update') || a.contains('edit')) return Colors.orange;
    if (a.contains('delete')) return Colors.red;
    return const Color(0xFF1565C0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log'),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.history_rounded, size: 64, color: const Color(0xFF2A4060)),
                  const SizedBox(height: 12),
                  Text('No activity logs found', style: TextStyle(color: const Color(0xFF90A4B8), fontSize: 14)),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final log = _items[i];
                      final action = log['action'] as String?;
                      final color  = _actionColor(action);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.1),
                            radius: 18,
                            child: Icon(_actionIcon(action), color: color, size: 16),
                          ),
                          title: Text(log['description'] ?? action ?? 'Action',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text('${log['username'] ?? ''}  •  ${_formatDate(log['created_at'])}',
                            style: const TextStyle(fontSize: 11)),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
