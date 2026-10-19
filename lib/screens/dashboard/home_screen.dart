import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/beneficiary_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../services/local_db_service.dart';
import '../../services/sync_service.dart';
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
      final messenger = ScaffoldMessenger.of(context);
      await _loadAll();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>();
    final user  = context.read<AuthProvider>().user;
    final role  = user?.role ?? '';
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF060D1F),
      body: RefreshIndicator(
        onRefresh: _doSync,
        color: const Color(0xFF00C6FF),
        backgroundColor: const Color(0xFF0B1527),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Header ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                    colors: [Color(0xFF0B1A3D), Color(0xFF060D1F)],
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.of(context).padding.top + 16, 20, 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_greeting()},',
                            style: const TextStyle(
                              fontSize:   14,
                              color:      Color(0xFF8EAFD4),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.fullName.split(' ').first ?? 'User',
                            style: const TextStyle(
                              fontSize:   24,
                              fontWeight: FontWeight.w700,
                              color:      Color(0xFFE8F4FD),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(children: [
                            _RoleBadge(role: role),
                            if ((user?.barangay ?? '').isNotEmpty) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.location_on_rounded,
                                  size: 12, color: Color(0xFF8EAFD4)),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  user!.barangay!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color:    Color(0xFF8EAFD4),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ]),
                        ],
                      ),
                    ),
                    // Sync indicator button
                    _SyncButton(
                      syncing:       _syncing,
                      unsyncedCount: _unsyncedCount,
                      lastSyncAt:    _lastSyncAt,
                      onTap:         _doSync,
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── Stats ────────────────────────────────────────────
                  if (!kIsWeb) ...[
                    Row(children: [
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
                      const SizedBox(width: 8),
                      _MiniStatCard(
                        label: 'Unsynced',
                        value: _unsyncedCount.toString(),
                        icon:  Icons.cloud_upload_rounded,
                        color: _unsyncedCount > 0 ? Colors.amber : Colors.green,
                      ),
                    ]),
                    const SizedBox(height: 16),
                  ],

                  // ── Validation alert ─────────────────────────────────
                  if (_pendingAssessments > 0 || _pendingBeneficiaries > 0) ...[
                    _ValidationAlertCard(
                      pendingAssessments:   _pendingAssessments,
                      pendingBeneficiaries: _pendingBeneficiaries,
                      user: user,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Quick Actions ────────────────────────────────────
                  const _SectionHeader(title: 'Quick Actions'),
                  const SizedBox(height: 10),
                  Builder(builder: (context) {
                    final u = context.read<AuthProvider>().user;
                    final r = u?.role ?? '';
                    final actions = <_QuickActionCard>[

                      // ── BNS / BHW ──────────────────────────────────
                      if (r == 'bns' || r == 'bhw') ...[
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
                          icon:  Icons.vaccines_outlined,
                          label: 'Programs',
                          color: Colors.purple.shade700,
                          onTap: () => Navigator.pushNamed(context, '/programs'),
                        ),
                        _QuickActionCard(
                          icon:  Icons.monitor_weight_rounded,
                          label: 'OPT Weighing',
                          color: Colors.teal.shade700,
                          onTap: () => Navigator.pushNamed(context, '/assessments/batch')
                              .then((_) => _loadAll()),
                        ),
                        _QuickActionCard(
                          icon:  Icons.track_changes_rounded,
                          label: 'DSP Follow-up',
                          color: Colors.cyan.shade700,
                          onTap: () => Navigator.pushNamed(context, '/dsp/monitoring')
                              .then((_) => _loadAll()),
                        ),
                        _QuickActionCard(
                          icon:  Icons.assignment_turned_in_outlined,
                          label: 'My Submissions',
                          color: Colors.orange.shade700,
                          onTap: () => Navigator.pushNamed(context, '/validation/submissions')
                              .then((_) => _loadAll()),
                        ),
                      ],

                      // ── MIDWIFE ────────────────────────────────────
                      if (r == 'midwife') ...[
                        _QuickActionCard(
                          icon:  Icons.fact_check_outlined,
                          label: 'Validation Queue',
                          color: Colors.orange.shade700,
                          onTap: () => Navigator.pushNamed(context, '/validation/queue')
                              .then((_) => _loadAll()),
                        ),
                        _QuickActionCard(
                          icon:  Icons.track_changes_rounded,
                          label: 'Track Records',
                          color: Colors.teal.shade700,
                          onTap: () => Navigator.pushNamed(context, '/validation/track')
                              .then((_) => _loadAll()),
                        ),
                      ],

                      // ── ADMIN / NUTRITIONIST / ENCODER ────────────
                      if (r == 'admin' || r == 'nutritionist' || r == 'encoder') ...[
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
                    ];
                    return GridView.count(
                      crossAxisCount:   3,
                      shrinkWrap:       true,
                      physics:          const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 8,
                      mainAxisSpacing:  8,
                      childAspectRatio: 1.05,
                      children: actions,
                    );
                  }),
                  const SizedBox(height: 20),

                  // ── Recent Beneficiaries ─────────────────────────────
                  if (!kIsWeb && _recent.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const _SectionHeader(title: 'Recent Beneficiaries'),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/beneficiaries'),
                          child: const Text('See All',
                              style: TextStyle(fontSize: 12, color: Color(0xFF00C6FF))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color:        const Color(0xFF0B1527),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Column(
                        children: [
                          ..._recent.asMap().entries.map((entry) {
                            final i    = entry.key;
                            final bene = entry.value;
                            return Column(children: [
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                leading: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: bene.sex == 'Male'
                                      ? const Color(0xFF1565C0)
                                      : const Color(0xFFAD1457),
                                  child: Text(
                                    bene.initials,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color:      Colors.white),
                                  ),
                                ),
                                title: Text(
                                  bene.displayName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                subtitle: Text(
                                  '${bene.barangay}${bene.purokZone != null ? " • ${bene.purokZone}" : ""}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: bene.latestStatus != null
                                    ? StatusBadge(status: bene.latestStatus!)
                                    : null,
                                onTap: () => Navigator.pushNamed(
                                  context, '/beneficiaries/detail',
                                  arguments: bene,
                                ).then((_) => _loadAll()),
                              ),
                              if (i < _recent.length - 1)
                                Divider(height: 1, indent: 70,
                                    color: Colors.white.withValues(alpha: 0.06)),
                            ]);
                          }),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 80),
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

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  static const _labels = {
    'bns':          'BNS',
    'bhw':          'BHW',
    'midwife':      'Midwife',
    'encoder':      'Encoder',
    'nutritionist': 'Nutritionist',
    'admin':        'Admin',
  };

  static const _colors = {
    'bns':          Color(0xFF00BCD4),
    'bhw':          Color(0xFF26A69A),
    'midwife':      Color(0xFF7E57C2),
    'encoder':      Color(0xFF42A5F5),
    'nutritionist': Color(0xFF66BB6A),
    'admin':        Color(0xFFEF5350),
  };

  @override
  Widget build(BuildContext context) {
    final label = _labels[role] ?? role.toUpperCase();
    final color = _colors[role] ?? const Color(0xFF8EAFD4);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _SyncButton extends StatelessWidget {
  final bool        syncing;
  final int         unsyncedCount;
  final String?     lastSyncAt;
  final VoidCallback onTap;

  const _SyncButton({
    required this.syncing,
    required this.unsyncedCount,
    required this.lastSyncAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnsynced = unsyncedCount > 0;
    final color = syncing
        ? const Color(0xFF42A5F5)
        : hasUnsynced
            ? const Color(0xFFFFB74D)
            : const Color(0xFF66BB6A);

    String tooltip;
    if (syncing) {
      tooltip = 'Syncing…';
    } else if (hasUnsynced) {
      tooltip = '$unsyncedCount unsynced record${unsyncedCount > 1 ? 's' : ''}';
    } else if (lastSyncAt != null) {
      final dt  = DateTime.tryParse(lastSyncAt!);
      final fmt = dt != null
          ? DateFormat('MMM d, h:mm a').format(dt.toLocal())
          : lastSyncAt!;
      tooltip = 'Last synced: $fmt';
    } else {
      tooltip = 'Tap to sync';
    }

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: syncing ? null : onTap,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color:        color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Stack(alignment: Alignment.center, children: [
            if (syncing)
              SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else
              Icon(
                hasUnsynced ? Icons.cloud_upload_rounded : Icons.cloud_done_rounded,
                color: color, size: 22,
              ),
            if (!syncing && hasUnsynced)
              Positioned(
                top: 6, right: 6,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFB74D),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String    label;
  final String    value;
  final IconData  icon;
  final Color     color;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color:        const Color(0xFF0B1527),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 10, color: Color(0xFF8EAFD4))),
          ],
        ),
      ),
    );
  }
}

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

    final semanticParts = <String>[];
    if (pendingAssessments > 0) semanticParts.add('$pendingAssessments pending assessment${pendingAssessments > 1 ? 's' : ''}');
    if (pendingBeneficiaries > 0) semanticParts.add('$pendingBeneficiaries pending beneficiar${pendingBeneficiaries > 1 ? 'ies' : 'y'}');

    return Semantics(
      label: '$title: ${semanticParts.join(', ')}. Tap to open.',
      button: true,
      child: InkWell(
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
    return Semantics(
      label: label,
      button: true,
      enabled: onTap != null,
      child: InkWell(
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
                  child: Icon(icon, color: color, size: 20, semanticLabel: ''),
                ),
                const SizedBox(height: 6),
                ExcludeSemantics(
                  child: Text(
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

