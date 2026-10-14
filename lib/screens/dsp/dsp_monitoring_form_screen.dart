import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';

class DspMonitoringFormScreen extends StatefulWidget {
  /// Pass a pre-selected enrollment to skip the picker.
  final Map<String, dynamic>? enrollment;
  const DspMonitoringFormScreen({super.key, this.enrollment});

  @override
  State<DspMonitoringFormScreen> createState() => _DspMonitoringFormScreenState();
}

class _DspMonitoringFormScreenState extends State<DspMonitoringFormScreen> {
  final _api        = ApiService();
  final _formKey    = GlobalKey<FormState>();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _muacCtrl   = TextEditingController();
  final _remarksCtrl = TextEditingController();

  List<Map<String, dynamic>> _enrollments = [];
  Map<String, dynamic>?      _selected;
  bool   _loadingEnrollments = false;
  bool   _saving = false;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.enrollment != null) {
      _selected = widget.enrollment;
    } else {
      _loadEnrollments();
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _muacCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEnrollments() async {
    setState(() => _loadingEnrollments = true);
    final user = context.read<AuthProvider>().user;
    final brgy = user?.isScopedToBarangay == true ? user?.barangay : null;
    final res  = await _api.getDspEnrollments(barangay: brgy);
    if (res['success'] == true && mounted) {
      final rows = List<Map<String, dynamic>>.from(
          (res['data'] as Map)['enrollments'] ?? []);
      setState(() { _enrollments = rows; _loadingEnrollments = false; });
    } else {
      if (mounted) setState(() => _loadingEnrollments = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: _date,
      firstDate:   DateTime(2020),
      lastDate:    DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1565C0)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selected == null) {
      _showError('Select a DSP enrollment first');
      return;
    }

    setState(() => _saving = true);
    final user = context.read<AuthProvider>().user;

    final res = await _api.createDspMonitoring({
      'enrollment_id':   _selected!['id'],
      'beneficiary_id':  _selected!['beneficiary_id'],
      'sex':             _selected!['sex'],
      'monitoring_date': DateFormat('yyyy-MM-dd').format(_date),
      'weight_kg':       double.tryParse(_weightCtrl.text.trim()),
      'height_cm':       _heightCtrl.text.trim().isNotEmpty
                             ? double.tryParse(_heightCtrl.text.trim())
                             : null,
      'muac_cm':         double.tryParse(_muacCtrl.text.trim()),
      'monitored_by':    user?.fullName,
      if (_remarksCtrl.text.trim().isNotEmpty)
        'remarks': _remarksCtrl.text.trim(),
    });

    if (mounted) setState(() => _saving = false);
    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         const Text('Follow-up record saved'),
        backgroundColor: Colors.green.shade700,
        behavior:        SnackBarBehavior.floating,
      ));
      Navigator.pop(context, true);
    } else {
      _showError(res['message'] as String? ?? 'Failed to save');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: Colors.red.shade700,
      behavior:        SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:           const Text('DSP Follow-up'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [

          // ── Child / Enrollment ──────────────────────────────
          _SectionCard(
            title: 'DSP Child',
            icon:  Icons.child_care_rounded,
            children: [
              if (widget.enrollment != null) ...[
                _InfoTile(
                  label: '${_selected!['last_name']}, ${_selected!['first_name']}',
                  sub:   '${_selected!['barangay']}  •  ${_selected!['intervention_type'] ?? 'DSP'}',
                ),
              ] else if (_loadingEnrollments) ...[
                const Center(child: Padding(
                  padding: EdgeInsets.all(12),
                  child:   CircularProgressIndicator(),
                )),
              ] else ...[
                DropdownButtonFormField<Map<String, dynamic>>(
                  value: _selected,
                  decoration: InputDecoration(
                    hintText: 'Select enrolled child…',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                  items: _enrollments.map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(
                      '${e['last_name']}, ${e['first_name']} (${e['barangay']})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  )).toList(),
                  onChanged: (v) => setState(() => _selected = v),
                  validator: (_) => _selected == null ? 'Select a child' : null,
                ),
              ],
            ],
          ),

          // ── Date ───────────────────────────────────────────
          _SectionCard(
            title: 'Monitoring Date',
            icon:  Icons.calendar_month_rounded,
            children: [
              InkWell(
                onTap:        _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    border:       Border.all(color: Colors.blue.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today_rounded, size: 18, color: Colors.blue.shade700),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat('MMMM d, yyyy').format(_date),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    const Icon(Icons.edit_calendar_rounded, size: 16, color: Color(0xFF616161)),
                  ]),
                ),
              ),
            ],
          ),

          // ── Measurements ───────────────────────────────────
          _SectionCard(
            title: 'Measurements',
            icon:  Icons.monitor_weight_rounded,
            children: [
              _MeasurementField(ctrl: _weightCtrl, label: 'Weight', unit: 'kg',
                  icon: Icons.monitor_weight_outlined, required: true, hint: 'e.g. 10.5'),
              const SizedBox(height: 12),
              _MeasurementField(ctrl: _heightCtrl, label: 'Height', unit: 'cm',
                  icon: Icons.height_rounded, hint: 'e.g. 85.0', helper: 'Optional'),
              const SizedBox(height: 12),
              _MeasurementField(ctrl: _muacCtrl, label: 'MUAC', unit: 'cm',
                  icon: Icons.straighten_rounded, required: true, hint: 'e.g. 13.5',
                  helper: 'Mid-Upper Arm Circumference'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _remarksCtrl,
                maxLines:   2,
                decoration: InputDecoration(
                  labelText: 'Remarks',
                  hintText:  'Optional notes…',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 3,
              ),
              child: _saving
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Save Follow-up',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}

// ── Helper widgets ──────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children, this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin:      const EdgeInsets.only(bottom: 12),
      elevation:   2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: const Color(0xFF1565C0)),
                const SizedBox(width: 8),
              ],
              Text(title,
                  style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: Color(0xFF1565C0), letterSpacing: 0.3,
                  )),
            ]),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String sub;
  const _InfoTile({required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        Colors.blue.shade50,
        border:       Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(Icons.check_circle_rounded, color: Colors.blue.shade600, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            Text(sub,   style: const TextStyle(fontSize: 11, color: Color(0xFF8FA8BF))),
          ],
        )),
      ]),
    );
  }
}

class _MeasurementField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, unit;
  final IconData icon;
  final bool required;
  final String? hint, helper;

  const _MeasurementField({
    required this.ctrl,
    required this.label,
    required this.unit,
    required this.icon,
    this.required = false,
    this.hint,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:   ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText:  required ? '$label *' : label,
        hintText:   hint,
        helperText: helper,
        prefixIcon: Icon(icon, size: 20),
        suffixText: unit,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      validator: required
          ? (v) {
              if (v == null || v.trim().isEmpty) return '$label is required';
              final val = double.tryParse(v.trim());
              if (val == null || val <= 0) return 'Enter a valid $label';
              return null;
            }
          : (v) {
              if (v != null && v.trim().isNotEmpty) {
                final val = double.tryParse(v.trim());
                if (val == null || val <= 0) return 'Enter a valid $label';
              }
              return null;
            },
    );
  }
}
