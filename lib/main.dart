import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings/plan_screen.dart';
import 'services/auth_service.dart';
import 'services/drive_service.dart';
import 'services/encryption_service.dart';
import 'services/exchange_rate_service.dart';
import 'services/ad_service.dart';
import 'services/reminder_service.dart';
import 'services/billing_service.dart';
import 'utils/app_theme.dart';
import 'screens/landing_screen.dart';
import 'widgets/web_shell.dart';
import 'widgets/keyboard_dismisser.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  if (!kIsWeb) await AdService.instance.initialize();
  if (!kIsWeb) await ReminderService.initialize();
  if (!kIsWeb) await BillingService().initialize();

  final authService = AuthService();
  final enc = EncryptionService();

  // Try to load the key from device secure storage so local data
  // (SharedPreferences) can be decrypted before Drive sync.
  await enc.tryLoadLocalKey();

  final appProvider = AppProvider(enc);

  // Load local cache first so the app feels instant.
  await appProvider.load();

  // Try silent sign-in (restores a previous session automatically).
  await authService.init();

  if (authService.isSignedIn) {
    final httpClient = await authService.getAuthClient();
    if (httpClient != null) {
      // Key management + Drive sync are both handled inside attachDriveAndSync.
      await appProvider.attachDriveAndSync(
        DriveService(httpClient),
        userEmail: authService.user?.email,
      );
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider.value(value: appProvider),
        ChangeNotifierProvider(create: (_) => ExchangeRateService()),
      ],
      child: const InvoiceApp(),
    ),
  );
}

class InvoiceApp extends StatelessWidget {
  const InvoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Invoice Generator',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const KeyboardDismisser(child: _AuthGate()),
      routes: {
        '/plans': (_) => const KeyboardDismisser(child: PlanScreen()),
      },
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _drivePending = false;
  // Set to true once an attach attempt completes (success or failure).
  // On web we must not check needsOnboarding until after the first attempt
  // because local SharedPreferences is empty and would falsely trigger onboarding.
  bool _driveAttachAttempted = false;
  // True when requestDriveScope() popup was blocked / denied by the browser.
  bool _driveGrantNeeded = false;

  Future<void> _attachDrive() async {
    if (_drivePending || !mounted) return;
    setState(() {
      _drivePending = true;
      _driveGrantNeeded = false;
    });
    final auth = context.read<AuthService>();
    final appProvider = context.read<AppProvider>();

    if (kIsWeb) {
      final granted = await auth.requestDriveScope();
      if (!mounted) return;
      if (!granted) {
        // Popup was blocked or user denied — show an explicit grant button.
        setState(() {
          _drivePending = false;
          _driveAttachAttempted = true;
          _driveGrantNeeded = true;
        });
        return;
      }
    }

    final httpClient = await auth.getAuthClient();
    if (!mounted) return;
    if (httpClient != null) {
      await appProvider.attachDriveAndSync(
        DriveService(httpClient),
        userEmail: auth.user?.email,
      );
    }
    if (mounted) {
      setState(() {
        _drivePending = false;
        _driveAttachAttempted = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (auth.initializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!auth.isSignedIn) {
      // Reset drive state so the next sign-in triggers a fresh sync.
      _driveAttachAttempted = false;
      _driveGrantNeeded = false;
      _drivePending = false;
      return kIsWeb ? const LandingScreen() : const LoginScreen();
    }

    final appProvider = context.watch<AppProvider>();

    // ── Web-specific Drive sync gate ─────────────────────────────────────────
    // On web, localStorage may be empty for a returning user (different browser,
    // cleared cache) so we must load from Drive before checking needsOnboarding.
    if (kIsWeb) {
      if (!_driveAttachAttempted && !_drivePending) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _attachDrive());
      }

      // Drive scope was blocked — show an explicit connect button so the user
      // can trigger the OAuth popup via a direct gesture (bypasses popup blocker).
      if (_driveGrantNeeded) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off_rounded,
                    size: 56, color: AppTheme.textSecondary),
                const SizedBox(height: 20),
                const Text(
                  'Drive access required',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'We need Google Drive to sync your invoices.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: _attachDrive,
                  icon: const Icon(Icons.drive_folder_upload_rounded),
                  label: const Text('Connect Google Drive'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // Show a loading screen until the first attach attempt finishes.
      if (!_driveAttachAttempted || _drivePending || appProvider.syncing) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Syncing from Google Drive…',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        );
      }
    } else {
      // Mobile: attach Drive in the background if not yet connected.
      if (!appProvider.hasDrive && !appProvider.syncing && !_drivePending) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _attachDrive());
      }
      if (appProvider.syncing || _drivePending) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Syncing from Google Drive…',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        );
      }
    }

    // ── Sync error gate ──────────────────────────────────────────────────────
    // Decryption or parse failures mean we couldn't read the user's Drive data.
    // Show a clear error rather than falling through to onboarding (which would
    // risk overwriting their Drive file with empty data).
    final syncError = appProvider.lastSyncError;
    if (syncError == 'decryption_failed' || syncError == 'parse_failed') {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 56, color: Colors.orange),
                const SizedBox(height: 20),
                const Text(
                  'Could not read your data',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  syncError == 'decryption_failed'
                      ? 'Your data exists in Google Drive but could not be decrypted. '
                        'This usually means you signed in on a different device. '
                        'Sign out and sign back in to restore your encryption key.'
                      : 'Your Drive data could not be parsed. '
                        'Please sign out and sign back in.',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () async {
                    final auth = context.read<AuthService>();
                    final ap = context.read<AppProvider>();
                    await ap.detachDriveAndClear();
                    await auth.signOut();
                  },
                  child: const Text('Sign out & retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (appProvider.needsOnboarding) {
      return const OnboardingScreen();
    }

    // On web always show WebShell (sidebar navigation is always available).
    // Premium gating is handled inside individual screens, not at shell level.
    return kIsWeb ? const WebShell() : const DashboardScreen();
  }
}
