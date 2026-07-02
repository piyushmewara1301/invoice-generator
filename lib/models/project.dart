// ─────────────────────────────────────────────────────────────────────────────
// Project — a billable engagement tied to a client.
// Groups TimeEntry records and drives invoice generation.
// ─────────────────────────────────────────────────────────────────────────────

class Project {
  final String id;
  String name;
  String? clientId;
  String? clientName; // cached for display
  double defaultHourlyRate; // fallback rate for new time entries
  String currency;
  bool isActive;
  final DateTime createdAt;
  String? description;

  Project({
    required this.id,
    required this.name,
    this.clientId,
    this.clientName,
    this.defaultHourlyRate = 1000.0,
    this.currency = 'INR',
    this.isActive = true,
    DateTime? createdAt,
    this.description,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'clientId': clientId,
        'clientName': clientName,
        'defaultHourlyRate': defaultHourlyRate,
        'currency': currency,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'description': description,
      };

  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        clientId: j['clientId'] as String?,
        clientName: j['clientName'] as String?,
        defaultHourlyRate:
            (j['defaultHourlyRate'] as num?)?.toDouble() ?? 1000.0,
        currency: j['currency'] as String? ?? 'INR',
        isActive: j['isActive'] as bool? ?? true,
        createdAt: j['createdAt'] != null
            ? DateTime.parse(j['createdAt'] as String)
            : null,
        description: j['description'] as String?,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// TimeEntry — a single block of billable work on a project.
// ─────────────────────────────────────────────────────────────────────────────

class TimeEntry {
  final String id;
  final String projectId;
  String memberName; // person who did the work (free text — not tied to Employee model)
  String? memberId; // optional Employee.id for team members
  double hours; // decimal hours, e.g. 1.5 = 1h 30m
  double hourlyRate; // frozen at entry time
  DateTime date; // date of work
  String description; // what was done
  bool isBilled; // true once on a generated invoice
  String? invoiceId; // which invoice this entry ended up on
  final DateTime createdAt;

  TimeEntry({
    required this.id,
    required this.projectId,
    required this.memberName,
    this.memberId,
    required this.hours,
    required this.hourlyRate,
    required this.date,
    required this.description,
    this.isBilled = false,
    this.invoiceId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get billableAmount => hours * hourlyRate;

  TimeEntry copyWith({
    String? memberName,
    String? memberId,
    double? hours,
    double? hourlyRate,
    DateTime? date,
    String? description,
    bool? isBilled,
    String? invoiceId,
  }) =>
      TimeEntry(
        id: id,
        projectId: projectId,
        memberName: memberName ?? this.memberName,
        memberId: memberId ?? this.memberId,
        hours: hours ?? this.hours,
        hourlyRate: hourlyRate ?? this.hourlyRate,
        date: date ?? this.date,
        description: description ?? this.description,
        isBilled: isBilled ?? this.isBilled,
        invoiceId: invoiceId ?? this.invoiceId,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'memberName': memberName,
        'memberId': memberId,
        'hours': hours,
        'hourlyRate': hourlyRate,
        'date': date.toIso8601String(),
        'description': description,
        'isBilled': isBilled,
        'invoiceId': invoiceId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TimeEntry.fromJson(Map<String, dynamic> j) => TimeEntry(
        id: j['id'] as String,
        projectId: j['projectId'] as String,
        memberName: j['memberName'] as String? ?? '',
        memberId: j['memberId'] as String?,
        hours: (j['hours'] as num?)?.toDouble() ?? 0,
        hourlyRate: (j['hourlyRate'] as num?)?.toDouble() ?? 0,
        date: DateTime.parse(j['date'] as String),
        description: j['description'] as String? ?? '',
        isBilled: j['isBilled'] as bool? ?? false,
        invoiceId: j['invoiceId'] as String?,
        createdAt: j['createdAt'] != null
            ? DateTime.parse(j['createdAt'] as String)
            : null,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Grouping option for invoice generation
// ─────────────────────────────────────────────────────────────────────────────

enum TimeEntryGrouping {
  byEntry,  // one line item per time entry
  byMember, // one line item per team member (hours summed)
  total,    // single line item with all hours combined
}
