// GST-related helpers: state codes, intra/inter-state detection,
// CGST/SGST/IGST split computation.

// ── State code ↔ name map ─────────────────────────────────────────────────────
// Key: 2-digit GST state code (as String), Value: state/UT name.
const Map<String, String> gstStateCodeToName = {
  '01': 'Jammu & Kashmir',
  '02': 'Himachal Pradesh',
  '03': 'Punjab',
  '04': 'Chandigarh',
  '05': 'Uttarakhand',
  '06': 'Haryana',
  '07': 'Delhi',
  '08': 'Rajasthan',
  '09': 'Uttar Pradesh',
  '10': 'Bihar',
  '11': 'Sikkim',
  '12': 'Arunachal Pradesh',
  '13': 'Nagaland',
  '14': 'Manipur',
  '15': 'Mizoram',
  '16': 'Tripura',
  '17': 'Meghalaya',
  '18': 'Assam',
  '19': 'West Bengal',
  '20': 'Jharkhand',
  '21': 'Odisha',
  '22': 'Chhattisgarh',
  '23': 'Madhya Pradesh',
  '24': 'Gujarat',
  '26': 'Dadra & Nagar Haveli and Daman & Diu',
  '27': 'Maharashtra',
  '28': 'Andhra Pradesh',
  '29': 'Karnataka',
  '30': 'Goa',
  '31': 'Lakshadweep',
  '32': 'Kerala',
  '33': 'Tamil Nadu',
  '34': 'Puducherry',
  '35': 'Andaman & Nicobar Islands',
  '36': 'Telangana',
  '37': 'Andhra Pradesh',
  '38': 'Ladakh',
  '97': 'Other Territory',
  '99': 'Centre Jurisdiction',
};

// Reverse map: state name → GST state code.
final Map<String, String> gstStateNameToCode = {
  for (final e in gstStateCodeToName.entries) e.value: e.key,
};

// All Indian state/UT names for Place of Supply dropdown (alphabetical).
final List<String> indianStatesForGst = (gstStateCodeToName.values.toList()
  ..sort())
    .toList();

// ── GSTIN helpers ─────────────────────────────────────────────────────────────

/// Extracts the 2-digit state code from a GSTIN (first 2 characters).
/// Returns null if GSTIN is empty or too short.
String? extractGstStateCode(String? gstin) {
  if (gstin == null || gstin.length < 2) return null;
  return gstin.substring(0, 2);
}

/// Validates GSTIN format loosely: 15 alphanumeric characters, starts with 2 digits.
bool isValidGstin(String gstin) {
  if (gstin.length != 15) return false;
  return RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z\d]{1}[Z]{1}[A-Z\d]{1}$')
      .hasMatch(gstin.toUpperCase());
}

// ── Supply type ───────────────────────────────────────────────────────────────

enum GstSupplyType { intraState, interState, unknown }

/// Determines supply type by comparing seller's GSTIN state code against
/// the [placeOfSupply] (stored as state name).
GstSupplyType getSupplyType(String? sellerGstin, String? placeOfSupply) {
  if (sellerGstin == null || placeOfSupply == null) return GstSupplyType.unknown;
  final sellerCode = extractGstStateCode(sellerGstin);
  final supplyCode = gstStateNameToCode[placeOfSupply];
  if (sellerCode == null || supplyCode == null) return GstSupplyType.unknown;
  return sellerCode == supplyCode
      ? GstSupplyType.intraState
      : GstSupplyType.interState;
}

// ── Tax split ─────────────────────────────────────────────────────────────────

class GstTaxSplit {
  /// CGST rate (half of tax rate, for intra-state supply).
  final double cgstRate;

  /// SGST/UTGST rate (half of tax rate, for intra-state supply).
  final double sgstRate;

  /// IGST rate (full tax rate, for inter-state supply).
  final double igstRate;

  final double taxableAmount;

  const GstTaxSplit({
    required this.cgstRate,
    required this.sgstRate,
    required this.igstRate,
    required this.taxableAmount,
  });

  double get cgstAmount => taxableAmount * cgstRate / 100;
  double get sgstAmount => taxableAmount * sgstRate / 100;
  double get igstAmount => taxableAmount * igstRate / 100;

  double get totalTax => cgstAmount + sgstAmount + igstAmount;
}

/// Computes CGST/SGST/IGST split for a single taxable amount and tax rate.
GstTaxSplit computeTaxSplit(
    double taxableAmount, double taxPercent, GstSupplyType supplyType) {
  if (supplyType == GstSupplyType.interState) {
    return GstTaxSplit(
      cgstRate: 0,
      sgstRate: 0,
      igstRate: taxPercent,
      taxableAmount: taxableAmount,
    );
  }
  // Intra-state or unknown → CGST + SGST (equal halves).
  final half = taxPercent / 2;
  return GstTaxSplit(
    cgstRate: half,
    sgstRate: half,
    igstRate: 0,
    taxableAmount: taxableAmount,
  );
}

/// Aggregated tax split for an entire invoice.
class InvoiceGstSummary {
  final GstSupplyType supplyType;
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  final double cgstRate; // representative rate (assumes same rate across items)
  final double sgstRate;
  final double igstRate;

  const InvoiceGstSummary({
    required this.supplyType,
    required this.totalCgst,
    required this.totalSgst,
    required this.totalIgst,
    required this.cgstRate,
    required this.sgstRate,
    required this.igstRate,
  });

  double get totalTax => totalCgst + totalSgst + totalIgst;
}

/// Computes the GST summary for a list of line items given the supply type.
/// Items with the same tax rate are grouped; mixed rates are summed individually.
InvoiceGstSummary computeInvoiceGst(
    List<({double taxableAmount, double taxPercent})> items,
    GstSupplyType supplyType) {
  double totalCgst = 0;
  double totalSgst = 0;
  double totalIgst = 0;
  double representativeTaxRate = 0;

  for (final item in items) {
    if (item.taxPercent <= 0) continue;
    final split = computeTaxSplit(item.taxableAmount, item.taxPercent, supplyType);
    totalCgst += split.cgstAmount;
    totalSgst += split.sgstAmount;
    totalIgst += split.igstAmount;
    representativeTaxRate = item.taxPercent; // last non-zero rate used for label
  }

  final half = representativeTaxRate / 2;
  return InvoiceGstSummary(
    supplyType: supplyType,
    totalCgst: totalCgst,
    totalSgst: totalSgst,
    totalIgst: totalIgst,
    cgstRate: supplyType == GstSupplyType.interState ? 0 : half,
    sgstRate: supplyType == GstSupplyType.interState ? 0 : half,
    igstRate: supplyType == GstSupplyType.interState ? representativeTaxRate : 0,
  );
}
