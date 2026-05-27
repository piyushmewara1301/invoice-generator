import 'package:csv/csv.dart';
import 'package:uuid/uuid.dart';
import '../models/client.dart';
import '../models/invoice.dart';
import '../models/line_item.dart';

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
