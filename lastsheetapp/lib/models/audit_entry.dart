import 'dart:io';

class AuditEntry {
  final int? id;
  final int group; // group ID
  final String groupName;
  final int auditor; // auditor ID
  final String auditorUsername;
  final double receivableAmount;
  final double payableAmount;
  final String? remarks;
  final DateTime? createdAt;
  final DateTime? lastUpdated;

  AuditEntry({
    this.id,
    required this.group,
    required this.groupName,
    required this.auditor,
    required this.auditorUsername,
    required this.receivableAmount,
    required this.payableAmount,
    this.remarks,
    this.createdAt,
    this.lastUpdated,
    File? imageFile,
    String? imageUrl,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> json) {
    return AuditEntry(
      id: json['id'],
      group: json['group'],
      groupName: json['group_name'],
      auditor: json['auditor'],
      auditorUsername: json['auditor_username'],
      receivableAmount: double.parse(json['receivable_amount'].toString()),
      payableAmount: double.parse(json['payable_amount'].toString()),
      remarks: json['remarks'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group': group,
      'auditor': auditor,
      'receivable_amount': receivableAmount.toString(),
      'payable_amount': payableAmount.toString(),
      'remarks': remarks,
    };
  }
}
