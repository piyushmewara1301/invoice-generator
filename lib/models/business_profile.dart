import 'custom_field.dart';
import 'invoice_template.dart';
import 'payment_method.dart';
import 'service_item.dart';

export 'custom_field.dart';
export 'invoice_template.dart';
export 'payment_method.dart';
export 'service_item.dart';

// Sentinel for distinguishing "not provided" from null in copyWith.
const Object _sentinel = Object();

// Legacy enum kept only for JSON migration — no longer used in UI or PDF.
enum InvoiceHeaderStyle { textOnly, logoOnly, logoAndText }

/// Keys used in [BusinessProfile.headerFields].
/// Each key controls whether that element appears in the invoice header.
const kHeaderLogo    = 'logo';
const kHeaderName    = 'name';
const kHeaderEmail   = 'email';
const kHeaderAddress = 'address';
const kHeaderGstin   = 'gstin';
const kHeaderWebsite = 'website';


enum VerificationStatus { unverified, pending, verified, rejected }

/// Controls which set of features are shown in the app's navigation.
/// - [invoiceBased]: full invoice workflow (default)
/// - [stockBased]: daily stock-sales entry + cash/bank reconciliation
enum BusinessMode { invoiceBased, stockBased }

enum BusinessType {
  restaurant,
  grocery,
  retail,
  professional,
  healthcare,
  education,
  construction,
  salon,
  technology,
  manufacturing,
  wholesale,
  transport,
  freelancer,
  other,
}

extension BusinessTypeX on BusinessType {
  String get displayName {
    switch (this) {
      case BusinessType.restaurant:    return 'Restaurant & Food';
      case BusinessType.grocery:       return 'Grocery';
      case BusinessType.retail:        return 'Retail Shop';
      case BusinessType.professional:  return 'Professional Services';
      case BusinessType.healthcare:    return 'Healthcare';
      case BusinessType.education:     return 'Education';
      case BusinessType.construction:  return 'Construction';
      case BusinessType.salon:         return 'Salon & Beauty';
      case BusinessType.technology:    return 'Technology / IT';
      case BusinessType.manufacturing: return 'Manufacturing';
      case BusinessType.wholesale:     return 'Wholesale & Trading';
      case BusinessType.transport:     return 'Transport & Logistics';
      case BusinessType.freelancer:    return 'Freelancer';
      case BusinessType.other:         return 'Other';
    }
  }
}

enum SubscriptionTier { free, lite, pro, premium, enterprise }

extension SubscriptionTierX on SubscriptionTier {
  bool get isAnyPaid => this != SubscriptionTier.free;
  bool get isPro => index >= SubscriptionTier.pro.index;
  bool get isPremium => index >= SubscriptionTier.premium.index;
  bool get isEnterprise => this == SubscriptionTier.enterprise;
}

class BusinessProfile {
  String name;
  String email;
  String phone;
  String address;
  String city;
  String state;
  String country;
  String postalCode;
  String? gstin;
  String? website;
  String currency;
  String invoicePrefix;
  String quotationPrefix;
  String challanPrefix;
  int nextInvoiceNumber;
  int nextQuotationNumber;
  int nextChallanNumber;
  int nextCreditNoteNumber;
  String? logoBase64;
  Set<String> headerFields;
  InvoiceTemplate defaultTemplate;
  String? themeColorHex;
  double defaultTaxPercent;
  bool showQuantity;
  String itemLabel;
  List<PaymentMethod> paymentMethods;
  VerificationStatus verificationStatus;
  String? verificationNotes;
  String? verificationSubmittedAt;
  SubscriptionTier subscriptionTier;
  DateTime? subscriptionExpiryDate;
  DateTime? subscriptionLastCheckedDate;
  String? signatureBase64;
  bool showPaymentDetailsOnInvoice;
  String? defaultPlaceOfSupply;
  bool defaultReverseCharge;
  bool isCompositionDealer;
  bool showThankYouMessage;
  String thankYouMessage;
  bool showClientAcknowledgment;
  bool posEnabled;
  bool purchaseBillEnabled;
  BusinessType? businessType;

  /// Specific profession or designation shown on invoices below the business name.
  /// Examples: "Chartered Accountant", "Advocate", "Doctor", "Architect".
  /// Relevant for any business type — shown when non-null and non-empty.
  String? professionTitle;

