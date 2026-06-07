import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/invoice.dart';
import '../models/business_profile.dart';
import '../services/template_service.dart';
import 'formatters.dart';
import 'pdf_generator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ShareService — generates PDF and routes to WhatsApp / Email
// ─────────────────────────────────────────────────────────────────────────────

class ShareService {
  static Future<String> _savePdfTemp(
      Invoice invoice, BusinessProfile profile) async {
    try {
      final bytes = await PdfGenerator.generateInvoicePdf(invoice, profile);
      final dir = await getTemporaryDirectory();
      final safe = invoice.invoiceNumber.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
      final file = File('${dir.path}/Invoice_$safe.pdf');
      await file.writeAsBytes(bytes);
      
      // Verify file was created
      if (!await file.exists()) {
        throw Exception('Failed to save PDF file');
      }
      return file.path;
    } catch (e) {
      print('Error saving PDF to temp: $e');
      rethrow;
    }
  }

  /// Opens the native print/save dialog.
  static Future<void> downloadPdf(
      Invoice invoice, BusinessProfile profile) async {
    final bytes = await PdfGenerator.generateInvoicePdf(invoice, profile);
    await Printing.layoutPdf(
      onLayout: (_) => bytes,
      name: 'Invoice_${invoice.invoiceNumber}',
    );
  }

  /// Opens WhatsApp with a pre-filled text message (no attachment).
  /// On iOS tries the `whatsapp://` deep link first (direct, no Safari hop),
  /// then falls back to the universal `https://wa.me/` link.
  static Future<void> shareViaWhatsApp(
      Invoice invoice, BusinessProfile profile) async {
    try {
      final success = await openWhatsAppDirectly(invoice, profile);
      if (!success) {
        throw Exception(
            'Could not open WhatsApp. '
            'Please ensure the phone number is correct and WhatsApp is installed.');
      }
    } catch (e) {
      print('Error in shareViaWhatsApp: $e');
      rethrow;
    }
  }

  /// Opens WhatsApp with a pre-filled text message.
  /// Tries the native `whatsapp://send` scheme first (no Safari hop on iOS),
  /// then falls back to `https://wa.me/` for web and cases where WhatsApp
  /// is not installed.
  static Future<bool> openWhatsAppDirectly(
      Invoice invoice, BusinessProfile profile) async {
    try {
      final phone = _cleanPhone(invoice.client?.phone ?? '');
      if (phone.isEmpty) {
        throw Exception(
            'Client phone number is required. '
            'Please add a phone number to the client.');
      }

      final tpl = await TemplateService.getWhatsApp();
      final message =
          TemplateService.fill(tpl, invoice: invoice, profile: profile);
      final encodedMsg = Uri.encodeComponent(message);

      // 1️⃣  Native deep link — works on iOS without opening Safari first.
      //    Requires `whatsapp` in LSApplicationQueriesSchemes (Info.plist).
      if (!kIsWeb) {
        final nativeUri =
            Uri.parse('whatsapp://send?phone=$phone&text=$encodedMsg');
        if (await canLaunchUrl(nativeUri)) {
          return launchUrl(nativeUri, mode: LaunchMode.externalApplication);
        }
      }

      // 2️⃣  Universal link fallback — works on web and when WhatsApp handles
      //    the wa.me universal link via iOS.
      final webUri =
          Uri.parse('https://wa.me/$phone?text=$encodedMsg');
      if (await canLaunchUrl(webUri)) {
        return launchUrl(webUri, mode: LaunchMode.externalApplication);
      }

      throw Exception(
          'Could not open WhatsApp. Make sure WhatsApp is installed.');
    } catch (e) {
      print('Error in openWhatsAppDirectly: $e');
      return false;
    }
  }

