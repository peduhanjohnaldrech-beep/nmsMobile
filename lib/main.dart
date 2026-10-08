import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'config/app_config.dart';
import 'services/auth_provider.dart';
import 'services/sync_service.dart';
import 'screens/login/login_screen.dart';
import 'screens/dashboard/home_screen.dart';
import 'screens/beneficiaries/beneficiary_list_screen.dart';
import 'screens/beneficiaries/beneficiary_form_screen.dart';
import 'screens/beneficiaries/beneficiary_detail_screen.dart';
import 'screens/assessments/assessment_list_screen.dart';
import 'screens/assessments/assessment_form_screen.dart';
import 'screens/programs/programs_screen.dart';
import 'screens/dispensing/dispensing_screen.dart';
import 'screens/dispensing/dispensing_form_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/reports/reports_full_screen.dart';
import 'screens/activity/activity_screen.dart';
import 'screens/beneficiaries/beneficiary_trash_screen.dart';
import 'screens/beneficiaries/beneficiary_followup_screen.dart';
import 'screens/assessments/assessment_batch_screen.dart';
import 'screens/admin/user_management_screen.dart';
import 'screens/admin/program_manager_screen.dart';
import 'screens/help/help_screen.dart';
import 'screens/validation/validation_queue_screen.dart';
import 'screens/validation/my_submissions_screen.dart';
import 'models/beneficiary_model.dart';
import 'services/api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const NmsApp(),
    ),
  );
}

// -------------------------------------------------------
// APP
// -------------------------------------------------------
class NmsApp extends StatelessWidget {
  const NmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: ApiService.navigatorKey,
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary:     Color(0xFF00C6FF),
          secondary:   Color(0xFF7B61FF),
          surface:     Color(0xFF0B1527),
          error:       Color(0xFFFF4757),
          onPrimary:   Color(0xFF060D1F),
          onSecondary: Colors.white,
          onSurface:   Color(0xFFE8F4FD),
          onError:     Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF060D1F),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Color(0xFF080F20),
          foregroundColor: Color(0xFFE8F4FD),
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF0B1527),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF1A3050), width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1A3050)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1A3050)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF00C6FF), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          filled: true,
          fillColor: const Color(0xFF0D1B2E),
          labelStyle: const TextStyle(color: Color(0xFF7B8FA6)),
          hintStyle: const TextStyle(color: Color(0xFF4A6070)),
          prefixIconColor: Color(0xFF7B8FA6),
          suffixIconColor: Color(0xFF7B8FA6),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C6FF),
            foregroundColor: const Color(0xFF060D1F),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF00C6FF)),
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFF1A3050), thickness: 1),
        drawerTheme: const DrawerThemeData(backgroundColor: Color(0xFF080F20)),
        listTileTheme: const ListTileThemeData(
          textColor: Color(0xFFE8F4FD),
          iconColor: Color(0xFF7B8FA6),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF0F1E35),
          contentTextStyle: TextStyle(color: Color(0xFFE8F4FD)),
        ),
      ),
      home: const _SplashRouter(),
      routes: {
        '/login':                  (_) => const LoginScreen(),
        '/home':                   (_) => const MainShell(),
        '/beneficiaries':          (_) => const MainShell(initialIndex: 1),
        '/beneficiaries/create':   (_) => const BeneficiaryFormScreen(),
        '/beneficiaries/trash':    (_) => const BeneficiaryTrashScreen(),
        '/beneficiaries/followup': (_) => const BeneficiaryFollowupScreen(),
        '/assessments':            (_) => const MainShell(initialIndex: 2),
        '/assessments/create':     (_) => const AssessmentFormScreen(),
        '/assessments/batch':      (_) => const AssessmentBatchScreen(),
        '/programs':               (_) => const MainShell(initialIndex: 3),
        '/dispensing':             (_) => const DispensingScreen(),
        '/dispensing/create':      (_) => const DispensingFormScreen(),
        '/reports':                (_) => const MainShell(initialIndex: 4),
        '/reports/full':           (_) => const ReportsFullScreen(),
        '/activity':               (_) => const ActivityScreen(),
        '/users':                  (_) => const UserManagementScreen(),
        '/programs-admin':         (_) => const ProgramManagerScreen(),
        '/help':                   (_) => const HelpScreen(),
        '/validation/queue':       (_) => const ValidationQueueScreen(),
        '/validation/submissions': (_) => const MySubmissionsScreen(),
      },
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/beneficiaries/detail':
            final bene = settings.arguments as BeneficiaryModel?;
            return MaterialPageRoute(
              builder: (_) => BeneficiaryDetailScreen(beneficiary: bene!),
            );
          case '/beneficiaries/edit':
            final bene = settings.arguments as BeneficiaryModel?;
            return MaterialPageRoute(
              builder: (_) => BeneficiaryFormScreen(existing: bene),
            );
          case '/assessments/create-for':
            final bene = settings.arguments as BeneficiaryModel?;
            return MaterialPageRoute(
              builder: (_) => AssessmentFormScreen(beneficiary: bene),
            );
        }
        return null;
      },
    );
  }
}

