import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/reminder_settings.dart';
import '../../providers/app_provider.dart';
import '../../services/reminder_service.dart';
import '../../utils/app_theme.dart';

class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  late ReminderSettings _settings;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await ReminderSettings.load();
    setState(() {
      _settings = s;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    // Ask for permission the first time the user enables reminders.
    if (_settings.enabled) {
      await ReminderService.requestPermissions();
    }

    // Persist and re-schedule via provider so state stays consistent.
    if (mounted) {
      await context.read<AppProvider>().updateReminderSettings(_settings);
    }

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Reminder settings saved.'),
        duration: Duration(seconds: 2),
      ));
    }
  }

  void _toggleBeforeDay(int day) {
    final list = List<int>.from(_settings.beforeDueDays);
    if (list.contains(day)) {
      list.remove(day);
    } else {
      list.add(day);
    }
    setState(() => _settings = _settings.copyWith(beforeDueDays: list));
  }

  void _toggleAfterDay(int day) {
    final list = List<int>.from(_settings.afterDueDays);
    if (list.contains(day)) {
      list.remove(day);
    } else {
      list.add(day);
    }
    setState(() => _settings = _settings.copyWith(afterDueDays: list));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _settings.notificationHour,
        minute: _settings.notificationMinute,
      ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _settings = _settings.copyWith(
            notificationHour: picked.hour,
            notificationMinute: picked.minute,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        appBar: _TitleBar(),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Reminders'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Master toggle
          _card(children: [
            SwitchListTile(
              value: _settings.enabled,
              onChanged: (v) =>
                  setState(() => _settings = _settings.copyWith(enabled: v)),
              title: const Text('Enable Reminders',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
              subtitle: const Text(
                  'Push notifications reminding you to follow up on unpaid invoices',
                  style: TextStyle(fontSize: 12)),
              activeThumbColor: AppTheme.primary,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ]),

          if (_settings.enabled) ...[
            const SizedBox(height: 16),

            // Notification time
            _sectionHeader('Notify me at'),
            _card(children: [
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.access_time,
                      size: 18, color: AppTheme.primary),
                ),
                title: Text(_settings.notificationTimeLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                subtitle: const Text('Daily notification time',
                    style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right,
                    size: 18, color: AppTheme.textSecondary),
                onTap: _pickTime,
              ),
            ]),

            const SizedBox(height: 16),

            // Before due date
            _sectionHeader('Before due date'),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Remind you in advance so you can send an invoice reminder to the client.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
            _dayChips(
              days: ReminderSettings.availableBeforeDays,
              selected: _settings.beforeDueDays,
              labelBuilder: (d) => '$d day${d == 1 ? '' : 's'} before',
              onTap: _toggleBeforeDay,
            ),

            const SizedBox(height: 16),

            // On due date
            _sectionHeader('On the due date'),
            _card(children: [
              SwitchListTile(
                value: _settings.onDueDate,
                onChanged: (v) =>
                    setState(() => _settings = _settings.copyWith(onDueDate: v)),
                title: const Text('Notify on due date',
                    style: TextStyle(fontSize: 14)),
                activeThumbColor: AppTheme.primary,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ]),

            const SizedBox(height: 16),

            // After due date (overdue)
            _sectionHeader('After due date (overdue)'),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Follow-up reminders for invoices that have already passed their due date.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
            _dayChips(
              days: ReminderSettings.availableAfterDays,
              selected: _settings.afterDueDays,
              labelBuilder: (d) => '$d day${d == 1 ? '' : 's'} overdue',
              onTap: _toggleAfterDay,
            ),

            const SizedBox(height: 16),

            // Summary
            if (_settings.hasAnyTrigger) _summaryCard(),

            const SizedBox(height: 8),
            const Text(
              'Reminders are local notifications on your device. '
              'Tapping one opens the invoice so you can quickly send a WhatsApp or email to your client.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _summaryCard() {
    final triggers = <String>[];
    final sorted = List<int>.from(_settings.beforeDueDays)..sort();
    for (final d in sorted.reversed) {
      triggers.add('$d day${d == 1 ? '' : 's'} before due');
    }
    if (_settings.onDueDate) triggers.add('On the due date');
    final sortedAfter = List<int>.from(_settings.afterDueDays)..sort();
    for (final d in sortedAfter) {
      triggers.add('$d day${d == 1 ? '' : 's'} overdue');
    }

    return _card(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: [
            const Icon(Icons.notifications_active_outlined,
                size: 18, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text('${triggers.length} reminder${triggers.length == 1 ? '' : 's'} per invoice',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.primary)),
          ],
        ),
      ),
      ...triggers.map((t) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 5, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text(t,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          )),
      const SizedBox(height: 12),
    ]);
  }

  Widget _dayChips({
    required List<int> days,
    required List<int> selected,
    required String Function(int) labelBuilder,
    required void Function(int) onTap,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: days.map((d) {
        final isSelected = selected.contains(d);
        return FilterChip(
          label: Text(labelBuilder(d)),
          selected: isSelected,
          onSelected: (_) => onTap(d),
          selectedColor: AppTheme.primary.withValues(alpha: 0.15),
          checkmarkColor: AppTheme.primary,
          labelStyle: TextStyle(
            fontSize: 13,
            color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          side: BorderSide(
            color: isSelected ? AppTheme.primary : AppTheme.divider,
          ),
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 4),
        );
      }).toList(),
    );
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                letterSpacing: 0.3)),
      );

  Widget _card({required List<Widget> children}) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(children: children),
      );
}

// Minimal AppBar used while loading so the title still shows.
class _TitleBar extends StatelessWidget implements PreferredSizeWidget {
  const _TitleBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) =>
      AppBar(title: const Text('Payment Reminders'));
}
