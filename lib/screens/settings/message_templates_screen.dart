import 'package:flutter/material.dart';
import '../../services/template_service.dart';
import '../../utils/app_theme.dart';

class MessageTemplatesScreen extends StatefulWidget {
  const MessageTemplatesScreen({super.key});

  @override
  State<MessageTemplatesScreen> createState() => _MessageTemplatesScreenState();
}

class _MessageTemplatesScreenState extends State<MessageTemplatesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _waCtrl = TextEditingController();
  final _subCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  final _waFocus = FocusNode();
  final _subFocus = FocusNode();
  final _bodyFocus = FocusNode();

  // Tracks which email field (subject vs body) was last focused.
  late TextEditingController _emailActive;

  bool _loading = true;
  bool _dirty = false;
  bool _waPreview = false;
  bool _emailPreview = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _emailActive = _bodyCtrl;

    _subFocus.addListener(() {
      if (_subFocus.hasFocus) setState(() => _emailActive = _subCtrl);
    });
    _bodyFocus.addListener(() {
      if (_bodyFocus.hasFocus) setState(() => _emailActive = _bodyCtrl);
    });

    _waCtrl.addListener(_markDirty);
    _subCtrl.addListener(_markDirty);
    _bodyCtrl.addListener(_markDirty);

    _load();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _load() async {
    final wa = await TemplateService.getWhatsApp();
    final sub = await TemplateService.getEmailSubject();
    final body = await TemplateService.getEmailBody();
    if (!mounted) return;
    // Temporarily remove listeners so loading doesn't mark dirty.
    _waCtrl.removeListener(_markDirty);
    _subCtrl.removeListener(_markDirty);
    _bodyCtrl.removeListener(_markDirty);
    _waCtrl.text = wa;
    _subCtrl.text = sub;
    _bodyCtrl.text = body;
    _waCtrl.addListener(_markDirty);
    _subCtrl.addListener(_markDirty);
    _bodyCtrl.addListener(_markDirty);
    setState(() {
      _loading = false;
      _dirty = false;
    });
  }

  Future<void> _save() async {
    await TemplateService.saveWhatsApp(_waCtrl.text);
    await TemplateService.saveEmailSubject(_subCtrl.text);
    await TemplateService.saveEmailBody(_bodyCtrl.text);
    if (!mounted) return;
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Templates saved'),
          duration: Duration(seconds: 2)),
    );
  }

  Future<void> _resetCurrentTab() async {
    final isWa = _tab.index == 0;
    final label = isWa ? 'WhatsApp' : 'Email';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Reset $label template?'),
        content: const Text(
            'This will restore the default message. Your custom changes will be lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Reset',
                  style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (isWa) {
      await TemplateService.resetWhatsApp();
      _waCtrl.text = TemplateService.defaultWhatsApp;
    } else {
      await TemplateService.resetEmail();
      _subCtrl.text = TemplateService.defaultEmailSubject;
      _bodyCtrl.text = TemplateService.defaultEmailBody;
    }
    setState(() => _dirty = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('$label template reset to default'),
            duration: const Duration(seconds: 2)),
      );
    }
  }

  void _insertVariable(TextEditingController ctrl, FocusNode focus, String ph) {
    final sel = ctrl.selection;
    final base = sel.baseOffset.clamp(0, ctrl.text.length);
    final ext = sel.extentOffset.clamp(0, ctrl.text.length);
    ctrl.value = TextEditingValue(
      text: ctrl.text.substring(0, base) + ph + ctrl.text.substring(ext),
      selection: TextSelection.collapsed(offset: base + ph.length),
    );
    focus.requestFocus();
  }

  @override
  void dispose() {
    _tab.dispose();
    _waCtrl.dispose();
    _subCtrl.dispose();
    _bodyCtrl.dispose();
    _waFocus.dispose();
    _subFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Templates'),
        actions: [
          TextButton(
            onPressed: _resetCurrentTab,
            child: const Text('Reset'),
          ),
          FilledButton(
            onPressed: _dirty ? _save : null,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Save'),
          ),
          const SizedBox(width: 12),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(
              icon: Icon(Icons.chat_bubble_outline, size: 18),
              text: 'WhatsApp',
            ),
            Tab(
              icon: Icon(Icons.email_outlined, size: 18),
              text: 'Email',
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [
                _waTab(),
                _emailTab(),
              ],
            ),
    );
  }

  // ── WhatsApp tab ──────────────────────────────────────────────────────────

  Widget _waTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _helpBanner(
          'Write your WhatsApp message below. Tap a variable chip to insert '
          'it — the app will automatically replace it with the real value '
          'when you send an invoice.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _waCtrl,
          focusNode: _waFocus,
          maxLines: null,
          minLines: 14,
          keyboardType: TextInputType.multiline,
          style: const TextStyle(fontSize: 14, height: 1.55),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 16),
        _variableSection(
          onChipTap: (ph) => _insertVariable(_waCtrl, _waFocus, ph),
        ),
        const SizedBox(height: 16),
        _previewSection(
          show: _waPreview,
          onToggle: () => setState(() => _waPreview = !_waPreview),
          template: _waCtrl.text,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Email tab ─────────────────────────────────────────────────────────────

  Widget _emailTab() {
    final subActive = _emailActive == _subCtrl;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _helpBanner(
          'Customise the subject and body of the email. '
          'Tap on a field first, then tap a variable to insert it there.',
        ),
        const SizedBox(height: 12),

        // Subject
        _fieldLabel('Subject'),
        const SizedBox(height: 6),
        TextField(
          controller: _subCtrl,
          focusNode: _subFocus,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            suffixIcon: subActive
                ? const Tooltip(
                    message: 'Variables will be inserted here',
                    child: Icon(Icons.edit, size: 16, color: AppTheme.primary),
                  )
                : null,
          ),
        ),

        const SizedBox(height: 16),

        // Body
        Row(
          children: [
            _fieldLabel('Body'),
            const Spacer(),
            if (!subActive)
              const Chip(
                label: Text('Variables insert here',
                    style: TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                avatar: Icon(Icons.edit, size: 14),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _bodyCtrl,
          focusNode: _bodyFocus,
          maxLines: null,
          minLines: 12,
          keyboardType: TextInputType.multiline,
          style: const TextStyle(fontSize: 14, height: 1.55),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.all(14),
            suffixIcon: !subActive
                ? const Tooltip(
                    message: 'Variables will be inserted here',
                    child: Icon(Icons.edit, size: 16, color: AppTheme.primary),
                  )
                : null,
          ),
        ),

        const SizedBox(height: 16),
        _variableSection(
          onChipTap: (ph) =>
              _insertVariable(_emailActive, _emailActive == _subCtrl ? _subFocus : _bodyFocus, ph),
        ),
        const SizedBox(height: 16),
        _previewSection(
          show: _emailPreview,
          onToggle: () => setState(() => _emailPreview = !_emailPreview),
          subjectTemplate: _subCtrl.text,
          template: _bodyCtrl.text,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────

  Widget _helpBanner(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline,
              size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.primary,
                    height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.4),
    );
  }

  Widget _variableSection({required void Function(String) onChipTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TAP TO INSERT',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: TemplateService.variables.map((v) {
            final (ph, label) = v;
            return ActionChip(
              label: Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500)),
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.add, size: 14),
              onPressed: () => onChipTap(ph),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _previewSection({
    required bool show,
    required VoidCallback onToggle,
    required String template,
    String? subjectTemplate,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 16,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  show ? 'Hide preview' : 'Preview with sample data',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary),
                ),
              ],
            ),
          ),
        ),
        if (show) ...[
          const SizedBox(height: 10),
          if (subjectTemplate != null) ...[
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: RichText(
                text: TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Subject: ',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569)),
                    ),
                    TextSpan(
                      text: TemplateService.fillPreview(subjectTemplate),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              TemplateService.fillPreview(template),
              style: const TextStyle(
                  fontSize: 13,
                  height: 1.65,
                  color: Color(0xFF334155)),
            ),
          ),
        ],
      ],
    );
  }
}
