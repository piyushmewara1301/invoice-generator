import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/business_profile.dart';
import '../models/client.dart';
import '../providers/app_provider.dart';
import '../services/template_service.dart';
import '../utils/app_theme.dart';
import '../utils/share_service.dart';
import '../widgets/feature_guide_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BulkOfferScreen
// ─────────────────────────────────────────────────────────────────────────────
// Lets the user:
//  1. Compose a promotional message (with {client_name}, {business_name} etc.)
//  2. Select one or more clients from the directory
//  3. Send via WhatsApp (sequential) or Email (batch in one composer)
// ─────────────────────────────────────────────────────────────────────────────

enum _Channel { whatsapp, email }

class BulkOfferScreen extends StatefulWidget {
  const BulkOfferScreen({super.key});

  @override
  State<BulkOfferScreen> createState() => _BulkOfferScreenState();
}

class _BulkOfferScreenState extends State<BulkOfferScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // ── Compose state ─────────────────────────────────────────────────────────
  final _waCtrl      = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _emailCtrl   = TextEditingController();
  bool _previewMode  = false;
  bool _templatesLoaded = false;

  // ── Recipients state ──────────────────────────────────────────────────────
  final Set<String> _selectedIds = {};
  String _search = '';
  _Channel _channel = _Channel.whatsapp;

  // ── Send state ────────────────────────────────────────────────────────────
  bool _sending = false;
  int  _whatsappIndex = 0;       // which client we are currently opening WA for
  final Map<String, _SendStatus> _statusMap = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadTemplates();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showFeatureGuide(context, AppGuides.bulkOffer);
    });
  }

  Future<void> _loadTemplates() async {
    final wa      = await TemplateService.getOfferWhatsApp();
    final subj    = await TemplateService.getOfferEmailSubject();
    final emailBd = await TemplateService.getOfferEmailBody();
    if (!mounted) return;
    setState(() {
      _waCtrl.text      = wa;
      _subjectCtrl.text = subj;
      _emailCtrl.text   = emailBd;
      _templatesLoaded  = true;
    });
  }

  Future<void> _saveTemplates() async {
    await TemplateService.saveOfferWhatsApp(_waCtrl.text.trim());
    await TemplateService.saveOfferEmailSubject(_subjectCtrl.text.trim());
    await TemplateService.saveOfferEmailBody(_emailCtrl.text.trim());
  }

  @override
  void dispose() {
    _tabs.dispose();
    _waCtrl.dispose();
    _subjectCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  BusinessProfile get _profile => context.read<AppProvider>().profile;

  List<Client> _filtered(List<Client> all) {
    final q = _search.toLowerCase();
    var list = q.isEmpty
        ? all
        : all.where((c) =>
            c.displayName.toLowerCase().contains(q) ||
            c.phone.toLowerCase().contains(q) ||
            c.email.toLowerCase().contains(q)).toList();

    // Only show clients that have the required contact info for the channel.
    if (_channel == _Channel.whatsapp) {
      list = list.where((c) => c.phone.isNotEmpty).toList();
    } else {
      list = list.where((c) => c.email.isNotEmpty).toList();
    }
    return list;
  }

  List<Client> get _selectedClients {
    final all = context.read<AppProvider>().clients;
    return all.where((c) => _selectedIds.contains(c.id)).toList();
  }

  String _filledWa(Client c) => TemplateService.fillOffer(
        _waCtrl.text,
        client: c,
        profile: _profile,
      );

  String _filledSubject(Client c) => TemplateService.fillOffer(
        _subjectCtrl.text,
        client: c,
        profile: _profile,
      );

  String _filledEmail(Client c) => TemplateService.fillOffer(
        _emailCtrl.text,
        client: c,
        profile: _profile,
      );

  // ── Send ──────────────────────────────────────────────────────────────────

  Future<void> _send() async {
    if (_selectedIds.isEmpty) {
      _snack('Select at least one client first.');
      return;
    }
    await _saveTemplates();
    if (_channel == _Channel.whatsapp) {
      await _sendWhatsApp();
    } else {
      await _sendEmail();
    }
  }

  /// Opens WhatsApp for each selected client one-by-one.
  /// After each launch the user is prompted to tap "Next" before the app
  /// proceeds to the next recipient — this is the only reliable mobile pattern
  /// since WhatsApp has no batch API.
  Future<void> _sendWhatsApp() async {
    final clients = _selectedClients.where((c) => c.phone.isNotEmpty).toList();
    if (clients.isEmpty) {
      _snack('None of the selected clients have a phone number.');
      return;
    }

    setState(() {
      _sending = true;
      _whatsappIndex = 0;
      for (final c in clients) {
        _statusMap[c.id] = _SendStatus.pending;
      }
    });

    for (var i = 0; i < clients.length; i++) {
      if (!mounted) break;
      setState(() => _whatsappIndex = i);
      final client = clients[i];
      final ok = await ShareService.sendWhatsAppOffer(
        client.phone,
        _filledWa(client),
      );
      if (!mounted) break;
      setState(() => _statusMap[client.id] =
          ok ? _SendStatus.opened : _SendStatus.failed);

      // After each WA launch, wait for user to return and confirm before next.
      if (ok && i < clients.length - 1) {
        final proceed = await _showNextPrompt(client, i + 1, clients.length);
        if (!proceed) break;
      }
    }

    if (mounted) setState(() => _sending = false);
    _showSummary();
  }

  /// Opens a single email composer with all selected client emails as recipients.
  Future<void> _sendEmail() async {
    final clients = _selectedClients.where((c) => c.email.isNotEmpty).toList();
    if (clients.isEmpty) {
      _snack('None of the selected clients have an email address.');
      return;
    }

    setState(() {
      _sending = true;
      for (final c in clients) {
        _statusMap[c.id] = _SendStatus.pending;
      }
    });

    // For personalised subject/body we send one email per client.
    // (opening composer once per client is the only way to personalise
    //  {client_name} in the body on mobile).
    for (final client in clients) {
      if (!mounted) break;
      try {
        await ShareService.sendEmailOffer(
          recipients: [client.email],
          subject: _filledSubject(client),
          body: _filledEmail(client),
        );
        if (mounted) setState(() => _statusMap[client.id] = _SendStatus.opened);
      } catch (_) {
        if (mounted) setState(() => _statusMap[client.id] = _SendStatus.failed);
      }
      // If personalising per-client, brief pause between opens so the system
      // doesn't collapse them into a single compose window.
      if (clients.length > 1 && clients.indexOf(client) < clients.length - 1) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }

    if (mounted) setState(() => _sending = false);
    _showSummary();
  }

  Future<bool> _showNextPrompt(Client sent, int nextIdx, int total) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('WhatsApp Opened'),
            content: Text(
              'WhatsApp opened for ${sent.displayName}.\n'
              'Send the message there, then tap Continue to '
              'open WhatsApp for client $nextIdx of $total.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Stop'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSummary() {
    if (!mounted) return;
    final opened = _statusMap.values.where((s) => s == _SendStatus.opened).length;
    final failed = _statusMap.values.where((s) => s == _SendStatus.failed).length;
    final channel = _channel == _Channel.whatsapp ? 'WhatsApp' : 'email';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? '$channel opened for $opened client${opened == 1 ? '' : 's'}.'
              : '$channel opened for $opened, failed for $failed.',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final clients = context.watch<AppProvider>().clients;
    final filtered = _filtered(clients);
    final selectedCount = _selectedClients
        .where((c) => _channel == _Channel.whatsapp
            ? c.phone.isNotEmpty
            : c.email.isNotEmpty)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Offer Message'),
        actions: [
          if (_sending)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: selectedCount == 0 ? null : _send,
              icon: Icon(
                _channel == _Channel.whatsapp
                    ? Icons.chat_bubble_outline
                    : Icons.email_outlined,
                size: 18,
              ),
              label: Text(
                selectedCount == 0
                    ? 'Send'
                    : 'Send to $selectedCount',
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Compose', icon: Icon(Icons.edit_outlined, size: 18)),
            Tab(text: 'Recipients', icon: Icon(Icons.people_outline, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ComposeTab(
            waCtrl: _waCtrl,
            subjectCtrl: _subjectCtrl,
            emailCtrl: _emailCtrl,
            channel: _channel,
            onChannelChanged: (c) => setState(() {
              _channel = c;
              _selectedIds.clear();
              _statusMap.clear();
            }),
            previewMode: _previewMode,
            onTogglePreview: () => setState(() => _previewMode = !_previewMode),
            previewClient: _selectedClients.firstOrNull ??
                (filtered.isNotEmpty ? filtered.first : null),
            profile: _profile,
            loaded: _templatesLoaded,
          ),
          _RecipientsTab(
            clients: filtered,
            allClients: clients,
            selectedIds: _selectedIds,
            search: _search,
            channel: _channel,
            statusMap: _statusMap,
            currentIndex: _whatsappIndex,
            sending: _sending,
            onSearchChanged: (v) => setState(() => _search = v),
            onToggle: (id) => setState(() {
              if (_selectedIds.contains(id)) {
                _selectedIds.remove(id);
              } else {
                _selectedIds.add(id);
              }
            }),
            onSelectAll: () => setState(() {
              if (_selectedIds.length == filtered.length) {
                _selectedIds.removeAll(filtered.map((c) => c.id));
              } else {
                _selectedIds.addAll(filtered.map((c) => c.id));
              }
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compose tab
// ─────────────────────────────────────────────────────────────────────────────

class _ComposeTab extends StatelessWidget {
  final TextEditingController waCtrl;
  final TextEditingController subjectCtrl;
  final TextEditingController emailCtrl;
  final _Channel channel;
  final ValueChanged<_Channel> onChannelChanged;
  final bool previewMode;
  final VoidCallback onTogglePreview;
  final Client? previewClient;
  final BusinessProfile profile;
  final bool loaded;

  const _ComposeTab({
    required this.waCtrl,
    required this.subjectCtrl,
    required this.emailCtrl,
    required this.channel,
    required this.onChannelChanged,
    required this.previewMode,
    required this.onTogglePreview,
    required this.previewClient,
    required this.profile,
    required this.loaded,
  });

  String _preview(String raw, Client? c) {
    if (c == null) return TemplateService.fillPreview(raw);
    return TemplateService.fillOffer(raw, client: c, profile: profile);
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Channel picker ────────────────────────────────────────────────
        _SectionLabel('Send via'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ChannelChip(
                label: 'WhatsApp',
                icon: Icons.chat_bubble_outline,
                color: const Color(0xFF25D366),
                selected: channel == _Channel.whatsapp,
                onTap: () => onChannelChanged(_Channel.whatsapp),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ChannelChip(
                label: 'Email',
                icon: Icons.email_outlined,
                color: const Color(0xFF2563EB),
                selected: channel == _Channel.email,
                onTap: () => onChannelChanged(_Channel.email),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Message fields ─────────────────────────────────────────────────
        if (channel == _Channel.email) ...[
          _SectionLabel('Email Subject'),
          const SizedBox(height: 8),
          previewMode
              ? _PreviewBox(_preview(subjectCtrl.text, previewClient))
              : TextFormField(
                  controller: subjectCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Special Offer from {business_name}',
                    border: OutlineInputBorder(),
                  ),
                ),
          const SizedBox(height: 16),
        ],

        _SectionLabel(channel == _Channel.whatsapp
            ? 'WhatsApp Message'
            : 'Email Body'),
        const SizedBox(height: 8),
        previewMode
            ? _PreviewBox(_preview(
                channel == _Channel.whatsapp ? waCtrl.text : emailCtrl.text,
                previewClient))
            : TextFormField(
                controller:
                    channel == _Channel.whatsapp ? waCtrl : emailCtrl,
                maxLines: 10,
                decoration: const InputDecoration(
                  hintText: 'Type your offer message…',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),

        const SizedBox(height: 12),

        // ── Preview toggle ────────────────────────────────────────────────
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: onTogglePreview,
              icon: Icon(
                previewMode ? Icons.edit_outlined : Icons.visibility_outlined,
                size: 16,
              ),
              label: Text(previewMode ? 'Edit' : 'Preview'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                textStyle: const TextStyle(fontSize: 12),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            if (previewMode && previewClient != null) ...[
              const SizedBox(width: 8),
              Text(
                'Preview for ${previewClient!.displayName}',
                style: TextStyle(
                    fontSize: 11, color: AppTheme.subtext(context)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),

        // ── Variable chips ────────────────────────────────────────────────
        _SectionLabel('Insert variable'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TemplateService.offerVariables.map((v) {
            final (placeholder, label) = v;
            return ActionChip(
              label: Text(label,
                  style: const TextStyle(fontSize: 12)),
              avatar: const Icon(Icons.add, size: 14),
              onPressed: () {
                final ctrl = channel == _Channel.whatsapp
                    ? waCtrl
                    : emailCtrl;
                final sel = ctrl.selection;
                final txt = ctrl.text;
                final pos =
                    sel.isValid ? sel.baseOffset : txt.length;
                ctrl.text =
                    txt.substring(0, pos) + placeholder + txt.substring(pos);
                ctrl.selection = TextSelection.collapsed(
                    offset: pos + placeholder.length);
              },
            );
          }).toList(),
        ),

        if (!kIsWeb) ...[
          const SizedBox(height: 16),
          _InfoBox(
            channel == _Channel.whatsapp
                ? 'WhatsApp messages open one at a time — you tap Send in WhatsApp for each client, then come back.'
                : 'A separate email composer will open for each client so every message is personalised.',
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recipients tab
// ─────────────────────────────────────────────────────────────────────────────

class _RecipientsTab extends StatelessWidget {
  final List<Client> clients;
  final List<Client> allClients;
  final Set<String> selectedIds;
  final String search;
  final _Channel channel;
  final Map<String, _SendStatus> statusMap;
  final int currentIndex;
  final bool sending;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onToggle;
  final VoidCallback onSelectAll;

  const _RecipientsTab({
    required this.clients,
    required this.allClients,
    required this.selectedIds,
    required this.search,
    required this.channel,
    required this.statusMap,
    required this.currentIndex,
    required this.sending,
    required this.onSearchChanged,
    required this.onToggle,
    required this.onSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    final allSelected = clients.isNotEmpty &&
        clients.every((c) => selectedIds.contains(c.id));
    final contactField = channel == _Channel.whatsapp ? 'phone' : 'email';
    final selectedCount =
        allClients.where((c) => selectedIds.contains(c.id)).length;

    return Column(
      children: [
        // ── Search + select-all bar ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search clients…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0),
                  isDense: true,
                  filled: true,
                  fillColor: AppTheme.inputFill(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: AppTheme.outline(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: AppTheme.outline(context)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onSelectAll,
                    icon: Icon(
                      allSelected
                          ? Icons.deselect
                          : Icons.select_all,
                      size: 16,
                    ),
                    label: Text(allSelected ? 'Deselect All' : 'Select All'),
                    style: TextButton.styleFrom(
                      textStyle: const TextStyle(fontSize: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const Spacer(),
                  if (selectedCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$selectedCount selected',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        if (clients.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline,
                      size: 48,
                      color: AppTheme.subtext(context)
                          .withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Text(
                    'No clients with a $contactField',
                    style: TextStyle(
                        color: AppTheme.subtext(context)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add a $contactField to clients to send them messages.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.subtext(context)
                            .withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              itemCount: clients.length,
              itemBuilder: (_, i) {
                final c = clients[i];
                final selected = selectedIds.contains(c.id);
                final status = statusMap[c.id];
                final isCurrent =
                    sending && statusMap[c.id] == _SendStatus.pending &&
                        clients.indexOf(c) == currentIndex;

                return _ClientTile(
                  client: c,
                  channel: channel,
                  selected: selected,
                  status: status,
                  isCurrent: isCurrent,
                  onTap: sending ? null : () => onToggle(c.id),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ClientTile extends StatelessWidget {
  final Client client;
  final _Channel channel;
  final bool selected;
  final _SendStatus? status;
  final bool isCurrent;
  final VoidCallback? onTap;

  const _ClientTile({
    required this.client,
    required this.channel,
    required this.selected,
    this.status,
    required this.isCurrent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final contact = channel == _Channel.whatsapp
        ? client.phone
        : client.email;
    final contactIcon = channel == _Channel.whatsapp
        ? Icons.phone_outlined
        : Icons.email_outlined;

    Widget? trailing;
    if (status == _SendStatus.opened) {
      trailing = const Icon(Icons.check_circle_outline,
          color: Color(0xFF16A34A), size: 20);
    } else if (status == _SendStatus.failed) {
      trailing = const Icon(Icons.error_outline,
          color: Color(0xFFDC2626), size: 20);
    } else if (isCurrent) {
      trailing = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else {
      trailing = Checkbox(
        value: selected,
        onChanged: onTap == null ? null : (_) => onTap!(),
        activeColor: AppTheme.primary,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.05)
              : AppTheme.card(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.3)
                : AppTheme.outline(context),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
              child: Text(
                client.displayName.isNotEmpty
                    ? client.displayName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppTheme.onCard(context),
                    ),
                  ),
                  if (contact.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(contactIcon,
                            size: 12,
                            color: AppTheme.subtext(context)),
                        const SizedBox(width: 4),
                        Text(
                          contact,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.subtext(context)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ChannelChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.1)
              : AppTheme.card(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : AppTheme.outline(context),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? color : AppTheme.subtext(context),
                size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : AppTheme.onCard(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewBox extends StatelessWidget {
  final String text;
  const _PreviewBox(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 13, height: 1.55)),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.onCard(context),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String message;
  const _InfoBox(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              size: 16, color: Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF1E40AF)),
            ),
          ),
        ],
      ),
    );
  }
}

enum _SendStatus { pending, opened, failed }
