import 'package:shared_preferences/shared_preferences.dart';
import '../models/client.dart';
import '../models/invoice.dart';
import '../models/business_profile.dart';
import '../utils/formatters.dart';

class TemplateService {
  static const _waKey = 'tpl_whatsapp';
  static const _emailSubjectKey = 'tpl_email_subject';
  static const _emailBodyKey = 'tpl_email_body';

  // ── Offer / Bulk-messaging templates ─────────────────────────────────────
  static const _offerWaKey          = 'tpl_offer_whatsapp';
  static const _offerEmailSubjectKey = 'tpl_offer_email_subject';
  static const _offerEmailBodyKey    = 'tpl_offer_email_body';

  static const defaultOfferWhatsApp =
      'Dear {client_name},\n\n'
      '🎉 *Special offer from {business_name}!*\n\n'
      '{offer_details}\n\n'
      'For details, call/WhatsApp us: {business_phone}\n\n'
      'Regards,\n'
      '{business_name}';

  static const defaultOfferEmailSubject =
      'Special Offer from {business_name}';

  static const defaultOfferEmailBody =
      'Dear {client_name},\n\n'
      '{offer_details}\n\n'
      'Feel free to reach us at {business_email} or {business_phone}.\n\n'
      'Warm regards,\n'
      '{business_name}';

  /// Offer-specific variable list (client context, no Invoice needed).
  static const List<(String, String)> offerVariables = [
    ('{client_name}',    'Client Name'),
    ('{offer_details}',  'Your Offer / Message'),
    ('{business_name}',  'Business Name'),
    ('{business_phone}', 'Your Phone'),
    ('{business_email}', 'Your Email'),
  ];

  static const defaultWhatsApp = 'Dear {client_name},\n\n'
      'Please find the invoice attached.\n\n'
      '🧾 *Invoice #{invoice_no}*\n'
      '📅 Date: {invoice_date}\n'
      '📆 Due: {due_date}\n'
      '💰 Amount: *{amount}*\n\n'
      'Kindly arrange payment by the due date.\n\n'
      'Regards,\n'
      '{business_name}\n'
      '{business_phone}';

  static const defaultEmailSubject =
      'Invoice #{invoice_no} from {business_name}';

  static const defaultEmailBody = 'Dear {client_name},\n\n'
      'Please find attached the invoice as per the details below:\n\n'
      'Invoice #: {invoice_no}\n'
      'Date: {invoice_date}\n'
      'Due Date: {due_date}\n'
      'Amount Due: {amount}\n\n'
      'Kindly arrange the payment on or before the due date.\n\n'
      'Please feel free to reach out for any queries.\n\n'
      'Warm regards,\n'
      '{business_name}\n'
      '{business_email}\n'
      '{business_phone}';

  static Future<String> getWhatsApp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_waKey) ?? defaultWhatsApp;
  }

  static Future<String> getEmailSubject() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailSubjectKey) ?? defaultEmailSubject;
  }

  static Future<String> getEmailBody() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailBodyKey) ?? defaultEmailBody;
  }

  static Future<void> saveWhatsApp(String t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_waKey, t);
  }

  static Future<void> saveEmailSubject(String t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailSubjectKey, t);
  }

  static Future<void> saveEmailBody(String t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailBodyKey, t);
  }

  static Future<void> resetWhatsApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_waKey);
  }

  static Future<void> resetEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailSubjectKey);
    await prefs.remove(_emailBodyKey);
  }

  // ── Offer template CRUD ───────────────────────────────────────────────────

  static Future<String> getOfferWhatsApp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_offerWaKey) ?? defaultOfferWhatsApp;
  }

  static Future<String> getOfferEmailSubject() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_offerEmailSubjectKey) ?? defaultOfferEmailSubject;
  }

  static Future<String> getOfferEmailBody() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_offerEmailBodyKey) ?? defaultOfferEmailBody;
  }

  static Future<void> saveOfferWhatsApp(String t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_offerWaKey, t);
  }

  static Future<void> saveOfferEmailSubject(String t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_offerEmailSubjectKey, t);
  }

  static Future<void> saveOfferEmailBody(String t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_offerEmailBodyKey, t);
  }

  static Future<void> resetOfferTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_offerWaKey);
    await prefs.remove(_offerEmailSubjectKey);
    await prefs.remove(_offerEmailBodyKey);
  }

  /// Fills an offer template for a specific [client] — no Invoice required.
  /// [offerDetails] is the core offer text that replaces `{offer_details}`.
  static String fillOffer(
    String template, {
    required Client client,
    required BusinessProfile profile,
    String offerDetails = '',
  }) =>
      template
          .replaceAll('{client_name}',
              client.displayName.isNotEmpty ? client.displayName : 'Valued Customer')
          .replaceAll('{offer_details}', offerDetails)
          .replaceAll('{business_name}', profile.name)
          .replaceAll('{business_phone}', profile.phone)
          .replaceAll('{business_email}', profile.email);

  /// Fills a template with real invoice + profile values.
  static String fill(
    String template, {
    required Invoice invoice,
    required BusinessProfile profile,
  }) {
    final client = invoice.client;
    final clientName = (client?.companyName?.isNotEmpty == true
            ? client!.companyName!
            : client?.name) ??
        'Sir/Madam';
    final sym = Fmt.currencySymbol(invoice.currency);
    final amount = Fmt.currency(invoice.grandTotal, symbol: sym);
    final upiId = profile.paymentMethods
            .where((m) => m.upiId?.isNotEmpty == true)
            .map((m) => m.upiId!)
            .firstOrNull ??
        '';

    return template
        .replaceAll('{client_name}', clientName)
        .replaceAll('{invoice_no}', invoice.invoiceNumber)
        .replaceAll('{amount}', amount)
        .replaceAll('{invoice_date}', Fmt.date(invoice.invoiceDate))
        .replaceAll('{due_date}', Fmt.date(invoice.dueDate))
        .replaceAll('{invoice_subject}', invoice.subject ?? '')
        .replaceAll('{business_name}', profile.name)
        .replaceAll('{business_phone}', profile.phone)
        .replaceAll('{business_email}', profile.email)
        .replaceAll('{upi_id}', upiId);
  }

  /// Fills a template with sample data for the live preview.
  static String fillPreview(String template) {
    return template
        .replaceAll('{client_name}', 'Raj Enterprises')
        .replaceAll('{invoice_no}', 'INV-0042')
        .replaceAll('{amount}', '₹15,000.00')
        .replaceAll('{invoice_date}', '24 May 2026')
        .replaceAll('{due_date}', '23 Jun 2026')
        .replaceAll('{invoice_subject}', 'Professional consultation fees')
        .replaceAll('{business_name}', 'Your Business Name')
        .replaceAll('{business_phone}', '+91 98765 43210')
        .replaceAll('{business_email}', 'you@email.com')
        .replaceAll('{upi_id}', 'yourbiz@upi');
  }

  /// Variable list: (placeholder, display label).
  static const List<(String, String)> variables = [
    ('{client_name}', 'Client Name'),
    ('{invoice_no}', 'Invoice #'),
    ('{amount}', 'Total Amount'),
    ('{invoice_date}', 'Invoice Date'),
    ('{due_date}', 'Due Date'),
    ('{invoice_subject}', 'Invoice Subject'),
    ('{business_name}', 'Business Name'),
    ('{business_phone}', 'Your Phone'),
    ('{business_email}', 'Your Email'),
    ('{upi_id}', 'UPI ID'),
  ];
}