  /// Shares the invoice PDF via the native share sheet (user picks the app).
  ///
  /// [sharePositionOrigin] **must** be supplied on iPad to anchor the
  /// UIActivityViewController popover.  On iPhone it is optional but prevents
  /// presentation issues when called from inside a modal bottom sheet.
  static Future<void> sharePdf(
    Invoice invoice,
    BusinessProfile profile, {
    Rect? sharePositionOrigin,
  }) async {
    try {
      final path = await _savePdfTemp(invoice, profile);
      await Share.shareXFiles(
        [XFile(path, mimeType: 'application/pdf')],
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      print('Error sharing PDF: $e');
      rethrow;
    }
  }

  /// Sends the invoice as an email with the PDF attached.
  ///
  /// Strategy (mobile):
  ///   1. Try `flutter_email_sender` → uses Apple Mail / MFMailComposeVC.
  ///   2. If Mail is not configured or the user cancels, fall back to the
  ///      native share sheet (they can pick Gmail, Outlook, etc.).
  ///
  /// [sharePositionOrigin] is forwarded to the share-sheet fallback so iOS
  /// can anchor the UIActivityViewController correctly.
  static Future<void> shareViaEmail(
    Invoice invoice,
    BusinessProfile profile, {
    Rect? sharePositionOrigin,
  }) async {
    try {
      final clientEmail = invoice.client?.email ?? '';
      if (clientEmail.isEmpty) {
        throw Exception(
            'Client email is required. '
            'Please add an email address to the client.');
      }

      final subjectTpl = await TemplateService.getEmailSubject();
      final bodyTpl    = await TemplateService.getEmailBody();
      final subject =
          TemplateService.fill(subjectTpl, invoice: invoice, profile: profile);
      final body =
          TemplateService.fill(bodyTpl, invoice: invoice, profile: profile);

      // ── Web: mailto deep link (no attachment — browser limitation) ──────
      if (kIsWeb) {
        final uri = Uri(
          scheme: 'mailto',
          path: clientEmail,
          queryParameters: {'subject': subject, 'body': body},
        );
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          throw Exception('Could not launch email client.');
        }
        return;
      }

      // ── Mobile: generate PDF then try email → share-sheet fallback ──────
      final path = await _savePdfTemp(invoice, profile);

      try {
        // flutter_email_sender uses MFMailComposeViewController on iOS.
        // Works when Apple Mail is configured; throws otherwise.
        await FlutterEmailSender.send(Email(
          subject: subject,
          body: body,
          recipients: [clientEmail],
          attachmentPaths: [path],
        ));
      } catch (emailError) {
        print('flutter_email_sender failed ($emailError) — '
            'opening native share sheet as fallback.');
        // Fallback: native iOS share sheet — user picks Gmail, Outlook, etc.
        // Passing sharePositionOrigin avoids UIActivityViewController crashes
        // on iPad and presentation failures from inside modal sheets.
        await Share.shareXFiles(
          [XFile(path, mimeType: 'application/pdf')],
          subject: subject,
          text: body,
          sharePositionOrigin: sharePositionOrigin,
        );
      }
    } catch (e) {
      print('Error in shareViaEmail: $e');
      rethrow;
    }
  }

  // ── Offer / bulk-message helpers (no Invoice required) ───────────────────