// -------------------------------------------------------
// SPLASH ROUTER
// -------------------------------------------------------
class _SplashRouter extends StatefulWidget {
  const _SplashRouter();
  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    _check();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final auth    = context.read<AuthProvider>();
    final success = await auth.tryAutoLogin();
    if (mounted) {
      Navigator.pushReplacementNamed(context, success ? '/home' : '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060D1F),
      body: Center(
        child: FadeTransition(
          opacity: _anim,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF00C6FF).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFF00C6FF).withValues(alpha: 0.6), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00C6FF).withValues(alpha: 0.2),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Image.asset('assets/images/app_icon.png', width: 64, height: 64),
              ),
              const SizedBox(height: 20),
              const Text(AppConfig.appName,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF00C6FF), letterSpacing: 2)),
              const SizedBox(height: 4),
              const Text('Nutrition Monitoring System',
                style: TextStyle(color: Color(0xFF7B8FA6), fontSize: 12, letterSpacing: 0.5)),
              const SizedBox(height: 40),
              const SizedBox(width: 26, height: 26,
                child: CircularProgressIndicator(color: Color(0xFF00C6FF), strokeWidth: 2)),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------
// MAIN SHELL — sidebar drawer navigation (matches web)
// -------------------------------------------------------
class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index;
  final _sync = SyncService();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _wasOffline = false;
  bool _autoSyncing = false;

  // Pages shown in IndexedStack
  static const _pages = [
    HomeScreen(),
    BeneficiaryListScreen(),
    AssessmentListScreen(),
    ProgramsScreen(),
    ReportsScreen(),
    _ProfilePage(),
  ];

  static const _titles = [
    'Dashboard',
    'Beneficiaries',
    'Assessments',
    'Programs',
    'Reports',
    'Profile & Settings',
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _initConnectivityListener();
  }

  void _initConnectivityListener() async {
    // Record initial connectivity so we can detect transitions
    final initial = await Connectivity().checkConnectivity();
    _wasOffline = initial.contains(ConnectivityResult.none);

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = !results.contains(ConnectivityResult.none);
      if (isOnline && _wasOffline && !_autoSyncing) {
        _autoSync();
      }
      _wasOffline = !isOnline;
    });
  }

  Future<void> _autoSync() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    _autoSyncing = true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Back online — syncing data...'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.blueGrey,
        ),
      );
    }
    final brgy   = user.isScopedToBarangay ? user.barangay : null;
    final result = await _sync.sync(barangay: brgy);
    _autoSyncing = false;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.success ? 'Auto-sync complete: ${result.message}' : 'Auto-sync failed: ${result.message}'),
          backgroundColor: result.success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  void _navigate(int idx) {
    setState(() => _index = idx);
    Navigator.pop(context); // close drawer
  }

  Future<void> _logout() async {
    Navigator.pop(context); // close drawer
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text(
          'Are you sure you want to log out?\n\n'
          '⚠️ You will need an internet connection to log back in.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 40),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: _NmsAppBar(
        title: _titles[_index],
        user:  user,
      ),
      drawer: _NmsSidebar(
        currentIndex: _index,
        user:         user,
        onNavigate:   _navigate,
        onLogout:     _logout,
      ),
      body: IndexedStack(
        index:    _index,
        children: _pages,
      ),
    );
  }
}

