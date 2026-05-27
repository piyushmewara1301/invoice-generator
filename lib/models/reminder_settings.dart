import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ReminderSettings {
  bool enabled;
  List<int> beforeDueDays; // positive numbers: days BEFORE due date
  bool onDueDate;
  List<int> afterDueDays; // positive numbers: days AFTER due date (overdue)
  int notificationHour;
  int notificationMinute;

  static const _key = 'reminder_settings';
  static const availableBeforeDays = [14, 7, 3, 1];
  static const availableAfterDays = [1, 3, 7, 14];

  ReminderSettings({
    this.enabled = true,
    this.beforeDueDays = const [],
    this.onDueDate = true,
    this.afterDueDays = const [],
    this.notificationHour = 10,
    this.notificationMinute = 0,
  });

  bool get hasAnyTrigger =>
      onDueDate || beforeDueDays.isNotEmpty || afterDueDays.isNotEmpty;

  String get notificationTimeLabel {
    final h = notificationHour;
    final m = notificationMinute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour:$m $period';
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'beforeDueDays': beforeDueDays,
        'onDueDate': onDueDate,
        'afterDueDays': afterDueDays,
        'notificationHour': notificationHour,
        'notificationMinute': notificationMinute,
      };

  factory ReminderSettings.fromJson(Map<String, dynamic> json) =>
      ReminderSettings(
        enabled: json['enabled'] as bool? ?? true,
        beforeDueDays: List<int>.from(json['beforeDueDays'] as List? ?? []),
        onDueDate: json['onDueDate'] as bool? ?? true,
        afterDueDays: List<int>.from(json['afterDueDays'] as List? ?? []),
        notificationHour: json['notificationHour'] as int? ?? 10,
        notificationMinute: json['notificationMinute'] as int? ?? 0,
      );

  static Future<ReminderSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return ReminderSettings();
    try {
      return ReminderSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return ReminderSettings();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }

  ReminderSettings copyWith({
    bool? enabled,
    List<int>? beforeDueDays,
    bool? onDueDate,
    List<int>? afterDueDays,
    int? notificationHour,
    int? notificationMinute,
  }) =>
      ReminderSettings(
        enabled: enabled ?? this.enabled,
        beforeDueDays: beforeDueDays ?? this.beforeDueDays,
        onDueDate: onDueDate ?? this.onDueDate,
        afterDueDays: afterDueDays ?? this.afterDueDays,
        notificationHour: notificationHour ?? this.notificationHour,
        notificationMinute: notificationMinute ?? this.notificationMinute,
      );
}
