import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../constants/barangays.dart';
import '../../models/beneficiary_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../services/local_db_service.dart';
import '../../services/sync_service.dart';

class BeneficiaryFormScreen extends StatefulWidget {
  final BeneficiaryModel? existing;
  const BeneficiaryFormScreen({super.key, this.existing});

  @override
  State<BeneficiaryFormScreen> createState() => _BeneficiaryFormScreenState();
}

class _BeneficiaryFormScreenState extends State<BeneficiaryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api     = ApiService();
  final _local   = LocalDbService();
  final _sync    = SyncService();

  // Controllers — Personal
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _middleNameCtrl;
  late final TextEditingController _suffixCtrl;
  late final TextEditingController _placeOfBirthCtrl;

  // Controllers — Location
  late final TextEditingController _purokCtrl;
  late final TextEditingController _householdNoCtrl;

  // Controllers — Family
  late final TextEditingController _motherCtrl;
  late final TextEditingController _fatherCtrl;
  late final TextEditingController _guardianNameCtrl;
  late final TextEditingController _guardianRelCtrl;
  late final TextEditingController _contactCtrl;

  // Controllers — Socioeconomic
  late final TextEditingController _incomeCtrl;
  late final TextEditingController _incomeSourceCtrl;

  // Dropdowns / toggles
  String?  _sex;
  String?  _barangay;
  DateTime? _dob;
  String?  _philhealthStatus;
  String?  _nhtsStatus;
  String?  _incomeClassification;
  String?  _ipGroup;
  bool     _is4ps             = false;
  bool     _isPwd             = false;
  bool     _isIP              = false;

  List<String> _barangays = [];
  bool         _saving    = false;
  String?      _duplicateWarning;

  bool get _isEdit => widget.existing != null;

  static const _philhealthOptions    = ['Active', 'Inactive', 'None'];
  static const _nhtsOptions          = ['Poor', 'Near Poor', 'Not Poor', 'Not assessed'];
  static const _incomeClassOptions   = ['Poor', 'Low Income', 'Middle Income', 'High Income'];

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    _lastNameCtrl      = TextEditingController(text: b?.lastName);
    _firstNameCtrl     = TextEditingController(text: b?.firstName);
    _middleNameCtrl    = TextEditingController(text: b?.middleName);
    _suffixCtrl        = TextEditingController(text: b?.suffix);
    _placeOfBirthCtrl  = TextEditingController(text: b?.placeOfBirth);
    _purokCtrl         = TextEditingController(text: b?.purokZone);
    _householdNoCtrl   = TextEditingController(text: b?.householdNo);
    _motherCtrl        = TextEditingController(text: b?.motherName);
    _fatherCtrl        = TextEditingController(text: b?.fatherName);
    _guardianNameCtrl  = TextEditingController(text: b?.guardianName);
    _guardianRelCtrl   = TextEditingController(text: b?.guardianRelationship);
    _contactCtrl       = TextEditingController(text: b?.contactNumber);
    _incomeCtrl        = TextEditingController(
        text: b?.householdMonthlyIncome?.toString());
    _incomeSourceCtrl  = TextEditingController(text: b?.incomeSource);

    _sex                  = b?.sex;
    _barangay             = b?.barangay;
    _philhealthStatus     = b?.philhealthStatus;
    _nhtsStatus           = b?.nhtsStatus;
    _incomeClassification = b?.incomeClassification;
    _ipGroup              = b?.ipGroup;
    _is4ps                = b?.is4ps ?? false;
    _isPwd                = b?.isPwd ?? false;
    _isIP                 = b?.isIP  ?? false;

    if (b?.dateOfBirth != null && b!.dateOfBirth.isNotEmpty) {
      _dob = DateTime.tryParse(b.dateOfBirth);
    }
    _loadBarangays();
  }

  Future<void> _loadBarangays() async {
    final user = context.read<AuthProvider>().user;
    if (user?.isScopedToBarangay == true && user?.barangay != null) {
      setState(() {
        _barangays = [user!.barangay!];
        _barangay  = user.barangay;
      });
      return;
    }
    List<String> list = [];
    if (!kIsWeb) list = await _local.getBarangays();
    if (list.isEmpty) {
      try {
        final result = await _api.getBarangays();
        if (result['success'] == true) {
          final data = result['data'] as Map<String, dynamic>? ?? {};
          list = List<String>.from(data['barangays'] ?? []);
          if (!kIsWeb && list.isNotEmpty) await _local.upsertBarangays(list);
        }
      } catch (_) {}
    }
    if (list.isEmpty) list = List<String>.from(kBarangays);
    if (mounted) setState(() => _barangays = list);
  }

  @override
  void dispose() {
    _lastNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _suffixCtrl.dispose();
    _placeOfBirthCtrl.dispose();
    _purokCtrl.dispose();
    _householdNoCtrl.dispose();
    _motherCtrl.dispose();
    _fatherCtrl.dispose();
    _guardianNameCtrl.dispose();
    _guardianRelCtrl.dispose();
    _contactCtrl.dispose();
    _incomeCtrl.dispose();
    _incomeSourceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context:     context,
      initialDate: _dob ?? now.subtract(const Duration(days: 365)),
      firstDate:   now.subtract(const Duration(days: 365 * 7)),
      lastDate:    now,
      helpText:    'Select Date of Birth',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1565C0)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dob = picked);
      _checkDuplicate();
    }
  }

  Future<void> _checkDuplicate() async {
    if (_isEdit) return;
    final fn = _firstNameCtrl.text.trim();
    final ln = _lastNameCtrl.text.trim();
    if (fn.isEmpty || ln.isEmpty || _dob == null) return;
    try {
      final res = await _api.checkDuplicate(
        firstName: fn,
        lastName:  ln,
        dob:       DateFormat('yyyy-MM-dd').format(_dob!),
      );
      if (!mounted) return;
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final exists = data['has_duplicate'] == true || data['has_duplicate'] == 1;
      setState(() => _duplicateWarning = exists
          ? 'A beneficiary with the same name and date of birth may already exist.'
          : null);
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) { _showError('Date of birth is required'); return; }
    if (_sex == null) { _showError('Sex is required'); return; }
    if (_barangay == null || _barangay!.isEmpty) { _showError('Barangay is required'); return; }

    setState(() => _saving = true);

    String? n(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    String? titleCase(TextEditingController c) {
      final v = c.text.trim();
      if (v.isEmpty) return null;
      return v.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ');
    }

    final data = <String, dynamic>{
      'last_name':              _lastNameCtrl.text.trim(),
      'first_name':             _firstNameCtrl.text.trim(),
      'middle_name':            n(_middleNameCtrl),
      'suffix':                 n(_suffixCtrl),
      'date_of_birth':          DateFormat('yyyy-MM-dd').format(_dob!),
      'sex':                    _sex,
      'place_of_birth':         n(_placeOfBirthCtrl),
      'barangay':               _barangay,
      'purok_zone':             titleCase(_purokCtrl),
      'household_no':           n(_householdNoCtrl),
      'mother_name':            n(_motherCtrl),
      'father_name':            n(_fatherCtrl),
      'guardian_name':          n(_guardianNameCtrl),
      'guardian_relationship':  n(_guardianRelCtrl),
      'contact_number':         n(_contactCtrl),
      'philhealth_status':      _philhealthStatus,
      'is_4ps_member':          _is4ps ? 1 : 0,
      'nhts_pr_status':         _nhtsStatus,
      'income_classification':  _incomeClassification,
      'household_monthly_income': _incomeCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_incomeCtrl.text.trim()),
      'income_source':          n(_incomeSourceCtrl),
      'is_pwd_household':       _isPwd ? 1 : 0,
      'is_indigenous_people':   _isIP  ? 1 : 0,
      'ip_group':               _isIP  ? n(_ipGroup != null ? (TextEditingController()..text = _ipGroup!) : _guardianRelCtrl) : null,
      'source':                 'Mobile',
    };

    // ip_group from dedicated field
    data['ip_group'] = _isIP ? (_ipGroup?.isNotEmpty == true ? _ipGroup : null) : null;

    final isOnline = await _sync.isOnline();
    try {
      if (isOnline) {
        final result = _isEdit
            ? await _api.updateBeneficiary(widget.existing!.id, data)
            : await _api.createBeneficiary(data);
        if (result['success'] == true) {
          final serverData = (result['data'] as Map<String, dynamic>?)?['beneficiary']
              as Map<String, dynamic>?;
          if (serverData != null && !kIsWeb) {
            await _local.upsertBeneficiaries([serverData]);
          }
          final newBene = serverData != null ? BeneficiaryModel.fromJson(serverData) : null;
          if (_isEdit) {
            _showSuccess('Beneficiary updated');
          } else {
            _promptRecordAssessment(newBene);
          }
        } else {
          _showError(result['message'] as String? ?? 'Failed to save');
        }
      } else {
        if (!kIsWeb) {
          if (_isEdit) {
            await _local.updateBeneficiary(widget.existing!.id, data);
            _showSuccess('Beneficiary updated');
          } else {
            final localId = const Uuid().v4();
            final now     = DateTime.now().toIso8601String();
            await _local.insertOfflineBeneficiary({
              ...data,
              'id':                DateTime.now().millisecondsSinceEpoch,
              'local_id':          localId,
              'created_at':        now,
              'updated_at':        now,
              'validation_status': 'pending',
            });
            _promptRecordAssessment(null);
          }
        } else {
          _showError('No internet connection.');
        }
      }
    } catch (e) {
      // API call failed despite network check (server unreachable) — fall back to local save
      if (!kIsWeb) {
        try {
          if (_isEdit) {
            await _local.updateBeneficiary(widget.existing!.id, data);
            _showSuccess('Saved locally (will sync when reconnected)');
          } else {
            final localId = const Uuid().v4();
            final now     = DateTime.now().toIso8601String();
            await _local.insertOfflineBeneficiary({
              ...data,
              'id':                DateTime.now().millisecondsSinceEpoch,
              'local_id':          localId,
              'created_at':        now,
              'updated_at':        now,
              'validation_status': 'pending',
            });
            _promptRecordAssessment(null);
          }
        } catch (localErr) {
          _showError('Error: $localErr');
        }
      } else {
        _showError('Error: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _promptRecordAssessment(BeneficiaryModel? newBene) {
    if (!mounted) return;
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 28),
          const SizedBox(width: 10),
          const Text('Beneficiary Saved!'),
        ]),
        content: const Text(
          'Do you want to record an assessment for this beneficiary now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Later'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.monitor_weight_outlined, size: 18),
            label: const Text('Record Assessment'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    ).then((record) {
      if (!mounted) return;
      // Pop with result so BeneficiaryListScreen can open AssessmentFormScreen
      // from its own context (ensuring the list reloads before & after assessment).
      Navigator.pop(context, record == true ? {'openAssessment': newBene} : true);
    });
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating));

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Beneficiary' : 'Add Beneficiary')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── PERSONAL INFORMATION ──────────────────────────────
            _SectionCard(
              title: 'Personal Information',
              icon:  Icons.person_outline_rounded,
              children: [
                _buildField(_lastNameCtrl,   'Last Name',  required: true),
                _buildField(_firstNameCtrl,  'First Name', required: true),
                _buildField(_middleNameCtrl, 'Middle Name'),
                _buildField(_suffixCtrl,     'Suffix (Jr., Sr., III)'),
                _buildField(_placeOfBirthCtrl, 'Place of Birth'),

                // Date of Birth
                const SizedBox(height: 4),
                const Text('Date of Birth *',
                    style: TextStyle(fontSize: 12, color: const Color(0xFF8FA8BF))),
                const SizedBox(height: 6),
                InkWell(
                  onTap:        _pickDob,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _dob == null ? const Color(0xFF4A6080) : const Color(0xFF1565C0),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Icon(Icons.cake_rounded, size: 20,
                          color: _dob == null ? Colors.grey : const Color(0xFF1565C0)),
                      const SizedBox(width: 10),
                      Text(
                        _dob == null ? 'Select date of birth' : DateFormat('MMMM d, yyyy').format(_dob!),
                        style: TextStyle(
                          color:    _dob == null ? const Color(0xFF607896) : const Color(0xFFE8F4FD),
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.calendar_today_rounded, size: 16, color: Colors.grey),
                    ]),
                  ),
                ),
                if (_duplicateWarning != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color:        Colors.amber.shade50,
                      border:       Border.all(color: Colors.amber.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(
                        _duplicateWarning!,
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                      )),
                    ]),
                  ),
                ],
                const SizedBox(height: 14),

                // Sex
                const Text('Sex *',
                    style: TextStyle(fontSize: 12, color: const Color(0xFF8FA8BF))),
                const SizedBox(height: 6),
                Row(
                  children: ['Male', 'Female'].map((s) {
                    final sel = _sex == s;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _sex = s),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color:  sel ? const Color(0xFF1565C0) : const Color(0xFF0F1E35),
                            border: Border.all(
                                color: sel ? const Color(0xFF1565C0) : const Color(0xFF1E3050)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(s == 'Male' ? Icons.male_rounded : Icons.female_rounded,
                                color: sel ? Colors.white : Colors.grey, size: 18),
                            const SizedBox(width: 6),
                            Text(s, style: TextStyle(
                              color:      sel ? Colors.white : const Color(0xFFE8F4FD),
                              fontWeight: FontWeight.w600,
                              fontSize:   14,
                            )),
                          ]),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),

            // ── LOCATION ─────────────────────────────────────────
            _SectionCard(
              title: 'Location',
              icon:  Icons.location_on_outlined,
              children: [
                const Text('Barangay *',
                    style: TextStyle(fontSize: 12, color: const Color(0xFF8FA8BF))),
                const SizedBox(height: 6),
                _barangays.isEmpty
                    ? OutlinedButton.icon(
                        onPressed: _loadBarangays,
                        icon:  const Icon(Icons.refresh),
                        label: const Text('Load barangays'),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48)),
                      )
                    : _barangays.length == 1
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF1565C0)),
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFF1565C0).withValues(alpha: 0.06),
                        ),
                        child: Row(children: [
                          const Icon(Icons.location_on_rounded, size: 18, color: Color(0xFF1565C0)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_barangay ?? _barangays.first,
                              style: const TextStyle(fontSize: 14, color: Color(0xFFE8F4FD)))),
                          const Icon(Icons.lock_outline_rounded, size: 16, color: Colors.grey),
                        ]),
                      )
                    : DropdownButtonFormField<String>(
                        value: _barangay,
                        decoration: InputDecoration(
                          hintText: 'Select barangay',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                        isExpanded: true,
                        items: _barangays
                            .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                            .toList(),
                        onChanged: (v) => setState(() => _barangay = v),
                        validator: (v) => v == null ? 'Barangay is required' : null,
                      ),
                const SizedBox(height: 12),
                _buildField(_purokCtrl,       'Purok / Zone / Sitio'),
                _buildField(_householdNoCtrl, 'Household Number'),
              ],
            ),

            // ── FAMILY INFORMATION ────────────────────────────────
            _SectionCard(
              title: 'Family Information',
              icon:  Icons.family_restroom_rounded,
              children: [
                _buildField(_motherCtrl,      "Mother's Full Name"),
                _buildField(_fatherCtrl,      "Father's Full Name"),
                _buildField(_guardianNameCtrl, 'Guardian Name'),
                _buildField(_guardianRelCtrl,  'Guardian Relationship'),
                _buildField(_contactCtrl, 'Contact Number',
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 4),

                // PhilHealth
                const Text('PhilHealth Status',
                    style: TextStyle(fontSize: 12, color: const Color(0xFF8FA8BF))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _philhealthStatus,
                  decoration: InputDecoration(
                    hintText: 'Select status',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('Not specified')),
                    ..._philhealthOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                  ],
                  onChanged: (v) => setState(() => _philhealthStatus = v),
                ),
                const SizedBox(height: 12),

                // 4Ps
                _buildToggle(
                  label:    '4Ps Member',
                  subtitle: 'Pantawid Pamilyang Pilipino Program',
                  value:    _is4ps,
                  onTap:    () => setState(() => _is4ps = !_is4ps),
                ),
              ],
            ),

            // ── SOCIOECONOMIC ─────────────────────────────────────
            _SectionCard(
              title: 'Socioeconomic Information',
              icon:  Icons.bar_chart_rounded,
              children: [
                // NHTS-PR
                const Text('NHTS-PR Status',
                    style: TextStyle(fontSize: 12, color: const Color(0xFF8FA8BF))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _nhtsStatus,
                  decoration: InputDecoration(
                    hintText: 'Select NHTS-PR status',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('Not specified')),
                    ..._nhtsOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                  ],
                  onChanged: (v) => setState(() => _nhtsStatus = v),
                ),
                const SizedBox(height: 12),

                // Income classification
                const Text('Income Classification',
                    style: TextStyle(fontSize: 12, color: const Color(0xFF8FA8BF))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _incomeClassification,
                  decoration: InputDecoration(
                    hintText: 'Select classification',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('Not specified')),
                    ..._incomeClassOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                  ],
                  onChanged: (v) => setState(() => _incomeClassification = v),
                ),
                const SizedBox(height: 12),

                _buildField(_incomeCtrl, 'Monthly Household Income (₱)',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                _buildField(_incomeSourceCtrl, 'Income Source'),

                // PWD Household
                _buildToggle(
                  label:    'PWD Household',
                  subtitle: 'Household with Person with Disability',
                  value:    _isPwd,
                  onTap:    () => setState(() => _isPwd = !_isPwd),
                ),
                const SizedBox(height: 8),

                // Indigenous People
                _buildToggle(
                  label:    'Indigenous People (IP)',
                  subtitle: 'Member of indigenous cultural community',
                  value:    _isIP,
                  onTap:    () => setState(() => _isIP = !_isIP),
                ),
                if (_isIP) ...[
                  const SizedBox(height: 12),
                  const Text('IP Group / Tribe',
                      style: TextStyle(fontSize: 12, color: const Color(0xFF8FA8BF))),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: _ipGroup,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'e.g. Higaonon, Maranao, Badjao',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                    onChanged: (v) => _ipGroup = v.trim().isEmpty ? null : v.trim(),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 8),

            // Save button
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation:   3,
                  shadowColor: const Color(0xFF1565C0).withValues(alpha: 0.4),
                ),
                child: _saving
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text(
                        _isEdit ? 'Update Beneficiary' : 'Save Beneficiary',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label, {
    bool required           = false,
    TextInputType? keyboardType,
    int maxLines            = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller:  ctrl,
        keyboardType: keyboardType,
        maxLines:    maxLines,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
            : null,
      ),
    );
  }

  Widget _buildToggle({
    required String label,
    required String subtitle,
    required bool   value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap:        onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
              color: value ? const Color(0xFF1565C0) : const Color(0xFF1E3050)),
          borderRadius: BorderRadius.circular(10),
          color: value
              ? const Color(0xFF1565C0).withValues(alpha: 0.06)
              : const Color(0xFF080F20),
        ),
        child: Row(children: [
          Icon(
            value ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
            color: value ? const Color(0xFF1565C0) : Colors.grey,
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF8FA8BF))),
            ],
          )),
        ]),
      ),
    );
  }
}

// ── SECTION CARD ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String       title;
  final IconData?    icon;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
              ],
              Text(title, style: TextStyle(
                fontSize:    13,
                fontWeight:  FontWeight.w700,
                color:       theme.colorScheme.primary,
                letterSpacing: 0.3,
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
