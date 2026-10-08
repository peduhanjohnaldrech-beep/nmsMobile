import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/beneficiary_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../services/local_db_service.dart';
import '../../services/sync_service.dart';
import '../../widgets/sync_banner.dart';
import '../../widgets/info_card.dart';
import '../../widgets/status_badge.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _sync  = SyncService();
  final _local = LocalDbService();
  final _api   = ApiService();

  bool    _syncing        = false;
  int     _totalBene      = 0;
  int     _uwCount        = 0;
  int     _unsyncedCount  = 0;
  String? _lastSyncAt;
  List<BeneficiaryModel> _recent = [];

  // Validation counts
  int _pendingAssessments   = 0;
  int _pendingBeneficiaries = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadStats(), _loadRecent(), _loadValidationCounts()]);
  }

  Future<void> _loadValidationCounts() async {
    try {
      final user = context.read<AuthProvider>().user;
      if (user == null) return;
      final res = await _api.getValidationCounts();
      if (!mounted) return;
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final role = user.role;
      if (role == 'midwife' || role == 'admin' || role == 'nutritionist') {
        setState(() => _pendingAssessments = (data['pending'] as int? ?? 0));
        final bRes = await _api.getBeneficiaryValidationPending();
        if (mounted) {
          setState(() => _pendingBeneficiaries =
              (bRes['data']?['count'] as int? ?? 0));
        }
      } else {
        // BHW/encoder: show their own pending submissions
        setState(() {
          _pendingAssessments   = (data['pending'] as int? ?? 0);
          _pendingBeneficiaries = (data['pending_beneficiaries'] as int? ?? 0);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    if (kIsWeb) return;
    final user   = context.read<AuthProvider>().user;
    final brgy   = user?.isScopedToBarangay == true ? user?.barangay : null;

    final total    = await _local.countBeneficiaries(barangay: brgy);
    final uw       = await _local.countByStatus('UW',  barangay: brgy);
    final unsynced = await _local.getUnsyncedCount();
    final lastSync = await _sync.getLastSyncTime();

    if (mounted) {
      setState(() {
        _totalBene     = total;
        _uwCount       = uw;
        _unsyncedCount = unsynced;
        _lastSyncAt    = lastSync;
      });
    }
  }

  Future<void> _loadRecent() async {
    if (kIsWeb) return;
    final user = context.read<AuthProvider>().user;
    final brgy = user?.isScopedToBarangay == true ? user?.barangay : null;
    final rows = await _local.getRecentBeneficiaries(limit: 5, barangay: brgy);
    if (mounted) {
      setState(() {
        _recent = rows.map((r) => BeneficiaryModel.fromJson(r)).toList();
      });
    }
  }

  Future<void> _doSync() async {
    if (_syncing) return;
    setState(() => _syncing = true);

    final user   = context.read<AuthProvider>().user;
    final brgy   = user?.isScopedToBarangay == true ? user?.barangay : null;
    final result = await _sync.sync(barangay: brgy);

    if (mounted) {
      setState(() => _syncing = false);
      await _loadAll();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth  = context.watch<AuthProvider>();
    final user  = auth.user;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF060D1F),
      body: RefreshIndicator(
        onRefresh: _doSync,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                // Sync banner
                SyncBanner(
                  unsyncedCount: _unsyncedCount,
                  lastSyncAt:    _lastSyncAt,
                  syncing:       _syncing,
                  onSyncTap:     _doSync,
                ),

                // Stats row
                if (!kIsWeb) ...[
                  Row(
                    children: [
                      StatCard(
                        label: 'Beneficiaries',
                        value: _totalBene.toString(),
                        icon:  Icons.people_rounded,
                        color: theme.colorScheme.primary,
                        onTap: () => Navigator.pushNamed(context, '/beneficiaries'),
                      ),
                      const SizedBox(width: 8),
                      StatCard(
                        label: 'Underweight',
                        value: _uwCount.toString(),
                        icon:  Icons.trending_down_rounded,
                        color: Colors.orange,
                        onTap: () => Navigator.pushNamed(context, '/beneficiaries'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Validation alert card
                if (_pendingAssessments > 0 || _pendingBeneficiaries > 0) ...[
                  _ValidationAlertCard(
                    pendingAssessments:   _pendingAssessments,
                    pendingBeneficiaries: _pendingBeneficiaries,
                    user: context.read<AuthProvider>().user,
                  ),
                  const SizedBox(height: 16),
                ],

                // Quick actions
                const _SectionHeader(title: 'Quick Actions'),
                const SizedBox(height: 10),
                Builder(builder: (context) {
                  final u    = context.read<AuthProvider>().user;
                  final role = u?.role ?? '';
                  final actions = <_QuickActionCard>[

                    // ── BNS / BHW ──────────────────────────────────────
                    if (role == 'bns' || role == 'bhw') ...[
                      _QuickActionCard(
                        icon:  Icons.person_add_rounded,
                        label: 'Add Beneficiary',
                        color: Colors.blue.shade700,
                        onTap: () => Navigator.pushNamed(context, '/beneficiaries/create')
                            .then((_) => _loadAll()),
                      ),
                      _QuickActionCard(
                        icon:  Icons.people_rounded,
                        label: 'My Beneficiaries',
                        color: Colors.indigo.shade600,
                        onTap: () => Navigator.pushNamed(context, '/beneficiaries'),
                      ),
                      _QuickActionCard(
                        icon:  Icons.monitor_weight_rounded,
                        label: 'OPT Weighing',
                        color: Colors.teal.shade700,
                        onTap: () => Navigator.pushNamed(context, '/assessments/batch')
                            .then((_) => _loadAll()),
                      ),
                    ],

                    // ── MIDWIFE ─────────────────────────────────────────
                    if (role == 'midwife')
                      _QuickActionCard(
                        icon:  Icons.fact_check_outlined,
                        label: 'Validation Queue',
                        color: Colors.orange.shade700,
                        onTap: () => Navigator.pushNamed(context, '/validation/queue'),
                      ),

                    // ── ADMIN / NUTRITIONIST / ENCODER ──────────────────
                    if (role == 'admin' || role == 'nutritionist' || role == 'encoder') ...[
                      if (u?.hasPermission('beneficiaries') ?? false) ...[
                        _QuickActionCard(
                          icon:  Icons.person_add_rounded,
                          label: 'Add Beneficiary',
                          color: Colors.blue.shade700,
                          onTap: () => Navigator.pushNamed(context, '/beneficiaries/create')
                              .then((_) => _loadAll()),
                        ),
                        _QuickActionCard(
                          icon:  Icons.people_rounded,
                          label: 'Beneficiaries',
                          color: Colors.indigo.shade600,
                          onTap: () => Navigator.pushNamed(context, '/beneficiaries'),
                        ),
                      ],
                      if (u?.hasPermission('assessments') ?? false)
                        _QuickActionCard(
                          icon:  Icons.assignment_add,
                          label: 'Add Assessment',
                          color: Colors.teal.shade700,
                          onTap: () => Navigator.pushNamed(context, '/assessments/create')
                              .then((_) => _loadAll()),
                        ),
                      if (u?.hasPermission('programs') ?? false)
                        _QuickActionCard(
                          icon:  Icons.vaccines_outlined,
                          label: 'Programs',
                          color: Colors.purple.shade700,
                          onTap: () => Navigator.pushNamed(context, '/programs'),
                        ),
                      if (u?.hasPermission('dispensing') ?? false)
                        _QuickActionCard(
                          icon:  Icons.medical_services_outlined,
                          label: 'Dispensing',
                          color: Colors.teal.shade600,
                          onTap: () => Navigator.pushNamed(context, '/dispensing'),
                        ),
                      if (u?.hasPermission('reports') ?? false)
                        _QuickActionCard(
                          icon:  Icons.bar_chart_rounded,
                          label: 'Reports',
                          color: Colors.brown.shade600,
                          onTap: () => Navigator.pushNamed(context, '/reports'),
                        ),
                      if (u?.hasPermission('activity_log') ?? false)
                        _QuickActionCard(
                          icon:  Icons.history_rounded,
                          label: 'Activity Log',
                          color: Colors.blueGrey.shade700,
                          onTap: () => Navigator.pushNamed(context, '/activity'),
                        ),
                      if (u?.hasPermission('validation') ?? false)
                        _QuickActionCard(
                          icon:  Icons.fact_check_outlined,
                          label: 'Validation',
                          color: Colors.orange.shade700,
                          onTap: () => Navigator.pushNamed(context, '/validation/queue'),
                        ),
                    ],

                    // ── ALWAYS ──────────────────────────────────────────
                    _QuickActionCard(
                      icon:  Icons.sync_rounded,
                      label: 'Sync Now',
                      color: Colors.green.shade700,
                      onTap: _syncing ? null : _doSync,
                    ),
                  ];
                  return GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap:     true,
                    physics:        const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing:  8,
                    childAspectRatio: 1.1,
                    children: actions,
                  );
                }),
                const SizedBox(height: 20),

                // Recent beneficiaries
                if (!kIsWeb && _recent.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _SectionHeader(title: 'Recent Beneficiaries'),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/beneficiaries'),
                        child: const Text('See All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Card(
                    child: Column(
                      children: [
                        ..._recent.asMap().entries.map((entry) {
                          final i    = entry.key;
                          final bene = entry.value;
                          return Column(
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                leading: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: bene.sex == 'Male'
                                      ? Colors.blue.shade100
                                      : Colors.pink.shade100,
                                  child: Text(
                                    bene.initials,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color:      bene.sex == 'Male'
                                          ? Colors.blue.shade800
                                          : Colors.pink.shade800,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  bene.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize:   14,
                                  ),
                                ),
                                subtitle: Text(
                                  '${bene.barangay}${bene.purokZone != null ? " • ${bene.purokZone}" : ""}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: bene.latestStatus != null
                                    ? StatusBadge(status: bene.latestStatus!)
                                    : null,
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  '/beneficiaries/detail',
                                  arguments: bene,
                                ).then((_) => _loadAll()),
                              ),
                              if (i < _recent.length - 1)
                                const Divider(height: 1, indent: 70),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ],

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------
// SUB-WIDGETS
// -------------------------------------------------------

class _ValidationAlertCard extends StatelessWidget {
  final int     pendingAssessments;
  final int     pendingBeneficiaries;
  final dynamic user;

  const _ValidationAlertCard({
    required this.pendingAssessments,
    required this.pendingBeneficiaries,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final role       = (user?.role ?? '') as String;
    final isMidwife  = role == 'midwife' || role == 'admin' || role == 'nutritionist';
    final route      = isMidwife ? '/validation/queue' : '/validation/submissions';
    final title      = isMidwife ? 'Pending Validation' : 'Your Submissions Pending';

    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFF9100).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFF9100).withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9100).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.pending_actions_rounded, color: Color(0xFFFF9100), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFFFB74D))),
            const SizedBox(height: 2),
            if (pendingAssessments > 0)
              Text('• $pendingAssessments assessment${pendingAssessments > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFFF9100))),
            if (pendingBeneficiaries > 0)
              Text('• $pendingBeneficiaries beneficiar${pendingBeneficiaries > 1 ? 'ies' : 'y'}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFFF9100))),
          ])),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFFF9100)),
        ]),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(
          color: const Color(0xFF00C6FF),
          borderRadius: BorderRadius.circular(2),
        )),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize:      14,
            fontWeight:    FontWeight.w700,
            color:         Color(0xFFE8F4FD),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData      icon;
  final String        label;
  final Color         color;
  final VoidCallback? onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:        onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B1527),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color:        color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize:   11,
                  fontWeight: FontWeight.w600,
                  color:      Color(0xFFB0BEC5),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

