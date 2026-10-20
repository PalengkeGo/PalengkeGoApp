/// Immutable domain model representing a user or stallholder report.
/// Matches the schema used in both `PalengkeGoAPP` and `Palengke Admin`.
class UserReport {
  final String id;
  final String? userId;
  final String type; // 'Customer', 'Vendor', 'Stall Holder'
  final String accountIssue;
  final String category;
  final String submittedBy;
  final String reason;
  final String description;
  final String reporterEmail;
  final String phone;
  final String vendorName;
  final String owner;
  final String stallNumber;
  final int previousViolations;
  final String status; // 'pending', 'underReview', 'resolved', 'dismissed'
  final String priority; // 'low', 'medium', 'high'
  final String notes;
  final String? decision;
  final String? actionTaken;
  final String? resolutionNote;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String> evidenceUrls;

  const UserReport({
    required this.id,
    this.userId,
    this.type = 'Customer',
    required this.accountIssue,
    this.category = 'General',
    required this.submittedBy,
    required this.reason,
    required this.description,
    this.reporterEmail = '',
    this.phone = '',
    this.vendorName = '',
    this.owner = '',
    this.stallNumber = '',
    this.previousViolations = 0,
    this.status = 'pending',
    this.priority = 'medium',
    this.notes = '',
    this.decision,
    this.actionTaken,
    this.resolutionNote,
    this.resolvedAt,
    this.resolvedBy,
    required this.createdAt,
    this.updatedAt,
    this.evidenceUrls = const [],
  });

  bool get isResolved => status.toLowerCase() == 'resolved';
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isDismissed => status.toLowerCase() == 'dismissed';
  bool get isUnderReview =>
      status.toLowerCase() == 'underreview' ||
      status.toLowerCase() == 'under_review';

  Map<String, dynamic> toJson() => {
        'id': id,
        if (userId != null && userId!.isNotEmpty) 'user_id': userId,
        'type': type,
        'account_issue': accountIssue,
        'category': category,
        'submitted_by': submittedBy,
        'reason': reason,
        'description': description,
        'reporter_email': reporterEmail,
        'phone': phone,
        'vendor_name': vendorName,
        'owner': owner,
        'stall_number': stallNumber,
        'previous_violations': previousViolations,
        'status': status,
        'priority': priority,
        'notes': notes,
        if (decision != null) 'decision': decision,
        if (actionTaken != null) 'action_taken': actionTaken,
        if (resolutionNote != null) 'resolution_note': resolutionNote,
        if (resolvedAt != null) 'resolved_at': resolvedAt!.toIso8601String(),
        if (resolvedBy != null) 'resolved_by': resolvedBy,
        if (evidenceUrls.isNotEmpty) 'evidence_urls': evidenceUrls,
        'created_at': createdAt.toIso8601String(),
        'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      };

  factory UserReport.fromJson(Map<String, dynamic> json) {
    return UserReport(
      id: (json['id'] ?? '').toString(),
      userId: json['user_id']?.toString(),
      type: (json['type'] ?? 'Customer').toString(),
      accountIssue: (json['account_issue'] ?? json['accountIssue'] ?? '').toString(),
      category: (json['category'] ?? 'General').toString(),
      submittedBy: (json['submitted_by'] ?? json['submittedBy'] ?? 'User').toString(),
      reason: (json['reason'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      reporterEmail: (json['reporter_email'] ?? json['reporterEmail'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      vendorName: (json['vendor_name'] ?? json['vendorName'] ?? '').toString(),
      owner: (json['owner'] ?? '').toString(),
      stallNumber: (json['stall_number'] ?? json['stallNumber'] ?? '').toString(),
      previousViolations: (json['previous_violations'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? 'pending').toString(),
      priority: (json['priority'] ?? 'medium').toString(),
      notes: (json['notes'] ?? '').toString(),
      decision: json['decision']?.toString(),
      actionTaken: (json['action_taken'] ?? json['actionTaken'])?.toString(),
      resolutionNote: (json['resolution_note'] ?? json['resolutionNote'])?.toString(),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'].toString())
          : null,
      resolvedBy: (json['resolved_by'] ?? json['resolvedBy'])?.toString(),
      createdAt: DateTime.tryParse(
            json['created_at']?.toString() ?? json['date']?.toString() ?? '',
          ) ??
          DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      evidenceUrls: () {
        final raw = json['evidence_urls'] ?? json['evidenceUrls'];
        if (raw is List) {
          return raw.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
        }
        return const <String>[];
      }(),
    );
  }

  UserReport copyWith({
    String? status,
    String? notes,
    String? decision,
    String? actionTaken,
    String? resolutionNote,
    DateTime? resolvedAt,
    String? resolvedBy,
    List<String>? evidenceUrls,
  }) {
    return UserReport(
      id: id,
      userId: userId,
      type: type,
      accountIssue: accountIssue,
      category: category,
      submittedBy: submittedBy,
      reason: reason,
      description: description,
      reporterEmail: reporterEmail,
      phone: phone,
      vendorName: vendorName,
      owner: owner,
      stallNumber: stallNumber,
      previousViolations: previousViolations,
      status: status ?? this.status,
      priority: priority,
      notes: notes ?? this.notes,
      decision: decision ?? this.decision,
      actionTaken: actionTaken ?? this.actionTaken,
      resolutionNote: resolutionNote ?? this.resolutionNote,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      evidenceUrls: evidenceUrls ?? this.evidenceUrls,
    );
  }
}
