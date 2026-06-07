/// A single entry in the operation log. Every CRUD action appends one of these
/// so there is a full audit trail of who did what and when.
///
/// Op types:
///   createInvoice, updateInvoice, deleteInvoice, updateInvoiceStatus
///   createClient,  updateClient,  deleteClient
///   updateProfile
class OpEntry {
  final String id;
  final String actorEmail;
  final DateTime timestamp;
  final String opType;
  final String entityId;

  /// Human-readable label (invoice number, client name, etc.)
  final String entityLabel;

  const OpEntry({
    required this.id,
    required this.actorEmail,
    required this.timestamp,
    required this.opType,
    required this.entityId,
    required this.entityLabel,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'actorEmail': actorEmail,
        'timestamp': timestamp.toIso8601String(),
        'opType': opType,
        'entityId': entityId,
        'entityLabel': entityLabel,
      };

  factory OpEntry.fromJson(Map<String, dynamic> json) => OpEntry(
        id: json['id'] as String? ?? '',
        actorEmail: json['actorEmail'] as String? ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
        opType: json['opType'] as String? ?? '',
        entityId: json['entityId'] as String? ?? '',
        entityLabel: json['entityLabel'] as String? ?? '',
      );
}
