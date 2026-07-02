import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'providers/app_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
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
import 'widgets/web_shell.dart';
import 'widgets/keyboard_dismisser.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final authService = AuthService();
  final enc = EncryptionService();
  final db = await AppProvider.openInitialDatabase();
  final appProvider = AppProvider(enc, db);
  final localeProvider = LocaleProvider();
  final themeProvider = ThemeProvider();
  await localeProvider.init();
  await themeProvider.init();

  if (kIsWeb) {
    // On web, run the app immediately so the landing page renders at once.
    // Auth + Drive sync happen in the background and update the UI reactively.
    _webInit(authService, enc, appProvider);
  } else {
    await AdService.instance.initialize();
    await ReminderService.initialize();
    await BillingService().initialize();
    await enc.tryLoadLocalKey();
    await appProvider.load();
    await authService.init();
    if (authService.isSignedIn) {
      final httpClient = await authService.getAuthClient();
      if (httpClient != null) {
        await appProvider.attachDriveAndSync(
          DriveService(httpClient),
          userEmail: authService.user?.email,
        );
      }
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider.value(value: appProvider),
        ChangeNotifierProvider.value(value: localeProvider),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => ExchangeRateService()),
      ],
      child: const InvoiceApp(),
    ),
  );
}

/// Web-only background initializer. Runs after [runApp] so the landing page
/// renders immediately. Auth state changes propagate via [ChangeNotifier].
Future<void> _webInit(
  AuthService authService,
  EncryptionService enc,
  AppProvider appProvider,
) async {
  await enc.tryLoadLocalKey();
  await appProvider.load();
  // Drive attach is handled by _AuthGate once auth resolves.
  await authService.init();
}

