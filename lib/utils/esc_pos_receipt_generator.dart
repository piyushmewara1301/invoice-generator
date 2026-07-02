import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../models/business_profile.dart';
import '../models/invoice.dart';
import 'formatters.dart';
import 'gst_utils.dart';

/// Builds ESC/POS byte commands for printing an [Invoice] on a Bluetooth
/// thermal receipt printer. Mirrors the layout of the thermal PDF template
/// in [PdfGenerator] but renders plain text suitable for 58mm/80mm printers.
class EscPosReceiptGenerator {
  static Future<List<int>> generateInvoiceReceipt(
    Invoice invoice,
    BusinessProfile profile, {
    PaperSize paperSize = PaperSize.mm58,
  }) async {
    final cap = await CapabilityProfile.load();
    final gen = Generator(paperSize, cap);
    var bytes = <int>[];

    String money(double v) {
      final amt = v.toStringAsFixed(2);
      switch (invoice.currency) {
        case 'INR':
          return 'Rs. $amt';
        case 'USD':
          return '\$$amt';
        default:
          return '${Fmt.currencySymbol(invoice.currency)}$amt';
      }
    }

    const center = PosStyles(align: PosAlign.center);
    const centerBold = PosStyles(align: PosAlign.center, bold: true);
    const right = PosStyles(align: PosAlign.right);
    const titleStyle = PosStyles(
      align: PosAlign.center,
      bold: true,
      height: PosTextSize.size2,
      width: PosTextSize.size2,
    );
    const bigTotal = PosStyles(
      bold: true,
      height: PosTextSize.size2,
      width: PosTextSize.size2,
    );

    // ── Header ────────────────────────────────────────────────────
    if (profile.headerFields.contains(kHeaderName)) {
      bytes += gen.text(
        (profile.name.isNotEmpty ? profile.name : 'YOUR BUSINESS')
            .toUpperCase(),
        styles: titleStyle,
      );
      if (profile.address.isNotEmpty) {
        bytes += gen.text(profile.address, styles: center);
      }
      final cityState = [profile.city, profile.state]
          .where((s) => s.isNotEmpty)
          .join(', ');
      if (cityState.isNotEmpty) {
        bytes += gen.text(cityState, styles: center);
      }
      if (profile.phone.isNotEmpty) {
        bytes += gen.text('Phone: ${profile.phone}', styles: center);
      }
    }

    bytes += gen.hr();

    // ── Receipt meta ──────────────────────────────────────────────
    final hh = invoice.invoiceDate.hour.toString().padLeft(2, '0');
    final mm = invoice.invoiceDate.minute.toString().padLeft(2, '0');
    bytes += gen.row([
      PosColumn(text: Fmt.date(invoice.invoiceDate), width: 6),
      PosColumn(text: '$hh:$mm', width: 6, styles: right),
    ]);
    bytes += gen.text('Receipt: ${invoice.invoiceNumber}');

    if (invoice.client != null) {
      bytes += gen.row([
        PosColumn(text: 'Customer:', width: 4),
        PosColumn(
            text: invoice.client!.displayName, width: 8, styles: right),
      ]);
      if (invoice.client!.phone.isNotEmpty) {
        bytes += gen.row([
          PosColumn(text: 'Phone:', width: 4),
          PosColumn(text: invoice.client!.phone, width: 8, styles: right),
        ]);
      }
    }

    bytes += gen.hr(ch: '-');

    // ── Items ─────────────────────────────────────────────────────
    for (final item in invoice.items) {
      final hasQty = profile.showQuantity && item.quantity != 1;
      final qtyStr = item.quantity % 1 == 0
          ? item.quantity.toInt().toString()
          : item.quantity.toString();
      final desc =
          hasQty ? '${qtyStr}x ${item.description}' : item.description;
      bytes += gen.row([
        PosColumn(text: desc, width: 8),
        PosColumn(text: money(item.subtotal), width: 4, styles: right),
      ]);
    }

    bytes += gen.hr(ch: '-');

    // ── Totals ────────────────────────────────────────────────────
    final showTax = invoice.totalTax > 0;
    if (invoice.subtotal != invoice.grandTotal) {
      bytes += gen.row([
        PosColumn(text: 'Subtotal', width: 8),
        PosColumn(text: money(invoice.subtotal), width: 4, styles: right),
      ]);
      if (invoice.totalDiscount > 0) {
        bytes += gen.row([
          PosColumn(text: 'Discount', width: 8),
          PosColumn(
              text: '-${money(invoice.totalDiscount)}',
              width: 4,
              styles: right),
        ]);
      }
      if (showTax) {
        for (final lv in _gstTaxLabelValues(invoice, profile)) {
          bytes += gen.row([
            PosColumn(text: lv.$1, width: 8),
            PosColumn(text: lv.$2, width: 4, styles: right),
          ]);
        }
      }
      bytes += gen.hr(ch: '-');
    }

    bytes += gen.row([
      PosColumn(text: 'TOTAL', width: 6, styles: bigTotal),
      PosColumn(
          text: money(invoice.grandTotal),
          width: 6,
          styles: bigTotal.copyWith(align: PosAlign.right)),
    ]);

    // ── Payments ──────────────────────────────────────────────────
    if (invoice.showPaymentsOnInvoice && invoice.amountPaid > 0) {
      bytes += gen.hr(ch: '-');
      for (final p in invoice.payments) {
        bytes += gen.row([
          PosColumn(
              text: '${p.paymentMethodName ?? 'Paid'} '
                  '(${Fmt.date(p.date)})',
              width: 8),
          PosColumn(text: '-${money(p.amount)}', width: 4, styles: right),
        ]);
      }
      bytes += gen.hr();
      bytes += gen.row([
        PosColumn(text: 'BALANCE DUE', width: 6, styles: bigTotal),
        PosColumn(
            text: money(invoice.amountRemaining),
            width: 6,
            styles: bigTotal.copyWith(align: PosAlign.right)),
      ]);
    }

    // ── Payment method ────────────────────────────────────────────
    if (invoice.paymentMethodName?.isNotEmpty == true) {
      bytes += gen.hr(ch: '-');
      bytes += gen.row([
        PosColumn(text: 'Payment Method', width: 6),
        PosColumn(text: invoice.paymentMethodName!, width: 6, styles: right),
      ]);
    }

    // ── Notes ─────────────────────────────────────────────────────
    if (invoice.notes?.isNotEmpty == true) {
      bytes += gen.hr(ch: '-');
      bytes += gen.text(invoice.notes!, styles: center);
    }

    // ── Footer ────────────────────────────────────────────────────
    bytes += gen.hr();
    if (profile.isGstRegistered && profile.gstin?.isNotEmpty == true) {
      bytes += gen.text('GSTIN: ${profile.gstin}', styles: center);
    }
    if (profile.showThankYouMessage) {
      bytes += gen.text(profile.thankYouMessage, styles: centerBold);
    }

    bytes += gen.cut();
    return bytes;
  }

  /// Returns (label, formatted value) pairs for the tax breakdown — mirrors
  /// the GST-aware logic used in the PDF thermal receipt template.
  static List<(String, String)> _gstTaxLabelValues(
      Invoice inv, BusinessProfile profile) {
    String money(double v) {
      final amt = v.toStringAsFixed(2);
      return inv.currency == 'INR' ? 'Rs. $amt' : '${Fmt.currencySymbol(inv.currency)}$amt';
    }

    if (profile.isCompositionDealer) return [];
    if (!profile.isGstRegistered || inv.totalTax <= 0) {
      return [('Tax', money(inv.totalTax))];
    }
    final supplyType = getSupplyType(profile.gstin, inv.placeOfSupply);
    final taxItems = inv.items
        .where((i) => i.taxPercent > 0)
        .map((i) => (taxableAmount: i.taxableAmount, taxPercent: i.taxPercent))
        .toList();
    final gst = computeInvoiceGst(taxItems, supplyType);

    if (supplyType == GstSupplyType.interState) {
      return [('IGST', money(gst.totalIgst))];
    }
    return [
      ('CGST', money(gst.totalCgst)),
      ('SGST/UTGST', money(gst.totalSgst)),
    ];
  }
}
