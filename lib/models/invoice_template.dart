enum InvoiceTemplate { classic, minimal, corporate, modern, restaurant, receipt, professional, gstBill, letterhead }

extension InvoiceTemplateInfo on InvoiceTemplate {
  String get displayName {
    switch (this) {
      case InvoiceTemplate.classic:
        return 'Classic';
      case InvoiceTemplate.minimal:
        return 'Minimal';
      case InvoiceTemplate.corporate:
        return 'Corporate';
      case InvoiceTemplate.modern:
        return 'Modern';
      case InvoiceTemplate.restaurant:
        return 'Restaurant';
      case InvoiceTemplate.receipt:
        return 'Receipt';
      case InvoiceTemplate.professional:
        return 'Professional';
      case InvoiceTemplate.gstBill:
        return 'GST Bill';
      case InvoiceTemplate.letterhead:
        return 'Letterhead';
    }
  }

  String get description {
    switch (this) {
      case InvoiceTemplate.classic:
        return 'Blue accents, structured grid layout';
      case InvoiceTemplate.minimal:
        return 'Clean, typography-first, black & white';
      case InvoiceTemplate.corporate:
        return 'Dark header, formal & professional';
      case InvoiceTemplate.modern:
        return 'Teal accents, contemporary design';
      case InvoiceTemplate.restaurant:
        return 'Burgundy & gold, centered dining style';
      case InvoiceTemplate.receipt:
        return 'Compact POS receipt with QR · for cafes & restaurants';
      case InvoiceTemplate.professional:
        return 'Letterhead style · for lawyers, CAs & consultants';
      case InvoiceTemplate.gstBill:
        return 'GST-compliant · CGST/SGST/IGST split · HSN/SAC column';
      case InvoiceTemplate.letterhead:
        return 'Double-rule header · Sr.No/Particulars/Amount · for advocates & CAs';
    }
  }
}
