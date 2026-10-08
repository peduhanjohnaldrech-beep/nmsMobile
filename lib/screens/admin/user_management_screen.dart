import 'package:flutter/material.dart';
import '../../constants/barangays.dart';
import '../../services/api_service.dart';

const _kModules = {
  'beneficiaries':  'Beneficiaries',
  'assessments':    'Assessments',
  'programs':       'Programs (OPT/DSP/MNS)',
  'reports':        'Reports',
  'dispensing':     'Dispensing Tracker',
  'activity_log':   'Activity Log',
  'validation':     'Validation',
  'programs_admin': 'Program Manager',
  'import':         'Data Import (web only)',
};

const _kFullAccessRoles = ['admin', 'nutritionist'];
const _scopedRoles = ['bhw', 'bns', 'midwife', 'encoder'];


class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});
  @override State<UserManagementScreen> createState() => _State();
}

class _State extends State<UserManagementScreen> {
  final _api = ApiService();
  List<dynamic> _users = [];
  bool _loading = true;
  String? _error;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.getUsers();
      if (res['success'] == true) {
        setState(() { _users = res['data']['users'] ?? []; _loading = false; });
      } else {
        setState(() { _error = res['message']; _loading = false; });
      }
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':        return Colors.red;
      case 'nutritionist': return Colors.blue;
      case 'bhw':          return Colors.green;
      case 'bns':          return Colors.teal;
      case 'midwife':      return Colors.purple;
      default:             return Colors.grey;
    }
  }

  String _permissionsSummary(Map<String, dynamic> user) {
    final role = user['role'] ?? 'encoder';
    if (_kFullAccessRoles.contains(role)) return 'Full access';
    final perms = user['permissions'];
    List<String> list = [];
    if (perms is List) {
      list = List<String>.from(perms);
    } else if (perms is String && perms.isNotEmpty) {
      // fallback if returned as comma string
      list = perms.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    if (list.isEmpty) return 'No permissions';
    return list.map((k) => _kModules[k] ?? k).join(', ');
  }

  void _showForm({Map<String, dynamic>? user}) {
    final usernameCtrl = TextEditingController(text: user?['username'] ?? '');
    final fullNameCtrl = TextEditingController(text: user?['full_name'] ?? '');
    final passwordCtrl = TextEditingController();
    final barangayCtrl = TextEditingController(text: user?['barangay'] ?? '');
    String role = user?['role'] ?? 'encoder';
    bool isActive = (user?['is_active'] ?? 1) == 1;

    // Load existing permissions
    Set<String> selectedPerms = {};
    final existingPerms = user?['permissions'];
    if (existingPerms is List) {
      selectedPerms = Set<String>.from(existingPerms);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx2, scrollCtrl) => StatefulBuilder(
          builder: (ctx3, ss) => Column(
            children: [
              // drag handle
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(children: [
                  Text(user == null ? 'Create User' : 'Edit User',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: EdgeInsets.only(
                    left: 16, right: 16, top: 12,
                    bottom: MediaQuery.of(ctx2).viewInsets.bottom + 24,
                  ),
                  children: [
                    if (user == null) ...[
                      TextField(controller: usernameCtrl,
                          decoration: const InputDecoration(labelText: 'Username *', border: OutlineInputBorder())),
                      const SizedBox(height: 8),
                    ],
                    TextField(controller: fullNameCtrl,
                        decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passwordCtrl,
                      decoration: InputDecoration(
                        labelText: user == null ? 'Password *' : 'New Password (leave blank to keep)',
                        border: const OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: role,
                      decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                      items: ['admin', 'nutritionist', 'bhw', 'bns', 'midwife', 'encoder']
                          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (v) => ss(() => role = v!),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: barangayCtrl.text.isNotEmpty && kBarangays.contains(barangayCtrl.text)
                          ? barangayCtrl.text : null,
                      decoration: InputDecoration(
                        labelText: _scopedRoles.contains(role) ? 'Barangay *' : 'Barangay',
                        border: const OutlineInputBorder(),
                        suffixIcon: _scopedRoles.contains(role)
                            ? const Icon(Icons.location_on, color: Colors.orange)
                            : null,
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— Select Barangay —')),
                        ...kBarangays.map((b) => DropdownMenuItem(value: b, child: Text(b))),
                      ],
                      onChanged: (v) => ss(() => barangayCtrl.text = v ?? ''),
                    ),
                    const SizedBox(height: 8),
                    if (user != null) SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      value: isActive,
                      onChanged: (v) => ss(() => isActive = v),
                    ),

                    // Permissions section — only for non-full-access roles
                    if (!_kFullAccessRoles.contains(role)) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.lock_outline, size: 18, color: Color(0xFF1565C0)),
                        const SizedBox(width: 6),
                        const Text('Module Permissions',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1565C0))),
                        const Spacer(),
                        TextButton(
                          onPressed: () => ss(() {
                            if (selectedPerms.length == _kModules.length) {
                              selectedPerms.clear();
                            } else {
                              selectedPerms = Set<String>.from(_kModules.keys);
                            }
                          }),
                          child: Text(selectedPerms.length == _kModules.length ? 'Deselect all' : 'Select all',
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ]),
                      ..._kModules.entries.map((e) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(e.value),
                        value: selectedPerms.contains(e.key),
                        activeColor: const Color(0xFF1565C0),
                        onChanged: (v) => ss(() {
                          if (v == true) {
                            selectedPerms.add(e.key);
                          } else {
                            selectedPerms.remove(e.key);
                          }
                        }),
                      )),
                      const SizedBox(height: 4),
                    ],

                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
                        onPressed: () async {
                          // Validate required fields
                          if (user == null && usernameCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx3).showSnackBar(
                                const SnackBar(content: Text('Username is required')));
                            return;
                          }
                          if (_scopedRoles.contains(role) && barangayCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx3).showSnackBar(SnackBar(
                                content: Text('Barangay is required for $role'),
                                backgroundColor: Colors.orange[700]));
                            return;
                          }
                          Navigator.pop(ctx);
                          final data = {
                            if (user == null) 'username': usernameCtrl.text,
                            'full_name': fullNameCtrl.text,
                            'role': role,
                            'barangay': barangayCtrl.text.isNotEmpty ? barangayCtrl.text : null,
                            if (passwordCtrl.text.isNotEmpty) 'password': passwordCtrl.text,
                            if (user != null) 'is_active': isActive ? 1 : 0,
                            'permissions': _kFullAccessRoles.contains(role)
                                ? []
                                : selectedPerms.toList(),
                          };
                          final res = user == null
                              ? await _api.createUser(data)
                              : await _api.updateUser(user['id'], data);
                          if (mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text(res['message'] ?? 'Done')));
                            if (res['success'] == true) _load();
                          }
                        },
                        child: Text(user == null ? 'Create' : 'Save',
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleActive(Map<String, dynamic> user) async {
    final isActive = user['is_active'] == 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isActive ? 'Deactivate User' : 'Activate User'),
        content: Text('${isActive ? 'Deactivate' : 'Activate'} ${user['full_name']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isActive ? 'Deactivate' : 'Activate',
                style: TextStyle(color: isActive ? Colors.red : Colors.green)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final res = await _api.toggleUserActive(user['id'], !isActive);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Done')));
      if (res['success'] == true) _load();
    }
  }

  Future<void> _delete(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Delete ${user['full_name']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    final res = await _api.deleteUser(user['id']);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Done')));
      if (res['success'] == true) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (_, i) {
                    final u = _users[i];
                    final role = u['role'] ?? 'encoder';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _roleColor(role).withValues(alpha: 0.15),
                        child: Text(
                          (u['full_name'] ?? '?').substring(0, 1).toUpperCase(),
                          style: TextStyle(
                              color: _roleColor(role), fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(u['full_name'] ?? u['username']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$role${u['barangay'] != null ? ' • ${u['barangay']}' : ''}'
                            ' • ${u['is_active'] == 1 ? 'Active' : 'Inactive'}',
                          ),
                          Text(
                            _permissionsSummary(u),
                            style: TextStyle(
                              fontSize: 11,
                              color: _kFullAccessRoles.contains(role)
                                  ? Colors.blue[700]
                                  : Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          icon: Icon(
                            u['is_active'] == 1 ? Icons.toggle_on : Icons.toggle_off,
                            color: u['is_active'] == 1 ? Colors.green : Colors.grey,
                            size: 28,
                          ),
                          tooltip: u['is_active'] == 1 ? 'Deactivate' : 'Activate',
                          onPressed: () => _toggleActive(u),
                        ),
                        IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showForm(user: u)),
                        IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _delete(u)),
                      ]),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        backgroundColor: const Color(0xFF1565C0),
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }
}
