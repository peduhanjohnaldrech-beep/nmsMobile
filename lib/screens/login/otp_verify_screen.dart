import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';

class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({super.key});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) return;
    final auth    = context.read<AuthProvider>();
    final success = await auth.verifyOtp(code);
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _back() {
    context.read<AuthProvider>().clearPendingOtp();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final auth        = context.watch<AuthProvider>();
    final maskedEmail = auth.pendingMaskedEmail ?? 'your registered email';

    return Scaffold(
      backgroundColor: const Color(0xFF060D1F),
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IconButton(
                    alignment: Alignment.centerLeft,
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF7B8FA6)),
                    onPressed: _back,
                  ),
                  const SizedBox(height: 32),
                  const Icon(Icons.mark_email_read_outlined,
                      color: Color(0xFF00C6FF), size: 56),
                  const SizedBox(height: 20),
                  const Text(
                    'Verify Your Identity',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize:   24,
                      fontWeight: FontWeight.w800,
                      color:      Color(0xFFE8F4FD),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'A 6-digit OTP has been sent to\n$maskedEmail',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color:    Color(0xFF7B8FA6),
                      height:   1.5,
                    ),
                  ),
                  const SizedBox(height: 36),
                  TextFormField(
                    controller:     _codeCtrl,
                    keyboardType:   TextInputType.number,
                    textAlign:      TextAlign.center,
                    maxLength:      6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      color:         Color(0xFFE8F4FD),
                      fontSize:      28,
                      fontWeight:    FontWeight.w700,
                      letterSpacing: 12,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText:    '------',
                      hintStyle:   TextStyle(
                        color:         const Color(0xFF7B8FA6).withValues(alpha: 0.5),
                        fontSize:      28,
                        letterSpacing: 12,
                      ),
                    ),
                    onChanged: (v) { if (v.length == 6) _submit(); },
                  ),
                  if (auth.error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color:  const Color(0xFFFF4757).withValues(alpha: 0.08),
                        border: Border.all(color: const Color(0xFFFF4757).withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: Color(0xFFFF4757), size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(auth.error!,
                          style: const TextStyle(color: Color(0xFFFF6B7A), fontSize: 12))),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: auth.loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C6FF),
                        foregroundColor: const Color(0xFF060D1F),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      ),
                      child: auth.loading
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(
                                color: Color(0xFF060D1F), strokeWidth: 2.5))
                          : const Text('VERIFY',
                              style: TextStyle(
                                fontSize:      15,
                                fontWeight:    FontWeight.w800,
                                letterSpacing: 2,
                              )),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
