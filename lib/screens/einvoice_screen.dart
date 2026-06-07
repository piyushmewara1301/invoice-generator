import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/invoice.dart';
import '../providers/app_provider.dart';
import '../services/einvoice_service.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

class EInvoiceScreen extends StatelessWidget {
  const EInvoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final eligible = provider.invoices.where((i) =>
        !i.isQuotation &&
        !i.isCreditNote &&
        !i.isDeliveryChallan &&
        i.status != InvoiceStatus.cancelled &&
        provider.profile.isGstRegistered).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final pending   = eligible.where((i) => i.irn == null).toList();
    final generated = eligible.where((i) => i.irn != null).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.bg(context),
        appBar: AppBar(
          title: const Text('E-Invoice (IRP)'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending IRN'),
              Tab(text: 'Generated'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _InvoiceList(
              invoices: pending,
              emptyMessage: 'All eligible invoices have IRNs',
              emptyIcon: Icons.check_circle_outline,
            ),
            _InvoiceList(
              invoices: generated,
              emptyMessage: 'No IRNs generated yet',
              emptyIcon: Icons.receipt_long_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Invoice list tab ──────────────────────────────────────────────────────────

class _InvoiceList extends StatelessWidget {
  final List<Invoice> invoices;
  final String emptyMessage;
  final IconData emptyIcon;
  const _InvoiceList(
      {required this.invoices,
      required this.emptyMessage,
      required this.emptyIcon});

  @override
  Widget build(BuildContext context) {
    final sym = Fmt.currencySymbol(
        context.read<AppProvider>().profile.currency);
    if (invoices.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(emptyIcon,
              size: 64,
              color: AppTheme.subtext(context).withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(emptyMessage,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onCard(context))),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: invoices.length,
      itemBuilder: (_, i) => _InvoiceTile(invoice: invoices[i], sym: sym),
    );
  }
}

// ── Invoice tile ──────────────────────────────────────────────────────────────

class _InvoiceTile extends StatelessWidget {
  final Invoice invoice;
  final String sym;
  const _InvoiceTile({required this.invoice, required this.sym});

  @override
  Widget build(BuildContext context) {
    final hasIrn = invoice.irn != null;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EInvoiceDetailScreen(invoice: invoice),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.outline(context)),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (hasIrn
                      ? const Color(0xFF059669)
                      : const Color(0xFF1D4ED8))
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              hasIrn ? Icons.verified_outlined : Icons.receipt_outlined,
              size: 20,
              color: hasIrn
                  ? const Color(0xFF059669)
                  : const Color(0xFF1D4ED8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('#${invoice.invoiceNumber}',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onCard(context))),
              const SizedBox(height: 2),
              Text(
                invoice.client?.displayName ?? 'No customer',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.subtext(context)),
              ),
              if (hasIrn) ...[
                const SizedBox(height: 4),
                Text(
                  'IRN: ${invoice.irn!.substring(0, 20)}…',
                  style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF059669),
                      fontWeight: FontWeight.w600),
                ),
              ],
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$sym${Fmt.compact(invoice.grandTotal)}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onCard(context))),
            const SizedBox(height: 4),
            Text(Fmt.shortDate(invoice.invoiceDate),
                style: TextStyle(
                    fontSize: 11, color: AppTheme.subtext(context))),
          ]),
        ]),
      ),
    );
  }
}

// ── Detail / generate screen ──────────────────────────────────────────────────

class EInvoiceDetailScreen extends StatefulWidget {
  final Invoice invoice;
  const EInvoiceDetailScreen({super.key, required this.invoice});

  @override
  State<EInvoiceDetailScreen> createState() => _EInvoiceDetailScreenState();
}

class _EInvoiceDetailScreenState extends State<EInvoiceDetailScreen> {
  final _userCtrl   = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _cidCtrl    = TextEditingController();
  final _csecCtrl   = TextEditingController();
  bool  _obscurePass = true;
  bool  _loading    = false;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _cidCtrl.dispose();
    _csecCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final provider = context.read<AppProvider>();
    final profile  = provider.profile;