// -------------------------------------------------------
// NMS APP BAR — matches web top navbar (blue)
// -------------------------------------------------------
class _NmsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String  title;
  final dynamic user;

  const _NmsAppBar({required this.title, required this.user});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF080F20),
      foregroundColor: const Color(0xFFE8F4FD),
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFF00C6FF).withValues(alpha: 0.3), height: 1),
      ),
      title: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF00C6FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF00C6FF).withValues(alpha: 0.4), width: 1),
            ),
            child: Image.asset('assets/images/app_icon.png', width: 20, height: 20),
          ),
          const SizedBox(width: 8),
          Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFE8F4FD), letterSpacing: 0.5)),
        ],
      ),
      actions: [
        if (user != null) ...[
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                user.fullName.split(' ').first,
                style: const TextStyle(fontSize: 12, color: Color(0xFFE8F4FD), fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C6FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF00C6FF).withValues(alpha: 0.3), width: 1),
                ),
                child: Text(
                  user.roleDisplay,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF00C6FF)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ],
    );
  }
}

// -------------------------------------------------------
// NMS SIDEBAR DRAWER — matches web dark sidebar
// -------------------------------------------------------
class _NmsSidebar extends StatefulWidget {
  final int      currentIndex;
  final dynamic  user;
  final void Function(int) onNavigate;
  final VoidCallback        onLogout;

  const _NmsSidebar({
    required this.currentIndex,
    required this.user,
    required this.onNavigate,
    required this.onLogout,
  });

  @override
  State<_NmsSidebar> createState() => _NmsSidebarState();
}

class _NmsSidebarState extends State<_NmsSidebar> {
  final _api = ApiService();
  List<dynamic> _programs = [];

  @override
  void initState() {
    super.initState();
    _loadPrograms();
  }

