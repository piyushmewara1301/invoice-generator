import 'package:csv/csv.dart';
import 'package:uuid/uuid.dart';
import '../models/client.dart';
import '../models/invoice.dart';
import '../models/line_item.dart';
import '../models/service_item.dart';

// ── Column indexes ────────────────────────────────────────────────────────────
// Matches the sample template header row exactly.
const _colInvoiceNo = 0;
const _colInvoiceDate = 1;
const _colDueDate = 2;
const _colStatus = 3;
const _colClientName = 4;
const _colClientCompany = 5;
const _colClientEmail = 6;
const _colClientPhone = 7;
const _colSubject = 8;
const _colCurrency = 9;
const _colItemDesc = 10;
const _colItemQty = 11;
const _colItemRate = 12;
const _colItemTax = 13;
const _colItemDiscount = 14;
const _colNotes = 15;
const _colTerms = 16;
const _minColumns = 12; // at least through item rate

// ── Public types ──────────────────────────────────────────────────────────────

class CsvImportRow {
  final int rowNumber; // 1-based display row (excluding header)
  final String invoiceNo;
  final bool isValid;
  final String? errorMessage;

  // These are non-null when isValid is true
  final String? clientName;
  final double? total;

  const CsvImportRow({
    required this.rowNumber,
    required this.invoiceNo,
    required this.isValid,
    this.errorMessage,
    this.clientName,
    this.total,
  });
}

class CsvImportPreview {
  final List<CsvImportRow> rows; // one per raw CSV data row
  final int invoiceCount; // distinct valid invoice numbers
  final int errorCount;
  final List<Invoice> invoices; // ready to save (only when no errors)

  const CsvImportPreview({
    required this.rows,
    required this.invoiceCount,
    required this.errorCount,
    required this.invoices,
  });

  bool get hasErrors => errorCount > 0;
}

// ── Template ──────────────────────────────────────────────────────────────────

/// Returns the CSV content of the sample template that users fill in.
String buildTemplate() {
  const header =
      'Invoice No,Invoice Date (DD/MM/YYYY),Due Date (DD/MM/YYYY),Status (Draft/Sent/Paid),Client Name,Client Company,Client Email,Client Phone,Subject,Currency,Item Description,Item Qty,Item Rate,Item Tax %,Item Discount %,Notes,Terms';

  const rows = [
    'INV-0001,01/01/2025,31/01/2025,Paid,John Doe,Acme Corp,john@acme.com,9876543210,Website Redesign,INR,Logo Design,1,5000,18,0,Thank you for your business,Payment due within 30 days',
    // Second row shows multi-item: same invoice number → same invoice
    'INV-0001,01/01/2025,31/01/2025,Paid,John Doe,Acme Corp,john@acme.com,9876543210,Website Redesign,INR,Web Development,10,2000,18,5,,',
    'INV-0002,15/01/2025,15/02/2025,Sent,Jane Smith,,jane@example.com,9123456789,Monthly Consulting,INR,Business Strategy Consulting,2,3000,0,0,,',
  ];

  return '$header\n${rows.join('\n')}';
}

// ── Parser ────────────────────────────────────────────────────────────────────

