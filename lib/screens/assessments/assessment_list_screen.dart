import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/assessment_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../services/local_db_service.dart';
import '../../widgets/status_badge.dart';

class AssessmentListScreen extends StatefulWidget {
  const AssessmentListScreen({super.key});

  @override
  State<AssessmentListScreen> createState() => _AssessmentListScreenState();
}

class _AssessmentListScreenState extends State<AssessmentListScreen> {
  final _local      = LocalDbService();
  final _api        = ApiService();
  final _scrollCtrl = ScrollController();

  List<AssessmentModel> _items       = [];
  bool    _loading      = true;
  bool    _loadingMore  = false;
  bool    _hasMore      = true;
  int     _page         = 1;
  int?    _filterYear;
  String? _filterPeriod;

  final List<int> _years = [
    DateTime.now().year,
    DateTime.now().year - 1,
    DateTime.now().year - 2,
  ];

  @override
  void initState() {
    super.initState();
    _filterYear = DateTime.now().year;
    _load();
    _scrollCtrl.addListener(_onScroll);
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
      final result = await _api.getAssessments(
        barangay: brgy,
        year:     _filterYear,
        period:   _filterPeriod,
        page:     page,
        perPage:  30,
      );
      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        rows = List<Map<String, dynamic>>.from(data['assessments'] ?? []);
      }
    } else {
      rows = await _local.getAllAssessments(
        year:     _filterYear,
        period:   _filterPeriod,
        barangay: brgy,
        page:     page,
        perPage:  30,
      );
    }

    if (mounted) {
      setState(() {
        _items.addAll(rows.map((r) => AssessmentModel.fromJson(r)));
        _hasMore = rows.length == 30;
        _page    = page + 1;
      });
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _formatDate(String date) {
    final dt = DateTime.tryParse(date);
    if (dt == null) return date;
    return DateFormat('MMM d, yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:   const Text('Assessments'),
        actions: [
          IconButton(
            icon:    const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => _load(reset: true),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/assessments/create')
            .then((_) => _load(reset: true)),
        icon:            const Icon(Icons.assignment_add),
        label:           const Text('Add Assessment'),
        backgroundColor: Colors.teal.shade700,
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            color:   const Color(0xFF1565C0),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                // Year filter
                Expanded(
                  child: _FilterDropdown<int>(
                    hint:  'All Years',
                    value: _filterYear,
                    items: _years
                        .map((y) => DropdownMenuItem(
                              value: y,
                              child: Text(y.toString()),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _filterYear = v);
                      _load(reset: true);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Period filter
                Expanded(
                  child: _FilterDropdown<String>(
                    hint:  'All Periods',
                    value: _filterPeriod,
                    items: const [
                      DropdownMenuItem(value: 'January', child: Text('January')),
                      DropdownMenuItem(value: 'July',    child: Text('July')),
                    ],
                    onChanged: (v) {
                      setState(() => _filterPeriod = v);
                      _load(reset: true);
                    },
                  ),
                ),
                if (_filterYear != null || _filterPeriod != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon:    const Icon(Icons.filter_alt_off_rounded, color: Colors.white),
                    tooltip: 'Clear filters',
                    onPressed: () {
                      setState(() {
                        _filterYear   = null;
                        _filterPeriod = null;
                      });
                      _load(reset: true);
                    },
                  ),
                ],
              ],
            ),
          ),

          // Summary chip
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:        const Color(0xFF1565C0).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_items.length}${_hasMore ? '+' : ''} assessments',
                      style: const TextStyle(
                        fontSize:   12,
                        fontWeight: FontWeight.w600,
                        color:      Color(0xFF1565C0),
                      ),
                    ),
                  ),
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
                          padding:    const EdgeInsets.fromLTRB(12, 8, 12, 100),
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
                            return _AssessmentCard(
                              assessment: _items[i],
                              formatDate: _formatDate,
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
          Icon(Icons.assignment_outlined, size: 64, color: const Color(0xFF2A4060)),
          const SizedBox(height: 16),
          Text(
            'No assessments found',
            style: TextStyle(color: const Color(0xFF90A4B8), fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap + to record an assessment',
            style: TextStyle(color: Color(0xFF616161), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------
// FILTER DROPDOWN
// -------------------------------------------------------

class _FilterDropdown<T> extends StatelessWidget {
  final String                   hint;
  final T?                       value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>         onChanged;

  const _FilterDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<T>(
        value:          value,
        hint:           Text(hint, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        items:          items,
        onChanged:      onChanged,
        isExpanded:     true,
        underline:      const SizedBox.shrink(),
        style:          const TextStyle(color: Color(0xFFE8F4FD), fontSize: 13),
        dropdownColor:  const Color(0xFF0D1B2E),
        icon:           const Icon(Icons.expand_more, color: Colors.white70, size: 18),
      ),
    );
  }
}

// -------------------------------------------------------
// ASSESSMENT CARD
// -------------------------------------------------------

class _AssessmentCard extends StatelessWidget {
  final AssessmentModel          assessment;
  final String Function(String)  formatDate;

  const _AssessmentCard({
    required this.assessment,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final a = assessment;
    return Card(
      margin:      const EdgeInsets.only(bottom: 8),
      elevation:   1.5,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Status indicator strip
            Container(
              width:  4,
              height: 60,
              decoration: BoxDecoration(
                color:        a.statusColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          a.beneficiaryName,
                          style: const TextStyle(
                            fontSize:   14,
                            fontWeight: FontWeight.w700,
                            color:      const Color(0xFFE8F4FD),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      StatusBadge(status: a.nutritionalStatus),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 12, color: const Color(0xFF607896)),
                      const SizedBox(width: 4),
                      Text(
                        formatDate(a.assessmentDate),
                        style: TextStyle(fontSize: 12, color: const Color(0xFF90A4B8)),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.event_note_outlined,
                          size: 12, color: const Color(0xFF607896)),
                      const SizedBox(width: 4),
                      Text(
                        a.periodDisplay,
                        style: TextStyle(fontSize: 12, color: const Color(0xFF90A4B8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _MeasurementChip(label: '${a.weightKg} kg'),
                      if (a.heightCm != null) ...[
                        const SizedBox(width: 6),
                        _MeasurementChip(label: '${a.heightCm} cm'),
                      ],
                      if (a.muacCm != null) ...[
                        const SizedBox(width: 6),
                        _MeasurementChip(label: 'MUAC: ${a.muacCm} cm'),
                      ],
                      if (a.isPending) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.hourglass_top_rounded, size: 11, color: Colors.orange.shade700),
                            const SizedBox(width: 3),
                            Text('Pending',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange.shade700)),
                          ]),
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
    );
  }
}

class _MeasurementChip extends StatelessWidget {
  final String label;
  const _MeasurementChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color:        const Color(0xFF0F1E35),
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: const Color(0xFF1E3050)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF8FA8BF)),
      ),
    );
  }
}
