import 'package:flutter/gestures.dart';
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
  bool _accepted = false;
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
    if (!mounted) return;
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
    if (!mounted) return;
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
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.card(context),
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
                      Text(
                        'Invoice Generator',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onCard(context),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Create professional invoices and access\nthem from any device.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppTheme.subtext(context),
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
              // ── T&C checkbox ─────────────────────────────────────────
              FadeTransition(
                opacity: _btnAnim,
                child: _termsCheckbox(),
              ),
              const SizedBox(height: 14),
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
              SizedBox(height: 16),
              FadeTransition(
                opacity: _btnAnim,
                child: Text(
                  'Your data is stored privately in your own\nGoogle Drive account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.subtext(context)),
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
        SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
                fontSize: 14,
                color: AppTheme.onCard(context),
                fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _termsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _accepted,
            activeColor: AppTheme.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (v) => setState(() => _accepted = v ?? false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 12.5, color: AppTheme.subtext(context), height: 1.5),
              children: [
                const TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Terms of Service',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: AppTheme.primary,
                  ),
                  recognizer: TapGestureRecognizer()..onTap = _showTermsDialog,
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: AppTheme.primary,
                  ),
                  recognizer: TapGestureRecognizer()..onTap = _showPrivacyDialog,
                ),
                const TextSpan(
                  text: '. My invoice data will be stored in my Google Drive'
                      ' and may be processed on servers outside India.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (_) => const _PolicyDialog(
        title: 'Terms of Service',
        content: _termsContent,
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (_) => const _PolicyDialog(
        title: 'Privacy Policy',
        content: _privacyContent,
      ),
    );
  }

  Widget _signInButton() {
    final enabled = _accepted && !_loading;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: enabled ? _signIn : null,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppTheme.outline(context), width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppTheme.inputFill(context),
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
                  SizedBox(width: 12),
                  Text(
                    'Sign in with Google',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onCard(context),
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

// ── Policy dialog ─────────────────────────────────────────────────────────────

class _PolicyDialog extends StatelessWidget {
  final String title;
  final String content;
  const _PolicyDialog({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.description_outlined,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                content,
                style: const TextStyle(fontSize: 13.5, height: 1.7),
              ),
            ),
          ),
          // Close button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Policy text content ───────────────────────────────────────────────────────

const _termsContent = '''
Terms of Service
Last updated: June 2026

1. Acceptance of Terms
By creating an account or using Invoice Generator ("the App"), you agree to these Terms of Service. If you do not agree, please do not use the App.

2. Description of Service
Invoice Generator is a mobile application that allows you to create, manage, and share professional invoices, quotations, and expense records. Your data is stored in your personal Google Drive account.

3. Your Account
You are responsible for maintaining the confidentiality of your Google account credentials. You agree to provide accurate information and to keep your business profile up to date. You must be at least 18 years old to use the App.

4. Data Ownership
All invoices, client records, and business data you create belong entirely to you. The App stores this data in your own Google Drive — we do not host or own your business data. You can delete or export your data at any time by accessing your Google Drive.

5. Acceptable Use
You agree not to use the App to:
• Create fraudulent or misleading invoices
• Violate any applicable laws or regulations
• Attempt to reverse-engineer or tamper with the App
• Use the App for any unlawful commercial purpose

6. Subscription and Billing
Free features are available without payment. Paid plans (Lite, Pro, Premium, Enterprise) are offered on a subscription basis. Subscription fees are charged in advance. Refunds are available within 7 days of purchase if you have not used any paid features. Prices are subject to change with 30 days' notice.

7. Intellectual Property
The App, including its design, code, and content, is owned by the developer. You retain all rights to your business data and invoices. You grant the App a limited licence to process your data solely to provide the service.

8. Disclaimer of Warranties
The App is provided "as is" without warranties of any kind. We do not guarantee uninterrupted or error-free service. Invoice Generator is not a substitute for professional accounting or legal advice.

9. Limitation of Liability
To the maximum extent permitted by law, the developer shall not be liable for any indirect, incidental, or consequential damages arising from your use of the App.

10. Termination
You may stop using the App at any time. We reserve the right to suspend or terminate accounts that violate these Terms.

11. Governing Law
These Terms are governed by the laws of India. Any disputes shall be subject to the jurisdiction of courts in India.

12. Changes to Terms
We may update these Terms from time to time. Continued use of the App after changes constitutes acceptance of the new Terms.

Contact: support@invoicegenerator.app
''';

const _privacyContent = '''
Privacy Policy
Last updated: June 2026

1. Introduction
Invoice Generator ("we", "our", or "the App") is committed to protecting your privacy. This Privacy Policy explains what information we collect, how we use it, and your rights.

2. Information We Collect

a) Information you provide:
• Business name, address, phone number, email, and GSTIN
• Client names, contact details, and GST information
• Invoice data, line items, and payment records
• Profile photo (if uploaded)

b) Information collected automatically:
• Anonymous usage statistics (feature usage frequency, crash reports)
• Device type and operating system version
• App version

We do NOT collect your Google account password, payment card details, or any sensitive personal information beyond what you voluntarily enter into the App.

3. How We Use Your Information
• To provide and improve the App's features
• To sync your data securely via Google Drive
• To send payment reminders on your behalf (only when you enable this)
• To display anonymous aggregate statistics on our admin dashboard
• To respond to your support requests

4. Data Storage and Cross-Border Transfer
Your invoices and business data are stored exclusively in your own Google Drive account under the folder "InvoiceGenerator". We use the Google Drive API with the minimum permissions necessary. We do not store copies of your invoice data on our servers.

Google Drive is operated by Google LLC (USA). Your data may be stored and processed on Google's servers located outside India, including in the United States or other countries. By using this App and accepting these terms, you expressly consent to this cross-border transfer of your personal data as permitted under the Digital Personal Data Protection Act, 2023 (DPDP Act). Google's data handling is governed by Google's Privacy Policy (policies.google.com/privacy).

5. Data Sharing
We do not sell, rent, or trade your personal information. We may share anonymised, aggregated statistics (e.g. total number of users) for business reporting. We may disclose information if required by law or to protect our legal rights.

6. Third-Party Services
The App uses the following third-party services:
• Google Sign-In and Google Drive API (Google LLC) — for authentication and data storage
• Google AdMob — for displaying advertisements on the free tier
• Firebase — for push notifications and anonymous crash reporting

Each third party has its own privacy policy governing how they handle your data.

7. Data Retention
Your data remains in your Google Drive as long as you choose to keep it. If you uninstall the App, your Drive data is not deleted. You can permanently delete your data by removing the "InvoiceGenerator" folder from your Google Drive and revoking the App's access in your Google account settings.

8. Security
We implement AES-256 encryption for all data stored locally on your device. Data transmitted to Google Drive uses HTTPS/TLS. We follow industry-standard security practices, but no method of electronic storage is 100% secure.

9. Children's Privacy
The App is not directed to children under the age of 13. We do not knowingly collect personal information from children.

10. Your Rights
You have the right to:
• Access all your data (available directly in your Google Drive)
• Correct inaccurate information
• Delete your data (by removing your Drive folder)
• Withdraw consent by uninstalling the App and revoking Drive access

11. Changes to this Policy
We may update this Privacy Policy periodically. We will notify you of significant changes through the App. Continued use after changes constitutes acceptance.

12. Grievance Officer
In accordance with the Information Technology Act, 2000 and the Digital Personal Data Protection Act, 2023, the name and contact details of the Grievance Officer are provided below. If you have any complaints or concerns regarding the processing of your personal data, please contact:

Grievance Officer: App Support Team
Email: grievance@invoicegenerator.app
Response time: We will acknowledge your grievance within 48 hours and resolve it within 30 days.

13. Contact Us
If you have questions about this Privacy Policy, please contact:
Email: privacy@invoicegenerator.app
''';
