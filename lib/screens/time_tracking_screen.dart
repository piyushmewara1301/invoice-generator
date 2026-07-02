import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/client.dart';
import '../models/project.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import 'create_invoice_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TimeTrackingScreen
// ─────────────────────────────────────────────────────────────────────────────
// Layout:
//   Desktop (≥720 px): left project rail | right entry panel
//   Mobile: project list → tap → entry panel (full screen)
// ─────────────────────────────────────────────────────────────────────────────

class TimeTrackingScreen extends StatefulWidget {
  const TimeTrackingScreen({super.key});

  @override
  State<TimeTrackingScreen> createState() => _TimeTrackingScreenState();
}

class _TimeTrackingScreenState extends State<TimeTrackingScreen> {
  String? _selectedProjectId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final projects = provider.projects;
    final isDesktop = MediaQuery.of(context).size.width >= 720;

    // Auto-select first project on desktop when nothing is selected.
    if (isDesktop && _selectedProjectId == null && projects.isNotEmpty) {
      _selectedProjectId = projects.first.id;
    }

    final selected = projects.where((p) => p.id == _selectedProjectId).firstOrNull;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppTheme.surface,
        body: Row(
          children: [
            // ── Project rail ─────────────────────────────────────────
            SizedBox(
              width: 260,
              child: _ProjectRail(
                projects: projects,
                selectedId: _selectedProjectId,
                onSelect: (id) => setState(() => _selectedProjectId = id),
                onNew: () => _newProject(context),
              ),
            ),
            Container(width: 1, color: AppTheme.divider),
            // ── Entry panel ──────────────────────────────────────────
            Expanded(
              child: selected == null
                  ? _EmptyProjectPrompt(onNew: () => _newProject(context))
                  : _EntryPanel(project: selected),
            ),
          ],
        ),
      );
    }

    // Mobile: full-width project list; tap to enter entry panel.
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Time Tracking'),
        backgroundColor: AppTheme.card(context),
        foregroundColor: AppTheme.onCard(context),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Project',
            onPressed: () => _newProject(context),
          ),
        ],
      ),
      body: projects.isEmpty
          ? _EmptyProjectPrompt(onNew: () => _newProject(context))
          : ListView.separated(
              itemCount: projects.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
              itemBuilder: (ctx, i) {
                final p = projects[i];
                final entries = provider.timeEntries
                    .where((t) => t.projectId == p.id)
                    .toList();
                final unbilled = entries.where((t) => !t.isBilled);
                final totalHours =
                    unbilled.fold(0.0, (s, t) => s + t.hours);
                final totalAmt =
                    unbilled.fold(0.0, (s, t) => s + t.billableAmount);
                final sym = Fmt.currencySymbol(p.currency);
                return ListTile(
                  leading: _ProjectAvatar(project: p),
                  title: Text(p.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    p.clientName?.isNotEmpty == true
                        ? p.clientName!
                        : 'No client',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.subtext(context)),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_fmtHours(totalHours),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary)),
                      Text('$sym${Fmt.compact(totalAmt)} unbilled',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.subtext(context))),
                    ],
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _EntryPanelPage(project: p),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _newProject(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ProjectFormSheet(
        onSave: (p) {
          context.read<AppProvider>().addProject(p);
          setState(() => _selectedProjectId = p.id);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile wrapper for EntryPanel
// ─────────────────────────────────────────────────────────────────────────────

class _EntryPanelPage extends StatelessWidget {
  final Project project;
  const _EntryPanelPage({required this.project});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(project.name),
        backgroundColor: AppTheme.card(context),
        foregroundColor: AppTheme.onCard(context),
        elevation: 0,
      ),
      body: _EntryPanel(project: project),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Project rail (desktop left panel)
// ─────────────────────────────────────────────────────────────────────────────

class _ProjectRail extends StatelessWidget {
  final List<Project> projects;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onNew;

  const _ProjectRail({
    required this.projects,
    required this.selectedId,
    required this.onSelect,
    required this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.card(context),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Text(
                  'Projects',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onCard(context),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                  tooltip: 'New Project',
                  color: AppTheme.primary,
                  onPressed: onNew,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: projects.isEmpty
                ? Center(
                    child: Text('No projects yet',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.subtext(context))),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: projects.length,
                    itemBuilder: (ctx, i) {
                      final p = projects[i];
                      final sel = p.id == selectedId;
                      return _RailTile(
                        project: p,
                        selected: sel,
                        onTap: () => onSelect(p.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RailTile extends StatelessWidget {
  final Project project;
  final bool selected;
  final VoidCallback onTap;
  const _RailTile(
      {required this.project, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final entries = context
        .watch<AppProvider>()
        .timeEntries
        .where((t) => t.projectId == project.id && !t.isBilled);
    final hours = entries.fold(0.0, (s, t) => s + t.hours);

    return Material(
      color: selected
          ? AppTheme.primary.withValues(alpha: 0.09)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _ProjectAvatar(project: project, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? AppTheme.primary
                            : AppTheme.onCard(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hours > 0)
                      Text(
                        '${_fmtHours(hours)} unbilled',
                        style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.primary.withValues(alpha: 0.7)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Entry panel (right side on desktop, full screen on mobile)
// ─────────────────────────────────────────────────────────────────────────────

class _EntryPanel extends StatefulWidget {
  final Project project;
  const _EntryPanel({required this.project});

  @override
  State<_EntryPanel> createState() => _EntryPanelState();
}

class _EntryPanelState extends State<_EntryPanel> {
  bool _showBilled = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final sym = Fmt.currencySymbol(widget.project.currency);
    final allEntries = provider.timeEntries
        .where((t) => t.projectId == widget.project.id)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final unbilled = allEntries.where((t) => !t.isBilled).toList();
    final billed = allEntries.where((t) => t.isBilled).toList();
    final displayed = _showBilled ? billed : unbilled;

    final totalHours = unbilled.fold(0.0, (s, t) => s + t.hours);
    final totalAmt = unbilled.fold(0.0, (s, t) => s + t.billableAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ────────────────────────────────────────────────────
        Container(
          color: AppTheme.card(context),
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.project.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.onCard(context),
                            letterSpacing: -0.4,
                          ),
                        ),
                        if (widget.project.clientName?.isNotEmpty == true)
                          Text(
                            widget.project.clientName!,
                            style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.subtext(context)),
                          ),
                      ],
                    ),
                  ),
                  // Edit project
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: 'Edit project',
                    color: AppTheme.subtext(context),
                    onPressed: () => _editProject(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Summary chips
              Row(
                children: [
                  _SummaryChip(
                    icon: Icons.timer_outlined,
                    label: _fmtHours(totalHours),
                    sub: 'unbilled hours',
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 10),
                  _SummaryChip(
                    icon: Icons.currency_rupee_rounded,
                    label: '$sym${Fmt.compact(totalAmt)}',
                    sub: 'unbilled amount',
                    color: const Color(0xFF059669),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Actions row
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () => _logTime(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Log Time'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (unbilled.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () =>
                          _generateInvoice(context, unbilled),
                      icon: const Icon(Icons.receipt_long_outlined, size: 16),
                      label: const Text('Generate Invoice'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── Toggle billed / unbilled ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              _ToggleChip(
                label: 'Unbilled (${unbilled.length})',
                selected: !_showBilled,
                onTap: () => setState(() => _showBilled = false),
              ),
              const SizedBox(width: 8),
              _ToggleChip(
                label: 'Billed (${billed.length})',
                selected: _showBilled,
                onTap: () => setState(() => _showBilled = true),
              ),
            ],
          ),
        ),

        // ── Entries list ──────────────────────────────────────────────
        Expanded(
          child: displayed.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_outlined,
                          size: 40, color: AppTheme.subtext(context)),
                      const SizedBox(height: 12),
                      Text(
                        _showBilled
                            ? 'No billed entries yet'
                            : 'No unbilled entries\nTap "Log Time" to start',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.subtext(context),
                            height: 1.5),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: displayed.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 56),
                  itemBuilder: (ctx, i) => _EntryTile(
                    entry: displayed[i],
                    currency: sym,
                    onEdit: _showBilled
                        ? null
                        : () => _editEntry(context, displayed[i]),
                    onDelete: _showBilled
                        ? null
                        : () => _deleteEntry(context, displayed[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _logTime(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _TimeEntryFormSheet(
        project: widget.project,
        onSave: (entry) => context.read<AppProvider>().addTimeEntry(entry),
      ),
    );
  }

  Future<void> _editEntry(BuildContext context, TimeEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _TimeEntryFormSheet(
        project: widget.project,
        existing: entry,
        onSave: (updated) =>
            context.read<AppProvider>().updateTimeEntry(updated),
      ),
    );
  }

  Future<void> _deleteEntry(BuildContext context, TimeEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Entry'),
        content: Text(
            'Delete "${entry.description}" (${_fmtHours(entry.hours)})?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<AppProvider>().deleteTimeEntry(entry.id);
    }
  }

  Future<void> _editProject(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ProjectFormSheet(
        existing: widget.project,
        onSave: (p) => context.read<AppProvider>().updateProject(p),
      ),
    );
  }

  Future<void> _generateInvoice(
      BuildContext context, List<TimeEntry> unbilled) async {
    final grouping = await showDialog<TimeEntryGrouping>(
      context: context,
      builder: (ctx) => _GroupingDialog(entryCount: unbilled.length),
    );
    if (grouping == null || !context.mounted) return;

    final provider = context.read<AppProvider>();
    try {
      final invoice = await provider.generateInvoiceFromTimeEntries(
        project: widget.project,
        entries: unbilled,
        grouping: grouping,
      );
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CreateInvoiceScreen(invoice: invoice)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grouping selection dialog
// ─────────────────────────────────────────────────────────────────────────────

class _GroupingDialog extends StatefulWidget {
  final int entryCount;
  const _GroupingDialog({required this.entryCount});

  @override
  State<_GroupingDialog> createState() => _GroupingDialogState();
}

class _GroupingDialogState extends State<_GroupingDialog> {
  TimeEntryGrouping _selected = TimeEntryGrouping.byEntry;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Generate Invoice'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.entryCount} time entr${widget.entryCount == 1 ? 'y' : 'ies'} → how should they appear on the invoice?',
            style: TextStyle(
                fontSize: 13, color: AppTheme.subtext(context), height: 1.4),
          ),
          const SizedBox(height: 16),
          ...[
            (TimeEntryGrouping.byEntry, 'One line per entry',
                'Each time log becomes a separate line item.'),
            (TimeEntryGrouping.byMember, 'Group by team member',
                'Hours are summed per person — one line each.'),
            (TimeEntryGrouping.total, 'Single total line',
                'All hours combined into one line item.'),
          ].map((opt) {
            final sel = _selected == opt.$1;
            return GestureDetector(
              onTap: () => setState(() => _selected = opt.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: sel
                      ? AppTheme.primary.withValues(alpha: 0.08)
                      : AppTheme.card(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sel ? AppTheme.primary : AppTheme.divider,
                    width: sel ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      sel
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: sel
                          ? AppTheme.primary
                          : AppTheme.subtext(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(opt.$2,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: sel
                                    ? AppTheme.primary
                                    : AppTheme.onCard(context),
                              )),
                          Text(opt.$3,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.subtext(context))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Generate'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Entry tile
// ─────────────────────────────────────────────────────────────────────────────

class _EntryTile extends StatelessWidget {
  final TimeEntry entry;
  final String currency;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _EntryTile({
    required this.entry,
    required this.currency,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Date
          SizedBox(
            width: 42,
            child: Column(
              children: [
                Text(
                  _shortDay(entry.date),
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.subtext(context),
                      letterSpacing: 0.5),
                ),
                Text(
                  entry.date.day.toString(),
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onCard(context),
                      height: 1.1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Description + member
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onCard(context)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 12, color: AppTheme.subtext(context)),
                    const SizedBox(width: 3),
                    Text(
                      entry.memberName,
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.subtext(context)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Hours + amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmtHours(entry.hours),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: entry.isBilled
                        ? AppTheme.subtext(context)
                        : AppTheme.primary),
              ),
              Text(
                '$currency${Fmt.compact(entry.billableAmount)}',
                style: TextStyle(
                    fontSize: 11, color: AppTheme.subtext(context)),
              ),
              if (entry.isBilled)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Billed',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF059669)),
                  ),
                ),
            ],
          ),

          // Actions
          if (onEdit != null || onDelete != null)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert,
                  size: 18, color: AppTheme.subtext(context)),
              itemBuilder: (_) => [
                if (onEdit != null)
                  const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                          dense: true,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'))),
                if (onDelete != null)
                  const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                          dense: true,
                          leading: Icon(Icons.delete_outline,
                              color: AppTheme.error),
                          title: Text('Delete',
                              style: TextStyle(color: AppTheme.error)))),
              ],
              onSelected: (v) {
                if (v == 'edit') onEdit?.call();
                if (v == 'delete') onDelete?.call();
              },
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Project form (create / edit) bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ProjectFormSheet extends StatefulWidget {
  final Project? existing;
  final ValueChanged<Project> onSave;

  const _ProjectFormSheet({this.existing, required this.onSave});

  @override
  State<_ProjectFormSheet> createState() => _ProjectFormSheetState();
}

class _ProjectFormSheetState extends State<_ProjectFormSheet> {
  final _nameCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  Client? _client;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final p = widget.existing!;
      _nameCtrl.text = p.name;
      _rateCtrl.text = p.defaultHourlyRate.toStringAsFixed(0);
      _descCtrl.text = p.description ?? '';
    } else {
      _rateCtrl.text = '1000';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rateCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final p = widget.existing != null
        ? (widget.existing!
          ..name = _nameCtrl.text.trim()
          ..clientId = _client?.id
          ..clientName = _client?.displayName
          ..defaultHourlyRate =
              double.tryParse(_rateCtrl.text) ?? 1000
          ..description =
              _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim())
        : Project(
            id: const Uuid().v4(),
            name: _nameCtrl.text.trim(),
            clientId: _client?.id,
            clientName: _client?.displayName,
            defaultHourlyRate:
                double.tryParse(_rateCtrl.text) ?? 1000,
            description:
                _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          );
    widget.onSave(p);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final clients = context.read<AppProvider>().clients;
    final sym =
        Fmt.currencySymbol(context.read<AppProvider>().profile.currency);

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.existing == null ? 'New Project' : 'Edit Project',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),

              // Name
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Project Name *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),

              // Client picker
              DropdownButtonFormField<Client?>(
                initialValue: _client,
                decoration: const InputDecoration(
                  labelText: 'Client (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<Client?>(
                      value: null, child: Text('— No client —')),
                  ...clients.map((c) => DropdownMenuItem<Client?>(
                      value: c, child: Text(c.displayName))),
                ],
                onChanged: (c) => setState(() => _client = c),
              ),
              const SizedBox(height: 14),

              // Default rate
              TextFormField(
                controller: _rateCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'))
                ],
                decoration: InputDecoration(
                  labelText: 'Default Hourly Rate ($sym)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Enter a number';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Description
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    widget.existing == null ? 'Create Project' : 'Save',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Time entry form (log / edit) bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _TimeEntryFormSheet extends StatefulWidget {
  final Project project;
  final TimeEntry? existing;
  final ValueChanged<TimeEntry> onSave;

  const _TimeEntryFormSheet({
    required this.project,
    this.existing,
    required this.onSave,
  });

  @override
  State<_TimeEntryFormSheet> createState() => _TimeEntryFormSheetState();
}

class _TimeEntryFormSheetState extends State<_TimeEntryFormSheet> {
  final _descCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _memberCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _descCtrl.text = e.description;
      _hoursCtrl.text = e.hours.toStringAsFixed(
          e.hours == e.hours.truncateToDouble() ? 0 : 2);
      _rateCtrl.text = e.hourlyRate.toStringAsFixed(0);
      _memberCtrl.text = e.memberName;
      _date = e.date;
    } else {
      _rateCtrl.text =
          widget.project.defaultHourlyRate.toStringAsFixed(0);
      // Default member name from last entry for this project.
      final last = context
          .read<AppProvider>()
          .timeEntries
          .where((t) => t.projectId == widget.project.id)
          .firstOrNull;
      _memberCtrl.text = last?.memberName ?? '';
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _hoursCtrl.dispose();
    _rateCtrl.dispose();
    _memberCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final hours = double.parse(_hoursCtrl.text);
    final rate = double.parse(_rateCtrl.text);
    final entry = widget.existing != null
        ? widget.existing!.copyWith(
            description: _descCtrl.text.trim(),
            hours: hours,
            hourlyRate: rate,
            memberName: _memberCtrl.text.trim(),
            date: _date,
          )
        : TimeEntry(
            id: const Uuid().v4(),
            projectId: widget.project.id,
            memberName: _memberCtrl.text.trim(),
            hours: hours,
            hourlyRate: rate,
            date: _date,
            description: _descCtrl.text.trim(),
          );
    widget.onSave(entry);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final sym =
        Fmt.currencySymbol(context.read<AppProvider>().profile.currency);
    final hours = double.tryParse(_hoursCtrl.text) ?? 0;
    final rate = double.tryParse(_rateCtrl.text) ?? 0;
    final preview = hours * rate;

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.existing == null ? 'Log Time' : 'Edit Entry',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                  // Live billing preview
                  if (preview > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$sym${Fmt.compact(preview)}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Date
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.divider),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 16, color: AppTheme.subtext(context)),
                      const SizedBox(width: 8),
                      Text(Fmt.date(_date),
                          style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.onCard(context))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Description
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'What did you work on? *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 14),

              // Team member
              TextFormField(
                controller: _memberCtrl,
                decoration: const InputDecoration(
                  labelText: 'Team member name *',
                  hintText: 'e.g. John / Sarah',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),

              // Hours + rate side by side
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _hoursCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'))
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Hours *',
                        hintText: 'e.g. 2.5',
                        border: OutlineInputBorder(),
                        isDense: true,
                        suffixText: 'hr',
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final d = double.tryParse(v);
                        if (d == null || d <= 0) return 'Enter hours > 0';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _rateCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'))
                      ],
                      decoration: InputDecoration(
                        labelText: 'Rate *',
                        hintText: '1000',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        prefixText: sym,
                        suffixText: '/hr',
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (double.tryParse(v) == null) return 'Enter a number';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    widget.existing == null ? 'Save Entry' : 'Update Entry',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ProjectAvatar extends StatelessWidget {
  final Project project;
  final double size;
  const _ProjectAvatar({required this.project, this.size = 40});

  static const _colors = [
    Color(0xFF2563EB), Color(0xFF7C3AED), Color(0xFF059669),
    Color(0xFFD97706), Color(0xFFEF4444), Color(0xFF0891B2),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[project.id.codeUnitAt(0) % _colors.length];
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          project.name.isNotEmpty ? project.name[0].toUpperCase() : 'P',
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  const _SummaryChip(
      {required this.icon,
      required this.label,
      required this.sub,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: -0.3)),
              Text(sub,
                  style: TextStyle(
                      fontSize: 10,
                      color: color.withValues(alpha: 0.7))),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppTheme.subtext(context)),
        ),
      ),
    );
  }
}

class _EmptyProjectPrompt extends StatelessWidget {
  final VoidCallback onNew;
  const _EmptyProjectPrompt({required this.onNew});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined,
              size: 48, color: AppTheme.subtext(context)),
          const SizedBox(height: 16),
          Text('No projects yet',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onCard(context))),
          const SizedBox(height: 6),
          Text(
            'Create a project to start\ntracking billable hours.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: AppTheme.subtext(context), height: 1.5),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onNew,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Project'),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmtHours(double hours) {
  if (hours == 0) return '0h';
  final h = hours.floor();
  final m = ((hours - h) * 60).round();
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

String _shortDay(DateTime d) {
  const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  return days[d.weekday - 1];
}
