import 'dart:io' show Platform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Prompts the user to rate the app after key milestones.
///
/// Rules:
/// - Only asks once per 90-day window.
/// - Triggers at invoice-count milestones: 5, 10, 25, 50, 100.
/// - Never prompts again once the user has dismissed three times.
class ReviewService {
  static const _keyLastPrompt    = 'review_last_prompt_ms';
  static const _keyInvoiceCount  = 'review_invoice_count';
  static const _keyDismissed     = 'review_dismissed';

  static const _milestones      = [5, 10, 25, 50, 100];
  static const _minDaysBetween  = 90;

  static const _appStoreId  = '6743295154';
  static const _playStoreId = 'com.example.invoice_genreator';

  static Uri get _storeUri => Platform.isIOS
      ? Uri.parse(
          'itms-apps://itunes.apple.com/app/id$_appStoreId?action=write-review')
      : Uri.parse(
          'https://play.google.com/store/apps/details?id=$_playStoreId');

  /// Call after every successful invoice save.
  static Future<void> onInvoiceSaved() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyDismissed) == true) return;

    final count = (prefs.getInt(_keyInvoiceCount) ?? 0) + 1;
    await prefs.setInt(_keyInvoiceCount, count);

    if (!_milestones.contains(count)) return;

    final lastMs   = prefs.getInt(_keyLastPrompt) ?? 0;
    final daysSince = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(lastMs))
        .inDays;
    if (lastMs != 0 && daysSince < _minDaysBetween) return;

    await prefs.setInt(_keyLastPrompt, DateTime.now().millisecondsSinceEpoch);
    await _launch(_storeUri);
  }

  /// Call when the user explicitly taps "Rate Us" in settings.
  static Future<void> openStoreListing() async {
    await _launch(_storeUri);
  }

  /// Mark that the user has opted out.
  static Future<void> dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDismissed, true);
  }

  static Future<void> _launch(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