  /// Opens WhatsApp for [phone] with [message] pre-filled.
  /// Returns true if WhatsApp was launched successfully.
  static Future<bool> sendWhatsAppOffer(String phone, String message) async {
    final cleaned = _cleanPhone(phone);
    if (cleaned.isEmpty) return false;
    final encoded = Uri.encodeComponent(message);
    if (!kIsWeb) {
      final native = Uri.parse('whatsapp://send?phone=$cleaned&text=$encoded');
      if (await canLaunchUrl(native)) {
        return launchUrl(native, mode: LaunchMode.externalApplication);
      }
    }
    final web = Uri.parse('https://wa.me/$cleaned?text=$encoded');
    if (await canLaunchUrl(web)) {
      return launchUrl(web, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Opens the email client pre-filled with [recipients], [subject], and [body].
  /// On mobile tries `flutter_email_sender` first, then falls back to `mailto:`.
  /// No PDF attachment — suitable for plain-text offer messages.
  static Future<void> sendEmailOffer({
    required List<String> recipients,
    required String subject,
    required String body,
  }) async {
    if (recipients.isEmpty) return;

    if (kIsWeb) {
      final uri = Uri(
        scheme: 'mailto',
        path: recipients.join(','),
        queryParameters: {'subject': subject, 'body': body},
      );
      if (await canLaunchUrl(uri)) await launchUrl(uri);
      return;
    }

    try {
      await FlutterEmailSender.send(Email(
        subject: subject,
        body: body,
        recipients: recipients,
      ));
    } catch (_) {
      final uri = Uri(
        scheme: 'mailto',
        path: recipients.join(','),
        queryParameters: {'subject': subject, 'body': body},
      );
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    }
  }

  static String _cleanPhone(String raw) {
    String s = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (s.startsWith('+')) s = s.substring(1);
    if (s.length == 10) s = '91$s';
    return s;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ShareInvoiceSheet — bottom sheet shown after marking invoice as Sent
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showShareInvoiceSheet(
    BuildContext context, Invoice invoice, BusinessProfile profile) {
  final hasPhone = invoice.client?.phone.isNotEmpty == true;
  final hasEmail = invoice.client?.email.isNotEmpty == true;

  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ShareSheet(
      invoice: invoice,
      profile: profile,
      hasPhone: hasPhone,
      hasEmail: hasEmail,
    ),
  );
}

class _ShareSheet extends StatefulWidget {
  final Invoice invoice;
  final BusinessProfile profile;
  final bool hasPhone;
  final bool hasEmail;

  const _ShareSheet({
    required this.invoice,
    required this.profile,
    required this.hasPhone,
    required this.hasEmail,
  });

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  bool _loadingWa    = false;
  bool _loadingWaPdf = false;
  bool _loadingEmail = false;
  bool _loadingPdf   = false;

  bool get _busy => _loadingWa || _loadingWaPdf || _loadingEmail || _loadingPdf;

  /// Computes the bounding rect of this bottom sheet in global coordinates.
  /// Passed to [Share.shareXFiles] so iOS can anchor the
  /// UIActivityViewController popover (required on iPad, prevents
  /// presentation issues from inside modal sheets on iPhone).
  Rect? get _shareAnchor {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sym        = Fmt.currencySymbol(widget.invoice.currency);
    final amount     = Fmt.currency(widget.invoice.grandTotal, symbol: sym);
    final clientName = (widget.invoice.client?.companyName?.isNotEmpty == true
            ? widget.invoice.client!.companyName!
            : widget.invoice.client?.name) ??
        '';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Invoice summary row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle_outline,
                    color: Color(0xFF059669), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Invoice Sent!',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(
                      '${widget.invoice.invoiceNumber}'
                      '${clientName.isNotEmpty ? ' · $clientName' : ''}'
                      ' · $amount',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(),
          const SizedBox(height: 4),

          const Text('Share invoice with client',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569))),
          const SizedBox(height: 12),

          // ── View / Print PDF (always shown) ─────────────────────────────────
          _ShareTile(
            icon: Icons.print_outlined,
            iconColor: const Color(0xFF7C3AED),
            bgColor: const Color(0xFF7C3AED),
            title: 'View / Print PDF',
            subtitle: 'Preview, print, or save invoice as PDF',
            loading: _loadingPdf,
            onTap: _busy
                ? null
                : () async {
                    setState(() => _loadingPdf = true);
                    try {
                      await ShareService.downloadPdf(
                          widget.invoice, widget.profile);
                    } finally {
                      if (mounted) setState(() => _loadingPdf = false);
                    }
                  },
          ),
          const SizedBox(height: 10),

          // ── WhatsApp message ─────────────────────────────────────────────────
          if (widget.hasPhone) ...[
            _ShareTile(
              icon: Icons.chat_bubble_outline,
              iconColor: const Color(0xFF25D366),
              bgColor: const Color(0xFF25D366),
              title: 'Send WhatsApp Message',
              subtitle: 'Opens WhatsApp with pre-filled message',
              loading: _loadingWa,
              onTap: _busy
                  ? null
                  : () async {
                      setState(() => _loadingWa = true);
                      try {
                        await ShareService.shareViaWhatsApp(
                            widget.invoice, widget.profile);
                      } catch (e) {
                        _showError(e.toString().replaceAll('Exception: ', ''));
                      } finally {
                        if (mounted) setState(() => _loadingWa = false);
                      }
                    },
            ),
            const SizedBox(height: 10),
          ],

          // ── Share PDF via WhatsApp (mobile only) ─────────────────────────────
          if (widget.hasPhone && !kIsWeb) ...[
            _ShareTile(
              icon: Icons.picture_as_pdf_outlined,
              iconColor: const Color(0xFF25D366),
              bgColor: const Color(0xFF25D366),
              title: 'Share PDF via WhatsApp',
              subtitle: 'Opens share sheet — pick WhatsApp to send PDF',
              loading: _loadingWaPdf,
              onTap: _busy
                  ? null
                  : () async {
                      setState(() => _loadingWaPdf = true);
                      try {
                        await ShareService.sharePdf(
                          widget.invoice, widget.profile,
                          sharePositionOrigin: _shareAnchor,
                        );
                      } catch (e) {
                        _showError(e.toString().replaceAll('Exception: ', ''));
                      } finally {
                        if (mounted) setState(() => _loadingWaPdf = false);
                      }
                    },
            ),
            const SizedBox(height: 10),
          ],

          // ── Email ────────────────────────────────────────────────────────────
          if (widget.hasEmail) ...[
            _ShareTile(
              icon: Icons.email_outlined,
              iconColor: const Color(0xFF2563EB),
              bgColor: const Color(0xFF2563EB),
              title: kIsWeb ? 'Send via Email' : 'Send via Email',
              subtitle: kIsWeb
                  ? 'Opens your default email app'
                  : 'Sends PDF + message to ${widget.invoice.client!.email}',
              loading: _loadingEmail,
              onTap: _busy
                  ? null
                  : () async {
                      setState(() => _loadingEmail = true);
                      try {
                        await ShareService.shareViaEmail(
                          widget.invoice, widget.profile,
                          sharePositionOrigin: _shareAnchor,
                        );
                      } catch (e) {
                        _showError(e.toString().replaceAll('Exception: ', ''));
                      } finally {
                        if (mounted) setState(() => _loadingEmail = false);
                      }
                    },
            ),
            const SizedBox(height: 10),
          ],

          // ── No contact info ──────────────────────────────────────────────────
          if (!widget.hasPhone && !widget.hasEmail)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No phone or email on this client. Add contact details to enable sharing.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Share tile ────────────────────────────────────────────────────────────────

class _ShareTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback? onTap;

  const _ShareTile({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: bgColor.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bgColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: loading
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: bgColor),
                      )
                    : Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: bgColor)),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 14, color: bgColor.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