  /// Extra registration / compliance fields shown on every invoice
  /// (e.g. PAN Number, FSSAI Licence, MSME Reg., Trade Licence).
  List<CustomField> businessInfoFields;

  // ── Credit limit ──────────────────────────────────────────────────────────
  /// Global default credit limit applied to clients that have no individual
  /// limit set. null means no default (no enforcement unless client has one).
  double? defaultCreditLimit;

  // ── Approval workflow ──────────────────────────────────────────────────────
  /// When true, invoices must be approved by a manager before being sent.
  bool approvalWorkflowEnabled;

  // ── Late payment penalty ───────────────────────────────────────────────────
  /// When true, a penalty is auto-calculated on overdue invoices.
  bool lateFeeEnabled;
  /// Monthly interest rate applied after [gracePeriodDays]. Default: 2 % / month.
  double lateFeePercent;
  /// Days after due date before the penalty clock starts. Default: 0.
  int gracePeriodDays;

  /// Whether this business operates in invoice-based or stock-based mode.
  BusinessMode businessMode;

  /// When false, employees cannot change the unit price of line items
  /// while creating or editing invoices. The rate field becomes read-only.
  bool allowEmployeePriceChange;

  /// Limits how many days of past Daily Sales entries an employee can view.
  /// null means employees can see the full history (no limit).
  int? employeeDailySalesVisibilityDays;

  /// Per-shop list of payment method ids shown in Daily Sales "Money Received".
  /// Keyed by shopId. If a shop has no entry the full [allPaymentMethods] list is shown.
  Map<String, List<String>> shopPaymentMethodIds;

  // ── Low-stock alerts ────────────────────────────────────────────────────────
  /// When true, a push notification fires the first time any tracked item
  /// drops to or below its [ServiceItem.lowStockThreshold].
  bool lowStockAlertsEnabled;

  BusinessProfile({
    this.name = '',
    this.email = '',
    this.phone = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.country = 'India',
    this.postalCode = '',
    this.gstin,
    this.website,
    this.currency = 'INR',
    this.invoicePrefix = 'INV-',
    this.quotationPrefix = 'QT-',
    this.challanPrefix = 'DC-',
    this.nextInvoiceNumber = 1,
    this.nextQuotationNumber = 1,
    this.nextChallanNumber = 1,
    this.nextCreditNoteNumber = 1,
    this.logoBase64,
    Set<String>? headerFields,
    this.defaultTemplate = InvoiceTemplate.classic,
    this.themeColorHex,
    this.defaultTaxPercent = 0,
    this.showQuantity = true,
    this.itemLabel = 'Item',
    List<PaymentMethod>? paymentMethods,
    this.verificationStatus = VerificationStatus.unverified,
    this.verificationNotes,
    this.verificationSubmittedAt,
    this.subscriptionTier = SubscriptionTier.free,
    this.subscriptionExpiryDate,
    this.subscriptionLastCheckedDate,
    this.signatureBase64,
    this.showPaymentDetailsOnInvoice = true,
    this.defaultPlaceOfSupply,
    this.defaultReverseCharge = false,
    this.isCompositionDealer = false,
    this.showThankYouMessage = true,
    this.thankYouMessage = 'Thank you for your business!',
    this.showClientAcknowledgment = true,
    this.posEnabled = false,
    this.purchaseBillEnabled = true,
    this.businessType,
    this.professionTitle,
    List<CustomField>? businessInfoFields,
    this.defaultCreditLimit,
    this.approvalWorkflowEnabled = false,
    this.lateFeeEnabled = false,
    this.lateFeePercent = 2.0,
    this.gracePeriodDays = 0,
    this.businessMode = BusinessMode.invoiceBased,
    this.allowEmployeePriceChange = true,
    this.employeeDailySalesVisibilityDays,
    Map<String, List<String>>? shopPaymentMethodIds,
    this.lowStockAlertsEnabled = true,
  })  : headerFields = headerFields ?? {kHeaderLogo, kHeaderName, kHeaderAddress},
        paymentMethods = paymentMethods ?? [],
        businessInfoFields = businessInfoFields ?? [],
        shopPaymentMethodIds = shopPaymentMethodIds ?? {};

