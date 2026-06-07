import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which feature guides have been permanently dismissed by the user.
/// Each guide is identified by a short string [key].
class GuideService {
  static const _prefix = 'guide_v1_';

  /// Returns true if the user has permanently dismissed the guide for [key].
  static Future<bool> isDismissed(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefix$key') ?? false;
  }

  /// Permanently dismisses the guide for [key].
  static Future<void> dismiss(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$key', true);
  }

  /// Resets all dismissed guides (e.g., for a "Show all guides again" setting).
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    final toRemove =
        prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in toRemove) {
      await prefs.remove(k);
    }
  }

  /// Shows the guide sheet if the user has NOT permanently dismissed it.
  /// Call this from a screen's initState using addPostFrameCallback so it
  /// doesn't block the first frame.
  static Future<bool> shouldShow(String key) async {
    return !(await isDismissed(key));
  }
}
