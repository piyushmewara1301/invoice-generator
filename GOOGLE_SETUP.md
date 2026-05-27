# Google Sign-In & Drive Setup Guide

> **No `google-services.json` needed.** The app uses the `google_sign_in` Flutter plugin directly with no Firebase. You only need credentials registered in Google Cloud Console and one value pasted into `Info.plist` for iOS.

---

## Android Setup — no file to copy

Android Google Sign-In works by matching your **package name + SHA-1 fingerprint** in Google Cloud Console. Nothing needs to be copied into the project folder.

**Checklist:**
- OAuth 2.0 Client ID (type: Android) created with package name `com.example.invoice_genreator`
- Your debug SHA-1 fingerprint is entered on that credential

To get your debug SHA-1 (run in Terminal):

```bash
keytool -list -v \
  -keystore ~/.android/debug.keystore \
  -alias androiddebugkey \
  -storepass android -keypass android
```

Copy the `SHA1:` line and paste it into the Android OAuth credential in Cloud Console. That is all — no JSON file to copy anywhere.

---

## iOS Setup

### Step 1 — Find your Reversed Client ID

1. Go to Google Cloud Console → Credentials
2. Click your **iOS OAuth 2.0 Client ID**
3. Note the **Client ID** value, e.g. `123456-abcdef.apps.googleusercontent.com`
4. The **Reversed Client ID** is the same string reversed: `com.googleusercontent.apps.123456-abcdef`

### Step 2 — Paste it into Info.plist (edit in VS Code, no Xcode needed)

Open `ios/Runner/Info.plist` and find this section:

```xml
<string>REPLACE_WITH_YOUR_REVERSED_CLIENT_ID</string>
```

Replace that placeholder with your actual Reversed Client ID, e.g.:

```xml
<string>com.googleusercontent.apps.123456-abcdef</string>
```

Save the file. Done — no need to open Xcode for this step.

### Step 3 — If you need to open Xcode (optional)

If you downloaded a `GoogleService-Info.plist` and want to add it:

1. In VS Code Terminal run: `open ios/Runner.xcworkspace`
   (always open `.xcworkspace`, not `.xcodeproj`)
2. In Xcode, click the **folder icon** at the very top-left of the left panel (Project Navigator)
3. You will see **Runner** at the top with a blue icon — expand it
4. Inside there is another **Runner** folder (also blue) — this is where source files live
5. Right-click that inner **Runner** folder → **Add Files to Runner...**
6. Select `GoogleService-Info.plist`, tick **Copy items if needed**, click **Add**

---

## Web Client ID — skip it

The Web OAuth client ID is for backend servers. This app writes directly from the device to Google Drive — there is no server — so the Web client is not used and nothing needs to be configured for it.

---

## Verify

```bash
flutter run
```

On first launch the Sign In screen appears. Tap **Sign in with Google**, pick your account, and you land on the Dashboard. Data is stored at:

**Google Drive → My Drive → InvoiceGenerator → invoice_data.json**

---

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| Sign-in never completes (Android) | SHA-1 not registered | Check SHA-1 on the Android OAuth credential |
| `ApiException: 10` | Package name mismatch | Credential must use `com.example.invoice_genreator` |
| Sign-in redirect fails (iOS) | Wrong URL scheme | Double-check the Reversed Client ID in `Info.plist` |
| `403` on Drive | Missing scope | Add `drive.file` on the OAuth consent screen |
| App shows "unverified" warning | Normal for test accounts | Add your email as a Test User on the consent screen |
