import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/invoice.dart';
import '../models/reminder_settings.dart';
import '../utils/formatters.dart';

// Notification channel ID used for Android.
const _channelId = 'payment_reminders';

class ReminderService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Called once from main() before runApp.
  static Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Create the Android notification channel once.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          'Payment Reminders',
          description: 'Reminders to follow up on unpaid invoices',
          importance: Importance.high,
        ));

    _initialized = true;
  }

  // Request OS-level notification permissions (iOS + Android 13+).
  // Returns true if granted.
  static Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    final iosOk = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        true;
    final androidOk =
        await android?.requestNotificationsPermission() ?? true;
    return iosOk && androidOk;
  }

  // Deterministic notification ID: invoiceId hash × 10 + trigger index.
  // Supports up to 9 triggers per invoice without collision between invoices.
  static int _notifId(String invoiceId, int dayOffset) {
    // dayOffset: negative = before due, 0 = on due, positive = after due
    const offsets = [-14, -7, -3, -1, 0, 1, 3, 7, 14];
    final idx = offsets.indexOf(dayOffset).clamp(0, 8);
    return (invoiceId.hashCode.abs() % 10000000) * 10 + idx;
  }

  // Cancel every possible notification for one invoice.
  static Future<void> cancelForInvoice(String invoiceId) async {
    const offsets = [-14, -7, -3, -1, 0, 1, 3, 7, 14];
    for (final offset in offsets) {
      await _plugin.cancel(_notifId(invoiceId, offset));
    }
  }

  // Schedule (or re-schedule) all reminder notifications for [invoice].
  static Future<void> scheduleForInvoice(
      Invoice invoice, ReminderSettings settings) async {
    if (!_initialized) await initialize();
    await cancelForInvoice(invoice.id);

    if (!settings.enabled || !settings.hasAnyTrigger) { return; }
    if (invoice.status == InvoiceStatus.paid ||
        invoice.status == InvoiceStatus.cancelled) { return; }
    if (invoice.client == null) { return; }

    final now = DateTime.now();
    final clientName = invoice.client!.displayName;
    final amount =
        Fmt.currencyAmount(invoice.amountRemaining, invoice.currency);

    void schedule(int dayOffset) {
      // dayOffset is the signed offset from the due date
      final triggerDay = invoice.dueDate.add(Duration(days: dayOffset));
      final notifTime = DateTime(
        triggerDay.year,
        triggerDay.month,
        triggerDay.day,
        settings.notificationHour,
        settings.notificationMinute,
      );
      if (notifTime.isBefore(now)) { return; } // skip past times

      String title, body;
      if (dayOffset < 0) {
        final days = -dayOffset;
        title = 'Payment due in $days day${days == 1 ? '' : 's'}';
        body = '$clientName · $amount — ${invoice.invoiceNumber}';
      } else if (dayOffset == 0) {
        title = 'Payment due today';
        body = '$clientName · $amount — ${invoice.invoiceNumber}';
      } else {
        final days = dayOffset;
        title = '$days day${days == 1 ? '' : 's'} overdue';
        body = '$clientName · $amount outstanding — ${invoice.invoiceNumber}';
      }

      // Payload carries invoice ID so a tap can open the right screen.
      _plugin.zonedSchedule(
        _notifId(invoice.id, dayOffset),
        title,
        body,
        tz.TZDateTime.from(notifTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Payment Reminders',
            channelDescription:
                'Reminders to follow up on unpaid invoices',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: invoice.id,
      );
    }

    for (final days in settings.beforeDueDays) {
      schedule(-days);
    }
    if (settings.onDueDate) schedule(0);
    for (final days in settings.afterDueDays) {
      schedule(days);
    }
  }

  // Re-schedule reminders for every invoice (called when settings change).
  static Future<void> rescheduleAll(
      List<Invoice> invoices, ReminderSettings settings) async {
    for (final invoice in invoices) {
      await scheduleForInvoice(invoice, settings);
    }
  }

  // Returns all currently pending notifications (useful for debug / display).
  static Future<List<PendingNotificationRequest>>
      pendingNotifications() async {
    return _plugin.pendingNotificationRequests();
  }
}