/// Parses [csvContent] and returns a [CsvImportPreview].
/// [existingInvoiceNumbers] is the set of invoice numbers already in the app
/// — matching ones are flagged as duplicates.
/// [existingClients] is used to reuse clients by name+email match.
CsvImportPreview parseCsv(
  String csvContent, {
  required Set<String> existingInvoiceNumbers,
  required List<Client> existingClients,
}) {
  final uuid = const Uuid();

  // Parse raw CSV (handles quoted fields, embedded commas, etc.)
  final rows = const CsvToListConverter(eol: '\n').convert(csvContent);
  if (rows.isEmpty) {
    return const CsvImportPreview(
        rows: [], invoiceCount: 0, errorCount: 0, invoices: []);
  }

  // Skip header row (first row that starts with 'Invoice No' or similar).
  final startIdx = _isHeaderRow(rows.first) ? 1 : 0;
  final dataRows = rows.sublist(startIdx);

  if (dataRows.isEmpty) {
    return const CsvImportPreview(
        rows: [], invoiceCount: 0, errorCount: 0, invoices: []);
  }

  final previewRows = <CsvImportRow>[];
  // Map: invoiceNo → accumulated data for grouping multi-item rows.
  final Map<String, _InvoiceAccumulator> accumulators = {};
  // Preserve insertion order for display.
  final invoiceOrder = <String>[];

  for (int i = 0; i < dataRows.length; i++) {
    final rowNum = i + 1;
    final row = dataRows[i];

    if (row.every((cell) => cell.toString().trim().isEmpty)) continue;

    if (row.length < _minColumns) {
      previewRows.add(CsvImportRow(
        rowNumber: rowNum,
        invoiceNo: '—',
        isValid: false,
        errorMessage: 'Too few columns (expected at least $_minColumns)',
      ));
      continue;
    }

    final String invoiceNo = row[_colInvoiceNo].toString().trim();
    if (invoiceNo.isEmpty) {
      previewRows.add(CsvImportRow(
        rowNumber: rowNum,
        invoiceNo: '—',
        isValid: false,
        errorMessage: 'Invoice No is required',
      ));
      continue;
    }

    // Parse invoice-level fields only on the first row for this number.
    DateTime? invoiceDate;
    DateTime? dueDate;
    InvoiceStatus? status;
    String? clientName;
    String clientError = '';

    if (!accumulators.containsKey(invoiceNo)) {
      // This is the first row for this invoice — parse all invoice fields.
      invoiceDate = _parseDate(row[_colInvoiceDate].toString().trim());
      if (invoiceDate == null) {
        clientError =
            'Invalid Invoice Date "${row[_colInvoiceDate]}" — use DD/MM/YYYY';
      }

      dueDate = _parseDate(row[_colDueDate].toString().trim());
      if (dueDate == null && clientError.isEmpty) {
        // Due date is optional — default to invoice date + 30 days.
        dueDate = (invoiceDate ?? DateTime.now()).add(const Duration(days: 30));
      }

      clientName = row[_colClientName].toString().trim();
      if (clientName.isEmpty && clientError.isEmpty) {
        clientError = 'Client Name is required';
      }

      status = _parseStatus(row[_colStatus].toString().trim());
    }

    // Parse line item fields (required on every row).
    final String desc = row[_colItemDesc].toString().trim();
    if (desc.isEmpty && clientError.isEmpty) {
      previewRows.add(CsvImportRow(
        rowNumber: rowNum,
        invoiceNo: invoiceNo,
        isValid: false,
        errorMessage: 'Item Description is required',
      ));
      continue;
    }

    final double? qty = _parseDouble(row[_colItemQty].toString().trim());
    final double? rate = _parseDouble(row[_colItemRate].toString().trim());

    if ((qty == null || rate == null) && clientError.isEmpty) {
      previewRows.add(CsvImportRow(
        rowNumber: rowNum,
        invoiceNo: invoiceNo,
        isValid: false,
        errorMessage: 'Item Qty and Rate must be valid numbers',
      ));
      continue;
    }

    if (clientError.isNotEmpty) {
      previewRows.add(CsvImportRow(
        rowNumber: rowNum,
        invoiceNo: invoiceNo,
        isValid: false,
        errorMessage: clientError,
      ));
      continue;
    }

    final double taxPct =
        _parseDouble(row.length > _colItemTax ? row[_colItemTax].toString().trim() : '') ?? 0;
    final double discPct =
        _parseDouble(row.length > _colItemDiscount ? row[_colItemDiscount].toString().trim() : '') ?? 0;

    final item = LineItem(
      description: desc,
      quantity: qty!,
      rate: rate!,
      taxPercent: taxPct,
      discountPercent: discPct,
    );

    if (!accumulators.containsKey(invoiceNo)) {
      // First row for this invoice.
      final isDuplicate = existingInvoiceNumbers.contains(invoiceNo);
      final String? companyName = row.length > _colClientCompany
          ? row[_colClientCompany].toString().trim().nullIfEmpty()
          : null;
      final String email = row.length > _colClientEmail
          ? row[_colClientEmail].toString().trim()
          : '';
      final String phone = row.length > _colClientPhone
          ? row[_colClientPhone].toString().trim()
          : '';
      final String subject = row.length > _colSubject
          ? row[_colSubject].toString().trim()
          : '';
      final String currency = row.length > _colCurrency
          ? row[_colCurrency].toString().trim().toUpperCase()
          : 'INR';
      final String notes = row.length > _colNotes
          ? row[_colNotes].toString().trim()
          : '';
      final String terms = row.length > _colTerms
          ? row[_colTerms].toString().trim()
          : '';

      // Reuse existing client if name+email match.
      final existingClient = existingClients.firstWhere(
        (c) =>
            c.name.toLowerCase() == clientName!.toLowerCase() &&
            (email.isEmpty || c.email.toLowerCase() == email.toLowerCase()),
        orElse: () => Client(
          id: uuid.v4(),
          name: clientName!,
          companyName: companyName,
          email: email,
          phone: phone,
        ),
      );

      accumulators[invoiceNo] = _InvoiceAccumulator(
        invoiceNo: invoiceNo,
        invoiceDate: invoiceDate!,
        dueDate: dueDate!,
        status: status ?? InvoiceStatus.draft,
        client: existingClient,
        subject: subject.nullIfEmpty(),
        currency: currency.isEmpty ? 'INR' : currency,
        notes: notes.nullIfEmpty(),
        terms: terms.nullIfEmpty(),
        isDuplicate: isDuplicate,
        id: uuid.v4(),
      );
      invoiceOrder.add(invoiceNo);
    }

    accumulators[invoiceNo]!.items.add(item);
    previewRows.add(CsvImportRow(
      rowNumber: rowNum,
      invoiceNo: invoiceNo,
      isValid: !accumulators[invoiceNo]!.isDuplicate,
      errorMessage: accumulators[invoiceNo]!.isDuplicate
          ? 'Duplicate — "$invoiceNo" already exists in the app'
          : null,
      clientName: accumulators[invoiceNo]!.client.displayName,
      total: _totalForAccumulator(accumulators[invoiceNo]!),
    ));
  }

  // Build Invoice objects for non-duplicate, valid invoices.
  final validInvoices = <Invoice>[];
  final seenInThisBatch = <String>{};
  for (final no in invoiceOrder) {
    final acc = accumulators[no]!;
    if (!acc.isDuplicate && !seenInThisBatch.contains(no)) {
      seenInThisBatch.add(no);
      validInvoices.add(acc.toInvoice());
    }
  }

  final errorCount = previewRows.where((r) => !r.isValid).length;

  return CsvImportPreview(
    rows: previewRows,
    invoiceCount: validInvoices.length,
    errorCount: errorCount,
    invoices: validInvoices,
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

bool _isHeaderRow(List row) {
  final first = row.isNotEmpty ? row.first.toString().toLowerCase() : '';
  return first.contains('invoice') || first.contains('no');
}

DateTime? _parseDate(String s) {
  if (s.isEmpty) return null;
  // Try DD/MM/YYYY
  final parts = s.split(RegExp(r'[/\-\.]'));
  if (parts.length == 3) {
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    final c = int.tryParse(parts[2]);
    if (a != null && b != null && c != null) {
      if (c > 1900) return DateTime.tryParse('$c-${b.toString().padLeft(2,'0')}-${a.toString().padLeft(2,'0')}');
      if (a > 1900) return DateTime.tryParse('$a-${b.toString().padLeft(2,'0')}-${c.toString().padLeft(2,'0')}');
    }
  }
  return DateTime.tryParse(s);
}

double? _parseDouble(String s) {
  if (s.isEmpty) return null;
  return double.tryParse(s.replaceAll(',', ''));
}

InvoiceStatus _parseStatus(String s) {
  switch (s.toLowerCase()) {
    case 'paid':
      return InvoiceStatus.paid;
    case 'sent':
      return InvoiceStatus.sent;
    case 'cancelled':
    case 'canceled':
      return InvoiceStatus.cancelled;
    default:
      return InvoiceStatus.draft;
  }
}

double _totalForAccumulator(_InvoiceAccumulator acc) {
  return acc.items.fold(0.0, (sum, item) => sum + item.total);
}

// ── Internal accumulator ──────────────────────────────────────────────────────

class _InvoiceAccumulator {
  final String id;
  final String invoiceNo;
  final DateTime invoiceDate;
  final DateTime dueDate;
  final InvoiceStatus status;
  final Client client;
  final String? subject;
  final String currency;
  final String? notes;
  final String? terms;
  final bool isDuplicate;
  final List<LineItem> items = [];

  _InvoiceAccumulator({
    required this.id,
    required this.invoiceNo,
    required this.invoiceDate,
    required this.dueDate,
    required this.status,
    required this.client,
    required this.subject,
    required this.currency,
    required this.notes,
    required this.terms,
    required this.isDuplicate,
  });

  Invoice toInvoice() => Invoice(
        id: id,
        invoiceNumber: invoiceNo,
        invoiceDate: invoiceDate,
        dueDate: dueDate,
        status: status,
        client: client,
        subject: subject,
        currency: currency,
        notes: notes,
        terms: terms,
        items: items,
      );
}

extension on String {
  String? nullIfEmpty() => isEmpty ? null : this;
}

// ─────────────────────────────────────────────────────────────────────────────
// Bulk Generate — simple format for creating new invoices in batch
// ─────────────────────────────────────────────────────────────────────────────
// CSV columns: Client Name | Client Email | Client Phone |
//              Item Description | Amount | Tax % | Notes
// One row = one new invoice (invoice number auto-assigned by the provider).

const _bColClientName = 0;
const _bColEmail = 1;
const _bColPhone = 2;
const _bColDesc = 3;
const _bColAmount = 4;
const _bColTax = 5;
const _bColNotes = 6;
const _bMinCols = 5; // at least through Amount

/// Spec for a single auto-generated invoice — no invoice number (provider assigns).
class BulkInvoiceSpec {
  final String clientName;
  final String clientEmail;
  final String clientPhone;
  final String itemDescription;
  final double amount;
  final double taxPercent;
  final String? notes;

  const BulkInvoiceSpec({
    required this.clientName,
    required this.clientEmail,
    required this.clientPhone,
    required this.itemDescription,
    required this.amount,
    this.taxPercent = 0,
    this.notes,
  });

  double get lineTotal => amount * (1 + taxPercent / 100);
}

class BulkGenerateRow {
  final int rowNumber;
  final bool isValid;
  final String? errorMessage;
  final BulkInvoiceSpec? spec;

  const BulkGenerateRow({
    required this.rowNumber,
    required this.isValid,
    this.errorMessage,
    this.spec,
  });
}

class BulkGeneratePreview {
  final List<BulkGenerateRow> rows;
  final List<BulkInvoiceSpec> validSpecs;
  final int errorCount;

  const BulkGeneratePreview({
    required this.rows,
    required this.validSpecs,
    required this.errorCount,
  });

  bool get hasErrors => errorCount > 0;
  int get validCount => validSpecs.length;
}

/// Returns the CSV content of the bulk-generate template.
String buildBulkTemplate() {
  const header =
      'Client Name,Client Email,Client Phone,Item Description,Amount,Tax %,Notes';
  const rows = [
    'Rahul Sharma,rahul@acme.com,9876543210,Monthly Tuition – October 2024,5000,0,',
    'Priya Gupta,priya@email.com,8765432109,Monthly Tuition – October 2024,5000,18,Including 18% GST',
    'Tech Solutions Pvt Ltd,billing@techsol.com,9123456789,Annual Maintenance Contract,24000,18,Q4 billing',
  ];
  return '$header\n${rows.join('\n')}';
}

/// Parses a bulk-generate CSV. Returns a [BulkGeneratePreview] with validated rows.
BulkGeneratePreview parseBulkCsv(String csvContent) {
  final raw =
      csvContent.startsWith('﻿') ? csvContent.substring(1) : csvContent;
  final rows = const CsvToListConverter(eol: '\n')
      .convert(raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n'));

  if (rows.isEmpty) {
    return const BulkGeneratePreview(rows: [], validSpecs: [], errorCount: 0);
  }

  // Skip header row
  final startIdx = _isBulkHeader(rows.first) ? 1 : 0;
  final dataRows = rows.sublist(startIdx);

  final previewRows = <BulkGenerateRow>[];
  final validSpecs = <BulkInvoiceSpec>[];

  for (int i = 0; i < dataRows.length; i++) {
    final rowNum = i + 1;
    final row = dataRows[i];

    if (row.every((c) => c.toString().trim().isEmpty)) continue;

    String cell(int col) =>
        col < row.length ? row[col].toString().trim() : '';

    BulkGenerateRow err(String msg) => BulkGenerateRow(
          rowNumber: rowNum,
          isValid: false,
          errorMessage: msg,
        );

    if (row.length < _bMinCols) {
      previewRows.add(err('Too few columns (need at least $_bMinCols)'));
      continue;
    }

    final clientName = cell(_bColClientName);
    if (clientName.isEmpty) {
      previewRows.add(err('Client Name is required'));
      continue;
    }

    final desc = cell(_bColDesc);
    if (desc.isEmpty) {
      previewRows.add(err('Item Description is required'));
      continue;
    }

    final amount = _parseDouble(cell(_bColAmount));
    if (amount == null || amount <= 0) {
      previewRows.add(err('Amount must be a positive number'));
      continue;
    }

    final tax = _parseDouble(cell(_bColTax)) ?? 0;
    final notes = cell(_bColNotes).nullIfEmpty();

    final spec = BulkInvoiceSpec(
      clientName: clientName,
      clientEmail: cell(_bColEmail),
      clientPhone: cell(_bColPhone),
      itemDescription: desc,
      amount: amount,
      taxPercent: tax,
      notes: notes,
    );

    previewRows.add(BulkGenerateRow(
      rowNumber: rowNum,
      isValid: true,
      spec: spec,
    ));
    validSpecs.add(spec);
  }

  final errorCount = previewRows.where((r) => !r.isValid).length;
  return BulkGeneratePreview(
    rows: previewRows,
    validSpecs: validSpecs,
    errorCount: errorCount,
  );
}

bool _isBulkHeader(List row) {
  if (row.isEmpty) return false;
  final first = row.first.toString().toLowerCase();
  return first.contains('client') || first.contains('name');
}

// ── Inventory import ──────────────────────────────────────────────────────────

// CSV columns for inventory import
const _invColName = 0;
const _invColCategory = 1;
const _invColDescription = 2;
const _invColRate = 3;
const _invColTax = 4;
const _invColUnit = 5;
const _invColHsn = 6;
const _invColBarcode = 7;
const _invColTrackStock = 8;
const _invColOpeningStock = 9;
const _invColLowStock = 10;
const _invColVariantName = 11;
const _invColVariantRate = 12;
const _invColCostPrice = 13;

class InventoryImportRow {
  final int rowNumber;
  final String name;
  final bool isValid;
  final String? errorMessage;
  final bool isVariantRow;
  final String? variantName;

  const InventoryImportRow({
    required this.rowNumber,
    required this.name,
    required this.isValid,
    this.errorMessage,
    this.isVariantRow = false,
    this.variantName,
  });
}

class InventoryImportPreview {
  final List<InventoryImportRow> rows;
  final int newCount;
  final int updateCount;
  final int errorCount;
  final List<ServiceItem> items;

  const InventoryImportPreview({
    required this.rows,
    required this.newCount,
    required this.updateCount,
    required this.errorCount,
    required this.items,
  });

  bool get hasErrors => errorCount > 0;
  int get totalCount => newCount + updateCount;
}

String buildInventoryTemplate() {
  final rows = <List<dynamic>>[
    [
      'Name',
      'Category',
      'Description',
      'Selling Price',
      'Tax%',
      'Unit',
      'HSN/SAC',
      'Barcode',
      'Track Stock (yes/no)',
      'Opening Stock',
      'Low Stock Alert',
      'Variant Name',
      'Variant Rate',
      'Cost Price',
    ],
    // Flat item example
    ['T-Shirt', 'Apparel', 'Cotton crew-neck', '499', '5', 'pcs', '', '', 'yes', '50', '10', '', '', '280'],
    // Variant item example (3 rows for same product)
    ['Denim Jeans', 'Apparel', 'Slim-fit denim', '', '12', 'pcs', '', '', 'yes', '', '', 'S / Blue', '799', '450'],
    ['Denim Jeans', 'Apparel', 'Slim-fit denim', '', '12', 'pcs', '', '', 'yes', '', '', 'M / Blue', '799', '450'],
    ['Denim Jeans', 'Apparel', 'Slim-fit denim', '', '12', 'pcs', '', '', 'yes', '', '', 'L / Blue', '849', '480'],
  ];
  return const ListToCsvConverter().convert(rows);
}

InventoryImportPreview parseInventoryCsv(
  String content, {
  List<ServiceItem> existingItems = const [],
  required String shopId,
}) {
  const uuid = Uuid();
  final allRows = const CsvToListConverter(eol: '\n').convert(content);

  final previewRows = <InventoryImportRow>[];
  final itemMap = <String, ServiceItem>{}; // keyed by lowercase name
  final isNew = <String, bool>{};

  // Pre-populate with existing items so we can update them
  for (final item in existingItems) {
    itemMap[item.name.toLowerCase()] = item;
    isNew[item.name.toLowerCase()] = false;
  }

  int rowNum = 0;
  for (final raw in allRows) {
    rowNum++;
    if (raw.isEmpty) continue;

    // Skip header row
    final first = raw.first.toString().trim();
    if (first.toLowerCase() == 'name') continue;
    if (first.isEmpty) continue;

    String cell(int col) => col < raw.length ? raw[col].toString().trim() : '';

    final name = cell(_invColName);
    if (name.isEmpty) {
      previewRows.add(InventoryImportRow(
        rowNumber: rowNum,
        name: '(empty)',
        isValid: false,
        errorMessage: 'Name is required',
      ));
      continue;
    }

    final rateStr = cell(_invColRate);
    final variantName = cell(_invColVariantName);
    final variantRateStr = cell(_invColVariantRate);
    final isVariantRow = variantName.isNotEmpty;

    // Validate rate: either item rate or variant rate must be present
    double? rate;
    double? variantRate;
    if (!isVariantRow) {
      if (rateStr.isEmpty) {
        previewRows.add(InventoryImportRow(
          rowNumber: rowNum,
          name: name,
          isValid: false,
          errorMessage: 'Rate is required for non-variant items',
        ));
        continue;
      }
      rate = double.tryParse(rateStr);
      if (rate == null) {
        previewRows.add(InventoryImportRow(
          rowNumber: rowNum,
          name: name,
          isValid: false,
          errorMessage: 'Invalid rate: $rateStr',
        ));
        continue;
      }
    } else {
      rate = double.tryParse(rateStr); // may be null for variant items — that's ok
      if (variantRateStr.isNotEmpty) {
        variantRate = double.tryParse(variantRateStr);
        if (variantRate == null) {
          previewRows.add(InventoryImportRow(
            rowNumber: rowNum,
            name: name,
            isValid: false,
            errorMessage: 'Invalid variant rate: $variantRateStr',
            isVariantRow: true,
            variantName: variantName,
          ));
          continue;
        }
      }
    }

    final taxStr = cell(_invColTax);
    final tax = double.tryParse(taxStr) ?? 0.0;
    final openingStockStr = cell(_invColOpeningStock);
    final openingStock = double.tryParse(openingStockStr) ?? 0.0;
    final lowStockStr = cell(_invColLowStock);
    final lowStock = double.tryParse(lowStockStr) ?? 0.0;
    final trackStock = cell(_invColTrackStock).toLowerCase() == 'yes';
    final category = cell(_invColCategory);
    final description = cell(_invColDescription);
    final unit = cell(_invColUnit);
    final hsn = cell(_invColHsn);
    final barcode = cell(_invColBarcode);
    final costPrice = double.tryParse(cell(_invColCostPrice));

    final key = name.toLowerCase();
    final existing = itemMap[key];

    if (isVariantRow) {
      final newVariant = ProductVariant(
        id: uuid.v4(),
        name: variantName,
        rate: variantRate ?? (rate ?? 0.0),
        costPrice: costPrice,
        barcode: barcode.isEmpty ? null : barcode,
        trackStock: trackStock,
        stockByShop: trackStock ? {shopId: openingStock} : {},
        lowStockThreshold: trackStock ? lowStock : 0,
      );

      if (existing != null) {
        // Add variant to existing item (avoid duplicates by variant name)
        final updatedVariants = List<ProductVariant>.from(existing.variants);
        final dupIdx = updatedVariants.indexWhere(
            (v) => v.name.toLowerCase() == variantName.toLowerCase());
        if (dupIdx >= 0) {
          final oldVariant = updatedVariants[dupIdx];
          updatedVariants[dupIdx] = ProductVariant(
            id: oldVariant.id,
            name: newVariant.name,
            rate: newVariant.rate,
            costPrice: costPrice ?? oldVariant.costPrice,
            barcode: barcode.isNotEmpty ? barcode : oldVariant.barcode,
            trackStock: trackStock || oldVariant.trackStock,
            stockByShop: trackStock
                ? {...oldVariant.stockByShop, shopId: openingStock}
                : oldVariant.stockByShop,
            lowStockThreshold:
                trackStock ? lowStock : oldVariant.lowStockThreshold,
          );
        } else {
          updatedVariants.add(newVariant);
        }
        itemMap[key] = ServiceItem(
          id: existing.id,
          name: existing.name,
          description: description.isNotEmpty ? description : existing.description,
          rate: existing.rate,
          taxPercent: tax > 0 ? tax : existing.taxPercent,
          unit: unit.isNotEmpty ? unit : existing.unit,
          hsnSac: hsn.isNotEmpty ? hsn : existing.hsnSac,
          category: category.isNotEmpty ? category : existing.category,
          barcode: existing.barcode,
          trackStock: existing.trackStock,
          stockByShop: existing.stockByShop,
          lowStockThreshold: existing.lowStockThreshold,
          variants: updatedVariants,
        );
      } else {
        // Create new item with this first variant
        itemMap[key] = ServiceItem(
          id: uuid.v4(),
          name: name,
          description: description,
          rate: rate ?? 0.0,
          taxPercent: tax,
          unit: unit,
          hsnSac: hsn.isEmpty ? null : hsn,
          category: category,
          barcode: null,
          variants: [newVariant],
          // costPrice lives on each variant for variant items
        );
        isNew[key] = true;
      }
    } else {
      // Flat item
      if (existing != null) {
        itemMap[key] = ServiceItem(
          id: existing.id,
          name: existing.name,
          description: description.isNotEmpty ? description : existing.description,
          rate: rate ?? existing.rate,
          costPrice: costPrice ?? existing.costPrice,
          taxPercent: tax > 0 ? tax : existing.taxPercent,
          unit: unit.isNotEmpty ? unit : existing.unit,
          hsnSac: hsn.isNotEmpty ? hsn : existing.hsnSac,
          category: category.isNotEmpty ? category : existing.category,
          barcode: barcode.isNotEmpty ? barcode : existing.barcode,
          trackStock: trackStock || existing.trackStock,
          stockByShop: trackStock
              ? {...existing.stockByShop, shopId: openingStock}
              : existing.stockByShop,
          lowStockThreshold: trackStock ? lowStock : existing.lowStockThreshold,
          variants: existing.variants,
        );
      } else {
        itemMap[key] = ServiceItem(
          id: uuid.v4(),
          name: name,
          description: description,
          rate: rate!,
          costPrice: costPrice,
          taxPercent: tax,
          unit: unit,
          hsnSac: hsn.isEmpty ? null : hsn,
          category: category,
          barcode: barcode.isEmpty ? null : barcode,
          trackStock: trackStock,
          stockByShop: trackStock ? {shopId: openingStock} : {},
          lowStockThreshold: trackStock ? lowStock : 0,
          variants: const [],
        );
        isNew[key] = true;
      }
    }

    previewRows.add(InventoryImportRow(
      rowNumber: rowNum,
      name: name,
      isValid: true,
      isVariantRow: isVariantRow,
      variantName: isVariantRow ? variantName : null,
    ));
  }

  int newCount = 0, updateCount = 0;
  for (final entry in isNew.entries) {
    if (entry.value) {
      newCount++;
    } else {
      // Only count as update if we actually processed it in this CSV
      final processedInCsv = previewRows.any(
          (r) => r.isValid && r.name.toLowerCase() == entry.key);
      if (processedInCsv) updateCount++;
    }
  }

  final errorCount = previewRows.where((r) => !r.isValid).length;

  return InventoryImportPreview(
    rows: previewRows,
    newCount: newCount,
    updateCount: updateCount,
    errorCount: errorCount,
    items: itemMap.values.toList(),
  );
}