    if (!profile.isGstRegistered || (profile.gstin?.isEmpty ?? true)) {
      _setError('Set up your GSTIN in Business Profile first.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final svc = EInvoiceService(
        gstin:        profile.gstin!,
        username:     _userCtrl.text.trim(),
        password:     _passCtrl.text,
        clientId:     _cidCtrl.text.trim(),
        clientSecret: _csecCtrl.text.trim(),
      );
      final resp = await svc.generateIRN(widget.invoice, profile);
      final data = resp['Result'] as Map<String, dynamic>? ?? {};

      widget.invoice
        ..irn          = data['Irn'] as String?
        ..ackNo        = data['AckNo']?.toString()
        ..ackDt        = data['AckDt'] != null
            ? DateTime.tryParse(data['AckDt'] as String)
            : null
        ..signedQRCode = data['SignedQRCode'] as String?;

      await provider.saveInvoice(widget.invoice);
      if (mounted) setState(() {});
    } on EInvoiceException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setError(String msg) {
    if (mounted) setState(() { _error = msg; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final inv    = widget.invoice;
    final hasIrn = inv.irn != null;
    final sym    = Fmt.currencySymbol(
        context.read<AppProvider>().profile.currency);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: Text('E-Invoice #${inv.invoiceNumber}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Status banner ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasIrn
                    ? [const Color(0xFF059669), const Color(0xFF047857)]
                    : [const Color(0xFF1D4ED8), const Color(0xFF1E40AF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Icon(
                hasIrn ? Icons.verified_rounded : Icons.pending_outlined,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                    hasIrn ? 'IRN Generated' : 'IRN Pending',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasIrn
                        ? 'Invoice registered on IRP portal'
                        : 'Submit to IRP to generate IRN & QR',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white70),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Invoice summary ───────────────────────────────────────────────
          _InfoCard(title: 'Invoice Details', children: [
            _Row('Invoice #', inv.invoiceNumber),
            _Row('Date', Fmt.shortDate(inv.invoiceDate)),
            _Row('Customer', inv.client?.displayName ?? '—'),
            _Row('Grand Total', '$sym${Fmt.compact(inv.grandTotal)}'),
          ]),
          const SizedBox(height: 16),

          // ── IRN details (if generated) ────────────────────────────────────
          if (hasIrn) ...[
            _InfoCard(title: 'IRN Details', children: [
              _Row('IRN', inv.irn!, copyable: true),
              if (inv.ackNo != null) _Row('Ack No.', inv.ackNo!),
              if (inv.ackDt != null)
                _Row('Ack Date', Fmt.shortDate(inv.ackDt!)),
            ]),
            const SizedBox(height: 16),

            // QR code
            if (inv.signedQRCode != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.card(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.outline(context)),
                ),
                child: Column(children: [
                  Text('Signed QR Code',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onCard(context))),
                  const SizedBox(height: 12),
                  Center(
                    child: QrImageView(
                      data: inv.signedQRCode!,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Print this QR on your invoice as required by GST law',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.subtext(context)),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
            ],
          ] else ...[
            // ── Credential form ───────────────────────────────────────────
            _InfoCard(
              title: 'IRP Credentials',
              subtitle: 'Enter your NIC / IRP API credentials to generate IRN',
              children: [
                _Field(label: 'Username', ctrl: _userCtrl),
                const SizedBox(height: 10),
                _Field(
                  label: 'Password',
                  ctrl: _passCtrl,
                  obscure: _obscurePass,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePass
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
                const SizedBox(height: 10),
                _Field(label: 'Client ID', ctrl: _cidCtrl),
                const SizedBox(height: 10),
                _Field(label: 'Client Secret', ctrl: _csecCtrl),
              ],
            ),
            const SizedBox(height: 8),
            // Sandbox note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    size: 16, color: Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Currently using IRP Sandbox. Switch to production in '
                    'einvoice_service.dart before going live.',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF92400E)),
                  ),
                ),
              ]),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_error!,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.error)),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _generate,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_outlined),
                label: Text(_loading ? 'Submitting…' : 'Generate IRN'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF1D4ED8),
                ),
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Small widgets ─────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  const _InfoCard({required this.title, this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.outline(context)),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onCard(context))),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style: TextStyle(
                    fontSize: 11, color: AppTheme.subtext(context))),
          ],
          const SizedBox(height: 12),
          ...children,
        ]),
      );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;
  const _Row(this.label, this.value, {this.copyable = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12, color: AppTheme.subtext(context))),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onCard(context))),
          ),
          if (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 1)),
                );
              },
              child: Icon(Icons.copy_outlined,
                  size: 14, color: AppTheme.subtext(context)),
            ),
        ]),
      );
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool obscure;
  final Widget? suffixIcon;
  const _Field(
      {required this.label,
      required this.ctrl,
      this.obscure = false,
      this.suffixIcon});

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        obscureText: obscure,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      );
}