  BusinessProfile copyWith({
    String? name,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? state,
    String? country,
    String? postalCode,
    Object? gstin = _sentinel,
    Object? website = _sentinel,
    String? currency,
    String? invoicePrefix,
    String? quotationPrefix,
    String? challanPrefix,
    int? nextInvoiceNumber,
    int? nextQuotationNumber,
    int? nextChallanNumber,
    int? nextCreditNoteNumber,
    Object? logoBase64 = _sentinel,
    Set<String>? headerFields,
    InvoiceTemplate? defaultTemplate,
    Object? themeColorHex = _sentinel,
    double? defaultTaxPercent,
    bool? showQuantity,
    String? itemLabel,
    List<PaymentMethod>? paymentMethods,
    VerificationStatus? verificationStatus,
    Object? verificationNotes = _sentinel,
    Object? verificationSubmittedAt = _sentinel,
    SubscriptionTier? subscriptionTier,
    Object? subscriptionExpiryDate = _sentinel,
    Object? subscriptionLastCheckedDate = _sentinel,
    Object? signatureBase64 = _sentinel,
    bool? showPaymentDetailsOnInvoice,
    Object? defaultPlaceOfSupply = _sentinel,
    bool? defaultReverseCharge,
    bool? isCompositionDealer,
    bool? showThankYouMessage,
    String? thankYouMessage,
    bool? showClientAcknowledgment,
    bool? posEnabled,
    bool? purchaseBillEnabled,
    Object? businessType = _sentinel,
    Object? professionTitle = _sentinel,
    List<CustomField>? businessInfoFields,
    Object? defaultCreditLimit = _sentinel,
    bool? lateFeeEnabled,
    double? lateFeePercent,
    int? gracePeriodDays,
    bool? approvalWorkflowEnabled,
    BusinessMode? businessMode,
    bool? allowEmployeePriceChange,
    Object? employeeDailySalesVisibilityDays = _sentinel,
    Map<String, List<String>>? shopPaymentMethodIds,
    bool? lowStockAlertsEnabled,
  }) =>
      BusinessProfile(
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        city: city ?? this.city,
        state: state ?? this.state,
        country: country ?? this.country,
        postalCode: postalCode ?? this.postalCode,
        gstin: gstin == _sentinel ? this.gstin : gstin as String?,
        website: website == _sentinel ? this.website : website as String?,
        currency: currency ?? this.currency,
        invoicePrefix: invoicePrefix ?? this.invoicePrefix,
        quotationPrefix: quotationPrefix ?? this.quotationPrefix,
        challanPrefix: challanPrefix ?? this.challanPrefix,
        nextInvoiceNumber: nextInvoiceNumber ?? this.nextInvoiceNumber,
        nextQuotationNumber: nextQuotationNumber ?? this.nextQuotationNumber,
        nextChallanNumber: nextChallanNumber ?? this.nextChallanNumber,
        nextCreditNoteNumber: nextCreditNoteNumber ?? this.nextCreditNoteNumber,
        logoBase64: logoBase64 == _sentinel ? this.logoBase64 : logoBase64 as String?,
        headerFields: headerFields ?? this.headerFields,
        defaultTemplate: defaultTemplate ?? this.defaultTemplate,
        themeColorHex: themeColorHex == _sentinel ? this.themeColorHex : themeColorHex as String?,
        defaultTaxPercent: defaultTaxPercent ?? this.defaultTaxPercent,
        showQuantity: showQuantity ?? this.showQuantity,
        itemLabel: itemLabel ?? this.itemLabel,
        paymentMethods: paymentMethods ?? this.paymentMethods,
        verificationStatus: verificationStatus ?? this.verificationStatus,
        verificationNotes: verificationNotes == _sentinel ? this.verificationNotes : verificationNotes as String?,
        verificationSubmittedAt: verificationSubmittedAt == _sentinel ? this.verificationSubmittedAt : verificationSubmittedAt as String?,
        subscriptionTier: subscriptionTier ?? this.subscriptionTier,
        subscriptionExpiryDate: subscriptionExpiryDate == _sentinel ? this.subscriptionExpiryDate : subscriptionExpiryDate as DateTime?,
        subscriptionLastCheckedDate: subscriptionLastCheckedDate == _sentinel ? this.subscriptionLastCheckedDate : subscriptionLastCheckedDate as DateTime?,
        signatureBase64: signatureBase64 == _sentinel ? this.signatureBase64 : signatureBase64 as String?,
        showPaymentDetailsOnInvoice: showPaymentDetailsOnInvoice ?? this.showPaymentDetailsOnInvoice,
        defaultPlaceOfSupply: defaultPlaceOfSupply == _sentinel ? this.defaultPlaceOfSupply : defaultPlaceOfSupply as String?,
        defaultReverseCharge: defaultReverseCharge ?? this.defaultReverseCharge,
        isCompositionDealer: isCompositionDealer ?? this.isCompositionDealer,
        showThankYouMessage: showThankYouMessage ?? this.showThankYouMessage,
        thankYouMessage: thankYouMessage ?? this.thankYouMessage,
        showClientAcknowledgment: showClientAcknowledgment ?? this.showClientAcknowledgment,
        posEnabled: posEnabled ?? this.posEnabled,
        purchaseBillEnabled: purchaseBillEnabled ?? this.purchaseBillEnabled,
        businessType: businessType == _sentinel ? this.businessType : businessType as BusinessType?,
        professionTitle: professionTitle == _sentinel ? this.professionTitle : professionTitle as String?,
        businessInfoFields: businessInfoFields ?? this.businessInfoFields,
        defaultCreditLimit: defaultCreditLimit == _sentinel ? this.defaultCreditLimit : defaultCreditLimit as double?,
        lateFeeEnabled: lateFeeEnabled ?? this.lateFeeEnabled,
        lateFeePercent: lateFeePercent ?? this.lateFeePercent,
        gracePeriodDays: gracePeriodDays ?? this.gracePeriodDays,
        approvalWorkflowEnabled: approvalWorkflowEnabled ?? this.approvalWorkflowEnabled,
        businessMode: businessMode ?? this.businessMode,
        allowEmployeePriceChange: allowEmployeePriceChange ?? this.allowEmployeePriceChange,
        employeeDailySalesVisibilityDays: employeeDailySalesVisibilityDays == _sentinel
            ? this.employeeDailySalesVisibilityDays
            : employeeDailySalesVisibilityDays as int?,
        shopPaymentMethodIds: shopPaymentMethodIds ?? this.shopPaymentMethodIds,
        lowStockAlertsEnabled: lowStockAlertsEnabled ?? this.lowStockAlertsEnabled,
      );