class InvoiceApp extends StatelessWidget {
  const InvoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    final themeMode = context.watch<ThemeProvider>().mode;
    return MaterialApp(
      title: 'BillBook',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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
  // Prevents the retry loop: when Drive is offline, attachDriveAndSync sets
  // _drive=null which would otherwise trigger another attach on every rebuild.
  bool _driveAttachAttempted = false;
  // True when requestDriveScope() popup was blocked / denied by the browser.
  bool _driveGrantNeeded = false;
  // True when a connectivity check confirmed we are offline at attach time.
  bool _syncOffline = false;

  /// Returns false when there is no working internet connection.
  /// Uses a 4-second DNS lookup — no extra package needed.
  Future<bool> _isOnline() async {
    if (kIsWeb) return true; // can't use dart:io on web; assume online
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _attachDrive() async {
    if (_drivePending || !mounted) return;

    // Capture context-dependent services before any async gap.
    final auth = context.read<AuthService>();
    final appProvider = context.read<AppProvider>();

    // ── Connectivity gate ────────────────────────────────────────────────────
    // Check internet BEFORE doing any Drive/OAuth work.  Without this guard,
    // attachDriveAndSync fails → _drive = null → rebuild → retry → blinks.
    if (!await _isOnline()) {
      if (mounted) {
        setState(() {
          _driveAttachAttempted = true;
          _syncOffline = true;
        });
      }
      return;
    }

    setState(() {
      _drivePending = true;
      _driveGrantNeeded = false;
      _syncOffline = false;
    });

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
    } else if (appProvider.isEmployeeMode) {
      // Employee mode needs the full drive scope to read/write the owner's
      // shared file. This is a no-op if the scope is already granted; it
      // shows a consent screen only if the token was issued with the older
      // drive.file scope (existing users must approve once).
      final granted = await auth.requestDriveScope();
      if (!mounted) return;
      if (!granted) {
        setState(() {
          _drivePending = false;
          _driveAttachAttempted = true;
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

  /// Resets attach state so the next build triggers a fresh attempt.
  void _retrySync() {
    setState(() {
      _driveAttachAttempted = false;
      _syncOffline = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final appProvider = context.watch<AppProvider>();

    if (auth.initializing) {
      // On web, show the sign-in screen while auth checks silently — the HTML
      // landing page already handles marketing, so no need for LandingScreen.
      // On mobile, auth resolves from local storage, so a brief spinner is fine.
      return kIsWeb
          ? const LoginScreen()
          : const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!auth.isSignedIn) {
      // If the user was previously signed in and has local data, allow offline
      // access instead of forcing them to the login screen.
      if (auth.isOfflineMode && !appProvider.needsOnboarding) {
        if (!_driveAttachAttempted) _driveAttachAttempted = true;
        return _AppShellWithBanner(
          shell: MediaQuery.sizeOf(context).width >= 720
              ? const WebShell()
              : const DashboardScreen(),
          message: 'No internet · Showing local data',
          // No retry — auth itself failed; user must reconnect to sign in again.
        );
      }
      // Reset drive state so the next sign-in triggers a fresh sync.
      _driveAttachAttempted = false;
      _driveGrantNeeded = false;
      _drivePending = false;
      _syncOffline = false;
      return const LoginScreen();
    }

    // ── Employee access revocation dialog ────────────────────────────────────
    final revokeMsg = appProvider.revocationMessage;
    if (revokeMsg != null) {
      appProvider.clearRevocationMessage();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            icon: const Icon(Icons.block_outlined,
                color: Colors.red, size: 40),
            title: const Text('Access removed'),
            content: Text(revokeMsg),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
    }

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

      // Show spinner only until first attach attempt completes.
      // _syncOffline is set quickly when offline so the spinner never hangs.
      if (!_driveAttachAttempted || _drivePending || appProvider.syncing) {
        // If we went offline before the first attach, show no-internet screen.
        if (_syncOffline && appProvider.needsOnboarding) {
          return _noInternetFullScreen();
        }
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
      // ── Mobile Drive attach ─────────────────────────────────────────────────
      // _driveAttachAttempted prevents the retry loop:
      //   attachDriveAndSync (offline) → key load fails → _drive=null
      //   → hasDrive=false → without this guard: triggers _attachDrive again → blinks
      if (!appProvider.hasDrive && !appProvider.syncing &&
          !_drivePending && !_driveAttachAttempted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _attachDrive());
      }
      // Show full-screen spinner only on the very first sync when there is
      // no local data yet.  If cached data exists the app loads immediately
      // and syncs silently in the background.
      if ((appProvider.syncing || _drivePending) && appProvider.needsOnboarding) {
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

    // On web always show WebShell. On native, use it for tablets/iPads (≥ 720 px)
    // where the sidebar layout fits; phones get DashboardScreen.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final shell = (kIsWeb || screenWidth >= 720)
        ? const WebShell()
        : const DashboardScreen();

    // Show a non-blocking banner when sync failed due to network.
    // decryption/parse errors are handled above with a hard block.
    final syncErr = appProvider.lastSyncError;
    final hasNetworkSyncError = syncErr != null &&
        syncErr != 'decryption_failed' &&
        syncErr != 'parse_failed';
    if (_syncOffline || hasNetworkSyncError) {
      return _AppShellWithBanner(
        message: 'No internet · Showing local data',
        onRetry: _retrySync,
        shell: shell,
      );
    }

    return shell;
  }

  Widget _noInternetFullScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 64, color: AppTheme.textSecondary),
              const SizedBox(height: 24),
              const Text(
                'No internet connection',
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'BillBook needs internet the first time you open it\nto load your data from Google Drive.',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _retrySync,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps the app shell with an amber banner at the top.
/// Used for offline/sync-failed states where local data is still usable.
class _AppShellWithBanner extends StatelessWidget {
  final Widget shell;
  final String message;
  final VoidCallback? onRetry;

  const _AppShellWithBanner({
    required this.shell,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        shell,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Material(
              color: Colors.transparent,
              child: Container(
                color: const Color(0xFFF59E0B),
                padding:
                    const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onRetry != null) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: onRetry,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            'Retry',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
