import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/invoice.dart';
import '../models/business_profile.dart';

/// Wraps IRP (Invoice Registration Portal) sandbox API.
/// Production endpoint: https://einvoice1.gst.gov.in
/// Sandbox endpoint:    https://einv-apisandbox.nic.in
///
/// Credentials (gstin, username, password, clientId, clientSecret) are
/// obtained from GST portal → E-Invoice → API registration.
class EInvoiceService {
  static const _sandboxBase = 'https://einv-apisandbox.nic.in';

  final String gstin;
  final String username;
  final String password;
  final String clientId;
  final String clientSecret;

  const EInvoiceService({
    required this.gstin,
    required this.username,
    required this.password,
    required this.clientId,
    required this.clientSecret,
  });

  Map<String, dynamic> _buildPayload(Invoice inv, BusinessProfile profile) {
    return {
      'Version': '1.1',
      'TranDtls': {
        'TaxSch': 'GST',
        'SupTyp': 'B2B',
        'RegRev': 'N',
        'IgstOnIntra': 'N',
      },
      'DocDtls': {
        'Typ': 'INV',
        'No': inv.invoiceNumber,
        'Dt': _fmtDate(inv.invoiceDate),
      },
      'SellerDtls': {
        'Gstin': profile.gstin ?? '',
        'LglNm': profile.name,
        'TrdNm': profile.name,
        'Addr1': profile.address,
        'Loc': profile.city,
        'Pin': int.tryParse(profile.postalCode) ?? 0,
        'Stcd': profile.gstStateCode ?? '0',
        'Ph': profile.phone,
        'Em': profile.email,
      },
      'BuyerDtls': {
        'Gstin': inv.client?.gstin ?? 'URP',
        'LglNm': inv.client?.displayName ?? '',
        'TrdNm': inv.client?.companyName ?? inv.client?.displayName ?? '',
        'Pos': profile.gstStateCode ?? '0',
        'Addr1': inv.client?.address ?? '',
        'Loc': inv.client?.city ?? '',
        'Pin': int.tryParse(inv.client?.postalCode ?? '0') ?? 0,
        'Stcd': profile.gstStateCode ?? '0',
        'Ph': inv.client?.phone ?? '',
        'Em': inv.client?.email ?? '',
      },
      'ItemList': inv.items.asMap().entries.map((e) {
        final idx = e.key + 1;
        final it = e.value;
        final hsn = it.hsnSac ?? '0';
        final isService = hsn.startsWith('99') ? 'Y' : 'N';
        return {
          'SlNo': '$idx',
          'PrdDesc': it.description,
          'IsServc': isService,
          'HsnCd': hsn,
          'Qty': it.quantity,
          'Unit': 'NOS',
          'UnitPrice': it.rate,
          'TotAmt': it.subtotal,
          'Discount': it.discountAmount,
          'AssAmt': it.taxableAmount,
          'GstRt': it.taxPercent,
          'IgstAmt': 0.0,
          'CgstAmt': it.taxAmount / 2,
          'SgstAmt': it.taxAmount / 2,
          'CesRt': 0,
          'CesAmt': 0,
          'CesNonAdvlAmt': 0,
          'StateCesRt': 0,
          'StateCesAmt': 0,
          'StateCesNonAdvlAmt': 0,
          'OthChrg': 0,
          'TotItemVal': it.total,
        };
      }).toList(),
      'ValDtls': {
        'AssVal': inv.subtotal,
        'CgstVal': inv.totalTax / 2,
        'SgstVal': inv.totalTax / 2,
        'IgstVal': 0,
        'CesVal': 0,
        'StCesVal': 0,
        'Discount': inv.totalDiscount,
        'OthChrg': 0,
        'RndOffAmt': 0,
        'TotInvVal': inv.grandTotal,
        'TotInvValFc': 0,
      },
    };
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        'gstin': gstin,
        'user_name': username,
        'client_id': clientId,
        'client_secret': clientSecret,
      };

  /// Generates an IRN via the IRP sandbox.
  /// Returns the full API response map on success.
  /// Throws [EInvoiceException] on API or network error.
  Future<Map<String, dynamic>> generateIRN(
      Invoice inv, BusinessProfile profile) async {
    final payload = _buildPayload(inv, profile);
    final response = await http
        .post(
          Uri.parse('$_sandboxBase/eicore/v1.03/Invoice'),
          headers: _headers,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 30));

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && json['Status'] == 1) return json;

    final msg = (json['ErrorDetails'] as List?)
            ?.map((e) => e['ErrorMessage'])
            .join(', ') ??
        json['message'] ??
        'Unknown IRP error (${response.statusCode})';
    throw EInvoiceException(msg);
  }

  /// Cancels a previously generated IRN.
  Future<void> cancelIRN(String irn, String reason) async {
    final response = await http
        .post(
          Uri.parse('$_sandboxBase/eicore/v1.03/Invoice/Cancel'),
          headers: _headers,
          body: jsonEncode({
            'Irn': irn,
            'CnlRsn': '1',
            'CnlRem': reason,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw EInvoiceException('Cancel failed: ${response.statusCode}');
    }
  }
}

class EInvoiceException implements Exception {
  final String message;
  const EInvoiceException(this.message);
  @override
  String toString() => message;
}
