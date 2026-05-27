import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../services/drive_service.dart';
import '../utils/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  String? _error;

  late final AnimationController _controller;
  late final Animation<double> _logoAnim;
  late final Animation<double> _titleAnim;
  late final Animation<double> _featAnim;
  late final Animation<double> _btnAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    Animation<double> interval(double begin, double end) =>
        CurvedAnimation(
          parent: _controller,
          curve: Interval(begin, end, curve: Curves.easeOutCubic),
        );

    _logoAnim = interval(0.0, 0.45);
    _titleAnim = interval(0.15, 0.6);
    _featAnim = interval(0.35, 0.8);
    _btnAnim = interval(0.55, 1.0);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthService>();
    final appProvider = context.read<AppProvider>();

    final success = await auth.signIn();
    if (!success) {
      setState(() {
        _loading = false;
        _error = auth.lastError != null
            ? 'Sign-in failed: ${auth.lastError}'
            : 'Sign-in was cancelled. Please try again.';
      });
      return;
    }

    final httpClient = await auth.getAuthClient();
    if (httpClient == null) {
      setState(() {
        _loading = false;
        _error =
            'Could not get authenticated session. Error: ${auth.lastError}';
      });
      return;
    }

    await appProvider.attachDriveAndSync(
      DriveService(httpClient),
      userEmail: auth.user?.email,
    );
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // ── Logo ────────────────────────────────────────────────
              FadeTransition(
                opacity: _logoAnim,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.6, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _controller,
                      curve: const Interval(0.0, 0.45,
                          curve: Curves.elasticOut),
                    ),
                  ),
                  child: _logo(),
                ),
              ),
              const SizedBox(height: 28),
              // ── Title + subtitle ────────────────────────────────────
              FadeTransition(
                opacity: _titleAnim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.25),
                    end: Offset.zero,
                  ).animate(_titleAnim),
                  child: Column(
                    children: [
                      const Text(
                        'Invoice Generator',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Create professional invoices and access\nthem from any device.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppTheme.textSecondary,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 2),
              // ── Features ────────────────────────────────────────────
              FadeTransition(
                opacity: _featAnim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.2),
                    end: Offset.zero,
                  ).animate(_featAnim),
                  child: Column(
                    children: [
                      _featureRow(Icons.lock_outline,
                          'End-to-end encrypted with AES-256'),
                      const SizedBox(height: 12),
                      _featureRow(Icons.sync_outlined,
                          'Syncs across all your devices'),
                      const SizedBox(height: 12),
                      _featureRow(Icons.cloud_upload_outlined,
                          'Stored securely in your Google Drive'),
                      const SizedBox(height: 12),
                      _featureRow(Icons.picture_as_pdf_outlined,
                          'Generate & share PDF invoices'),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 3),
              // ── Error ────────────────────────────────────────────────
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppTheme.error, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              // ── Sign-in button ──────────────────────────────────────
              FadeTransition(
                opacity: _btnAnim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(_btnAnim),
                  child: _signInButton(),
                ),
              ),
              const SizedBox(height: 16),
              FadeTransition(
                opacity: _btnAnim,
                child: const Text(
                  'Your data is stored privately in your own\nGoogle Drive account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logo() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: const Icon(Icons.receipt_long, color: Colors.white, size: 44),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _signInButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: _loading ? null : _signIn,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.divider, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.white,
        ),
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primary))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _googleIcon(),
                  const SizedBox(width: 12),
                  const Text(
                    'Sign in with Google',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _googleIcon() {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      const Color(0xFF4285F4),
      const Color(0xFF34A853),
      const Color(0xFFFBBC05),
      const Color(0xFFEA4335),
    ];
    final paint = Paint()..style = PaintingStyle.fill;
    final r = size.width / 2;
    final cx = size.width / 2;
    final cy = size.height / 2;

    paint.color = colors[0];
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -0.52, 1.56, true, paint);
    paint.color = colors[1];
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        1.04, 1.56, true, paint);
    paint.color = colors[2];
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        2.60, 1.04, true, paint);
    paint.color = colors[3];
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        3.64, 1.04, true, paint);
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.65, paint);
    paint.color = colors[0];
    canvas.drawRect(
        Rect.fromLTWH(cx, cy - r * 0.22, r, r * 0.44), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
