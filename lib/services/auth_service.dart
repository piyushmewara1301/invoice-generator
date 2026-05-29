import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;

// Web OAuth 2.0 client ID (type: Web application) from Google Cloud Console.
// Project: invoicegenerator-497122
// Replace this with your real Web client ID to enable sign-in on web.
const _kWebClientId =
    '891634878125-hh0jrdebvo205mclifdpau6tbo66a9cu.apps.googleusercontent.com';

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
  String? lastError;

  GoogleSignInAccount? get user => _user;
  bool get isSignedIn => _user != null;
  bool get initializing => _initializing;

  Future<void> init() async {
    if (kIsWeb) {
      // On web, sign-ins come via renderButton → onCurrentUserChanged stream.
      _instance.onCurrentUserChanged.listen((account) {
        _user = account;
        _initializing = false;
        notifyListeners();
      });
    }
    try {
      _user = await _instance.signInSilently();
    } catch (e) {
      _user = null;
      lastError = e.toString();
    } finally {
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
    notifyListeners();
  }

  /// Returns an HTTP client that automatically injects OAuth Bearer tokens.
  Future<http.Client?> getAuthClient() async {
    return _instance.authenticatedClient();
  }
}