  List<PaymentMethod> get allPaymentMethods {
    // Built-in generic options always available; suppress a built-in if the user
    // has already configured a specific method of the same type.
    final configuredTypes = paymentMethods.map((m) => m.type).toSet();
    final builtIns = [
      PaymentMethod.defaultCash,
      if (!configuredTypes.contains(PaymentMethodType.upi))
        PaymentMethod(
            id: '__upi__', name: 'UPI', type: PaymentMethodType.upi),
      if (!configuredTypes.contains(PaymentMethodType.bankAccount))
        PaymentMethod(
            id: '__bank__',
            name: 'Bank Transfer',
            type: PaymentMethodType.bankAccount),
      if (!configuredTypes.contains(PaymentMethodType.other)) ...[
        PaymentMethod(
            id: '__cheque__', name: 'Cheque', type: PaymentMethodType.other),
        PaymentMethod(
            id: '__other__', name: 'Other', type: PaymentMethodType.other),
      ],
    ];
    return [...builtIns, ...paymentMethods];
  }

  /// Returns the payment methods to display for a given shop's Daily Sales entry.
  /// Falls back to all [allPaymentMethods] when no per-shop config is set.
  List<PaymentMethod> paymentMethodsForShop(String shopId) {
    final ids = shopPaymentMethodIds[shopId];
    final all = allPaymentMethods;
    if (ids == null || ids.isEmpty) return all;
    return ids
        .map((id) => all.cast<PaymentMethod?>().firstWhere(
              (m) => m?.id == id,
              orElse: () => null,
            ))
        .whereType<PaymentMethod>()
        .toList();
  }

  bool get isGstRegistered => gstin != null && gstin!.isNotEmpty;

