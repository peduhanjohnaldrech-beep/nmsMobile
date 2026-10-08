import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/assessment_model.dart';
import '../../models/beneficiary_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../services/local_db_service.dart';
import '../../widgets/info_card.dart';
import '../../widgets/status_badge.dart';

class BeneficiaryDetailScreen extends StatefulWidget {
  final BeneficiaryModel beneficiary;
  const BeneficiaryDetailScreen({super.key, required this.beneficiary});

  @override
  State<BeneficiaryDetailScreen> createState() =>
      _BeneficiaryDetailScreenState();
}

class _BeneficiaryDetailScreenState extends State<BeneficiaryDetailScreen> {
  final _local = LocalDbService();
  final _api   = ApiService();

  late BeneficiaryModel _bene;
  List<AssessmentModel> _assessments = [];
  bool _loading     = true;
  bool _submitting  = false;

  @override
  void initState() {
    super.initState();
    _bene = widget.beneficiary;
    _loadAssessments();
  }

  Future<void> _loadAssessments() async {
    setState(() => _loading = true);
    try {
      List<AssessmentModel> items = [];
      if (kIsWeb) {
        final result = await _api.getAssessments(beneficiaryId: _bene.id);
        if (result['success'] == true) {
          final data = result['data'] as Map<String, dynamic>;
          final rows = List<Map<String, dynamic>>.from(data['assessments'] ?? []);
          items = rows.map((r) => AssessmentModel.fromJson(r)).toList();
        }
      } else {
        final rows = await _local.getAssessmentsByBeneficiary(_bene.id);
        items = rows.map((r) => AssessmentModel.fromJson(r)).toList();
      }
      if (mounted) setState(() { _assessments = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshBeneficiary() async {
    try {
      if (kIsWeb) {
        final result = await _api.getBeneficiary(_bene.id);
        if (result['success'] == true) {
          final data = result['data'] as Map<String, dynamic>;
          if (mounted) {
            setState(() => _bene = BeneficiaryModel.fromJson(
              data['beneficiary'] as Map<String, dynamic>,
            ));
          }
        }
      } else {
        final row = await _local.getBeneficiaryById(_bene.id);
        if (row != null && mounted) {
          setState(() => _bene = BeneficiaryModel.fromJson(row));
        }
      }
    } catch (_) {}
    await _loadAssessments();
  }

  Future<void> _submitToAdmin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit to Admin'),
        content: Text(
          'Submit ${_bene.firstName} ${_bene.lastName} to the city health admin? '
          'You will no longer be able to edit this record after submission.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(80, 40)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    final res = await _api.submitBeneficiary(_bene.id);
    if (!mounted) return;
    setState(() => _submitting = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message'] ?? 'Done'),
      backgroundColor: res['success'] == true ? Colors.green : Colors.red,
    ));
    if (res['success'] == true) await _refreshBeneficiary();
  }

  String _formatDate(String date) {
    final dt = DateTime.tryParse(date);
    if (dt == null) return date;
    return DateFormat('MMMM d, yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final latestAssessment = _assessments.isNotEmpty ? _assessments.first : null;
    final theme = Theme.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshBeneficiary,
        child: CustomScrollView(
          slivers: [
            // -------------------------------------------------------
            // HEADER
            // -------------------------------------------------------
            SliverAppBar(
              pinned:          true,
              expandedHeight:  190,
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon:    const Icon(Icons.edit_rounded),
                  tooltip: 'Edit',
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/beneficiaries/edit',
                    arguments: _bene,
                  ).then((_) => _refreshBeneficiary()),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Row(children: [
                          Icon(Icons.delete_outline_rounded, color: Colors.red.shade600, size: 22),
                          const SizedBox(width: 8),
                          const Text('Move to Trash'),
                        ]),
                        content: Text(
                          'Move ${_bene.displayName} to trash?\n\nThis can be restored later.',
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Move to Trash'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && mounted) {
                      final res = await _api.deleteBeneficiary(_bene.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Moved to trash')));
                        if (res['success'] == true) Navigator.pop(context, true);
                      }
                    }
                  },
                ),
                const SizedBox(width: 4),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin:  Alignment.topLeft,
                      end:    Alignment.bottomRight,
                      colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              color:        Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border:       Border.all(color: Colors.white30, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                _bene.initials,
                                style: const TextStyle(
                                  fontSize:   28,
                                  fontWeight: FontWeight.w800,
                                  color:      Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment:  MainAxisAlignment.center,
                              children: [
                                Text(
                                  _bene.displayName,
                                  style: const TextStyle(
                                    fontSize:   18,
                                    fontWeight: FontWeight.w800,
                                    color:      Colors.white,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Row(children: [
                                  const Icon(Icons.location_on_outlined, size: 12, color: Colors.white60),
                                  const SizedBox(width: 3),
                                  Text(_bene.barangay,
                                      style: const TextStyle(fontSize: 12, color: Colors.white70)),
                                ]),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _HeaderChip(label: _bene.sex),
                                    const SizedBox(width: 6),
                                    _HeaderChip(label: '${_bene.ageInYears} yrs  •  ${_bene.ageInMonths} mo'),
                                    if (_bene.ageInMonths >= 60) ...[
                                      const SizedBox(width: 6),
                                      _HeaderChip(label: 'Aged Out', color: Colors.red.shade300),
                                    ],
                                    if (latestAssessment != null) ...[
                                      const SizedBox(width: 6),
                                      _HeaderChip(
                                        label: latestAssessment.nutritionalStatus,
                                        color: latestAssessment.statusColor,
                                        solid: true,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // -------------------------------------------------------
            // BODY
            // -------------------------------------------------------
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Latest nutritional status
                  if (latestAssessment != null) ...[
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                      shadowColor: Colors.black12,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.monitor_weight_rounded, size: 16, color: theme.colorScheme.primary),
                              const SizedBox(width: 6),
                              Text('Latest Nutritional Status',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
                              const Spacer(),
                              if (latestAssessment.isPending)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    border: Border.all(color: Colors.orange.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.hourglass_top_rounded, size: 11, color: Colors.orange.shade700),
                                    const SizedBox(width: 3),
                                    Text('Pending',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.orange.shade800)),
                                  ]),
                                ),
                            ]),
                            const SizedBox(height: 12),
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              StatusChip(status: latestAssessment.nutritionalStatus),
                              const Spacer(),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                _MeasurementRow(icon: Icons.monitor_weight_outlined, label: '${latestAssessment.weightKg} kg'),
                                if (latestAssessment.heightCm != null)
                                  _MeasurementRow(icon: Icons.height_rounded, label: '${latestAssessment.heightCm} cm'),
                                if (latestAssessment.muacCm != null)
                                  _MeasurementRow(icon: Icons.straighten_rounded, label: '${latestAssessment.muacCm} cm MUAC'),
                              ]),
                            ]),
                            if (latestAssessment.weightForAgeZscore != null ||
                                latestAssessment.heightForAgeZscore != null ||
                                latestAssessment.wflhZscore != null) ...[
                              const SizedBox(height: 8),
                              Wrap(spacing: 6, children: [
                                if (latestAssessment.weightForAgeZscore != null)
                                  _ZscoreChip(label: 'WFA', value: latestAssessment.zscoreDisplay),
                                if (latestAssessment.heightForAgeZscore != null)
                                  _ZscoreChip(label: 'HFA', value: latestAssessment.hfaZscoreDisplay),
                                if (latestAssessment.wflhZscore != null)
                                  _ZscoreChip(label: 'WFLH', value: latestAssessment.wflhZscoreDisplay),
                              ]),
                            ],
                            const SizedBox(height: 10),
                            Row(children: [
                              Icon(Icons.calendar_today_rounded, size: 12, color: const Color(0xFF4A6080)),
                              const SizedBox(width: 4),
                              Text(
                                '${_formatDate(latestAssessment.assessmentDate)}  •  ${latestAssessment.periodDisplay}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Validation status banner
                  if (_bene.isPendingValidation) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        Icon(Icons.hourglass_top_rounded, color: Colors.orange.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          'Pending midwife validation — assessments are locked until approved.',
                          style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                        )),
                      ]),
                    ),
                  ] else if (_bene.isRejected) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        Icon(Icons.cancel_outlined, color: Colors.red.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          'Registration rejected. Please edit and resubmit for validation.',
                          style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                        )),
                      ]),
                    ),
                  ],

                  // Submit banner for BNS — show when validated but not yet submitted
                  Builder(builder: (ctx) {
                    final role = ctx.read<AuthProvider>().user?.role ?? '';
                    if (role != 'bns') return const SizedBox.shrink();
                    if (_bene.isSubmitted) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          border: Border.all(color: Colors.blue.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          Icon(Icons.check_circle_outline, color: Colors.blue.shade700, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            'Submitted to admin.',
                            style: TextStyle(color: Colors.blue.shade800, fontSize: 13),
                          )),
                        ]),
                      );
                    }
                    if (_bene.isValidated) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          border: Border.all(color: Colors.green.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          Icon(Icons.verified_outlined, color: Colors.green.shade700, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            'Validated — ready to submit to admin.',
                            style: TextStyle(color: Colors.green.shade800, fontSize: 13),
                          )),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _submitting ? null : _submitToAdmin,
                            icon: _submitting
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.send_rounded, size: 16),
                            label: const Text('Submit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              textStyle: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ]),
                      );
                    }
                    return const SizedBox.shrink();
                  }),

                  // Personal info
                  InfoCard(
                    title:    'Personal Information',
                    icon:     Icons.person_outline_rounded,
                    children: [
                      InfoRow(label: 'Last Name',   value: _bene.lastName),
                      InfoRow(label: 'First Name',  value: _bene.firstName),
                      InfoRow(label: 'Middle Name', value: _bene.middleName ?? '—'),
                      InfoRow(label: 'Suffix',      value: _bene.suffix      ?? '—'),
                      InfoRow(
                        label: 'Date of Birth',
                        value: _bene.dateOfBirth.isNotEmpty
                            ? _formatDate(_bene.dateOfBirth)
                            : '—',
                      ),
                      InfoRow(label: 'Age', value: '${_bene.ageInYears} years (${_bene.ageInMonths} months)'),
                      InfoRow(label: 'Sex',  value: _bene.sex),
                    ],
                  ),

                  // Location
                  InfoCard(
                    title:    'Location',
                    icon:     Icons.location_on_outlined,
                    children: [
                      InfoRow(label: 'Barangay',      value: _bene.barangay),
                      InfoRow(label: 'Purok/Zone',    value: _bene.purokZone    ?? '—'),
                      InfoRow(label: 'Household No.', value: _bene.householdNo  ?? '—'),
                      InfoRow(label: 'Place of Birth', value: _bene.placeOfBirth ?? '—'),
                    ],
                  ),

                  // Family
                  InfoCard(
                    title:    'Family Information',
                    icon:     Icons.family_restroom_rounded,
                    children: [
                      InfoRow(label: "Mother's Name",       value: _bene.motherName ?? '—'),
                      InfoRow(label: "Father's Name",       value: _bene.fatherName ?? '—'),
                      InfoRow(label: 'Guardian Name',       value: _bene.guardianName ?? '—'),
                      InfoRow(label: 'Guardian Relationship', value: _bene.guardianRelationship ?? '—'),
                      InfoRow(label: 'Contact Number',      value: _bene.contactNumber ?? '—'),
                      InfoRow(label: 'PhilHealth',          value: _bene.philhealthStatus ?? '—'),
                      InfoRow(label: '4Ps Member',          value: _bene.is4ps ? 'Yes' : 'No'),
                    ],
                  ),

                  // Socioeconomic
                  InfoCard(
                    title:    'Socioeconomic Information',
                    icon:     Icons.bar_chart_rounded,
                    children: [
                      InfoRow(label: 'NHTS-PR Status',      value: _bene.nhtsStatus ?? '—'),
                      InfoRow(label: 'Income Classification', value: _bene.incomeClassification ?? '—'),
                      InfoRow(
                        label: 'Monthly Income',
                        value: _bene.householdMonthlyIncome != null
                            ? '₱${_bene.householdMonthlyIncome!.toStringAsFixed(2)}'
                            : '—',
                      ),
                      InfoRow(label: 'Income Source',       value: _bene.incomeSource ?? '—'),
                      InfoRow(label: 'PWD Household',       value: _bene.isPwd ? 'Yes' : 'No'),
                      InfoRow(label: 'Indigenous People',   value: _bene.isIP  ? 'Yes' : 'No'),
                      if (_bene.isIP)
                        InfoRow(label: 'IP Group',          value: _bene.ipGroup ?? '—'),
                    ],
                  ),

                  // Assessment history
                  if (_loading) ...[
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(16),
                      child:   CircularProgressIndicator(),
                    )),
                  ] else ...[
                    _AssessmentHistoryCard(
                      assessments: _assessments,
                      formatDate:  _formatDate,
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon:  const Icon(Icons.edit_rounded),
                          label: const Text('Edit'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pushNamed(
                            context,
                            '/beneficiaries/edit',
                            arguments: _bene,
                          ).then((_) => _refreshBeneficiary()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Tooltip(
                          message: _bene.isRejected
                              ? 'Registration was rejected. Cannot add assessment.'
                              : '',
                          child: ElevatedButton.icon(
                            icon:  const Icon(Icons.assignment_add),
                            label: const Text('Add Assessment'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _bene.isRejected
                                  ? Colors.grey
                                  : Colors.teal,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 50),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _bene.isRejected
                                ? null
                                : () => Navigator.pushNamed(
                                    context,
                                    '/assessments/create-for',
                                    arguments: _bene,
                                  ).then((_) => _loadAssessments()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------
// SUB-WIDGETS
// -------------------------------------------------------

class _HeaderChip extends StatelessWidget {
  final String label;
  final Color? color;
  final bool   solid;
  const _HeaderChip({required this.label, this.color, this.solid = false});

  @override
  Widget build(BuildContext context) {
    if (solid && color != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color:        color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        (color ?? Colors.white).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: Colors.white30),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MeasurementRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _MeasurementRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: const Color(0xFF607896)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _ZscoreChip extends StatelessWidget {
  final String label, value;
  const _ZscoreChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFF0D1B2E),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: const Color(0xFF1A3050)),
    ),
    child: Text('$label: $value',
      style: const TextStyle(fontSize: 11, color: const Color(0xFF8FA8BF), fontWeight: FontWeight.w500)),
  );
}

class _AssessmentHistoryCard extends StatelessWidget {
  final List<AssessmentModel> assessments;
  final String Function(String) formatDate;

  const _AssessmentHistoryCard({
    required this.assessments,
    required this.formatDate,
  });

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
            Row(
              children: [
                Icon(Icons.history_rounded, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Assessment History (${assessments.length})',
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w700,
                    color:      theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            if (assessments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(children: [
                  Icon(Icons.monitor_weight_outlined, size: 40, color: const Color(0xFF2A4060)),
                  const SizedBox(height: 8),
                  const Text('No assessments recorded yet.',
                      style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 13)),
                ]),
              )
            else ...[
              // Period comparison banners per year
              ..._buildPeriodComparisons(assessments),
              const Divider(height: 1),
              ...assessments.asMap().entries.map((entry) {
                final i = entry.key;
                final a = entry.value;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Date column
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      formatDate(a.assessmentDate),
                                      style: const TextStyle(
                                        fontSize:   13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Row(children: [
                                      Text(
                                        a.periodDisplay,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color:    Color(0xFF9E9E9E),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: a.periodNumber == 1
                                              ? Colors.blue.shade50
                                              : Colors.purple.shade50,
                                          border: Border.all(
                                            color: a.periodNumber == 1
                                                ? Colors.blue.shade200
                                                : Colors.purple.shade200,
                                          ),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          a.periodLabel,
                                          style: TextStyle(
                                            fontSize:   9,
                                            fontWeight: FontWeight.w700,
                                            color: a.periodNumber == 1
                                                ? Colors.blue.shade700
                                                : Colors.purple.shade700,
                                          ),
                                        ),
                                      ),
                                    ]),
                                  ],
                                ),
                              ),
                              // Measurements
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${a.weightKg} kg',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    if (a.heightCm != null)
                                      Text('${a.heightCm} cm',
                                          style: const TextStyle(fontSize: 11, color: const Color(0xFF8FA8BF))),
                                    if (a.muacCm != null)
                                      Text('MUAC: ${a.muacCm} cm',
                                          style: const TextStyle(fontSize: 11, color: const Color(0xFF8FA8BF))),
                                    Text(a.ageDisplay,
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
                                  ],
                                ),
                              ),
                              // Status badge
                              StatusBadge(status: a.nutritionalStatus),
                            ],
                          ),
                          // Z-scores row
                          if (a.weightForAgeZscore != null || a.heightForAgeZscore != null || a.wflhZscore != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  if (a.weightForAgeZscore != null)
                                    _ZscoreChip(label: 'WFA', value: a.zscoreDisplay),
                                  if (a.heightForAgeZscore != null)
                                    _ZscoreChip(label: 'HFA', value: a.hfaZscoreDisplay),
                                  if (a.wflhZscore != null)
                                    _ZscoreChip(label: 'WFLH', value: a.wflhZscoreDisplay),
                                ],
                              ),
                            ),
                          // Validation status badges
                          if (a.validationStatus == 'pending' || a.validationStatus == 'rejected')
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: a.validationStatus == 'rejected'
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        border: Border.all(color: Colors.red.shade300),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        Icon(Icons.cancel_rounded, size: 12, color: Colors.red.shade700),
                                        const SizedBox(width: 4),
                                        Text('Rejected',
                                          style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                                      ]),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        border: Border.all(color: Colors.orange.shade300),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        Icon(Icons.hourglass_top_rounded, size: 12, color: Colors.orange.shade700),
                                        const SizedBox(width: 4),
                                        Text('Pending Validation',
                                          style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.w600)),
                                      ]),
                                    ),
                            ),
                        ],
                      ),
                    ),
                    if (i < assessments.length - 1) const Divider(height: 1),
                  ],
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPeriodComparisons(List<AssessmentModel> assessments) {
    // Group by year
    final Map<int, Map<int, AssessmentModel>> byYear = {};
    for (final a in assessments) {
      byYear.putIfAbsent(a.assessmentYear, () => {});
      // Keep first occurrence per period per year (most recent)
      byYear[a.assessmentYear]!.putIfAbsent(a.periodNumber, () => a);
    }

    const order = {'SUW': 0, 'UW': 1, 'Normal': 2, 'OW': 3, 'OB': 4};
    final widgets = <Widget>[];

    for (final year in byYear.keys.toList()..sort((a, b) => b.compareTo(a))) {
      final periods = byYear[year]!;
      if (!periods.containsKey(1) || !periods.containsKey(2)) continue;

      final first  = periods[1]!;
      final second = periods[2]!;
      final s1 = order[first.nutritionalStatus]  ?? 2;
      final s2 = order[second.nutritionalStatus] ?? 2;

      final String label;
      final Color  color;
      final IconData icon;

      if (s2 > s1) {
        label = 'Worsened from ${first.nutritionalStatus} → ${second.nutritionalStatus} ($year)';
        color = Colors.red.shade700;
        icon  = Icons.trending_down_rounded;
      } else if (s2 < s1) {
        label = 'Improved from ${first.nutritionalStatus} → ${second.nutritionalStatus} ($year)';
        color = Colors.green.shade700;
        icon  = Icons.trending_up_rounded;
      } else {
        label = 'Status unchanged: ${first.nutritionalStatus} ($year)';
        color = Colors.blue.shade700;
        icon  = Icons.trending_flat_rounded;
      }

      widgets.add(
        Container(
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color:        color.withValues(alpha: 0.07),
            border:       Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              ),
            ),
          ]),
        ),
      );
    }
    return widgets;
  }
}
