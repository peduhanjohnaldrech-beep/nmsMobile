import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/beneficiary_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../services/local_db_service.dart';
import '../../services/sync_service.dart';
import '../../widgets/status_badge.dart';
import '../assessments/assessment_form_screen.dart';
import 'beneficiary_detail_screen.dart';
import 'submit_to_admin_screen.dart';

class BeneficiaryListScreen extends StatefulWidget {
  const BeneficiaryListScreen({super.key});

  @override
  State<BeneficiaryListScreen> createState() => _BeneficiaryListScreenState();
}

class _BeneficiaryListScreenState extends State<BeneficiaryListScreen> {
  final _local      = LocalDbService();
  final _api        = ApiService();
  final _sync       = SyncService();
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<BeneficiaryModel> _items   = [];
  bool    _loading      = true;
  String  _search       = '';
  String  _statusFilter = 'All';
  String  _purokFilter  = '';
  List<String> _puroks  = [];
  int     _page         = 1;
  bool    _hasMore      = true;
  bool    _loadingMore  = false;

  static const _statusFilters = ['All', 'SUW', 'UW', 'Normal', 'OW', 'OB'];

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadPuroks();
    _syncThenLoad();
  }

  Future<void> _syncThenLoad() async {
    if (!kIsWeb) {
      final user = context.read<AuthProvider>().user;
      final brgy = user?.isScopedToBarangay == true ? user?.barangay : null;
      // Force full pull (no since) so validation status changes are always reflected
      await _sync.syncFull(barangay: brgy);
    }
    _load();
  }

  Future<void> _loadPuroks() async {
    if (kIsWeb) return;
    final user = context.read<AuthProvider>().user;
    final brgy = user?.isScopedToBarangay == true ? user?.barangay : null;
    final rows = await _local.getPuroksByBarangay(barangay: brgy);
    if (mounted) setState(() => _puroks = rows);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _page    = 1;
        _items   = [];
        _hasMore = true;
        _loading = true;
      });
    } else {
      setState(() => _loading = true);
    }

    await _fetchPage(_page);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    await _fetchPage(_page);
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _fetchPage(int page) async {
    final user = context.read<AuthProvider>().user;
    final brgy = user?.isScopedToBarangay == true ? user?.barangay : null;

    List<Map<String, dynamic>> rows = [];

    if (kIsWeb) {
      final result = await _api.getBeneficiaries(
        barangay: brgy,
        search:   _search.isNotEmpty ? _search : null,
        status:   _statusFilter != 'All' ? _statusFilter : null,
        page:     page,
        perPage:  30,
      );
      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        rows = List<Map<String, dynamic>>.from(data['beneficiaries'] ?? []);
      }
    } else {
      rows = await _local.getBeneficiaries(
        barangay:     brgy,
        purok:        _purokFilter.isNotEmpty ? _purokFilter : null,
        search:       _search,
        statusFilter: _statusFilter != 'All' ? _statusFilter : null,
        page:         page,
        perPage:      30,
      );
    }

    if (mounted) {
      setState(() {
        _items.addAll(rows.map((r) => BeneficiaryModel.fromJson(r)));
        _hasMore = rows.length == 30;
        _page    = page + 1;
      });
    }
  }

  void _onSearch(String val) {
    _search = val;
    _load(reset: true);
  }

  void _onFilterChanged(String filter) {
    setState(() => _statusFilter = filter);
    _load(reset: true);
  }

  Future<void> _openCreateForm(BuildContext ctx) async {
    final result = await Navigator.pushNamed(ctx, '/beneficiaries/create');
    _load(reset: true);
    if (!mounted) return;
    if (result is Map && result['openAssessment'] != null) {
      final bene = result['openAssessment'] as BeneficiaryModel?;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AssessmentFormScreen(beneficiary: bene)),
      );
      _load(reset: true);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beneficiaries'),
        actions: [
          IconButton(
            icon:    const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () async {
              if (!kIsWeb) {
                final user = context.read<AuthProvider>().user;
                await _sync.sync(barangay: user?.isScopedToBarangay == true ? user?.barangay : null);
              }
              _load(reset: true);
            },
          ),
        ],
      ),
      floatingActionButton: Builder(builder: (ctx) {
        final role = ctx.read<AuthProvider>().user?.role ?? '';
        if (role == 'bns') {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                heroTag: 'fab_submit',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubmitToAdminScreen()),
                ).then((_) => _load(reset: true)),
                icon:            const Icon(Icons.send_rounded),
                label:           const Text('Submit to Admin'),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              const SizedBox(height: 12),
              FloatingActionButton.extended(
                heroTag: 'fab_add',
                onPressed: () => _openCreateForm(context),
                icon:  const Icon(Icons.person_add_rounded),
                label: const Text('Add Beneficiary'),
              ),
            ],
          );
        }
        return FloatingActionButton.extended(
          heroTag: 'fab_add',
          onPressed: () => _openCreateForm(context),
          icon:  const Icon(Icons.person_add_rounded),
          label: const Text('Add Beneficiary'),
        );
      }),
      body: Column(
        children: [
          // Search bar
          Container(
            color:   const Color(0xFF1565C0),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextField(
              controller:  _searchCtrl,
              onChanged:   _onSearch,
              style:       const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText:    'Search by name...',
                hintStyle:   const TextStyle(color: Colors.white54),
                prefixIcon:  const Icon(Icons.search_rounded, color: Colors.white70),
                filled:      true,
                fillColor:   Colors.white.withValues(alpha: 0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:   BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon:      const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearch('');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Filter row: status chips + purok
          Container(
            color: const Color(0xFF0B1527),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 46,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding:         const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemCount:       _statusFilters.length,
                    itemBuilder: (ctx, i) {
                      final f = _statusFilters[i];
                      final selected = _statusFilter == f;
                      return FilterChip(
                        label: Text(f),
                        selected:       selected,
                        onSelected:     (_) => _onFilterChanged(f),
                        selectedColor:  const Color(0xFF1565C0),
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color:      selected ? Colors.white : const Color(0xFFE8F4FD),
                          fontSize:   12,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      );
                    },
                  ),
                ),
                if (_puroks.isNotEmpty) ...[
                  const Divider(height: 1),
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      children: [
                        ChoiceChip(
                          label: const Text('All Puroks'),
                          selected: _purokFilter.isEmpty,
                          onSelected: (_) { setState(() => _purokFilter = ''); _load(reset: true); },
                          selectedColor: Colors.teal.shade700,
                          labelStyle: TextStyle(
                            color: _purokFilter.isEmpty ? Colors.white : const Color(0xFFE8F4FD),
                            fontSize: 11,
                          ),
                        ),
                        ..._puroks.map((p) {
                          final selected = _purokFilter == p;
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: ChoiceChip(
                              label: Text(p),
                              selected: selected,
                              onSelected: (_) { setState(() => _purokFilter = selected ? '' : p); _load(reset: true); },
                              selectedColor: Colors.teal.shade700,
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : const Color(0xFFE8F4FD),
                                fontSize: 11,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
                const Divider(height: 1),
              ],
            ),
          ),

          // List
          Expanded(
            child: _loading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        onRefresh: () => _load(reset: true),
                        child: ListView.builder(
                          controller: _scrollCtrl,
                          padding:    const EdgeInsets.fromLTRB(12, 4, 12, 100),
                          itemCount:  _items.length + (_loadingMore ? 1 : 0),
                          itemBuilder: (ctx, i) {
                            if (i == _items.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child:   CircularProgressIndicator(),
                                ),
                              );
                            }
                            return _BeneficiaryCard(
                              beneficiary: _items[i],
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BeneficiaryDetailScreen(beneficiary: _items[i]),
                                ),
                              ).then((_) => _load(reset: true)),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded, size: 64, color: const Color(0xFF2A4060)),
          const SizedBox(height: 16),
          Text(
            _search.isNotEmpty
                ? 'No results for "$_search"'
                : 'No beneficiaries found',
            style: TextStyle(color: const Color(0xFF90A4B8), fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (_search.isEmpty)
            const Text(
              'Tap + to add your first beneficiary',
              style: TextStyle(color: Color(0xFF616161), fontSize: 13),
            ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------
// BENEFICIARY CARD
// -------------------------------------------------------

class _BeneficiaryCard extends StatelessWidget {
  final BeneficiaryModel beneficiary;
  final VoidCallback?    onTap;

  const _BeneficiaryCard({required this.beneficiary, this.onTap});

  @override
  Widget build(BuildContext context) {
    final b = beneficiary;
    final isMale = b.sex == 'Male';

    return Card(
      margin:      const EdgeInsets.only(bottom: 8),
      elevation:   1.5,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    isMale ? Colors.blue.shade100 : Colors.pink.shade100,
                child: Text(
                  b.initials,
                  style: TextStyle(
                    fontSize:   15,
                    fontWeight: FontWeight.w700,
                    color:      isMale
                        ? Colors.blue.shade800
                        : Colors.pink.shade800,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.displayName,
                      style: const TextStyle(
                        fontSize:   14,
                        fontWeight: FontWeight.w700,
                        color:      Color(0xFFE8F4FD),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 12, color: const Color(0xFF607896)),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            '${b.barangay}${b.purokZone != null ? " • ${b.purokZone}" : ""}',
                            style: TextStyle(fontSize: 12, color: const Color(0xFF90A4B8)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(children: [
                      Text(
                        '${b.sex} • ${b.ageInYears} yrs old',
                        style: TextStyle(fontSize: 12, color: const Color(0xFF90A4B8)),
                      ),
                      if (b.ageInMonths >= 60) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF152236),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Aged Out',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF90A4B8))),
                        ),
                      ],
                    ]),
                  ],
                ),
              ),

              // Right side: validation/status badge + chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (b.isPendingValidation)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Text('Pending',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.orange.shade800)),
                    )
                  else if (b.isRejected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Text('Rejected',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.red.shade700)),
                    )
                  else if (b.latestStatus != null)
                    StatusBadge(status: b.latestStatus!),
                  const SizedBox(height: 6),
                  Icon(Icons.chevron_right_rounded,
                      color: const Color(0xFF4A6080), size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
