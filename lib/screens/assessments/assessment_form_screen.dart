import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/beneficiary_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../services/local_db_service.dart';
import '../../services/sync_service.dart';

class AssessmentFormScreen extends StatefulWidget {
  final BeneficiaryModel? beneficiary;
  const AssessmentFormScreen({super.key, this.beneficiary});

  @override
  State<AssessmentFormScreen> createState() => _AssessmentFormScreenState();
}

class _AssessmentFormScreenState extends State<AssessmentFormScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _api        = ApiService();
  final _local      = LocalDbService();
  final _sync       = SyncService();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _muacCtrl   = TextEditingController();
  final _remarksCtrl = TextEditingController();

  BeneficiaryModel?       _selectedBene;
  List<BeneficiaryModel>  _beneficiaries = [];
  bool                    _loadingBenes  = false;

  DateTime _date   = DateTime.now();
  String   _period = DateTime.now().month <= 6 ? 'January' : 'July';
  int      _year   = DateTime.now().year;
  bool     _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedBene = widget.beneficiary;
    if (widget.beneficiary == null) _loadBeneficiaries();
  }

  Future<void> _loadBeneficiaries() async {
    setState(() => _loadingBenes = true);
    final user = context.read<AuthProvider>().user;
    final brgy = user?.isScopedToBarangay == true ? user?.barangay : null;

    List<BeneficiaryModel> items = [];

    if (kIsWeb) {
      final result = await _api.getBeneficiaries(
        barangay: brgy,
        perPage:  999,
      );
      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        final rows = List<Map<String, dynamic>>.from(data['beneficiaries'] ?? []);
        items = rows.map((r) => BeneficiaryModel.fromJson(r)).toList();
      }
    } else {
      final rows = await _local.getBeneficiaries(barangay: brgy, perPage: 999);
      items = rows.map((r) => BeneficiaryModel.fromJson(r)).toList();
    }

    if (mounted) setState(() { _beneficiaries = items; _loadingBenes = false; });
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _muacCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  int _ageInMonths(String dob) {
    final birth = DateTime.tryParse(dob) ?? DateTime.now();
    return (_date.year - birth.year) * 12 + (_date.month - birth.month);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: _date,
      firstDate:   DateTime(2020),
      lastDate:    DateTime.now(),
      helpText:    'Select Assessment Date',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF00897B)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBene == null) {
      _showError('Please select a beneficiary');
      return;
    }
    if (_selectedBene!.isRejected) {
      _showError('This beneficiary registration was rejected. Please edit and resubmit first.');
      return;
    }

    // Warn if an assessment already exists for this period/year
    if (!kIsWeb) {
      final exists = await _local.assessmentExistsForPeriod(
        _selectedBene!.id, _period, _year,
      );
      if (exists && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Text('Duplicate Assessment'),
            content: Text(
              'An assessment for $_period $_year already exists for this beneficiary. '
              'Do you want to add another one?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Proceed'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }

    setState(() => _saving = true);

    final user = context.read<AuthProvider>().user;
    final data = {
      'beneficiary_id':  _selectedBene!.id,
      'assessment_date': DateFormat('yyyy-MM-dd').format(_date),
      'weight_kg':       double.tryParse(_weightCtrl.text.trim()) ?? 0,
      if (_heightCtrl.text.trim().isNotEmpty)
        'height_cm': double.tryParse(_heightCtrl.text.trim()),
      if (_muacCtrl.text.trim().isNotEmpty)
        'muac_cm': double.tryParse(_muacCtrl.text.trim()),
      'period':          _period,
      'assessment_year': _year,
      'assessed_by':     user?.fullName,
      if (_remarksCtrl.text.trim().isNotEmpty)
        'remarks': _remarksCtrl.text.trim(),
    };

    final isOnline = await _sync.isOnline();

    try {
      if (isOnline) {
        final result = await _api.createAssessment(data);
        if (result['success'] == true) {
          final serverData = (result['data'] as Map<String, dynamic>?)?['assessment']
              as Map<String, dynamic>?;
          if (serverData != null && !kIsWeb) {
            await _local.upsertAssessments([serverData]);
          }
          _showSuccess('Assessment recorded successfully');
        } else {
          _showError(result['message'] as String? ?? 'Failed to save');
        }
      } else {
        if (!kIsWeb) {
          await _local.insertOfflineAssessment({
            ...data,
            'id':                   DateTime.now().millisecondsSinceEpoch,
            'local_id':             const Uuid().v4(),
            'age_in_months':        _ageInMonths(_selectedBene!.dateOfBirth),
            'nutritional_status':   'Pending',
            'created_at':           DateTime.now().toIso8601String(),
          });
          _showSuccess('Saved offline. Will sync when connected.');
        } else {
          _showError('No internet connection. Please connect and try again.');
        }
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:         Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior:        SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:         Text(msg),
          backgroundColor: Colors.green.shade700,
          behavior:        SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:           const Text('Record Assessment'),
        backgroundColor: Colors.teal.shade700,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // -------------------------------------------------------
            // BENEFICIARY
            // -------------------------------------------------------
            _SectionCard(
              title: 'Beneficiary',
              icon:  Icons.person_rounded,
              color: Colors.teal.shade700,
              children: [
                if (widget.beneficiary != null) ...[
                  // Pre-filled — not editable
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:        Colors.teal.withValues(alpha: 0.06),
                      border:       Border.all(color: Colors.teal.shade200),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: widget.beneficiary!.sex == 'Male'
                              ? Colors.blue.shade100
                              : Colors.pink.shade100,
                          child: Text(
                            widget.beneficiary!.initials,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: widget.beneficiary!.sex == 'Male'
                                  ? Colors.blue.shade800
                                  : Colors.pink.shade800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.beneficiary!.displayName,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.beneficiary!.sex}  •  ${widget.beneficiary!.barangay}',
                                style: const TextStyle(fontSize: 12, color: const Color(0xFF8FA8BF)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Age at assessment: ${_ageInMonths(widget.beneficiary!.dateOfBirth)} months',
                                style: TextStyle(fontSize: 12, color: Colors.teal.shade700, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  _loadingBenes
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child:   CircularProgressIndicator(),
                          ),
                        )
                      : _BeneficiarySearchField(
                          beneficiaries: _beneficiaries,
                          selected: _selectedBene,
                          onSelected: (b) => setState(() => _selectedBene = b),
                        ),
                  if (_beneficiaries.isEmpty && !_loadingBenes)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: _loadBeneficiaries,
                        icon:  const Icon(Icons.refresh),
                        label: const Text('Reload beneficiaries'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                        ),
                      ),
                    ),
                ],
              ],
            ),

            // -------------------------------------------------------
            // DATE & PERIOD
            // -------------------------------------------------------
            _SectionCard(
              title: 'Assessment Period',
              icon:  Icons.calendar_month_rounded,
              color: Colors.teal.shade700,
              children: [
                // Assessment date
                const Text('Assessment Date *',
                    style: TextStyle(fontSize: 12, color: const Color(0xFF8FA8BF))),
                const SizedBox(height: 6),
                InkWell(
                  onTap:        _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.teal.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 18, color: Colors.teal.shade700),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('MMMM d, yyyy').format(_date),
                          style: const TextStyle(
                            fontSize:   14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.edit_calendar_rounded,
                            size: 16, color: Color(0xFF616161)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Period + Year
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('OPT Period *',
                              style: TextStyle(fontSize: 12, color: const Color(0xFF8FA8BF))),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _period,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                            ),
                            items: ['January', 'July']
                                .map((p) => DropdownMenuItem(
                                    value: p, child: Text(p)))
                                .toList(),
                            onChanged: (v) => setState(() => _period = v!),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Year *',
                              style: TextStyle(fontSize: 12, color: const Color(0xFF8FA8BF))),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            value: _year,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                            ),
                            items: [
                              DateTime.now().year,
                              DateTime.now().year - 1,
                              DateTime.now().year - 2,
                            ]
                                .map((y) => DropdownMenuItem(
                                    value: y, child: Text(y.toString())))
                                .toList(),
                            onChanged: (v) => setState(() => _year = v!),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // -------------------------------------------------------
            // MEASUREMENTS
            // -------------------------------------------------------
            _SectionCard(
              title: 'Measurements',
              icon:  Icons.monitor_weight_rounded,
              color: Colors.teal.shade700,
              children: [
                // Weight — required
                _buildMeasurementField(
                  ctrl:       _weightCtrl,
                  label:      'Weight',
                  unit:       'kg',
                  icon:       Icons.monitor_weight_outlined,
                  required:   true,
                  hintText:   'e.g. 12.5',
                ),
                const SizedBox(height: 12),

                // Height — optional
                _buildMeasurementField(
                  ctrl:       _heightCtrl,
                  label:      'Height',
                  unit:       'cm',
                  icon:       Icons.height_rounded,
                  hintText:   'e.g. 85.0',
                  helperText: 'Optional',
                ),
                const SizedBox(height: 12),

                // MUAC — optional
                _buildMeasurementField(
                  ctrl:       _muacCtrl,
                  label:      'MUAC',
                  unit:       'cm',
                  icon:       Icons.straighten_rounded,
                  hintText:   'e.g. 13.5',
                  helperText: 'Mid-Upper Arm Circumference (optional)',
                ),
                const SizedBox(height: 12),

                // Remarks
                TextFormField(
                  controller: _remarksCtrl,
                  maxLines:   3,
                  decoration: InputDecoration(
                    labelText:   'Remarks',
                    hintText:    'Optional notes...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Save button
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation:   3,
                  shadowColor: Colors.teal.withValues(alpha: 0.4),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                          color:       Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Save Assessment',
                        style: TextStyle(
                          fontSize:   16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementField({
    required TextEditingController ctrl,
    required String label,
    required String unit,
    required IconData icon,
    bool required   = false,
    String? hintText,
    String? helperText,
  }) {
    return TextFormField(
      controller:  ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText:  required ? '$label *' : label,
        hintText:   hintText,
        helperText: helperText,
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

// -------------------------------------------------------
// SECTION CARD
// -------------------------------------------------------

// -------------------------------------------------------
// SEARCHABLE BENEFICIARY FIELD
// -------------------------------------------------------

class _BeneficiarySearchField extends StatefulWidget {
  final List<BeneficiaryModel> beneficiaries;
  final BeneficiaryModel?      selected;
  final ValueChanged<BeneficiaryModel?> onSelected;

  const _BeneficiarySearchField({
    required this.beneficiaries,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<_BeneficiarySearchField> createState() => _BeneficiarySearchFieldState();
}

class _BeneficiarySearchFieldState extends State<_BeneficiarySearchField> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (widget.selected != null) _ctrl.text = widget.selected!.displayName;
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  List<BeneficiaryModel> get _filtered {
    if (_query.isEmpty) return widget.beneficiaries.take(50).toList();
    final q = _query.toLowerCase();
    return widget.beneficiaries
        .where((b) => b.displayName.toLowerCase().contains(q) ||
                      b.barangay.toLowerCase().contains(q))
        .take(50)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _ctrl,
          decoration: InputDecoration(
            hintText: 'Search beneficiary…',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            suffixIcon: _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _ctrl.clear();
                      setState(() => _query = '');
                      widget.onSelected(null);
                    },
                  )
                : null,
          ),
          onChanged: (v) => setState(() => _query = v),
          validator: (_) => widget.selected == null ? 'Select a beneficiary' : null,
        ),
        if (_query.isNotEmpty && widget.selected == null) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color:        const Color(0xFF0D1B2E),
              border:       Border.all(color: const Color(0xFF1A3050)),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
            child: _filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child:   Text('No results', style: TextStyle(color: Color(0xFF8FA8BF))),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final b = _filtered[i];
                      final months = b.ageInMonths;
                      final ageLabel = months < 12
                          ? '${months}mo'
                          : '${months ~/ 12}y ${months % 12}mo';
                      return InkWell(
                        onTap: () {
                          _ctrl.text = b.displayName;
                          setState(() => _query = '');
                          widget.onSelected(b);
                          FocusScope.of(context).unfocus();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: b.sex == 'Male'
                                  ? Colors.blue.shade100
                                  : Colors.pink.shade100,
                              child: Text(b.initials,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: b.sex == 'Male'
                                      ? Colors.blue.shade800
                                      : Colors.pink.shade800,
                                )),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.displayName,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                Text('${b.barangay}  •  $ageLabel  •  ${b.sex}',
                                    style: TextStyle(fontSize: 11, color: const Color(0xFF90A4B8))),
                              ],
                            )),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ],
        if (widget.selected != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.teal.shade600, size: 14),
              const SizedBox(width: 6),
              Text(
                '${widget.selected!.barangay}  •  ${widget.selected!.ageInMonths} months old  •  ${widget.selected!.sex}',
                style: TextStyle(fontSize: 12, color: Colors.teal.shade800, fontWeight: FontWeight.w500),
              ),
            ]),
          ),
        ],
      ],
    );
  }
}

// -------------------------------------------------------

class _SectionCard extends StatelessWidget {
  final String       title;
  final IconData?    icon;
  final Color?       color;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
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
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: c),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontSize:      13,
                    fontWeight:    FontWeight.w700,
                    color:         c,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
