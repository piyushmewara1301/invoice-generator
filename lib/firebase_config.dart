/// Firebase / Firestore configuration.
///
/// Setup steps:
/// 1. Go to https://console.firebase.google.com and create a project.
/// 2. Enable Firestore Database (start in test mode for development).
/// 3. Project Settings → General → Your apps → Add app (Web) → copy the config.
/// 4. Replace the placeholder values below with your real values.
/// 5. Copy the same projectId and apiKey into invoice_admin/lib/firebase_config.dart.
///
/// Firestore security rules (paste in Firestore → Rules tab):
/// ───────────────────────────────────────────────────────────
/// rules_version = '2';
/// service cloud.firestore {
///   match /databases/{database}/documents {
///     match /verifications/{doc}   { allow read, write: if true; }
///     match /stats/{doc}           { allow read, write: if true; }
///     // subscriptions collection — read/write required by the client app for
///     // IAP expiry checks and admin-granted tier sync.
///     match /subscriptions/{doc}   { allow read, write: if true; }
///   }
/// }
/// ───────────────────────────────────────────────────────────
/// (Tighten these rules once you go to production.)
class FirebaseConfig {
  static const String projectId = 'invoice-genrator-d6d42';
  static const String apiKey = 'AIzaSyCMBQE7beLgR18z_3axwRsLM3G9FYvvpMw';

  static bool get isConfigured =>
      projectId != 'YOUR_FIREBASE_PROJECT_ID' &&
      apiKey != 'YOUR_WEB_API_KEY';
}
