import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/invoice.dart';
import '../models/client.dart';
import '../models/line_item.dart';
import '../models/business_profile.dart';
import 'formatters.dart';
import 'gst_utils.dart';

// ─────────────────────────────────────────────────────────────
// UNVERIFIED DISCLAIMER
// Shown on every PDF when the business is not yet verified.
// ─────────────────────────────────────────────────────────────

class PdfGenerator {
  static pw.Font? _cachedRegular;
  static pw.Font? _cachedBold;

  static Future<pw.Font> _loadFont(String asset) async {
    final data = await rootBundle.load(asset);
    return pw.Font.ttf(data);
  }

  static Future<Uint8List> generateInvoicePdf(
      Invoice invoice, BusinessProfile profile) async {
    _cachedRegular ??= await _loadFont('assets/fonts/NotoSans-Regular.ttf');
    _cachedBold    ??= await _loadFont('assets/fonts/NotoSans-Bold.ttf');
    final theme = pw.ThemeData.withFont(base: _cachedRegular!, bold: _cachedBold!);

    final tpl = invoice.template ?? profile.defaultTemplate;
    switch (tpl) {
      case InvoiceTemplate.classic:
        return _buildClassic(invoice, profile, theme);
      case InvoiceTemplate.minimal:
        return _buildMinimal(invoice, profile, theme);
      case InvoiceTemplate.corporate:
        return _buildCorporate(invoice, profile, theme);
      case InvoiceTemplate.modern:
        return _buildModern(invoice, profile, theme);
      case InvoiceTemplate.restaurant:
        return _buildRestaurant(invoice, profile, theme);
      case InvoiceTemplate.receipt:
        return _buildReceipt(invoice, profile, theme);
      case InvoiceTemplate.professional:
        return _buildProfessional(invoice, profile, theme);
      case InvoiceTemplate.gstBill:
        return _buildGstBill(invoice, profile, theme);
      case InvoiceTemplate.letterhead:
        return _buildLetterhead(invoice, profile, theme);
      case InvoiceTemplate.legalPro:
        return _buildLegalPro(invoice, profile, theme);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // SAMPLE PDF — used for template preview in free tier
  // ─────────────────────────────────────────────────────────────
  static Future<Uint8List> generateSamplePdf(InvoiceTemplate template) async {
    final profile = BusinessProfile(
      name: 'Acme Solutions Pvt. Ltd.',
      email: 'billing@acmesolutions.in',
      phone: '+91 98765 43210',
      address: '42, Nehru Park, MG Road',
      city: 'Bengaluru',
      state: 'Karnataka',
      country: 'India',
      postalCode: '560001',
      gstin: '29ABCDE1234F1Z5',
      website: 'www.acmesolutions.in',
      headerFields: {kHeaderLogo, kHeaderName, kHeaderEmail, kHeaderAddress, kHeaderGstin, kHeaderWebsite},
      currency: '₹',
      invoicePrefix: 'INV',
      nextInvoiceNumber: 1,
      defaultTemplate: template,
      paymentMethods: [],
      serviceItems: [],
    );

    final client = Client(
      id: 'sample',
      name: 'Rajesh Kumar',
      companyName: 'Global Traders Co.',
      email: 'rajesh@globaltraders.in',
      phone: '+91 99000 11223',
      address: '17, Ring Road, Connaught Place',
      city: 'New Delhi',
      state: 'Delhi',
      country: 'India',
      postalCode: '110001',
      gstin: '07FGHIJ5678K2L6',
    );

    final now = DateTime(2025, 6, 15);
    final invoice = Invoice(
      id: 'sample',
      invoiceNumber: 'INV-2025-0042',
      client: client,
      invoiceDate: now,
      dueDate: DateTime(2025, 7, 15),
      template: template,
      currency: '₹',
      subject: 'Website Redesign & Development Services',
      notes: 'Thank you for your business. Payment due within 30 days.',
      terms: 'Late payments subject to 2% monthly interest.',
      items: [
        LineItem(description: 'UI/UX Design (5 screens)', quantity: 5, rate: 8000, taxPercent: 18, hsnSac: '998314'),
        LineItem(description: 'Frontend Development', quantity: 1, rate: 35000, taxPercent: 18, hsnSac: '998313'),
        LineItem(description: 'Backend API Integration', quantity: 1, rate: 25000, taxPercent: 18, hsnSac: '998313'),
        LineItem(description: 'Hosting Setup & Config', quantity: 1, rate: 5000, taxPercent: 18, hsnSac: '998315'),
      ],
    );

    return generateInvoicePdf(invoice, profile);
  }

  // ─────────────────────────────────────────────────────────────
  // TEMPLATE 1 — CLASSIC
  // Blue gradient header · grid table · alternating rows
  // ─────────────────────────────────────────────────────────────
  static Future<Uint8List> _buildClassic(
      Invoice invoice, BusinessProfile profile, pw.ThemeData theme) async {
    final pdf = pw.Document();
    final sym = Fmt.currencySymbol(invoice.currency);
    final logo = _decodeLogo(profile.logoBase64);
    final primary = _colorFromHex(profile.themeColorHex, const PdfColor(0.08, 0.40, 0.75));
    final primaryDark = PdfColor(primary.red * 0.7, primary.green * 0.7, primary.blue * 0.7);
    final showTax = invoice.totalTax > 0;
    final showQty = profile.showQuantity;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      theme: theme,
      build: (ctx) => [
        // Header
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logo != null &&
                    profile.headerFields.contains(kHeaderLogo))
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Image(logo, width: 110, height: 55,
                        fit: pw.BoxFit.contain),
                  ),
                if (profile.headerFields.contains(kHeaderName)) ...[
                  pw.Text(
                    profile.name.isNotEmpty ? profile.name : 'Your Business',
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                  ..._profileAddressLines(profile),
                ],
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: pw.BoxDecoration(
                    gradient: pw.LinearGradient(
                      colors: [primary, primaryDark],
                      begin: pw.Alignment.topLeft,
                      end: pw.Alignment.bottomRight,
                    ),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(_invoiceTitle(profile),
                      style: pw.TextStyle(
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white)),
                ),
                pw.SizedBox(height: 8),
                _kv('Invoice #', invoice.invoiceNumber),
                _kv('Date', Fmt.date(invoice.invoiceDate)),
                _kv('Due Date', Fmt.date(invoice.dueDate)),
                ..._gstMetaRows(invoice, profile),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        if (invoice.client != null) _clientBox(invoice.client!),
        pw.SizedBox(height: 20),
        _classicTable(invoice, sym, primary,
            showTax: showTax, showQty: showQty,
            showHsn: profile.isGstRegistered),
        pw.SizedBox(height: 12),
        _totalsBlock(invoice, sym, profile: profile),
        ..._notesTerms(invoice),
        ..._paymentAndSignatureSection(profile),
        if (profile.verificationStatus != VerificationStatus.verified)
          _unverifiedDisclaimer(),
        pw.SizedBox(height: 24),
        _centeredFooter(profile),
        _brandingFooter(),
      ],
    ));
    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────────
  // TEMPLATE 2 — MINIMAL
  // Black & white · hairline dividers · no colored boxes
  // ─────────────────────────────────────────────────────────────
  static Future<Uint8List> _buildMinimal(
      Invoice invoice, BusinessProfile profile, pw.ThemeData theme) async {
    final pdf = pw.Document();
    final sym = Fmt.currencySymbol(invoice.currency);
    final logo = _decodeLogo(profile.logoBase64);
    final showTax = invoice.totalTax > 0;
    final showQty = profile.showQuantity;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      theme: theme,
      build: (ctx) => [
        // Header row: business on left, INVOICE on right
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logo != null &&
                    profile.headerFields.contains(kHeaderLogo))
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 6),
                    child: pw.Image(logo, width: 90, height: 45,
                        fit: pw.BoxFit.contain),
                  ),
                if (profile.headerFields.contains(kHeaderName))
                  pw.Text(
                    profile.name.isNotEmpty ? profile.name : 'Your Business',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(_invoiceTitle(profile),
                    style: pw.TextStyle(
                        fontSize: 30,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey400)),
                pw.SizedBox(height: 4),
                pw.Text('# ${invoice.invoiceNumber}',
                    style: const pw.TextStyle(
                        fontSize: 13, color: PdfColors.grey600)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Divider(color: PdfColors.black, thickness: 1.5),
        pw.SizedBox(height: 16),

        // Details row: bill-to left, invoice meta right
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: invoice.client != null
                  ? pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BILL TO',
                            style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 1.5,
                                color: PdfColors.grey500)),
                        pw.SizedBox(height: 6),
                        ..._clientLines(invoice.client!),
                      ],
                    )
                  : pw.SizedBox(),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _kvLight('Issue Date', Fmt.date(invoice.invoiceDate)),
                _kvLight('Due Date', Fmt.date(invoice.dueDate)),
                if (profile.gstin?.isNotEmpty == true)
                  _kvLight('GSTIN', profile.gstin!),
                ..._gstMetaRowsLight(invoice, profile),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 24),
        _minimalTable(invoice, sym,
            showTax: showTax, showQty: showQty,
            showHsn: profile.isGstRegistered),
        pw.SizedBox(height: 16),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: _totalsBlock(invoice, sym, width: 200, profile: profile),
        ),
        ..._notesTerms(invoice),
        ..._paymentAndSignatureSection(profile),
        if (profile.verificationStatus != VerificationStatus.verified)
          _unverifiedDisclaimer(),
        pw.SizedBox(height: 32),
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 6),
        if (profile.showThankYouMessage)
          pw.Center(
            child: pw.Text(profile.thankYouMessage,
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey400)),
          ),
        _brandingFooter(),
      ],
    ));
    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────────
  // TEMPLATE 3 — CORPORATE
  // Dark charcoal header · full-width banner · formal grid
  // ─────────────────────────────────────────────────────────────
  static Future<Uint8List> _buildCorporate(
      Invoice invoice, BusinessProfile profile, pw.ThemeData theme) async {
    final pdf = pw.Document();
    final sym = Fmt.currencySymbol(invoice.currency);
    final logo = _decodeLogo(profile.logoBase64);
    const dark = PdfColor(0.14, 0.19, 0.24);
    final accent = _colorFromHex(profile.themeColorHex, const PdfColor(0.22, 0.60, 0.85));
    final showTax = invoice.totalTax > 0;
    final showQty = profile.showQuantity;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      theme: theme,
      build: (ctx) => [
        // Full-width dark header banner
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 28),
          color: dark,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logo != null &&
                      profile.headerFields.contains(kHeaderLogo))
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Image(logo, width: 100, height: 50,
                          fit: pw.BoxFit.contain),
                    ),
                  if (profile.headerFields.contains(kHeaderName))
                    pw.Text(
                      profile.name.isNotEmpty
                          ? profile.name
                          : 'Your Business',
                      style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white),
                    ),
                  if (profile.email.isNotEmpty)
                    pw.Text(profile.email,
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey300)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(_invoiceTitle(profile),
                      style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: accent)),
                  pw.SizedBox(height: 4),
                  pw.Text('# ${invoice.invoiceNumber}',
                      style: const pw.TextStyle(
                          fontSize: 12, color: PdfColors.white)),
                ],
              ),
            ],
          ),
        ),

        // Accent strip
        pw.Container(height: 4, color: accent),

        // Body
        pw.Padding(
          padding: const pw.EdgeInsets.all(40),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Dates row + client
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (invoice.client != null)
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('BILL TO',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: PdfColors.grey500)),
                          pw.SizedBox(height: 6),
                          ..._clientLines(invoice.client!),
                        ],
                      ),
                    ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(14),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor(0.95, 0.97, 1.0),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        _kv('Issue Date', Fmt.date(invoice.invoiceDate)),
                        _kv('Due Date', Fmt.date(invoice.dueDate)),
                        if (profile.gstin?.isNotEmpty == true)
                          _kv('GSTIN', profile.gstin!),
                        ..._gstMetaRows(invoice, profile),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              _corporateTable(invoice, sym, dark, accent,
                  showTax: showTax, showQty: showQty,
                  showHsn: profile.isGstRegistered),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(14),
                    decoration: pw.BoxDecoration(
                      color: dark,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        if (invoice.subtotal != invoice.grandTotal) ...[
                          _kvWhite('Subtotal',
                              '$sym${invoice.subtotal.toStringAsFixed(2)}'),
                          if (invoice.totalDiscount > 0)
                            _kvWhite('Discount',
                                '-$sym${invoice.totalDiscount.toStringAsFixed(2)}'),
                          if (invoice.totalTax > 0)
                            ..._gstTaxLabelValues(invoice, profile, sym)
                                .map((lv) => _kvWhite(lv.$1, lv.$2)),
                          pw.Divider(
                              color: const PdfColor(1, 1, 1, 0.54),
                              thickness: 0.5),
                        ],
                        pw.Row(
                          children: [
                            pw.Text('TOTAL',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 14,
                                    color: accent)),
                            pw.SizedBox(width: 24),
                            pw.Text(
                                '$sym${invoice.grandTotal.toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 14,
                                    color: PdfColors.white)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              ..._notesTerms(invoice),
              ..._paymentAndSignatureSection(profile),
              if (profile.verificationStatus != VerificationStatus.verified)
                _unverifiedDisclaimer(),
              pw.SizedBox(height: 24),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 6),
              _centeredFooter(profile),
              _brandingFooter(),
            ],
          ),
        ),
      ],
    ));
    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────────
  // TEMPLATE 4 — MODERN
  // Teal top bar · two-column details · accent on totals
  // ─────────────────────────────────────────────────────────────
  static Future<Uint8List> _buildModern(
      Invoice invoice, BusinessProfile profile, pw.ThemeData theme) async {
    final pdf = pw.Document();
    final sym = Fmt.currencySymbol(invoice.currency);
    final logo = _decodeLogo(profile.logoBase64);
    final teal = _colorFromHex(profile.themeColorHex, const PdfColor(0.00, 0.54, 0.48));
    final tealLight = PdfColor(
      teal.red * 0.12 + 0.88, teal.green * 0.12 + 0.88, teal.blue * 0.12 + 0.88);
    final showTax = invoice.totalTax > 0;
    final showQty = profile.showQuantity;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      theme: theme,
      build: (ctx) => [
        // Teal top bar
        pw.Container(height: 6, color: teal),

        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(40, 28, 40, 0),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header: logo/name left · invoice number right
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (logo != null &&
                          profile.headerFields.contains(kHeaderLogo))
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 6),
                          child: pw.Image(logo, width: 100, height: 50,
                              fit: pw.BoxFit.contain),
                        ),
                      if (profile.headerFields.contains(kHeaderName))
                        pw.Text(
                          profile.name.isNotEmpty
                              ? profile.name
                              : 'Your Business',
                          style: pw.TextStyle(
                              fontSize: 18, fontWeight: pw.FontWeight.bold),
                        ),
                      ..._profileAddressLines(profile),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(_invoiceTitle(profile),
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 3,
                              color: teal)),
                      pw.SizedBox(height: 2),
                      pw.Text(invoice.invoiceNumber,
                          style: pw.TextStyle(
                              fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Teal band with dates
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                color: tealLight,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _tealKv('Issue Date', Fmt.date(invoice.invoiceDate), teal),
                    _tealKv('Due Date', Fmt.date(invoice.dueDate), teal),
                    if (profile.gstin?.isNotEmpty == true)
                      _tealKv('GSTIN', profile.gstin!, teal),
                    if (invoice.placeOfSupply?.isNotEmpty == true &&
                        profile.isGstRegistered)
                      _tealKv('Place of Supply', invoice.placeOfSupply!, teal),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              if (invoice.client != null) ...[
                pw.Text('BILLED TO',
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.5,
                        color: teal)),
                pw.SizedBox(height: 6),
                ..._clientLines(invoice.client!),
                pw.SizedBox(height: 20),
              ],

              _modernTable(invoice, sym, teal, tealLight,
                  showTax: showTax, showQty: showQty,
                  showHsn: profile.isGstRegistered),
              pw.SizedBox(height: 12),

              // Totals with teal accent line
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 220,
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        left: pw.BorderSide(color: teal, width: 3),
                      ),
                    ),
                    padding: const pw.EdgeInsets.only(left: 12),
                    child: pw.Column(
                      children: [
                        if (invoice.subtotal != invoice.grandTotal) ...[
                          _totRow('Subtotal',
                              '$sym${invoice.subtotal.toStringAsFixed(2)}'),
                          if (invoice.totalDiscount > 0)
                            _totRow('Discount',
                                '-$sym${invoice.totalDiscount.toStringAsFixed(2)}',
                                color: PdfColors.red700),
                          if (invoice.totalTax > 0)
                            ..._gstTaxLabelValues(invoice, profile, sym)
                                .map((lv) => _totRow(lv.$1, lv.$2)),
                          pw.Divider(
                              color: PdfColors.grey300, thickness: 0.5),
                        ],
                        pw.Row(
                          mainAxisAlignment:
                              pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('TOTAL',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 13,
                                    color: teal)),
                            pw.Text(
                                '$sym${invoice.grandTotal.toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              ..._notesTerms(invoice),
              ..._paymentAndSignatureSection(profile),
              if (profile.verificationStatus != VerificationStatus.verified)
                _unverifiedDisclaimer(),
              pw.SizedBox(height: 28),
            ],
          ),
        ),

        // Teal bottom bar with branding
        pw.Container(
          color: teal,
          padding: const pw.EdgeInsets.symmetric(vertical: 7),
          child: pw.Column(
            children: [
              if (profile.showThankYouMessage)
                pw.Center(
                  child: pw.Text(profile.thankYouMessage,
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.white)),
                ),
              pw.SizedBox(height: 3),
              pw.Center(
                child: pw.Text('Generated by Invoice Generator',
                    style: const pw.TextStyle(
                        fontSize: 7, color: PdfColors.white)),
              ),
            ],
          ),
        ),
      ],
    ));
    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────────
  // TEMPLATE 5 — RESTAURANT
  // Centered header · burgundy & gold · GST-ready totals
  // ─────────────────────────────────────────────────────────────
  static Future<Uint8List> _buildRestaurant(
      Invoice invoice, BusinessProfile profile, pw.ThemeData theme) async {
    final pdf = pw.Document();
    final sym = Fmt.currencySymbol(invoice.currency);
    final logo = _decodeLogo(profile.logoBase64);
    final burgundy = _colorFromHex(profile.themeColorHex, const PdfColor(0.47, 0.07, 0.13));
    const gold = PdfColor(0.78, 0.60, 0.10);
    const cream = PdfColor(0.99, 0.97, 0.93);
    const goldLight = PdfColor(0.99, 0.96, 0.87);
    final showTax = invoice.totalTax > 0;
    final showQty = profile.showQuantity;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
      theme: theme,
      build: (ctx) => [
        // ── Centered header ──────────────────────────────────────
        pw.SizedBox(
          width: double.infinity,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null &&
                  profile.headerFields.contains(kHeaderLogo))
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Image(logo, width: 100, height: 50,
                      fit: pw.BoxFit.contain),
                ),
              if (profile.headerFields.contains(kHeaderName)) ...[
                pw.Text(
                  profile.name.isNotEmpty ? profile.name : 'Your Restaurant',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: burgundy),
                ),
                pw.SizedBox(height: 4),
                if (profile.address.isNotEmpty)
                  pw.Text(profile.address,
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700)),
                () {
                  final cs = [profile.city, profile.state]
                      .where((s) => s.isNotEmpty)
                      .join(', ');
                  return cs.isNotEmpty
                      ? pw.Text(cs,
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(
                              fontSize: 9, color: PdfColors.grey700))
                      : pw.SizedBox();
                }(),
                if (profile.phone.isNotEmpty)
                  pw.Text('Tel: ${profile.phone}',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700)),
                if (profile.gstin?.isNotEmpty == true)
                  pw.Text('GSTIN: ${profile.gstin}',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700)),
              ],
            ],
          ),
        ),

        pw.SizedBox(height: 10),
        // Gold rule
        pw.Container(height: 2, color: gold),
        pw.SizedBox(height: 4),
        // TAX INVOICE label centered
        pw.Center(
          child: pw.Text('TAX INVOICE',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 3,
                  color: burgundy)),
        ),
        pw.SizedBox(height: 4),
        pw.Container(height: 1, color: gold),
        pw.SizedBox(height: 14),

        // ── Bill-to + Invoice meta row ───────────────────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: invoice.client != null
                  ? pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BILL TO',
                            style: pw.TextStyle(
                                fontSize: 7,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 1.5,
                                color: gold)),
                        pw.SizedBox(height: 5),
                        ..._clientLines(invoice.client!),
                      ],
                    )
                  : pw.SizedBox(),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: goldLight,
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: gold, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _kv('Invoice #', invoice.invoiceNumber),
                  _kv('Date', Fmt.date(invoice.invoiceDate)),
                  _kv('Due Date', Fmt.date(invoice.dueDate)),
                  ..._gstMetaRows(invoice, profile),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),

        // ── Items table ──────────────────────────────────────────
        _restaurantTable(invoice, sym, burgundy, gold, cream,
            showTax: showTax, showQty: showQty,
            showHsn: profile.isGstRegistered),
        pw.SizedBox(height: 14),

        // ── Totals with GST-style breakdown ──────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Container(
              width: 230,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: gold, width: 0.8),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                children: [
                  if (invoice.subtotal != invoice.grandTotal) ...[
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: _totRow('Subtotal',
                          '$sym${invoice.subtotal.toStringAsFixed(2)}'),
                    ),
                    if (invoice.totalDiscount > 0)
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 12, vertical: 2),
                        child: _totRow('Discount',
                            '-$sym${invoice.totalDiscount.toStringAsFixed(2)}',
                            color: PdfColors.red700),
                      ),
                    if (invoice.totalTax > 0)
                      ..._gstTaxLabelValues(invoice, profile, sym).map((lv) =>
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 12, vertical: 2),
                            child: _totRow(lv.$1, lv.$2),
                          )),
                    pw.Container(height: 0.5, color: gold),
                  ],
                  pw.Container(
                    color: burgundy,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('GRAND TOTAL',
                            style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white)),
                        pw.Text(
                            '$sym${invoice.grandTotal.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                                color: gold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ..._notesTerms(invoice),
        ..._paymentAndSignatureSection(profile),
        if (profile.verificationStatus != VerificationStatus.verified)
          _unverifiedDisclaimer(),
        pw.SizedBox(height: 24),

        // ── Footer ───────────────────────────────────────────────
        pw.Container(height: 1, color: gold),
        pw.SizedBox(height: 8),
        if (profile.showThankYouMessage)
          pw.Center(
            child: pw.Text(profile.thankYouMessage,
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: burgundy)),
          ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text('We look forward to serving you again.',
              style: const pw.TextStyle(
                  fontSize: 8, color: PdfColors.grey500)),
        ),
        _brandingFooter(),
      ],
    ));
    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────────
  // TEMPLATE 6 — RECEIPT
  // Compact POS-style · centered · QR prominent · for cafes/restaurants
  // ─────────────────────────────────────────────────────────────
  static Future<Uint8List> _buildReceipt(
      Invoice invoice, BusinessProfile profile, pw.ThemeData theme) async {
    final pdf = pw.Document();
    final sym = Fmt.currencySymbol(invoice.currency);
    final logo = _decodeLogo(profile.logoBase64);
    final signatureImage = _decodeLogo(profile.signatureBase64);
    final showTax = invoice.totalTax > 0;

    // UPI QR
    PaymentMethod? upiMethod;
    if (profile.showPaymentDetailsOnInvoice) {
      for (final m in profile.paymentMethods) {
        if (m.type == PaymentMethodType.upi && m.upiId?.isNotEmpty == true) {
          upiMethod = m;
          break;
        }
      }
    }
    final qrData = upiMethod != null
        ? 'upi://pay?pa=${upiMethod.upiId!}'
            '&pn=${Uri.encodeComponent(profile.name)}'
            '&am=${invoice.grandTotal.toStringAsFixed(2)}&cu=INR'
        : null;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      theme: theme,
      build: (ctx) => [
        // ── Logo ────────────────────────────────────────────────
        if (logo != null && profile.headerFields.contains(kHeaderLogo))
          pw.Center(
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Image(logo, width: 80, height: 80, fit: pw.BoxFit.contain),
            ),
          ),

        // ── Business name & info ─────────────────────────────────
        if (profile.headerFields.contains(kHeaderName)) ...[
          pw.Center(
            child: pw.Text(
              profile.name.isNotEmpty ? profile.name.toUpperCase() : 'YOUR BUSINESS',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 4),
          if (profile.address.isNotEmpty)
            pw.Center(child: pw.Text(profile.address,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
          () {
            final cs = [profile.city, profile.state].where((s) => s.isNotEmpty).join(', ');
            return cs.isNotEmpty
                ? pw.Center(child: pw.Text(cs,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)))
                : pw.SizedBox();
          }(),
          if (profile.phone.isNotEmpty)
            pw.Center(child: pw.Text('Phone: ${profile.phone}',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
          if (profile.gstin?.isNotEmpty == true)
            pw.Center(child: pw.Text('GSTIN: ${profile.gstin}',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
        ],
        pw.SizedBox(height: 10),
        _dashedDivider(),
        pw.SizedBox(height: 8),

        // ── Invoice meta (centered) ──────────────────────────────
        pw.Center(child: pw.Text('ORDER / RECEIPT',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: 2))),
        pw.SizedBox(height: 6),
        pw.Center(child: pw.Text('Invoice #: ${invoice.invoiceNumber}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
        pw.Center(child: pw.Text('Date: ${Fmt.date(invoice.invoiceDate)}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
        if (invoice.subject?.isNotEmpty == true)
          pw.Center(child: pw.Text('Ref: ${invoice.subject}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
        if (invoice.client != null) ...[
          pw.SizedBox(height: 4),
          pw.Center(child: pw.Text(
              'Customer: ${invoice.client!.companyName?.isNotEmpty == true ? invoice.client!.companyName! : invoice.client!.name}',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
        ],
        pw.SizedBox(height: 8),
        _dashedDivider(),
        pw.SizedBox(height: 8),

        // ── Items table ──────────────────────────────────────────
        _receiptTable(invoice, sym, showTax: showTax),
        pw.SizedBox(height: 8),
        _dashedDivider(),
        pw.SizedBox(height: 8),

        // ── Totals ───────────────────────────────────────────────
        if (invoice.subtotal != invoice.grandTotal) ...[
          _receiptTotRow('Subtotal', '$sym${invoice.subtotal.toStringAsFixed(2)}', bold: false),
          if (invoice.totalDiscount > 0)
            _receiptTotRow('Discount', '-$sym${invoice.totalDiscount.toStringAsFixed(2)}', bold: false),
          if (showTax)
            ..._gstTaxLabelValues(invoice, profile, sym)
                .map((lv) => _receiptTotRow(lv.$1, lv.$2, bold: false)),
          pw.SizedBox(height: 4),
          _dashedDivider(),
          pw.SizedBox(height: 4),
        ],
        _receiptTotRow('Total', '$sym${invoice.grandTotal.toStringAsFixed(2)}', bold: true, fontSize: 13),
        pw.SizedBox(height: 6),

        // ── Payment mode ─────────────────────────────────────────
        if (invoice.paymentMethodName?.isNotEmpty == true)
          pw.Center(child: pw.Text('Payment Mode: ${invoice.paymentMethodName}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))),
        pw.SizedBox(height: 12),

        // ── QR code ──────────────────────────────────────────────
        if (qrData != null) ...[
          _dashedDivider(),
          pw.SizedBox(height: 12),
          pw.Center(child: pw.Text('SCAN & PAY',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: 2))),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: qrData,
              width: 130,
              height: 130,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Center(child: pw.Text('UPI: ${upiMethod!.upiId}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
          pw.Center(child: pw.Text('Amount: $sym${invoice.grandTotal.toStringAsFixed(2)}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
          pw.SizedBox(height: 12),
        ],

        // ── Signature ────────────────────────────────────────────
        if (signatureImage != null) ...[
          _dashedDivider(),
          pw.SizedBox(height: 10),
          pw.Center(child: pw.Image(signatureImage, width: 100, height: 44, fit: pw.BoxFit.contain)),
          pw.SizedBox(height: 3),
          pw.Center(child: pw.Text('Authorized Signatory',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500))),
          pw.SizedBox(height: 8),
        ],

        // ── Notes ────────────────────────────────────────────────
        if (invoice.notes?.isNotEmpty == true) ...[
          _dashedDivider(),
          pw.SizedBox(height: 8),
          pw.Center(child: pw.Text(invoice.notes!,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))),
          pw.SizedBox(height: 8),
        ],
        _dashedDivider(),
        pw.SizedBox(height: 10),
        if (profile.showThankYouMessage)
          pw.Center(
            child: pw.Text(
              profile.thankYouMessage,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
        pw.SizedBox(height: 4),
        if (profile.verificationStatus != VerificationStatus.verified)
          _unverifiedDisclaimer(),
        _brandingFooter(),
      ],
    ));
    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────────
  // TEMPLATE 7 — PROFESSIONAL
  // Letterhead style · for lawyers, CAs, consultants
  // ─────────────────────────────────────────────────────────────
  static Future<Uint8List> _buildProfessional(
      Invoice invoice, BusinessProfile profile, pw.ThemeData theme) async {
    final pdf = pw.Document();
    final sym = Fmt.currencySymbol(invoice.currency);
    final logo = _decodeLogo(profile.logoBase64);
    final signatureImage = _decodeLogo(profile.signatureBase64);

    // Find bank method and UPI for payment details
    final bankMethods = profile.showPaymentDetailsOnInvoice
        ? profile.paymentMethods
            .where((m) => m.type == PaymentMethodType.bankAccount)
            .toList()
        : <PaymentMethod>[];

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(56, 48, 56, 48),
      theme: theme,
      build: (ctx) => [
        // ── Letterhead header ────────────────────────────────────
        pw.SizedBox(
          width: double.infinity,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null && profile.headerFields.contains(kHeaderLogo))
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Image(logo, width: 72, height: 72, fit: pw.BoxFit.contain),
                ),
              if (profile.headerFields.contains(kHeaderName)) ...[
                pw.Text(
                  profile.name.isNotEmpty ? profile.name.toUpperCase() : 'YOUR NAME',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                // Address line
                () {
                  final parts = [
                    profile.address,
                    profile.city,
                    profile.state,
                    profile.postalCode,
                  ].where((s) => s.isNotEmpty).join(', ');
                  return parts.isNotEmpty
                      ? pw.Text(parts,
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))
                      : pw.SizedBox();
                }(),
                // Email + Phone
                () {
                  final ep = [
                    if (profile.email.isNotEmpty) 'Email: ${profile.email}',
                    if (profile.phone.isNotEmpty) 'Mb: ${profile.phone}',
                  ].join(';  ');
                  return ep.isNotEmpty
                      ? pw.Text(ep,
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))
                      : pw.SizedBox();
                }(),
                if (profile.gstin?.isNotEmpty == true)
                  pw.Text('PAN/GSTIN: ${profile.gstin}',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
            ],
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 1.5, color: PdfColors.black),
        pw.SizedBox(height: 12),

        // ── "INVOICE" centered heading ───────────────────────────
        pw.Center(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 1.5)),
            ),
            child: pw.Text(_invoiceTitle(profile),
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, letterSpacing: 3)),
          ),
        ),
        pw.SizedBox(height: 12),

        // ── Date + Invoice # right-aligned ───────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Date: ${Fmt.date(invoice.invoiceDate)}',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text('Invoice No. ${invoice.invoiceNumber}',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                if (profile.isGstRegistered &&
                    invoice.placeOfSupply?.isNotEmpty == true)
                  pw.Text('Place of Supply: ${invoice.placeOfSupply}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                if (profile.isGstRegistered && invoice.reverseCharge)
                  pw.Text('Reverse Charge: Yes',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 14),

        // ── To block ─────────────────────────────────────────────
        if (invoice.client != null) ...[
          pw.Text('To,', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          ..._professionalClientLines(invoice.client!),
          pw.SizedBox(height: 12),
        ],

        // ── Subject ──────────────────────────────────────────────
        if (invoice.subject?.isNotEmpty == true) ...[
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Sub: ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Expanded(
                child: pw.Text(invoice.subject!,
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
        ],

        // ── Items table: PARTICULARS | AMOUNT ────────────────────
        _professionalTable(invoice, sym, profile),
        pw.SizedBox(height: 8),

        // ── Amount in words ──────────────────────────────────────
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(width: 0.5, color: PdfColors.grey500),
              bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey500),
            ),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  _amountInWords(invoice.grandTotal),
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Text('$sym${invoice.grandTotal.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // ── Notes ────────────────────────────────────────────────
        if (invoice.notes?.isNotEmpty == true) ...[
          pw.Text(invoice.notes!,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 16),
        ],

        // ── Signature block (right) ───────────────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (signatureImage != null) ...[
                  pw.Image(signatureImage, width: 110, height: 50, fit: pw.BoxFit.contain),
                  pw.SizedBox(height: 4),
                ],
                pw.Container(
                  width: 140,
                  child: pw.Divider(thickness: 0.8, color: PdfColors.black),
                ),
                pw.Text(profile.name.isNotEmpty ? profile.name : 'Authorized Signatory',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20),

        // ── Bank Account Details ──────────────────────────────────
        if (bankMethods.isNotEmpty) ...[
          pw.Container(
            width: double.infinity,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Bank Account Details',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                for (final m in bankMethods) ...[
                  if (m.bankName?.isNotEmpty == true)
                    pw.Text('Bank Name:  ${m.bankName}',
                        style: const pw.TextStyle(fontSize: 9)),
                  if (m.accountHolder?.isNotEmpty == true)
                    pw.Text('A/C Holder: ${m.accountHolder}',
                        style: const pw.TextStyle(fontSize: 9)),
                  if (m.accountNumber?.isNotEmpty == true)
                    pw.Text('Account No.: ${m.accountNumber}',
                        style: const pw.TextStyle(fontSize: 9)),
                  if (m.ifscCode?.isNotEmpty == true)
                    pw.Text('IFSC Code:  ${m.ifscCode}',
                        style: const pw.TextStyle(fontSize: 9)),
                  pw.SizedBox(height: 4),
                ],
                if (profile.gstin?.isNotEmpty == true)
                  pw.Text('Pan Card:  ${profile.gstin}',
                      style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
        ],
        if (profile.verificationStatus != VerificationStatus.verified)
          _unverifiedDisclaimer(),
        _brandingFooter(),
      ],
    ));
    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────────
  // TABLE BUILDERS
  // ─────────────────────────────────────────────────────────────

  static pw.Widget _classicTable(Invoice inv, String sym, PdfColor primary,
      {bool showTax = true, bool showQty = true, bool showHsn = false}) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: _colWidths(showTax: showTax, showQty: showQty),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: primary),
          children: _headers(PdfColors.white, showTax: showTax, showQty: showQty),
        ),
        ...inv.items.asMap().entries.map((e) {
          final bg = e.key.isEven ? PdfColors.white : PdfColors.grey50;
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: _itemCells(e.key, e.value, sym,
                showTax: showTax, showQty: showQty, showHsn: showHsn),
          );
        }),
      ],
    );
  }

  static pw.Widget _minimalTable(Invoice inv, String sym,
      {bool showTax = true, bool showQty = true, bool showHsn = false}) {
    return pw.Table(
      border: const pw.TableBorder(
        bottom: pw.BorderSide(color: PdfColors.grey300),
        horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
      ),
      columnWidths: _colWidths(showTax: showTax, showQty: showQty),
      children: [
        pw.TableRow(
          decoration:
              const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide())),
          children: _headers(PdfColors.black,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              showTax: showTax, showQty: showQty),
        ),
        ...inv.items.asMap().entries.map((e) => pw.TableRow(
              children: _itemCells(e.key, e.value, sym,
                  showTax: showTax, showQty: showQty, showHsn: showHsn),
            )),
      ],
    );
  }

  static pw.Widget _corporateTable(
      Invoice inv, String sym, PdfColor dark, PdfColor accent,
      {bool showTax = true, bool showQty = true, bool showHsn = false}) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
      columnWidths: _colWidths(showTax: showTax, showQty: showQty),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: dark),
          children: _headers(PdfColors.white, showTax: showTax, showQty: showQty),
        ),
        ...inv.items.asMap().entries.map((e) {
          final bg = e.key.isEven
              ? const PdfColor(0.97, 0.98, 1.0)
              : PdfColors.white;
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: _itemCells(e.key, e.value, sym,
                showTax: showTax, showQty: showQty, showHsn: showHsn),
          );
        }),
      ],
    );
  }

  static pw.Widget _modernTable(
      Invoice inv, String sym, PdfColor teal, PdfColor tealLight,
      {bool showTax = true, bool showQty = true, bool showHsn = false}) {
    return pw.Table(
      columnWidths: _colWidths(showTax: showTax, showQty: showQty),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: tealLight),
          children: _headers(teal,
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 10, color: teal),
              showTax: showTax, showQty: showQty),
        ),
        ...inv.items.asMap().entries.map((e) => pw.TableRow(
              decoration: pw.BoxDecoration(
                border: const pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                ),
              ),
              children: _itemCells(e.key, e.value, sym,
                  showTax: showTax, showQty: showQty, showHsn: showHsn),
            )),
      ],
    );
  }

  static pw.Widget _restaurantTable(
      Invoice inv, String sym, PdfColor burgundy, PdfColor gold, PdfColor cream,
      {bool showTax = true, bool showQty = true, bool showHsn = false}) {
    return pw.Table(
      border: pw.TableBorder.all(color: gold, width: 0.5),
      columnWidths: _colWidths(showTax: showTax, showQty: showQty),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: burgundy),
          children: _headers(gold,
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 10, color: gold),
              showTax: showTax, showQty: showQty),
        ),
        ...inv.items.asMap().entries.map((e) {
          final bg = e.key.isEven ? cream : PdfColors.white;
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: _itemCells(e.key, e.value, sym,
                showTax: showTax, showQty: showQty, showHsn: showHsn),
          );
        }),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SHARED CELL / ROW HELPERS
  // ─────────────────────────────────────────────────────────────

  static PdfColor _colorFromHex(String? hex, PdfColor fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      final v = int.parse(hex, radix: 16);
      return PdfColor(
        ((v >> 16) & 0xFF) / 255.0,
        ((v >> 8) & 0xFF) / 255.0,
        (v & 0xFF) / 255.0,
      );
    } catch (_) {
      return fallback;
    }
  }

  static Map<int, pw.TableColumnWidth> _colWidths(
      {bool showTax = true, bool showQty = true}) {
    final cols = <pw.TableColumnWidth>[
      const pw.FixedColumnWidth(24),
      const pw.FlexColumnWidth(3),
      if (showQty) const pw.FixedColumnWidth(40),
      const pw.FixedColumnWidth(70),
      if (showTax) const pw.FixedColumnWidth(40),
      const pw.FixedColumnWidth(80),
    ];
    return {for (int i = 0; i < cols.length; i++) i: cols[i]};
  }

  static List<pw.Widget> _headers(PdfColor textColor,
      {pw.TextStyle? style, bool showTax = true, bool showQty = true}) {
    final s = style ??
        pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: textColor,
            fontSize: 10);
    return [
      '#', 'Description',
      if (showQty) 'Qty',
      'Rate',
      if (showTax) 'Tax%',
      'Amount',
    ].map((h) => _cell(h, style: s)).toList();
  }

  static List<pw.Widget> _itemCells(int idx, LineItem item, String sym,
      {bool showTax = true, bool showQty = true, bool showHsn = false}) {
    final hasHsn = showHsn && item.hsnSac?.isNotEmpty == true;
    return [
      _cell('${idx + 1}'),
      hasHsn
          ? _cellWithSub(item.description, 'HSN/SAC: ${item.hsnSac}')
          : _cell(item.description),
      if (showQty) _cell('${item.quantity} ${item.unit}'),
      _cell('$sym${item.rate.toStringAsFixed(2)}'),
      if (showTax) _cell('${item.taxPercent}%'),
      _cell('$sym${item.total.toStringAsFixed(2)}', align: pw.TextAlign.right),
    ];
  }

  static pw.Widget _cell(String text,
      {pw.TextAlign align = pw.TextAlign.left, pw.TextStyle? style}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(text,
          style: style ?? const pw.TextStyle(fontSize: 10),
          textAlign: align),
    );
  }

  static pw.Widget _cellWithSub(String text, String sub) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(sub,
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TOTALS BLOCK
  // ─────────────────────────────────────────────────────────────

  static pw.Widget _totalsBlock(Invoice inv, String sym,
      {double? width, BusinessProfile? profile}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: width ?? 220,
          child: pw.Column(
            children: [
              if (inv.subtotal != inv.grandTotal) ...[
                _totRow('Subtotal', '$sym${inv.subtotal.toStringAsFixed(2)}'),
                if (inv.totalDiscount > 0)
                  _totRow('Discount',
                      '-$sym${inv.totalDiscount.toStringAsFixed(2)}',
                      color: PdfColors.red700),
                if (inv.totalTax > 0)
                  ...(profile != null
                      ? _gstTaxLabelValues(inv, profile, sym)
                            .map((lv) => _totRow(lv.$1, lv.$2))
                      : [_totRow('Tax', '$sym${inv.totalTax.toStringAsFixed(2)}')]),
                pw.Divider(color: PdfColors.grey400),
              ],
              _totRow('Total', '$sym${inv.grandTotal.toStringAsFixed(2)}',
                  bold: true, fontSize: 13),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _totRow(String label, String value,
      {bool bold = false,
      double fontSize = 10,
      PdfColor color = PdfColors.black}) {
    final s = bold
        ? pw.TextStyle(
            fontWeight: pw.FontWeight.bold, fontSize: fontSize, color: color)
        : pw.TextStyle(fontSize: fontSize, color: color);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(label, style: s), pw.Text(value, style: s)],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // RECEIPT HELPERS
  // ─────────────────────────────────────────────────────────────

  static pw.Widget _dashedDivider() {
    return pw.Container(
      height: 1,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(style: pw.BorderStyle.dashed, color: PdfColors.grey500, width: 0.8),
        ),
      ),
    );
  }

  static pw.Widget _receiptTotRow(String label, String value,
      {bool bold = false, double fontSize = 10}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label,
            style: bold
                ? pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)
                : pw.TextStyle(fontSize: fontSize, color: PdfColors.grey700)),
        pw.Text(value,
            style: bold
                ? pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)
                : pw.TextStyle(fontSize: fontSize, color: PdfColors.grey700)),
      ],
    );
  }

  static pw.Widget _receiptTable(Invoice inv, String sym, {bool showTax = true}) {
    final rows = <pw.TableRow>[];
    // Header
    rows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 0.8, color: PdfColors.grey700),
          top: pw.BorderSide(width: 0.8, color: PdfColors.grey700),
        ),
      ),
      children: [
        _receiptCell('ITEM', bold: true, align: pw.TextAlign.left),
        _receiptCell('QTY', bold: true, align: pw.TextAlign.center),
        _receiptCell('RATE', bold: true, align: pw.TextAlign.right),
        _receiptCell('AMOUNT', bold: true, align: pw.TextAlign.right),
      ],
    ));
    // Items
    for (final item in inv.items) {
      rows.add(pw.TableRow(children: [
        _receiptCell(item.description, align: pw.TextAlign.left),
        _receiptCell('${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity}',
            align: pw.TextAlign.center),
        _receiptCell('$sym${item.rate.toStringAsFixed(2)}', align: pw.TextAlign.right),
        _receiptCell('$sym${item.subtotal.toStringAsFixed(2)}', align: pw.TextAlign.right),
      ]));
    }
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FixedColumnWidth(30),
        2: const pw.FixedColumnWidth(60),
        3: const pw.FixedColumnWidth(60),
      },
      children: rows,
    );
  }

  static pw.Widget _receiptCell(String text,
      {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Text(text,
          textAlign: align,
          style: bold
              ? pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)
              : const pw.TextStyle(fontSize: 9)),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PROFESSIONAL TEMPLATE HELPERS
  // ─────────────────────────────────────────────────────────────

  static List<pw.Widget> _professionalClientLines(Client client) {
    final lines = <pw.Widget>[];
    final hasCompany = client.companyName?.isNotEmpty == true;
    lines.add(pw.Text(hasCompany ? client.companyName! : client.name,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)));
    if (hasCompany && client.name.isNotEmpty) {
      lines.add(pw.Text('Attn: ${client.name}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)));
    }
    if (client.address.isNotEmpty) {
      lines.add(pw.Text('Having its office at ${client.address}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)));
    }
    final cityState = [client.city, client.state].where((s) => s.isNotEmpty).join(', ');
    final post = client.postalCode.isNotEmpty ? '– ${client.postalCode}' : '';
    if (cityState.isNotEmpty || post.isNotEmpty) {
      lines.add(pw.Text([cityState, post].where((s) => s.isNotEmpty).join(' '),
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)));
    }
    if (client.gstin?.isNotEmpty == true) {
      lines.add(pw.Text('GSTIN: ${client.gstin}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)));
    }
    return lines;
  }

  static pw.Widget _professionalTable(Invoice inv, String sym, BusinessProfile profile) {
    final hasMultipleItems = inv.items.length > 1;
    final rows = <pw.TableRow>[];
    // Header row
    rows.add(pw.TableRow(
      decoration: pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        _profCell('PARTICULARS', bold: true, align: pw.TextAlign.center),
        _profCell('AMOUNT', bold: true, align: pw.TextAlign.center),
      ],
    ));
    // Items
    for (final item in inv.items) {
      final desc = StringBuffer(item.description);
      if (hasMultipleItems && item.quantity != 1) {
        desc.write(' (${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} × $sym${item.rate.toStringAsFixed(2)})');
      }
      rows.add(pw.TableRow(children: [
        _profCell(desc.toString(), align: pw.TextAlign.left),
        _profCell('$sym${item.subtotal.toStringAsFixed(2)}', align: pw.TextAlign.right),
      ]));
    }
    // Discount / Tax / Grand total
    if (inv.totalDiscount > 0) {
      rows.add(pw.TableRow(children: [
        _profCell('Discount', align: pw.TextAlign.right),
        _profCell('-$sym${inv.totalDiscount.toStringAsFixed(2)}', align: pw.TextAlign.right),
      ]));
    }
    if (inv.totalTax > 0) {
      for (final lv in _gstTaxLabelValues(inv, profile, sym)) {
        rows.add(pw.TableRow(children: [
          _profCell(lv.$1, align: pw.TextAlign.right),
          _profCell(lv.$2, align: pw.TextAlign.right),
        ]));
      }
    }
    rows.add(pw.TableRow(
      decoration: pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        _profCell('Grand Total', bold: true, align: pw.TextAlign.right),
        _profCell('$sym${inv.grandTotal.toStringAsFixed(2)}', bold: true, align: pw.TextAlign.right),
      ],
    ));
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FixedColumnWidth(90),
      },
      children: rows,
    );
  }

  static pw.Widget _profCell(String text,
      {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(text,
          textAlign: align,
          style: bold
              ? pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)
              : const pw.TextStyle(fontSize: 10)),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // AMOUNT IN WORDS (Indian number system)
  // ─────────────────────────────────────────────────────────────

  static String _amountInWords(double amount) {
    final rupees = amount.truncate();
    final paise = ((amount - rupees) * 100).round();
    final words = _rupeeWords(rupees);
    if (paise > 0) {
      return '$words and ${_rupeeWords(paise)} Paise Only';
    }
    return '$words Only/-';
  }

  static final _ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen'
  ];
  static final _tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
  ];

  static String _twoDigits(int n) {
    if (n < 20) return _ones[n];
    return '${_tens[n ~/ 10]}${n % 10 > 0 ? ' ${_ones[n % 10]}' : ''}';
  }

  static String _threeDigits(int n) {
    if (n >= 100) {
      final rem = n % 100;
      return '${_ones[n ~/ 100]} Hundred${rem > 0 ? ' ${_twoDigits(rem)}' : ''}';
    }
    return _twoDigits(n);
  }

  static String _rupeeWords(int n) {
    if (n == 0) return 'Zero';
    final parts = <String>[];
    final crore = n ~/ 10000000;
    if (crore > 0) parts.add('${_threeDigits(crore)} Crore');
    n %= 10000000;
    final lakh = n ~/ 100000;
    if (lakh > 0) parts.add('${_twoDigits(lakh)} Lakh');
    n %= 100000;
    final thousand = n ~/ 1000;
    if (thousand > 0) parts.add('${_twoDigits(thousand)} Thousand');
    n %= 1000;
    if (n > 0) parts.add(_threeDigits(n));
    return parts.join(' ');
  }

  // ─────────────────────────────────────────────────────────────
  // CLIENT SECTION
  // ─────────────────────────────────────────────────────────────

  static pw.Widget _clientBox(Client client) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('BILL TO',
              style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.5,
                  color: PdfColors.grey500)),
          pw.SizedBox(height: 6),
          ..._clientLines(client),
        ],
      ),
    );
  }

  static List<pw.Widget> _clientLines(Client client) {
    final hasCompany = client.companyName?.isNotEmpty == true;
    final lines = <pw.Widget>[
      pw.Text(
        hasCompany ? client.companyName! : client.name,
        style: pw.TextStyle(
            fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
    ];
    if (hasCompany && client.name.isNotEmpty) {
      lines.add(_grayLine(client.name));
    }
    if (client.phone.isNotEmpty) { lines.add(_grayLine(client.phone)); }
    if (client.email.isNotEmpty) { lines.add(_grayLine(client.email)); }
    if (client.address.isNotEmpty) { lines.add(_grayLine(client.address)); }
    final cityState = [client.city, client.state]
        .where((s) => s.isNotEmpty)
        .join(', ');
    if (cityState.isNotEmpty) lines.add(_grayLine(cityState));
    final countryPost = [client.country, client.postalCode]
        .where((s) => s.isNotEmpty)
        .join(' – ');
    if (countryPost.isNotEmpty) lines.add(_grayLine(countryPost));
    if (client.gstin?.isNotEmpty == true) {
      lines.add(_grayLine('GSTIN: ${client.gstin}'));
    }
    return lines;
  }

  // ─────────────────────────────────────────────────────────────
  // MISC HELPERS
  // ─────────────────────────────────────────────────────────────

  static List<pw.Widget> _profileAddressLines(BusinessProfile p) {
    final f = p.headerFields;
    final lines = <pw.Widget>[];
    if (f.contains(kHeaderAddress)) {
      if (p.address.isNotEmpty) lines.add(_grayLine(p.address));
      final cs = [p.city, p.state].where((s) => s.isNotEmpty).join(', ');
      if (cs.isNotEmpty) lines.add(_grayLine(cs));
    }
    if (f.contains(kHeaderEmail) && p.email.isNotEmpty) {
      lines.add(_grayLine(p.email));
    }
    if (f.contains(kHeaderGstin) && p.gstin?.isNotEmpty == true) {
      lines.add(_grayLine('GSTIN: ${p.gstin}'));
    }
    if (f.contains(kHeaderWebsite) && p.website?.isNotEmpty == true) {
      lines.add(_grayLine(p.website!));
    }
    return lines;
  }

  static pw.Widget _grayLine(String text) => pw.Text(text,
      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700));

  static pw.Widget _kv(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(label,
              style: const pw.TextStyle(
                  fontSize: 9, color: PdfColors.grey600)),
          pw.SizedBox(width: 6),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _kvLight(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Text('$label  ',
              style: const pw.TextStyle(
                  fontSize: 9, color: PdfColors.grey500)),
          pw.Text(value,
              style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  static pw.Widget _kvWhite(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: const pw.TextStyle(
                  fontSize: 9, color: PdfColors.grey300)),
          pw.SizedBox(width: 16),
          pw.Text(value,
              style: const pw.TextStyle(
                  fontSize: 9, color: PdfColors.white)),
        ],
      ),
    );
  }

  static pw.Widget _tealKv(String label, String value, PdfColor teal) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: teal)),
        pw.Text(value,
            style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  static List<pw.Widget> _notesTerms(Invoice inv) {
    final out = <pw.Widget>[];
    if (inv.notes?.isNotEmpty == true) {
      out.addAll([
        pw.SizedBox(height: 20),
        pw.Text('Notes',
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.SizedBox(height: 4),
        pw.Text(inv.notes!,
            style: const pw.TextStyle(
                fontSize: 9, color: PdfColors.grey700)),
      ]);
    }
    if (inv.terms?.isNotEmpty == true) {
      out.addAll([
        pw.SizedBox(height: 12),
        pw.Text('Terms & Conditions',
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.SizedBox(height: 4),
        pw.Text(inv.terms!,
            style: const pw.TextStyle(
                fontSize: 9, color: PdfColors.grey700)),
      ]);
    }
    return out;
  }

  static pw.Widget _centeredFooter(BusinessProfile profile) {
    if (!profile.showThankYouMessage) {
      return pw.SizedBox.shrink();
    }
    return pw.Center(
      child: pw.Text(profile.thankYouMessage,
          style: const pw.TextStyle(
              fontSize: 9, color: PdfColors.grey400)),
    );
  }

  static pw.Widget _brandingFooter() {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6),
      child: pw.Center(
        child: pw.Text('Generated by Invoice Generator',
            style: const pw.TextStyle(
                fontSize: 7, color: PdfColors.grey300)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // UNVERIFIED DISCLAIMER BANNER
  // ─────────────────────────────────────────────────────────────

  static pw.Widget _unverifiedDisclaimer() {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 16),
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: const PdfColor(1.0, 0.95, 0.85),
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(
            color: const PdfColor(0.85, 0.55, 0.05), width: 0.75),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 14,
            height: 14,
            decoration: pw.BoxDecoration(
              color: const PdfColor(0.70, 0.35, 0.00),
              borderRadius: pw.BorderRadius.circular(2),
            ),
            alignment: pw.Alignment.center,
            child: pw.Text('!',
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Text(
              'UNVERIFIED BUSINESS: This invoice was generated by a business '
              'that has not completed identity verification with Invoice Generator. '
              'Please verify the issuer\'s credentials independently before making any payment.',
              style: const pw.TextStyle(
                  fontSize: 8, color: PdfColor(0.45, 0.25, 0.00)),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PAYMENT DETAILS + SIGNATURE SECTION (bottom of every invoice)
  // ─────────────────────────────────────────────────────────────

  static List<pw.Widget> _paymentAndSignatureSection(
      BusinessProfile profile) {
    final showPayment = profile.showPaymentDetailsOnInvoice;

    final bankMethods = showPayment
        ? profile.paymentMethods
            .where((m) => m.type == PaymentMethodType.bankAccount)
            .toList()
        : <PaymentMethod>[];

    PaymentMethod? upiMethod;
    if (showPayment) {
      for (final m in profile.paymentMethods) {
        if (m.type == PaymentMethodType.upi &&
            m.upiId?.isNotEmpty == true) {
          upiMethod = m;
          break;
        }
      }
    }

    final hasPayment = bankMethods.isNotEmpty || upiMethod != null;
    final signatureImage = _decodeLogo(profile.signatureBase64);

    if (!hasPayment && signatureImage == null) return [];

    final qrData = upiMethod != null
        ? 'upi://pay?pa=${upiMethod.upiId!}'
            '&pn=${Uri.encodeComponent(profile.name)}&cu=INR'
        : null;

    final rightWidget = (qrData != null || signatureImage != null)
        ? pw.Container(
            width: 110,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (qrData != null) ...[
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrData,
                    width: 72,
                    height: 72,
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text('Scan to Pay',
                      style: const pw.TextStyle(
                          fontSize: 7, color: PdfColors.grey500)),
                  pw.SizedBox(height: 10),
                ],
                if (signatureImage != null) ...[
                  pw.Image(signatureImage,
                      width: 100, height: 44, fit: pw.BoxFit.contain),
                  pw.SizedBox(height: 3),
                  pw.Container(
                    width: 100,
                    child: pw.Divider(
                        thickness: 0.5, color: PdfColors.grey400),
                  ),
                  pw.Text('Authorized Signatory',
                      style: const pw.TextStyle(
                          fontSize: 7, color: PdfColors.grey500)),
                ],
              ],
            ),
          )
        : null;

    return [
      pw.SizedBox(height: 20),
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey50,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (hasPayment)
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PAYMENT DETAILS',
                        style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1.5,
                            color: PdfColors.grey600)),
                    pw.SizedBox(height: 8),
                    for (final m in bankMethods) ...[
                      if (m.bankName?.isNotEmpty == true)
                        _grayLine('Bank: ${m.bankName}'),
                      if (m.accountHolder?.isNotEmpty == true)
                        _grayLine('A/C Holder: ${m.accountHolder}'),
                      if (m.accountNumber?.isNotEmpty == true)
                        _grayLine('A/C No: ${m.accountNumber}'),
                      if (m.ifscCode?.isNotEmpty == true)
                        _grayLine('IFSC: ${m.ifscCode}'),
                      pw.SizedBox(height: 6),
                    ],
                    if (upiMethod != null)
                      _grayLine('UPI: ${upiMethod.upiId}'),
                  ],
                ),
              ),
            if (hasPayment && rightWidget != null)
              pw.SizedBox(width: 16),
            ?rightWidget,
          ],
        ),
      ),
    ];
  }

  // ─────────────────────────────────────────────────────────────
  // TEMPLATE 8 — GST BILL
  // Full GST-compliant tax invoice: HSN/SAC column · CGST/SGST/IGST
  // summary table · reverse-charge declaration · amount in words
  // ─────────────────────────────────────────────────────────────
  static Future<Uint8List> _buildGstBill(
      Invoice invoice, BusinessProfile profile, pw.ThemeData theme) async {
    final pdf = pw.Document();
    final sym = Fmt.currencySymbol(invoice.currency);
    final logo = _decodeLogo(profile.logoBase64);
    final signatureImage = _decodeLogo(profile.signatureBase64);
    final saffron = _colorFromHex(
        profile.themeColorHex, const PdfColor(0.90, 0.40, 0.00));
    final saffronLight = PdfColor(
      saffron.red * 0.08 + 0.92,
      saffron.green * 0.08 + 0.92,
      saffron.blue * 0.08 + 0.92,
    );
    const dark = PdfColor(0.13, 0.13, 0.13);

    final supplyType = getSupplyType(profile.gstin, invoice.placeOfSupply);
    final isInter = supplyType == GstSupplyType.interState;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 32),
      theme: theme,
      build: (ctx) => [
        // ── Outer border ────────────────────────────────────────
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: saffron, width: 1.2),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Title bar ──────────────────────────────────────
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 7),
                decoration: pw.BoxDecoration(
                  color: saffron,
                  borderRadius: const pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(3),
                    topRight: pw.Radius.circular(3),
                  ),
                ),
                child: pw.Center(
                  child: pw.Text('TAX INVOICE',
                      style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          letterSpacing: 3)),
                ),
              ),

              // ── Supplier + Buyer row ───────────────────────────
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(color: saffron, width: 0.8)),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Supplier (left)
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border(
                              right: pw.BorderSide(
                                  color: saffron, width: 0.8)),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('SUPPLIER',
                                style: pw.TextStyle(
                                    fontSize: 7,
                                    fontWeight: pw.FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: saffron)),
                            pw.SizedBox(height: 5),
                            if (logo != null &&
                                profile.headerFields.contains(kHeaderLogo))
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(bottom: 6),
                                child: pw.Image(logo,
                                    width: 80,
                                    height: 36,
                                    fit: pw.BoxFit.contain),
                              ),
                            if (profile.headerFields.contains(kHeaderName))
                              pw.Text(
                                profile.name.isNotEmpty
                                    ? profile.name
                                    : 'Your Business',
                                style: pw.TextStyle(
                                    fontSize: 12,
                                    fontWeight: pw.FontWeight.bold,
                                    color: dark),
                              ),
                            pw.SizedBox(height: 3),
                            ..._gstAddressLines(profile),
                            if (profile.gstin?.isNotEmpty == true) ...[
                              pw.SizedBox(height: 4),
                              _gstInfoRow('GSTIN', profile.gstin!),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // Buyer (right)
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('BUYER / BILL TO',
                                style: pw.TextStyle(
                                    fontSize: 7,
                                    fontWeight: pw.FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: saffron)),
                            pw.SizedBox(height: 5),
                            if (invoice.client != null) ...[
                              pw.Text(
                                invoice.client!.companyName?.isNotEmpty ==
                                        true
                                    ? invoice.client!.companyName!
                                    : invoice.client!.name,
                                style: pw.TextStyle(
                                    fontSize: 11,
                                    fontWeight: pw.FontWeight.bold,
                                    color: dark),
                              ),
                              ..._clientGstLines(invoice.client!),
                            ] else
                              pw.Text('—',
                                  style: const pw.TextStyle(
                                      fontSize: 10,
                                      color: PdfColors.grey500)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Invoice meta row ───────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10, vertical: 7),
                decoration: pw.BoxDecoration(
                  color: saffronLight,
                  border: pw.Border(
                      bottom: pw.BorderSide(color: saffron, width: 0.8)),
                ),
                child: pw.Row(
                  children: [
                    _metaCell('Invoice No.', invoice.invoiceNumber),
                    _metaDivider(saffron),
                    _metaCell(
                        'Invoice Date', Fmt.date(invoice.invoiceDate)),
                    _metaDivider(saffron),
                    _metaCell('Due Date', Fmt.date(invoice.dueDate)),
                    _metaDivider(saffron),
                    _metaCell('Place of Supply',
                        invoice.placeOfSupply ?? '—'),
                    _metaDivider(saffron),
                    _metaCell('Reverse Charge',
                        invoice.reverseCharge ? 'Yes' : 'No'),
                  ],
                ),
              ),

              // ── Items table ────────────────────────────────────
              _gstItemTable(invoice, sym, saffron, saffronLight,
                  isInter: isInter),

              // ── GST summary table ──────────────────────────────
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                      top: pw.BorderSide(color: saffron, width: 0.8)),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Tax breakdown (left 60%)
                    pw.Expanded(
                      flex: 6,
                      child: pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border(
                              right: pw.BorderSide(
                                  color: saffron, width: 0.8)),
                        ),
                        child: _gstSummaryTable(
                            invoice, sym, saffron, saffronLight,
                            isInter: isInter),
                      ),
                    ),
                    // Grand total box (right 40%)
                    pw.Expanded(
                      flex: 4,
                      child: _gstTotalsBox(
                          invoice, sym, saffron, saffronLight,
                          isInter: isInter),
                    ),
                  ],
                ),
              ),

              // ── Amount in words ────────────────────────────────
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: saffronLight,
                  border: pw.Border(
                    top: pw.BorderSide(color: saffron, width: 0.8),
                    bottom: pw.BorderSide(color: saffron, width: 0.8),
                  ),
                ),
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                          text: 'Amount in Words:  ',
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: dark)),
                      pw.TextSpan(
                          text: _amountInWords(invoice.grandTotal),
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey800)),
                    ],
                  ),
                ),
              ),

              // ── Notes / Terms / Declaration ────────────────────
              pw.Padding(
                padding: const pw.EdgeInsets.all(10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (invoice.notes?.isNotEmpty == true) ...[
                      pw.Text('Notes',
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: saffron)),
                      pw.SizedBox(height: 2),
                      pw.Text(invoice.notes!,
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey700)),
                      pw.SizedBox(height: 8),
                    ],
                    if (invoice.terms?.isNotEmpty == true) ...[
                      pw.Text('Terms & Conditions',
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: saffron)),
                      pw.SizedBox(height: 2),
                      pw.Text(invoice.terms!,
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey700)),
                      pw.SizedBox(height: 8),
                    ],
                    // Reverse charge declaration
                    pw.Text(
                      'Whether the tax is payable on Reverse Charge basis: '
                      '${invoice.reverseCharge ? "YES" : "NO"}',
                      style: const pw.TextStyle(
                          fontSize: 7.5, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ),

              // ── Signature footer ───────────────────────────────
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: saffronLight,
                  border: pw.Border(
                      top: pw.BorderSide(color: saffron, width: 0.8)),
                ),
                padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'This is a computer-generated invoice.',
                      style: const pw.TextStyle(
                          fontSize: 7, color: PdfColors.grey500),
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        if (signatureImage != null) ...[
                          pw.Image(signatureImage,
                              width: 90,
                              height: 36,
                              fit: pw.BoxFit.contain),
                          pw.SizedBox(height: 3),
                        ],
                        pw.Container(
                          width: 120,
                          child: pw.Divider(
                              thickness: 0.6, color: PdfColors.grey500),
                        ),
                        pw.Text(
                          profile.name.isNotEmpty
                              ? 'For ${profile.name}'
                              : 'Authorised Signatory',
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: dark),
                        ),
                        pw.Text('Authorised Signatory',
                            style: const pw.TextStyle(
                                fontSize: 7, color: PdfColors.grey500)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (profile.verificationStatus != VerificationStatus.verified)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10),
            child: _unverifiedDisclaimer(),
          ),
        _brandingFooter(),
      ],
    ));
    return pdf.save();
  }

  // ── GST Bill helpers ─────────────────────────────────────────

  static pw.Widget _gstItemTable(Invoice inv, String sym, PdfColor saffron,
      PdfColor saffronLight, {bool isInter = false}) {
    // Columns: # | Description (HSN/SAC) | Qty | Rate | Taxable | Tax% | Tax Amt | Total
    final rows = <pw.TableRow>[];

    // Header
    rows.add(pw.TableRow(
      decoration: pw.BoxDecoration(color: saffron),
      children: [
        _gstTh('#'),
        _gstTh('Description / HSN-SAC', flex: true),
        _gstTh('Qty'),
        _gstTh('Rate', right: true),
        _gstTh('Taxable\nValue', right: true),
        if (!isInter) ...[
          _gstTh('CGST\n%', right: true),
          _gstTh('CGST\nAmt', right: true),
          _gstTh('SGST\n%', right: true),
          _gstTh('SGST\nAmt', right: true),
        ] else ...[
          _gstTh('IGST\n%', right: true),
          _gstTh('IGST\nAmt', right: true),
        ],
        _gstTh('Total', right: true),
      ],
    ));

    // Item rows
    for (int i = 0; i < inv.items.length; i++) {
      final item = inv.items[i];
      final bg = i.isEven ? PdfColors.white : saffronLight;
      final split =
          computeTaxSplit(item.taxableAmount, item.taxPercent, isInter
              ? GstSupplyType.interState
              : GstSupplyType.intraState);

      rows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: bg),
        children: [
          _gstTd('${i + 1}'),
          _gstTdDesc(item.description, item.hsnSac),
          _gstTd('${_fmtQty(item.quantity)} ${item.unit}'),
          _gstTd('$sym${item.rate.toStringAsFixed(2)}', right: true),
          _gstTd('$sym${item.taxableAmount.toStringAsFixed(2)}',
              right: true),
          if (!isInter) ...[
            _gstTd('${_formatRate(split.cgstRate)}%', right: true),
            _gstTd('$sym${split.cgstAmount.toStringAsFixed(2)}',
                right: true),
            _gstTd('${_formatRate(split.sgstRate)}%', right: true),
            _gstTd('$sym${split.sgstAmount.toStringAsFixed(2)}',
                right: true),
          ] else ...[
            _gstTd('${_formatRate(split.igstRate)}%', right: true),
            _gstTd('$sym${split.igstAmount.toStringAsFixed(2)}',
                right: true),
          ],
          _gstTd('$sym${item.total.toStringAsFixed(2)}', right: true),
        ],
      ));
    }

    final colWidths = isInter
        ? <int, pw.TableColumnWidth>{
            0: const pw.FixedColumnWidth(20),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FixedColumnWidth(50),
            3: const pw.FixedColumnWidth(52),
            4: const pw.FixedColumnWidth(56),
            5: const pw.FixedColumnWidth(36),
            6: const pw.FixedColumnWidth(52),
            7: const pw.FixedColumnWidth(56),
          }
        : <int, pw.TableColumnWidth>{
            0: const pw.FixedColumnWidth(20),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FixedColumnWidth(46),
            3: const pw.FixedColumnWidth(48),
            4: const pw.FixedColumnWidth(52),
            5: const pw.FixedColumnWidth(32),
            6: const pw.FixedColumnWidth(46),
            7: const pw.FixedColumnWidth(32),
            8: const pw.FixedColumnWidth(46),
            9: const pw.FixedColumnWidth(52),
          };

    return pw.Table(
      border: pw.TableBorder.symmetric(
        inside: pw.BorderSide(color: saffron, width: 0.4),
      ),
      columnWidths: colWidths,
      children: rows,
    );
  }

  static pw.Widget _gstSummaryTable(Invoice inv, String sym, PdfColor saffron,
      PdfColor saffronLight, {bool isInter = false}) {
    // Group items by tax rate
    final Map<double, ({double taxable, double cgst, double sgst, double igst})>
        groups = {};
    for (final item in inv.items) {
      if (item.taxPercent <= 0) continue;
      final split = computeTaxSplit(
          item.taxableAmount,
          item.taxPercent,
          isInter ? GstSupplyType.interState : GstSupplyType.intraState);
      final existing = groups[item.taxPercent];
      groups[item.taxPercent] = (
        taxable: (existing?.taxable ?? 0) + item.taxableAmount,
        cgst: (existing?.cgst ?? 0) + split.cgstAmount,
        sgst: (existing?.sgst ?? 0) + split.sgstAmount,
        igst: (existing?.igst ?? 0) + split.igstAmount,
      );
    }

    final rows = <pw.TableRow>[];
    // Header
    rows.add(pw.TableRow(
      decoration: pw.BoxDecoration(color: saffron),
      children: [
        _gstTh('Tax Rate'),
        _gstTh('Taxable\nValue', right: true),
        if (!isInter) ...[
          _gstTh('CGST\nAmt', right: true),
          _gstTh('SGST\nAmt', right: true),
        ] else
          _gstTh('IGST\nAmt', right: true),
        _gstTh('Total Tax', right: true),
      ],
    ));

    if (groups.isEmpty) {
      rows.add(pw.TableRow(children: [
        _gstTd('0% (Nil rated)', cols: isInter ? 4 : 5),
        _gstTd('$sym${inv.subtotal.toStringAsFixed(2)}', right: true),
        if (!isInter) ...[_gstTd('—', right: true), _gstTd('—', right: true)],
        _gstTd('$sym 0.00', right: true),
      ]));
    } else {
      for (final entry in groups.entries) {
        final rate = entry.key;
        final g = entry.value;
        rows.add(pw.TableRow(children: [
          _gstTd('${_formatRate(rate)}%'),
          _gstTd('$sym${g.taxable.toStringAsFixed(2)}', right: true),
          if (!isInter) ...[
            _gstTd('$sym${g.cgst.toStringAsFixed(2)}', right: true),
            _gstTd('$sym${g.sgst.toStringAsFixed(2)}', right: true),
          ] else
            _gstTd('$sym${g.igst.toStringAsFixed(2)}', right: true),
          _gstTd(
              '$sym${(g.cgst + g.sgst + g.igst).toStringAsFixed(2)}',
              right: true),
        ]));
      }
    }

    return pw.Table(
      border: pw.TableBorder.symmetric(
          inside: pw.BorderSide(color: saffron, width: 0.4)),
      children: rows,
    );
  }

  static pw.Widget _gstTotalsBox(Invoice inv, String sym, PdfColor saffron,
      PdfColor saffronLight, {bool isInter = false}) {
    final taxItems = inv.items
        .where((i) => i.taxPercent > 0)
        .map((i) => (taxableAmount: i.taxableAmount, taxPercent: i.taxPercent))
        .toList();
    final gst = computeInvoiceGst(
        taxItems,
        isInter ? GstSupplyType.interState : GstSupplyType.intraState);

    return pw.Padding(
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _gstAmtRow('Subtotal', '$sym${inv.subtotal.toStringAsFixed(2)}'),
          if (inv.totalDiscount > 0)
            _gstAmtRow('Discount (-)',
                '$sym${inv.totalDiscount.toStringAsFixed(2)}',
                color: PdfColors.red700),
          if (!isInter) ...[
            if (gst.totalCgst > 0)
              _gstAmtRow('CGST', '$sym${gst.totalCgst.toStringAsFixed(2)}'),
            if (gst.totalSgst > 0)
              _gstAmtRow(
                  'SGST/UTGST', '$sym${gst.totalSgst.toStringAsFixed(2)}'),
          ] else
            if (gst.totalIgst > 0)
              _gstAmtRow('IGST', '$sym${gst.totalIgst.toStringAsFixed(2)}'),
          pw.SizedBox(height: 4),
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: pw.BoxDecoration(
              color: saffron,
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('GRAND TOTAL',
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
                pw.Text('$sym${inv.grandTotal.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _gstAmtRow(String label, String value,
      {PdfColor color = PdfColors.grey800}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(fontSize: 8, color: color)),
          pw.Text(value,
              style: pw.TextStyle(fontSize: 8, color: color)),
        ],
      ),
    );
  }

  static pw.Widget _metaCell(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: const pw.TextStyle(
                  fontSize: 7, color: PdfColors.grey600)),
          pw.SizedBox(height: 1),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _metaDivider(PdfColor color) => pw.Container(
        width: 0.6,
        height: 28,
        color: color.withAlpha(0.4),
        margin: const pw.EdgeInsets.symmetric(horizontal: 6),
      );

  static List<pw.Widget> _gstAddressLines(BusinessProfile p) {
    final lines = <pw.Widget>[];
    if (p.address.isNotEmpty) {
      lines.add(pw.Text(p.address,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)));
    }
    final cs =
        [p.city, p.state].where((s) => s.isNotEmpty).join(', ');
    if (cs.isNotEmpty) {
      lines.add(pw.Text(cs,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)));
    }
    if (p.phone.isNotEmpty) {
      lines.add(pw.Text('Ph: ${p.phone}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)));
    }
    if (p.email.isNotEmpty) {
      lines.add(pw.Text(p.email,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)));
    }
    return lines;
  }

  static List<pw.Widget> _clientGstLines(Client client) {
    final lines = <pw.Widget>[];
    if (client.companyName?.isNotEmpty == true && client.name.isNotEmpty) {
      lines.add(pw.Text(client.name,
          style: const pw.TextStyle(
              fontSize: 8, color: PdfColors.grey700)));
    }
    if (client.address.isNotEmpty) {
      lines.add(pw.Text(client.address,
          style: const pw.TextStyle(
              fontSize: 8, color: PdfColors.grey700)));
    }
    final cs =
        [client.city, client.state].where((s) => s.isNotEmpty).join(', ');
    if (cs.isNotEmpty) {
      lines.add(pw.Text(cs,
          style: const pw.TextStyle(
              fontSize: 8, color: PdfColors.grey700)));
    }
    if (client.gstin?.isNotEmpty == true) {
      lines.add(pw.SizedBox(height: 4));
      lines.add(_gstInfoRow('GSTIN', client.gstin!));
    }
    return lines;
  }

  static pw.Widget _gstInfoRow(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: pw.BoxDecoration(
        color: const PdfColor(0.95, 0.95, 0.95),
        borderRadius: pw.BorderRadius.circular(2),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
                text: '$label: ',
                style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700)),
            pw.TextSpan(
                text: value,
                style: const pw.TextStyle(
                    fontSize: 8, color: PdfColors.grey900)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _gstTh(String text,
      {bool flex = false, bool right = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(text,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white)),
    );
  }

  static pw.Widget _gstTd(String text,
      {bool right = false, int cols = 1}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(text,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey900)),
    );
  }

  static pw.Widget _gstTdDesc(String desc, String? hsnSac) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(desc,
              style: const pw.TextStyle(
                  fontSize: 8, color: PdfColors.grey900)),
          if (hsnSac?.isNotEmpty == true)
            pw.Text('HSN/SAC: $hsnSac',
                style: const pw.TextStyle(
                    fontSize: 6.5, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  static String _fmtQty(double qty) =>
      qty % 1 == 0 ? qty.toInt().toString() : qty.toString();

  // ─────────────────────────────────────────────────────────────
  // GST HELPERS
  // ─────────────────────────────────────────────────────────────

  static String _invoiceTitle(BusinessProfile profile) =>
      profile.isGstRegistered ? 'TAX INVOICE' : 'INVOICE';

  static String _formatRate(double r) =>
      r % 1 == 0 ? r.toInt().toString() : r.toStringAsFixed(1);

  // Returns (label, value) pairs for tax rows — CGST+SGST or IGST split when GST registered.
  static List<(String, String)> _gstTaxLabelValues(
      Invoice inv, BusinessProfile profile, String sym) {
    if (!profile.isGstRegistered || inv.totalTax <= 0) {
      return [('Tax', '$sym${inv.totalTax.toStringAsFixed(2)}')];
    }
    final supplyType = getSupplyType(profile.gstin, inv.placeOfSupply);
    final taxItems = inv.items
        .where((i) => i.taxPercent > 0)
        .map((i) => (taxableAmount: i.taxableAmount, taxPercent: i.taxPercent))
        .toList();
    final gst = computeInvoiceGst(taxItems, supplyType);
    final rates = taxItems.map((i) => i.taxPercent).toSet();
    final single = rates.length == 1 ? rates.first : null;

    if (supplyType == GstSupplyType.interState) {
      final lbl = single != null ? 'IGST (${_formatRate(single)}%)' : 'IGST';
      return [(lbl, '$sym${gst.totalIgst.toStringAsFixed(2)}')];
    }
    final half = single != null ? single / 2 : null;
    final cLbl = half != null ? 'CGST (${_formatRate(half)}%)' : 'CGST';
    final sLbl = half != null ? 'SGST/UTGST (${_formatRate(half)}%)' : 'SGST/UTGST';
    return [
      (cLbl, '$sym${gst.totalCgst.toStringAsFixed(2)}'),
      (sLbl, '$sym${gst.totalSgst.toStringAsFixed(2)}'),
    ];
  }

  // Returns Place of Supply and Reverse Charge meta rows (right-aligned).
  static List<pw.Widget> _gstMetaRows(Invoice inv, BusinessProfile profile) {
    if (!profile.isGstRegistered) return [];
    final rows = <pw.Widget>[];
    if (inv.placeOfSupply?.isNotEmpty == true) {
      rows.add(_kv('Place of Supply', inv.placeOfSupply!));
    }
    if (inv.reverseCharge) {
      rows.add(_kv('Reverse Charge', 'Yes'));
    }
    return rows;
  }

  // Like _gstMetaRows but uses _kvLight style (for minimal template).
  static List<pw.Widget> _gstMetaRowsLight(Invoice inv, BusinessProfile profile) {
    if (!profile.isGstRegistered) return [];
    final rows = <pw.Widget>[];
    if (inv.placeOfSupply?.isNotEmpty == true) {
      rows.add(_kvLight('Place of Supply', inv.placeOfSupply!));
    }
    if (inv.reverseCharge) {
      rows.add(_kvLight('Reverse Charge', 'Yes'));
    }
    return rows;
  }

  // ─────────────────────────────────────────────────────────────
  // TEMPLATE 9 — LETTERHEAD
  // Double-rule contact header · Sr.No/Particulars/Amount ·
  // Client acknowledgment strip · for advocates, CAs, consultants
  // ─────────────────────────────────────────────────────────────
  static Future<Uint8List> _buildLetterhead(
      Invoice invoice, BusinessProfile profile, pw.ThemeData theme) async {
    final pdf = pw.Document();
    final sym = Fmt.currencySymbol(invoice.currency);
    final logo = _decodeLogo(profile.logoBase64);
    final signatureImage = _decodeLogo(profile.signatureBase64);
    final f = profile.headerFields;

    final bankMethods = profile.showPaymentDetailsOnInvoice
        ? profile.paymentMethods
            .where((m) => m.type == PaymentMethodType.bankAccount)
            .toList()
        : <PaymentMethod>[];

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(52, 44, 52, 44),
      theme: theme,
      build: (ctx) => [

        // ── Logo (centered, above name) ──────────────────────────
        if (logo != null && f.contains(kHeaderLogo))
          pw.Center(
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Image(logo, width: 80, height: 50, fit: pw.BoxFit.contain),
            ),
          ),

        // ── Business name (large, centered, UPPERCASE) ───────────
        if (f.contains(kHeaderName))
          pw.Center(
            child: pw.Text(
              profile.name.isNotEmpty ? profile.name.toUpperCase() : 'YOUR BUSINESS',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5),
            ),
          ),
        pw.SizedBox(height: 5),

        // ── Rule 1 ───────────────────────────────────────────────
        pw.Divider(thickness: 1.5, color: PdfColors.black),
        pw.SizedBox(height: 4),

        // ── Contact strip (phone · email · website) ──────────────
        () {
          final parts = <String>[
            if (profile.phone.isNotEmpty) profile.phone,
            if (f.contains(kHeaderEmail) && profile.email.isNotEmpty) profile.email,
            if (f.contains(kHeaderWebsite) && profile.website?.isNotEmpty == true) profile.website!,
          ];
          return parts.isNotEmpty
              ? pw.Center(
                  child: pw.Text(
                    parts.join('          '),
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800),
                  ),
                )
              : pw.SizedBox();
        }(),
        pw.SizedBox(height: 4),

        // ── Rule 2 ───────────────────────────────────────────────
        pw.Divider(thickness: 1.5, color: PdfColors.black),
        pw.SizedBox(height: 14),

        // ── Centered "INVOICE" heading ───────────────────────────
        pw.Center(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 1.5, color: PdfColors.black)),
            ),
            child: pw.Text(
              _invoiceTitle(profile).toUpperCase(),
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, letterSpacing: 4),
            ),
          ),
        ),
        pw.SizedBox(height: 16),

        // ── Two-column meta: business address | invoice meta ──────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left: from block
            pw.Expanded(
              flex: 55,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (f.contains(kHeaderName))
                    pw.Text(
                      profile.name.isNotEmpty ? profile.name.toUpperCase() : '',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                    ),
                  if (f.contains(kHeaderAddress)) ...[
                    if (profile.address.isNotEmpty)
                      pw.Text('Add.: ${profile.address}',
                          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
                    () {
                      final cs = [profile.city, profile.state, profile.postalCode]
                          .where((s) => s.isNotEmpty).join(', ');
                      return cs.isNotEmpty
                          ? pw.Text(cs, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800))
                          : pw.SizedBox();
                    }(),
                  ],
                  if (profile.phone.isNotEmpty)
                    pw.Text('Contact No.: ${profile.phone}',
                        style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
                  if (f.contains(kHeaderGstin) && profile.gstin?.isNotEmpty == true)
                    pw.Text('GSTIN: ${profile.gstin}',
                        style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            // Right: invoice number, date, due date
            pw.Expanded(
              flex: 45,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Invoice No. ${invoice.invoiceNumber}',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text('Date: ${Fmt.date(invoice.invoiceDate)}',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text('Due Date: ${Fmt.date(invoice.dueDate)}',
                      style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                  if (profile.isGstRegistered && invoice.placeOfSupply?.isNotEmpty == true)
                    pw.Text('Place of Supply: ${invoice.placeOfSupply}',
                        style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 0.5, color: PdfColors.grey600),
        pw.SizedBox(height: 8),

        // ── Client block ─────────────────────────────────────────
        if (invoice.client != null) ...[
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Client Name : ',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      invoice.client!.companyName?.isNotEmpty == true
                          ? invoice.client!.companyName!
                          : invoice.client!.name,
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                    ),
                    if (invoice.client!.address.isNotEmpty)
                      pw.Text(invoice.client!.address,
                          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                    () {
                      final cs = [invoice.client!.city, invoice.client!.state, invoice.client!.country]
                          .where((s) => s.isNotEmpty).join(', ');
                      return cs.isNotEmpty
                          ? pw.Text(cs, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700))
                          : pw.SizedBox();
                    }(),
                  ],
                ),
              ),
            ],
          ),
          // "Kind Attention" line when company has a contact person
          if (invoice.client!.companyName?.isNotEmpty == true && invoice.client!.name.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 3),
              child: pw.Row(
                children: [
                  pw.Text('Kind Attention : ',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text(invoice.client!.name,
                      style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ),
          pw.SizedBox(height: 8),
        ],

        // ── Subject ──────────────────────────────────────────────
        if (invoice.subject?.isNotEmpty == true) ...[
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Sub: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Expanded(
                child: pw.Text(invoice.subject!,
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
        ],

        // ── Items table: Sr.No | Particulars | Amount ─────────────
        _letterheadTable(invoice, sym, profile),
        pw.SizedBox(height: 6),

        // ── Amount in words ──────────────────────────────────────
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(width: 0.5, color: PdfColors.grey500),
              bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey500),
            ),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Text(
                  'Amount in words: ${_amountInWords(invoice.grandTotal)}',
                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 16),

        // ── Notes ────────────────────────────────────────────────
        if (invoice.notes?.isNotEmpty == true) ...[
          pw.Text(invoice.notes!,
              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
          pw.SizedBox(height: 12),
        ],

        // ── Client acknowledgment strip ───────────────────────────
        if (profile.showClientAcknowledgment)
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Client Receipt / Acknowledgment: ',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(children: [
                        pw.Text('Name: ', style: const pw.TextStyle(fontSize: 9)),
                        pw.Expanded(child: pw.Divider(thickness: 0.5, color: PdfColors.grey500)),
                      ]),
                      pw.SizedBox(height: 10),
                      pw.Row(children: [
                        pw.Text('Signature: ', style: const pw.TextStyle(fontSize: 9)),
                        pw.Expanded(child: pw.Divider(thickness: 0.5, color: PdfColors.grey500)),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        pw.SizedBox(height: 20),

        // ── Bank details (left) | Signature (right) ───────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            // Bank details
            pw.Expanded(
              child: bankMethods.isEmpty
                  ? pw.SizedBox()
                  : pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Bank Details:',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        ...bankMethods.expand((m) {
                          final lines = <pw.Widget>[];
                          if (m.bankName?.isNotEmpty == true) {
                            lines.add(_grayLine('Bank: ${m.bankName}'));
                          }
                          if (m.accountHolder?.isNotEmpty == true) {
                            lines.add(_grayLine('Account Holder: ${m.accountHolder}'));
                          }
                          if (m.accountNumber?.isNotEmpty == true) {
                            lines.add(_grayLine('Account No.: ${m.accountNumber}'));
                          }
                          if (m.ifscCode?.isNotEmpty == true) {
                            lines.add(_grayLine('IFSC CODE: ${m.ifscCode}'));
                          }
                          return lines;
                        }),
                      ],
                    ),
            ),
            // Signature block
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (signatureImage != null) ...[
                  pw.Image(signatureImage, width: 100, height: 45, fit: pw.BoxFit.contain),
                  pw.SizedBox(height: 2),
                ],
                pw.Container(
                  width: 130,
                  child: pw.Divider(thickness: 0.8, color: PdfColors.black),
                ),
                pw.Text(
                  profile.name.isNotEmpty ? profile.name : 'Authorized Signatory',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Divider(thickness: 0.5, color: PdfColors.grey500),

        // ── Footer address ────────────────────────────────────────
        if (f.contains(kHeaderAddress) && profile.address.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              [
                'Address: ${profile.address}',
                [profile.city, profile.state, profile.postalCode]
                    .where((s) => s.isNotEmpty).join(', '),
              ].where((s) => s.isNotEmpty).join(', '),
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ),
        ],

        _centeredFooter(profile),
        _brandingFooter(),
      ],
    ));

    return pdf.save();
  }

  // ── Letterhead items table ────────────────────────────────────────────────

  static pw.Widget _letterheadTable(Invoice inv, String sym, BusinessProfile profile) {
    final rows = <pw.TableRow>[];

    // Header row
    rows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        _lhCell('Sr.\nNo.', bold: true, align: pw.TextAlign.center),
        _lhCell('Particulars', bold: true, align: pw.TextAlign.center),
        _lhCell('Amount', bold: true, align: pw.TextAlign.center),
      ],
    ));

    // Item rows
    for (int i = 0; i < inv.items.length; i++) {
      final item = inv.items[i];
      final desc = StringBuffer(item.description);
      // Show rate breakdown if qty > 1 or rate is meaningful
      if (item.quantity != 1 || inv.items.length == 1) {
        if (item.quantity != 1) {
          desc.write(
              '\n(${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity}'
              ' × $sym${item.rate.toStringAsFixed(2)} per unit)');
        }
      }
      rows.add(pw.TableRow(
        children: [
          _lhCell('${i + 1}.', align: pw.TextAlign.center),
          _lhCell(desc.toString(), align: pw.TextAlign.left),
          _lhCell(
            '$sym${item.subtotal.toStringAsFixed(2)}/-',
            align: pw.TextAlign.right,
          ),
        ],
      ));
    }

    // Discount row
    if (inv.totalDiscount > 0) {
      rows.add(pw.TableRow(children: [
        _lhCell('', align: pw.TextAlign.center),
        _lhCell('Discount', align: pw.TextAlign.right),
        _lhCell('-$sym${inv.totalDiscount.toStringAsFixed(2)}', align: pw.TextAlign.right),
      ]));
    }

    // Tax rows
    if (inv.totalTax > 0) {
      for (final lv in _gstTaxLabelValues(inv, profile, sym)) {
        rows.add(pw.TableRow(children: [
          _lhCell('', align: pw.TextAlign.center),
          _lhCell(lv.$1, align: pw.TextAlign.right),
          _lhCell(lv.$2, align: pw.TextAlign.right),
        ]));
      }
    }

    // Total row
    rows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        _lhCell('', align: pw.TextAlign.center),
        _lhCell('Total', bold: true, align: pw.TextAlign.right),
        _lhCell(
          '$sym${inv.grandTotal.toStringAsFixed(2)}/-',
          bold: true,
          align: pw.TextAlign.right,
        ),
      ],
    ));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(32),
        1: pw.FlexColumnWidth(4),
        2: pw.FixedColumnWidth(88),
      },
      children: rows,
    );
  }

  static pw.Widget _lhCell(String text,
      {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: bold
            ? pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)
            : const pw.TextStyle(fontSize: 9.5),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TEMPLATE 10 — LEGAL PRO
  // Logo+info header · Dated/Particulars/Amount · for lawyers & advocates
  // ─────────────────────────────────────────────────────────────
  static Future<Uint8List> _buildLegalPro(
      Invoice invoice, BusinessProfile profile, pw.ThemeData theme) async {
    final pdf = pw.Document();
    final sym = Fmt.currencySymbol(invoice.currency);
    final logo = _decodeLogo(profile.logoBase64);
    final signatureImage = _decodeLogo(profile.signatureBase64);
    final f = profile.headerFields;

    final bankMethods = profile.showPaymentDetailsOnInvoice
        ? profile.paymentMethods
            .where((m) => m.type == PaymentMethodType.bankAccount)
            .toList()
        : <PaymentMethod>[];

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(52, 44, 52, 44),
      theme: theme,
      build: (ctx) => [

        // ── Letterhead header box: Logo (left) | separator | Business info (right) ──
        pw.Container(
          // decoration: pw.BoxDecoration(
          //   border: pw.Border.all(color: PdfColors.grey700, width: 0.5),
          // ),
          child: pw.SizedBox(
            height: 82,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Logo on left
                pw.Container(
                  width: 110,
                  padding: const pw.EdgeInsets.all(10),
                  child: logo != null && f.contains(kHeaderLogo)
                      ? pw.Center(
                          child: pw.Image(logo, width: 90, height: 60, fit: pw.BoxFit.contain),
                        )
                      : pw.SizedBox(),
                ),
                // // Vertical separator
                // pw.Container(
                //   width: 0.5,
                //   color: PdfColors.grey700,
                // ),
                // Business info on right
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(12, 10, 10, 10),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (f.contains(kHeaderName))
                          pw.Text(
                            profile.name.isNotEmpty ? profile.name : 'Your Business',
                            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                          ),
                        pw.SizedBox(height: 3),
                        if (f.contains(kHeaderAddress)) ...[
                          () {
                            final parts = [
                              profile.address,
                              profile.city,
                              profile.state,
                              profile.postalCode,
                            ].where((s) => s.isNotEmpty).join(', ');
                            return parts.isNotEmpty
                                ? pw.Text(parts,
                                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800))
                                : pw.SizedBox();
                          }(),
                        ],
                        if (profile.phone.isNotEmpty)
                          pw.Text('Contact : ${profile.phone}',
                              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
                        if (f.contains(kHeaderEmail) && profile.email.isNotEmpty)
                          pw.Text('E-mail : ${profile.email}',
                              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
                        if (f.contains(kHeaderWebsite) && profile.website?.isNotEmpty == true)
                          pw.Text('Web: ${profile.website}',
                              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 14),

        // ── Client block (left) + Invoice meta (right) ───────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 55,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (invoice.client != null) ...[
                    pw.Text(
                      invoice.client!.companyName?.isNotEmpty == true
                          ? invoice.client!.companyName!
                          : invoice.client!.name,
                      style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                    ),
                    if (invoice.client!.companyName?.isNotEmpty == true &&
                        invoice.client!.name.isNotEmpty)
                      pw.Text('"${invoice.client!.name}"',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                    if (invoice.client!.address.isNotEmpty)
                      pw.Text(invoice.client!.address,
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                    () {
                      final parts = [
                        invoice.client!.city,
                        invoice.client!.state,
                        invoice.client!.postalCode,
                      ].where((s) => s.isNotEmpty).join(', ');
                      return parts.isNotEmpty
                          ? pw.Text(parts,
                              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800))
                          : pw.SizedBox();
                    }(),
                  ],
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              flex: 45,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('INVOICE NO:${invoice.invoiceNumber}',
                      style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text(Fmt.date(invoice.invoiceDate),
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                  if (invoice.terms?.isNotEmpty == true) ...[
                    pw.SizedBox(height: 2),
                    pw.Text('Payment terms ${invoice.terms}',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                  ],
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 14),

        // ── "INVOICE" centered heading ───────────────────────────────
        pw.Center(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(width: 1.5, color: PdfColors.black),
              ),
            ),
            child: pw.Text(
              _invoiceTitle(profile).toUpperCase(),
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold, letterSpacing: 4),
            ),
          ),
        ),
        pw.SizedBox(height: 12),

        // ── Subject ──────────────────────────────────────────────────
        if (invoice.subject?.isNotEmpty == true) ...[
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Sub: ',
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
              pw.Expanded(
                child: pw.Text(
                  invoice.subject!,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
        ],

        // ── Items table: DATED | PARTICULARS | CURRENCY IN RUPEES ────
        _legalProTable(invoice, sym, profile),
        pw.SizedBox(height: 20),

        // ── Notes ────────────────────────────────────────────────────
        if (invoice.notes?.isNotEmpty == true) ...[
          pw.Text(invoice.notes!,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 12),
        ],

        // ── Signature block ──────────────────────────────────────────
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (signatureImage != null) ...[
              pw.Image(signatureImage, width: 110, height: 50, fit: pw.BoxFit.contain),
              pw.SizedBox(height: 2),
            ],
            pw.Text(
              profile.name.isNotEmpty ? profile.name : 'Authorized Signatory',
              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Advocate',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ],
        ),
        pw.SizedBox(height: 14),

        // ── PAN NUMBER ───────────────────────────────────────────────
        if (profile.gstin?.isNotEmpty == true) ...[
          pw.Row(
            children: [
              pw.Text('PAN NUMBER – ',
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
              pw.Text(profile.gstin!,
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 10),
        ],

        // ── Bank Details ─────────────────────────────────────────────
        if (bankMethods.isNotEmpty) ...[
          pw.Text('Bank Details',
              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          for (final m in bankMethods) ...[
            if (m.bankName?.isNotEmpty == true)
              pw.Row(children: [
                pw.SizedBox(
                    width: 88,
                    child: pw.Text('Bank Name:',
                        style: const pw.TextStyle(fontSize: 9))),
                pw.Text(m.bankName!, style: const pw.TextStyle(fontSize: 9)),
              ]),
            if (m.accountHolder?.isNotEmpty == true)
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 88),
                child: pw.Text(m.accountHolder!,
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ),
            if (m.accountNumber?.isNotEmpty == true)
              pw.Row(children: [
                pw.SizedBox(
                    width: 88,
                    child: pw.Text('Account No. :',
                        style: const pw.TextStyle(fontSize: 9))),
                pw.Text(m.accountNumber!, style: const pw.TextStyle(fontSize: 9)),
              ]),
            if (m.ifscCode?.isNotEmpty == true)
              pw.Row(children: [
                pw.SizedBox(
                    width: 88,
                    child: pw.Text('IFS Code:',
                        style: const pw.TextStyle(fontSize: 9))),
                pw.Text(m.ifscCode!, style: const pw.TextStyle(fontSize: 9)),
              ]),
            pw.SizedBox(height: 4),
          ],
        ],

        if (profile.verificationStatus != VerificationStatus.verified)
          _unverifiedDisclaimer(),
        _brandingFooter(),
      ],
    ));
    return pdf.save();
  }

  // ── Legal Pro items table ─────────────────────────────────────────────────

  static pw.Widget _legalProTable(Invoice inv, String sym, BusinessProfile profile) {
    final rows = <pw.TableRow>[];
    final dateStr = Fmt.date(inv.invoiceDate);

    // Header row
    rows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        _lpCell('DATED', bold: true, align: pw.TextAlign.center),
        _lpCell('PARTICULARS', bold: true, align: pw.TextAlign.center),
        _lpCell('CURRENCY IN\nRUPEES', bold: true, align: pw.TextAlign.center),
      ],
    ));

    // Item rows
    for (final item in inv.items) {
      rows.add(pw.TableRow(children: [
        _lpCell(dateStr, align: pw.TextAlign.center),
        _lpCell(item.description, align: pw.TextAlign.left),
        _lpCell(item.subtotal.toStringAsFixed(2), align: pw.TextAlign.right),
      ]));
    }

    // Discount row
    if (inv.totalDiscount > 0) {
      rows.add(pw.TableRow(children: [
        _lpCell('', align: pw.TextAlign.center),
        _lpCell('Discount', align: pw.TextAlign.right),
        _lpCell('-${inv.totalDiscount.toStringAsFixed(2)}', align: pw.TextAlign.right),
      ]));
    }

    // Tax rows
    if (inv.totalTax > 0) {
      for (final lv in _gstTaxLabelValues(inv, profile, sym)) {
        rows.add(pw.TableRow(children: [
          _lpCell('', align: pw.TextAlign.center),
          _lpCell(lv.$1, align: pw.TextAlign.right),
          _lpCell(lv.$2, align: pw.TextAlign.right),
        ]));
      }
    }

    // Total row with amount in words
    final wordsUpper = _amountInWords(inv.grandTotal).toUpperCase();
    rows.add(pw.TableRow(children: [
      _lpCell('', align: pw.TextAlign.center),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('TOTAL',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
            pw.Text('($wordsUpper)',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
      _lpCell(inv.grandTotal.toStringAsFixed(2), bold: true, align: pw.TextAlign.right),
    ]));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(60),
        1: pw.FlexColumnWidth(4),
        2: pw.FixedColumnWidth(90),
      },
      children: rows,
    );
  }

  static pw.Widget _lpCell(String text,
      {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: bold
            ? pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)
            : const pw.TextStyle(fontSize: 9.5),
      ),
    );
  }

  static pw.ImageProvider? _decodeLogo(String? base64) {
    if (base64 == null || base64.isEmpty) return null;
    try {
      return pw.MemoryImage(base64Decode(base64));
    } catch (_) {
      return null;
    }
  }
}