  String? get gstStateCode =>
      gstin != null && gstin!.length >= 2 ? gstin!.substring(0, 2) : null;

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'city': city,
        'state': state,
        'country': country,
        'postalCode': postalCode,
        'gstin': gstin,
        'website': website,
        'currency': currency,
        'invoicePrefix': invoicePrefix,
        'quotationPrefix': quotationPrefix,
        'challanPrefix': challanPrefix,
        'nextInvoiceNumber': nextInvoiceNumber,
        'nextQuotationNumber': nextQuotationNumber,
        'nextChallanNumber': nextChallanNumber,
        'nextCreditNoteNumber': nextCreditNoteNumber,
        'logoBase64': logoBase64,
        'headerFields': headerFields.toList(),
        'defaultTemplate': defaultTemplate.name,
        'themeColorHex': themeColorHex,
        'defaultTaxPercent': defaultTaxPercent,
        'showQuantity': showQuantity,
        'itemLabel': itemLabel,
        'paymentMethods': paymentMethods.map((m) => m.toJson()).toList(),
        'verificationStatus': verificationStatus.name,
        'verificationNotes': verificationNotes,
        'verificationSubmittedAt': verificationSubmittedAt,
        'subscriptionTier': subscriptionTier.name,
        'subscriptionExpiryDate': subscriptionExpiryDate?.toIso8601String(),
        'subscriptionLastCheckedDate': subscriptionLastCheckedDate?.toIso8601String(),
        'signatureBase64': signatureBase64,
        'showPaymentDetailsOnInvoice': showPaymentDetailsOnInvoice,
        'defaultPlaceOfSupply': defaultPlaceOfSupply,
        'defaultReverseCharge': defaultReverseCharge,
        'isCompositionDealer': isCompositionDealer,
        'showThankYouMessage': showThankYouMessage,
        'thankYouMessage': thankYouMessage,
        'showClientAcknowledgment': showClientAcknowledgment,
        'posEnabled': posEnabled,
        'purchaseBillEnabled': purchaseBillEnabled,
        'businessType': businessType?.name,
        'professionTitle': professionTitle,
        'businessInfoFields': businessInfoFields.map((f) => f.toJson()).toList(),
        'lateFeeEnabled': lateFeeEnabled,
        'lateFeePercent': lateFeePercent,
        'gracePeriodDays': gracePeriodDays,
        'defaultCreditLimit': defaultCreditLimit,
        'approvalWorkflowEnabled': approvalWorkflowEnabled,
        'businessMode': businessMode.name,
        'allowEmployeePriceChange': allowEmployeePriceChange,
        'employeeDailySalesVisibilityDays': employeeDailySalesVisibilityDays,
        'shopPaymentMethodIds': shopPaymentMethodIds.map(
            (k, v) => MapEntry(k, v)),
        'lowStockAlertsEnabled': lowStockAlertsEnabled,
      };

  factory BusinessProfile.fromJson(Map<String, dynamic> json) =>
      BusinessProfile(
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        phone: json['phone'] ?? '',
        address: json['address'] ?? '',
        city: json['city'] ?? '',
        state: json['state'] ?? '',
        country: json['country'] ?? 'India',
        postalCode: json['postalCode'] ?? '',
        gstin: json['gstin'],
        website: json['website'],
        currency: json['currency'] ?? 'INR',
        invoicePrefix: json['invoicePrefix'] ?? 'INV-',
        quotationPrefix: json['quotationPrefix'] ?? 'QT-',
        challanPrefix: json['challanPrefix'] ?? 'DC-',
        nextInvoiceNumber: json['nextInvoiceNumber'] ?? 1,
        nextQuotationNumber: json['nextQuotationNumber'] ?? 1,
        nextChallanNumber: json['nextChallanNumber'] ?? 1,
        nextCreditNoteNumber: json['nextCreditNoteNumber'] ?? 1,
        logoBase64: json['logoBase64'],
        headerFields: _parseHeaderFields(json),
        defaultTemplate: InvoiceTemplate.values.firstWhere(
          (e) => e.name == json['defaultTemplate'],
          orElse: () => InvoiceTemplate.classic,
        ),
        themeColorHex: json['themeColorHex'],
        defaultTaxPercent: (json['defaultTaxPercent'] as num?)?.toDouble() ?? 0,
        showQuantity: json['showQuantity'] as bool? ?? true,
        itemLabel: json['itemLabel'] as String? ?? 'Item',
        paymentMethods: (json['paymentMethods'] as List<dynamic>?)
                ?.map((e) => PaymentMethod.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        verificationStatus: VerificationStatus.values.firstWhere(
          (e) => e.name == json['verificationStatus'],
          orElse: () => VerificationStatus.unverified,
        ),
        verificationNotes: json['verificationNotes'] as String?,
        verificationSubmittedAt: json['verificationSubmittedAt'] as String?,
        subscriptionTier: SubscriptionTier.values.firstWhere(
          (e) => e.name == json['subscriptionTier'],
          orElse: () => SubscriptionTier.free,
        ),
        subscriptionExpiryDate: json['subscriptionExpiryDate'] != null
            ? DateTime.parse(json['subscriptionExpiryDate'] as String)
            : null,
        subscriptionLastCheckedDate: json['subscriptionLastCheckedDate'] != null
            ? DateTime.parse(json['subscriptionLastCheckedDate'] as String)
            : null,
        signatureBase64: json['signatureBase64'] as String?,
        showPaymentDetailsOnInvoice:
            json['showPaymentDetailsOnInvoice'] as bool? ?? true,
        defaultPlaceOfSupply: json['defaultPlaceOfSupply'] as String?,
        defaultReverseCharge: json['defaultReverseCharge'] as bool? ?? false,
        isCompositionDealer: json['isCompositionDealer'] as bool? ?? false,
        showThankYouMessage: json['showThankYouMessage'] as bool? ?? true,
        thankYouMessage: json['thankYouMessage'] as String? ?? 'Thank you for your business!',
        showClientAcknowledgment: json['showClientAcknowledgment'] as bool? ?? true,
        posEnabled: json['posEnabled'] as bool? ?? false,
        purchaseBillEnabled: json['purchaseBillEnabled'] as bool? ?? true,
        businessType: json['businessType'] != null
            ? BusinessType.values.firstWhere(
                (e) => e.name == json['businessType'],
                orElse: () => BusinessType.other)
            : null,
        professionTitle: json['professionTitle'] as String?,
        businessInfoFields: (json['businessInfoFields'] as List<dynamic>?)
                ?.map((e) => CustomField.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        lateFeeEnabled: json['lateFeeEnabled'] as bool? ?? false,
        lateFeePercent: (json['lateFeePercent'] as num?)?.toDouble() ?? 2.0,
        gracePeriodDays: json['gracePeriodDays'] as int? ?? 0,
        defaultCreditLimit: (json['defaultCreditLimit'] as num?)?.toDouble(),
        approvalWorkflowEnabled: json['approvalWorkflowEnabled'] as bool? ?? false,
        businessMode: BusinessMode.values.firstWhere(
          (e) => e.name == json['businessMode'],
          orElse: () => BusinessMode.invoiceBased,
        ),
        allowEmployeePriceChange: json['allowEmployeePriceChange'] as bool? ?? true,
        employeeDailySalesVisibilityDays:
            json['employeeDailySalesVisibilityDays'] as int?,
        shopPaymentMethodIds: (json['shopPaymentMethodIds'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(
                    k, (v as List<dynamic>).map((e) => e as String).toList())) ??
            {},
        lowStockAlertsEnabled: json['lowStockAlertsEnabled'] as bool? ?? true,
      );

  /// Parses the `serviceItems` that older app versions stored inside the
  /// profile blob, for one-time migration into the local items database.
  /// `BusinessProfile` itself no longer stores these.
  static List<ServiceItem> extractLegacyServiceItems(Map<String, dynamic> json) =>
      (json['serviceItems'] as List<dynamic>?)
          ?.map((e) => ServiceItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [];
}

Set<String> _parseHeaderFields(Map<String, dynamic> json) {
  // New format: list of string keys.
  if (json['headerFields'] is List) {
    return Set<String>.from(json['headerFields'] as List);
  }
  // Migrate from legacy InvoiceHeaderStyle enum string.
  switch (json['headerStyle'] as String?) {
    case 'logoOnly':
      return {kHeaderLogo};
    case 'textOnly':
      return {kHeaderName, kHeaderAddress};
    default: // 'logoAndText' or missing
      return {kHeaderLogo, kHeaderName, kHeaderAddress};
  }
}