  Future<void> _loadPrograms() async {
    try {
      final res = await _api.getProgramsList();
      if (mounted && res['success'] == true) {
        setState(() => _programs = res['data']['programs'] ?? []);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final role = (user?.role ?? '').toLowerCase();
    return Drawer(
      width: 270,
      backgroundColor: const Color(0xFF080F20),
      child: SafeArea(
        child: Column(
          children: [
            // Header — app branding + user info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: BoxDecoration(
                color: const Color(0xFF060D1F),
                border: Border(
                  bottom: BorderSide(color: const Color(0xFF00C6FF).withValues(alpha: 0.3), width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C6FF).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF00C6FF).withValues(alpha: 0.4), width: 1),
                        ),
                        child: Image.asset('assets/images/app_icon.png', width: 28, height: 28),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppConfig.appName,
                            style: TextStyle(color: Color(0xFF00C6FF), fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1.5)),
                          Text('Nutrition Monitoring System',
                            style: TextStyle(color: Color(0xFF7B8FA6), fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: const Color(0xFF00C6FF).withValues(alpha: 0.15), height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF00C6FF).withValues(alpha: 0.15),
                        child: Text(
                          (user?.fullName?.isNotEmpty == true)
                              ? user!.fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: Color(0xFF00C6FF), fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?.fullName ?? 'User',
                              style: const TextStyle(color: Color(0xFFE8F4FD), fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00C6FF).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF00C6FF).withValues(alpha: 0.3), width: 1),
                              ),
                              child: Text(user?.roleDisplay ?? '',
                                style: const TextStyle(color: Color(0xFF00C6FF), fontSize: 10)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Navigation items
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NavItem(icon: Icons.speed_rounded,        label: 'Dashboard',           index: 0, current: widget.currentIndex, onTap: widget.onNavigate),

                    if (user?.hasPermission('beneficiaries') ?? false) ...[
                      const _NavSectionLabel('BENEFICIARIES'),
                      _NavItem(icon: Icons.people_rounded,     label: 'Beneficiaries',        index: 1, current: widget.currentIndex, onTap: widget.onNavigate),
                      _NavItemRoute(icon: Icons.warning_amber_rounded, label: 'Follow-up List', onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/beneficiaries/followup'); }),
                      _NavItemRoute(icon: Icons.delete_outline, label: 'Trash',               onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/beneficiaries/trash'); }),
                    ],

                    if (user?.hasPermission('assessments') ?? false) ...[
                      const _NavSectionLabel('ASSESSMENTS'),
                      _NavItem(icon: Icons.assignment_outlined, label: 'Assessments',         index: 2, current: widget.currentIndex, onTap: widget.onNavigate),
                      _NavItemRoute(icon: Icons.add_circle_outline, label: 'New Assessment',  onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/assessments/create'); }),
                      _NavItemRoute(icon: Icons.table_rows_outlined, label: 'Batch Entry',    onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/assessments/batch'); }),
                    ],

                    if ((user?.hasPermission('programs') ?? false) || (user?.hasPermission('dispensing') ?? false)) ...[
                      const _NavSectionLabel('PROGRAMS'),
                      if (user?.hasPermission('programs') ?? false) ...[
                        _NavItem(icon: Icons.grid_view_rounded, label: 'Programs',            index: 3, current: widget.currentIndex, onTap: widget.onNavigate),
                        // Dynamic custom programs (non-built-in active programs)
                        ..._programs.where((p) => !['OPT','DSP','MNS'].contains(p['code'])).map((p) =>
                          _NavItemRoute(
                            icon: Icons.extension_outlined,
                            label: p['name'] ?? p['code'],
                            onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/programs'); },
                          ),
                        ),
                      ],
                      if (user?.hasPermission('dispensing') ?? false) ...[
                        _NavItemRoute(icon: Icons.local_pharmacy_outlined, label: 'Dispensing', onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/dispensing'); }),
                        _NavItemRoute(icon: Icons.add_box_outlined, label: 'Record Dispensing', onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/dispensing/create'); }),
                      ],
                    ],

                    if (user?.hasPermission('reports') ?? false) ...[
                      const _NavSectionLabel('REPORTS'),
                      _NavItem(icon: Icons.bar_chart_rounded,  label: 'Summary Report',       index: 4, current: widget.currentIndex, onTap: widget.onNavigate),
                      _NavItemRoute(icon: Icons.assessment_outlined, label: 'All Reports',     onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/reports/full'); }),
                    ],

                    if (user?.hasPermission('validation') ?? false) ...[
                      const _NavSectionLabel('VALIDATION'),
                      if (role == 'admin' || role == 'nutritionist' || role == 'midwife')
                        _NavItemRoute(icon: Icons.fact_check_outlined, label: 'Validation Queue', onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/validation/queue'); }),
                      if (role == 'bhw' || role == 'encoder' || role == 'bns')
                        _NavItemRoute(icon: Icons.assignment_turned_in_outlined, label: 'My Submissions', onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/validation/submissions'); }),
                    ],

                    if ((user?.hasPermission('activity_log') ?? false) || role == 'admin') ...[
                      const _NavSectionLabel('ADMIN'),
                      if (user?.hasPermission('activity_log') ?? false)
                        _NavItemRoute(icon: Icons.history_rounded, label: 'Activity Log',       onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/activity'); }),
                      if (role == 'admin') ...[
                        _NavItemRoute(icon: Icons.manage_accounts_outlined, label: 'User Management', onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/users'); }),
                        _NavItemRoute(icon: Icons.grid_view_outlined, label: 'Program Manager', onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/programs-admin'); }),
                      ],
                    ],

                    const _NavSectionLabel('ACCOUNT'),
                    _NavItem(icon: Icons.person_rounded,       label: 'Profile / Settings',   index: 5, current: widget.currentIndex, onTap: widget.onNavigate),
                    _NavItemRoute(icon: Icons.help_outline_rounded, label: 'Help',             onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/help'); }),
                  ],
                ),
              ),
            ),

            // Logout button at bottom
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF2D3F55))),
              ),
              child: TextButton.icon(
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout_rounded, color: Colors.white54, size: 18),
                label: const Text('Log Out', style: TextStyle(color: Colors.white54)),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Sidebar nav item — selects a page in IndexedStack
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String   label;
  final int      index;
  final int      current;
  final void Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return InkWell(
      onTap: () => onTap(index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF00C6FF).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: active ? Border.all(color: const Color(0xFF00C6FF).withValues(alpha: 0.3), width: 1) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18,
              color: active ? const Color(0xFF00C6FF) : const Color(0xFF7B8FA6)),
            const SizedBox(width: 10),
            Text(label,
              style: TextStyle(
                color:      active ? const Color(0xFF00C6FF) : const Color(0xFFB0BEC5),
                fontSize:   13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              )),
          ],
        ),
      ),
    );
  }
}

// Sidebar nav item that pushes a named route
class _NavItemRoute extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;

  const _NavItemRoute({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.white54),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _NavSectionLabel extends StatelessWidget {
  final String text;
  const _NavSectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
    child: Text(text,
      style: const TextStyle(color: Color(0xFF00C6FF), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
  );
}

// -------------------------------------------------------
// PROFILE PAGE (inline, shown inside MainShell)
// -------------------------------------------------------
class _ProfilePage extends StatefulWidget {
  const _ProfilePage();
  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  final _api    = ApiService();
  final _urlCtrl = TextEditingController();
  String? _lastSync;
  bool    _editingUrl     = false;
  bool    _saving         = false;
  List<dynamic> _backups  = [];
  bool   _loadingBackups  = false;
  String? _downloadingFile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final url   = await AppConfig.getBaseUrl();
    final prefs = await SharedPreferences.getInstance();
    final sync  = prefs.getString(AppConfig.lastSyncKey);
    if (mounted) {
      setState(() {
        _urlCtrl.text = url;
        _lastSync     = sync;
      });
    }
    // Load backup list for admin
    if (!mounted) return;
    final user = context.read<AuthProvider>().user;
    if (user?.isAdmin == true) _loadBackups();
  }

  Future<void> _loadBackups() async {
    if (!mounted) return;
    setState(() => _loadingBackups = true);
    try {
      final list = await _api.listBackups();
      if (mounted) setState(() => _backups = list);
    } catch (_) {}
    if (mounted) setState(() => _loadingBackups = false);
  }

  Future<void> _downloadBackup(String filename) async {
    setState(() => _downloadingFile = filename);
    try {
      final bytes = await _api.downloadBackup(filename);
      if (!mounted) return;
      if (bytes == null) {
        _snack('Download failed', false);
        return;
      }
      final dir  = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.green),
              SizedBox(width: 8),
              Text('Backup Saved', style: TextStyle(fontSize: 16)),
            ]),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(filename, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              Text(file.path, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
      }
    } catch (e) {
      _snack('Error: $e', false);
    } finally {
      if (mounted) setState(() => _downloadingFile = null);
    }
  }

  void _snack(String msg, bool ok) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: ok ? Colors.green : Colors.red, behavior: SnackBarBehavior.floating));

  Future<void> _saveUrl() async {
    setState(() => _saving = true);
    final url = _urlCtrl.text.trim();
    if (url.isNotEmpty) await AppConfig.setBaseUrl(url);
    setState(() { _saving = false; _editingUrl = false; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server URL updated'), backgroundColor: Colors.green));
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user  = context.watch<AuthProvider>().user;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // User card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF1565C0),
                  child: Text(
                    (user?.fullName.isNotEmpty == true) ? user!.fullName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.fullName ?? '—',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('@${user?.username ?? '—'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(user?.roleDisplay ?? '—',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
                    ),
                  ],
                )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        if (user?.barangay != null)
          _tile(Icons.location_on_outlined, 'Assigned Barangay', user!.barangay!),
        _tile(Icons.sync_rounded, 'Last Sync', _lastSync != null ? _fmt(_lastSync!) : 'Never synced'),

        const SizedBox(height: 8),
        const _Label('SERVER SETTINGS'),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.dns_outlined, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Server URL', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: theme.colorScheme.primary)),
                  const Spacer(),
                  if (!_editingUrl)
                    TextButton(
                      onPressed: () => setState(() => _editingUrl = true),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Edit'),
                    ),
                ]),
                const SizedBox(height: 8),
                if (_editingUrl) ...[
                  TextField(
                    controller: _urlCtrl,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: InputDecoration(
                      hintText: 'https://xxxx.ngrok-free.dev/api',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () => setState(() => _editingUrl = false),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                      child: const Text('Cancel'),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: ElevatedButton(
                      onPressed: _saving ? null : _saveUrl,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
                      child: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save'),
                    )),
                  ]),
                ] else
                  Text(_urlCtrl.text.isNotEmpty ? _urlCtrl.text : AppConfig.defaultBaseUrl,
                    style: const TextStyle(fontSize: 12, color: Colors.black54, fontFamily: 'monospace')),
              ],
            ),
          ),
        ),


        const SizedBox(height: 8),
        const _Label('APP INFO'),
        _tile(Icons.info_outline_rounded, 'Version', AppConfig.appVersion),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _tile(IconData icon, String title, String value) => Card(
    margin: const EdgeInsets.only(bottom: 6),
    child: ListTile(
      dense: true,
      leading: Icon(icon, color: const Color(0xFF1565C0), size: 20),
      title: Text(title, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      subtitle: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
    ),
  );

  String _fmt(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final l = dt.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2,'0')}-${l.day.toString().padLeft(2,'0')} '
           '${l.hour.toString().padLeft(2,'0')}:${l.minute.toString().padLeft(2,'0')}';
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 6, top: 4),
    child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: Colors.grey.shade700)),
  );
}
