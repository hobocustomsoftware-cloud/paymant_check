// lib/models/audit_summary.dart
class AuditSummary {
  final String groupName;
  final double totalReceivable;
  final double totalPayable;
  final double netBalance;
  final DateTime? lastAuditDate; // Made nullable

  AuditSummary({
    required this.groupName,
    required this.totalReceivable,
    required this.totalPayable,
    required this.netBalance,
    this.lastAuditDate,
  });

  factory AuditSummary.fromJson(Map<String, dynamic> json) {
    return AuditSummary(
      groupName: json['group_name'] as String? ?? 'N/A', // Ensure type cast and default
      totalReceivable: (json['total_receivable'] as num?)?.toDouble() ?? 0.0,
      totalPayable: (json['total_payable'] as num?)?.toDouble() ?? 0.0,
      netBalance: (json['net_balance'] as num?)?.toDouble() ?? 0.0,
      lastAuditDate: json['last_audit_date'] != null
          ? DateTime.parse(json['last_audit_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'group_name': groupName,
      'total_receivable': totalReceivable,
      'total_payable': totalPayable,
      'net_balance': netBalance,
      'last_audit_date': lastAuditDate?.toIso8601String(),
    };
  }
}
