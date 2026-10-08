import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../services/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey  = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool   _obscure     = true;
  String _currentUrl  = AppConfig.defaultBaseUrl;

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
    AppConfig.getBaseUrl().then((url) {
      if (mounted) setState(() => _currentUrl = url);
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth    = context.read<AuthProvider>();
    final success = await auth.login(_userCtrl.text.trim(), _passCtrl.text);
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _showServerDialog() async {
    final ctrl = TextEditingController(text: _currentUrl);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B1527),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFF00C6FF).withValues(alpha: 0.3), width: 1),
        ),
        title: const Text('Server URL',
          style: TextStyle(color: Color(0xFF00C6FF), fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Color(0xFFE8F4FD)),
          decoration: const InputDecoration(
            labelText: 'API URL',
            hintText: 'http://your-server/api',
          ),
          keyboardType: TextInputType.url,
          autocorrect: false,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final url = ctrl.text.trim();
              if (url.isNotEmpty) {
                await AppConfig.setBaseUrl(url);
                if (mounted) setState(() => _currentUrl = url);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF060D1F),
      body: Stack(
        children: [
          // Background grid decoration
          Positioned.fill(
            child: CustomPaint(painter: _GridPainter()),
          ),

          SafeArea(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: size.height - MediaQuery.of(context).padding.top,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // Hero section
                      Expanded(
                        flex: 2,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Settings icon top-right
                              Positioned(
                                top: 8, right: 0,
                                child: IconButton(
                                  icon: const Icon(Icons.settings_outlined,
                                    color: Color(0xFF7B8FA6)),
                                  tooltip: 'Server URL',
                                  onPressed: _showServerDialog,
                                ),
                              ),
                              FadeTransition(
                                opacity: _fadeAnim,
                                child: SlideTransition(
                                  position: _slideAnim,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Glowing logo box
                                      Container(
                                        width: 88, height: 88,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00C6FF).withValues(alpha: 0.07),
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(
                                            color: const Color(0xFF00C6FF).withValues(alpha: 0.5),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF00C6FF).withValues(alpha: 0.25),
                                              blurRadius: 32,
                                              spreadRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: Image.asset(
                                          'assets/images/app_icon.png',
                                          width: 60,
                                          height: 60,
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      const Text(
                                        AppConfig.appName,
                                        style: TextStyle(
                                          fontSize:      28,
                                          fontWeight:    FontWeight.w800,
                                          color:         Color(0xFFE8F4FD),
                                          letterSpacing: 3,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: const Color(0xFF00C6FF).withValues(alpha: 0.3)),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Text(
                                          'NUTRITION MONITORING SYSTEM',
                                          style: TextStyle(
                                            fontSize:      10,
                                            color:         Color(0xFF00C6FF),
                                            letterSpacing: 2,
                                            fontWeight:    FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Form card section
                      Expanded(
                        flex: 3,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B1527),
                            borderRadius: const BorderRadius.only(
                              topLeft:  Radius.circular(32),
                              topRight: Radius.circular(32),
                            ),
                            border: Border(
                              top: BorderSide(
                                color: const Color(0xFF00C6FF).withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                          ),
                          child: FadeTransition(
                            opacity: _fadeAnim,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize:   22,
                                        fontWeight: FontWeight.w800,
                                        color:      Color(0xFFE8F4FD),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Enter your credentials to continue',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:    Color(0xFF7B8FA6),
                                      ),
                                    ),
                                    const SizedBox(height: 28),

                                    // Username field
                                    TextFormField(
                                      controller:      _userCtrl,
                                      textInputAction: TextInputAction.next,
                                      keyboardType:    TextInputType.text,
                                      autocorrect:     false,
                                      style: const TextStyle(color: Color(0xFFE8F4FD)),
                                      decoration: const InputDecoration(
                                        labelText:  'Username',
                                        hintText:   'Enter username',
                                        prefixIcon: Icon(Icons.person_outline_rounded),
                                      ),
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                              ? 'Username is required'
                                              : null,
                                    ),
                                    const SizedBox(height: 14),

                                    // Password field
                                    TextFormField(
                                      controller:      _passCtrl,
                                      obscureText:     _obscure,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _submit(),
                                      style: const TextStyle(color: Color(0xFFE8F4FD)),
                                      decoration: InputDecoration(
                                        labelText:  'Password',
                                        hintText:   'Enter password',
                                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscure
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            size: 20,
                                          ),
                                          onPressed: () =>
                                              setState(() => _obscure = !_obscure),
                                        ),
                                      ),
                                      validator: (v) =>
                                          (v == null || v.isEmpty)
                                              ? 'Password is required'
                                              : null,
                                    ),

                                    // Error message
                                    if (auth.error != null) ...[
                                      const SizedBox(height: 14),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF4757).withValues(alpha: 0.08),
                                          border: Border.all(
                                            color: const Color(0xFFFF4757).withValues(alpha: 0.4)),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.error_outline,
                                                color: Color(0xFFFF4757), size: 18),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                auth.error!,
                                                style: const TextStyle(
                                                  color:    Color(0xFFFF6B7A),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 24),

                                    // Sign In button
                                    SizedBox(
                                      height: 52,
                                      child: ElevatedButton(
                                        onPressed: auth.loading ? null : _submit,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF00C6FF),
                                          foregroundColor: const Color(0xFF060D1F),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ).copyWith(
                                          shadowColor: WidgetStateProperty.all(
                                            const Color(0xFF00C6FF).withValues(alpha: 0.4),
                                          ),
                                          elevation: WidgetStateProperty.all(
                                            auth.loading ? 0 : 8,
                                          ),
                                        ),
                                        child: auth.loading
                                            ? const SizedBox(
                                                width: 22, height: 22,
                                                child: CircularProgressIndicator(
                                                  color:       Color(0xFF060D1F),
                                                  strokeWidth: 2.5,
                                                ),
                                              )
                                            : const Text(
                                                'SIGN IN',
                                                style: TextStyle(
                                                  fontSize:      15,
                                                  fontWeight:    FontWeight.w800,
                                                  letterSpacing: 2,
                                                ),
                                              ),
                                      ),
                                    ),

                                    const Spacer(),
                                    const Text(
                                      'For BNS, BHW and authorized health workers only.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color:    Color(0xFF4A6070),
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'v${AppConfig.appVersion}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color:    Color(0xFF3A5060),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Subtle dot-grid background painter
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00C6FF).withValues(alpha: 0.04)
      ..strokeWidth = 1;

    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
