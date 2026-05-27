import 'invoice_template.dart';
import 'payment_method.dart';
import 'service_item.dart';

export 'invoice_template.dart';
export 'payment_method.dart';
export 'service_item.dart';

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

enum SubscriptionTier { free, lite, pro, premium }

extension SubscriptionTierX on SubscriptionTier {
  bool get isAnyPaid => this != SubscriptionTier.free;
  bool get isPro => this == SubscriptionTier.pro || this == SubscriptionTier.premium;
  bool get isPremium => this == SubscriptionTier.premium;
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
  int nextInvoiceNumber;
  String? logoBase64;
  Set<String> headerFields;
  InvoiceTemplate defaultTemplate;
  String? themeColorHex;
  double defaultTaxPercent;
  bool showQuantity;
  String itemLabel;
  List<PaymentMethod> paymentMethods;
  List<ServiceItem> serviceItems;
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
    this.nextInvoiceNumber = 1,
    this.logoBase64,
    Set<String>? headerFields,
    this.defaultTemplate = InvoiceTemplate.classic,
    this.themeColorHex,
    this.defaultTaxPercent = 0,
    this.showQuantity = true,
    this.itemLabel = 'Item',
    List<PaymentMethod>? paymentMethods,
    List<ServiceItem>? serviceItems,
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
  })  : headerFields = headerFields ?? {kHeaderLogo, kHeaderName, kHeaderAddress},
        paymentMethods = paymentMethods ?? [],
        serviceItems = serviceItems ?? [];

  List<PaymentMethod> get allPaymentMethods =>
      [PaymentMethod.defaultCash, ...paymentMethods];

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
        'nextInvoiceNumber': nextInvoiceNumber,
        'logoBase64': logoBase64,
        'headerFields': headerFields.toList(),
        'defaultTemplate': defaultTemplate.name,
        'themeColorHex': themeColorHex,
        'defaultTaxPercent': defaultTaxPercent,
        'showQuantity': showQuantity,
        'itemLabel': itemLabel,
        'paymentMethods': paymentMethods.map((m) => m.toJson()).toList(),
        'serviceItems': serviceItems.map((s) => s.toJson()).toList(),
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
        nextInvoiceNumber: json['nextInvoiceNumber'] ?? 1,
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
        serviceItems: (json['serviceItems'] as List<dynamic>?)
                ?.map((e) => ServiceItem.fromJson(e as Map<String, dynamic>))
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
      );
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
