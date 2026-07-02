import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Web OAuth 2.0 client ID (type: Web application) from Google Cloud Console.
// Project: invoicegenerator-497122
// Replace this with your real Web client ID to enable sign-in on web.
const _kWebClientId =
    '891634878125-hh0jrdebvo205mclifdpau6tbo66a9cu.apps.googleusercontent.com';

const _kPrefEmail = 'auth_cached_email';
const _kPrefName  = 'auth_cached_name';

class AuthService extends ChangeNotifier {
  static final _instance = GoogleSignIn(
    clientId: kIsWeb ? _kWebClientId : null,
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/drive',
    ],
  );

  GoogleSignInAccount? _user;
  bool _initializing = true;
  bool _offlineMode = false;
  String? _cachedEmail;
  String? _cachedDisplayName;
  String? lastError;

  GoogleSignInAccount? get user => _user;
  bool get isSignedIn => _user != null;
  bool get initializing => _initializing;

  /// True when the token refresh failed (offline) but the user was previously
  /// signed in and has local data. The app can operate read-only until the
  /// user reconnects and restarts.
  bool get isOfflineMode => _offlineMode;
  String? get cachedEmail => _cachedEmail;
  String? get cachedDisplayName => _cachedDisplayName;

  Future<void> init() async {
    // Load persisted identity before doing any network calls so we always
    // know whether this device had a previous session.
    final prefs = await SharedPreferences.getInstance();
    _cachedEmail = prefs.getString(_kPrefEmail);
    _cachedDisplayName = prefs.getString(_kPrefName);

    if (kIsWeb) {
      // On web, sign-ins come via renderButton → onCurrentUserChanged stream.
      _instance.onCurrentUserChanged.listen((account) {
        _user = account;
        _offlineMode = false;
        _initializing = false;
        if (account != null) _persistIdentity(account);
        notifyListeners();
      });
    }
    try {
      _user = await _instance.signInSilently();
      if (_user != null) await _persistIdentity(_user!);
    } catch (e) {
      _user = null;
      lastError = e.toString();
    } finally {
      // If sign-in failed but we have a cached identity, enter offline mode
      // so the _AuthGate can show local data instead of the login screen.
      if (_user == null && _cachedEmail != null) {
        _offlineMode = true;
      }
      _initializing = false;
      notifyListeners();
    }
  }

  /// Requests Drive scope after initial sign-in (web only).
  Future<bool> requestDriveScope() =>
      _instance.requestScopes(['https://www.googleapis.com/auth/drive']);

  Future<bool> signIn() async {
    try {
      lastError = null;
      _user = await _instance.signIn();
      if (_user != null) {
        _offlineMode = false;
        await _persistIdentity(_user!);
      }
      notifyListeners();
      return _user != null;
    } catch (e) {
      lastError = e.toString();
      _user = null;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _instance.signOut();
    _user = null;
    _offlineMode = false;
    // Clear cached identity on explicit sign out so offline mode won't
    // activate on the next launch after a deliberate sign-out.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefEmail);
    await prefs.remove(_kPrefName);
    _cachedEmail = null;
    _cachedDisplayName = null;
    notifyListeners();
  }

  /// Returns an HTTP client that automatically injects OAuth Bearer tokens.
  Future<http.Client?> getAuthClient() async {
    return _instance.authenticatedClient();
  }

  Future<void> _persistIdentity(GoogleSignInAccount account) async {
    _cachedEmail = account.email;
    _cachedDisplayName = account.displayName ?? account.email;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefEmail, _cachedEmail!);
    await prefs.setString(_kPrefName, _cachedDisplayName!);
  }
}
