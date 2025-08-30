import 'package:intl/intl.dart';

class Transaction {
  final int? id;
  final DateTime transactionDate;
  final int group;
  final String groupName;
  final int paymentAccount;
  final String paymentAccountName;
  final String transferIdLast6Digits;
  final double amount; // <-- num/string ဘယ်လိုပဲလာလာ double သို့ map
  final String transactionType;
  final int submittedBy;
  final String? submittedByUsername;
  final String status;
  final String? imageUrl;
  final DateTime submittedAt;
  final DateTime? approvedByOwnerAt;
  final String? ownerNotes;

  Transaction({
    this.id,
    required this.transactionDate,
    required this.group,
    required this.groupName,
    required this.paymentAccount,
    required this.paymentAccountName,
    required this.transferIdLast6Digits,
    required this.amount,
    required this.transactionType,
    required this.submittedBy,
    this.submittedByUsername,
    required this.status,
    this.imageUrl,
    required this.submittedAt,
    this.approvedByOwnerAt,
    this.ownerNotes,
  });

  // ---------- helpers ----------
  static double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) {
      // "20,000.00" လို format တွေလည်း ကိုင်နိုင်အောင်
      final cleaned = v.replaceAll(',', '').trim();
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    if (v is num) return v.toInt();
    return 0;
  }

  static DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is String && v.isEmpty) return null;
    return DateTime.parse(v as String);
  }

  // ---------- JSON ----------
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as int?,
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      group: _asInt(json['group']),
      groupName: (json['group_name'] ?? '') as String,
      paymentAccount: _asInt(json['payment_account']),
      paymentAccountName: (json['payment_account_name'] ?? '') as String,
      transferIdLast6Digits:
          (json['transfer_id_last_6_digits'] ?? '') as String,
      amount: _asDouble(json['amount']), // <-- FIX
      transactionType: (json['transaction_type'] ?? '') as String,
      submittedBy: _asInt(json['submitted_by']),
      submittedByUsername: json['submitted_by_username']?.toString(),
      status: (json['status'] ?? 'pending').toString(),
      imageUrl: json['image']?.toString(),
      submittedAt: DateTime.parse(json['submitted_at'] as String),
      approvedByOwnerAt: _asDateTime(json['approved_by_owner_at']),
      ownerNotes: json['owner_notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_date': DateFormat('yyyy-MM-dd').format(transactionDate),
      'group': group,
      'group_name': groupName,
      'payment_account': paymentAccount,
      'payment_account_name': paymentAccountName,
      'transfer_id_last_6_digits': transferIdLast6Digits,
      // Multipart POST/PUT တွေက field တွေကို string အဖြစ်ပို့ရတာများ—string အဖြစ် serialize
      'amount': amount.toString(),
      'transaction_type': transactionType,
      'submitted_by': submittedBy,
      'submitted_by_username': submittedByUsername,
      'status': status,
      'image': imageUrl,
      'submitted_at': submittedAt.toIso8601String(),
      'approved_by_owner_at': approvedByOwnerAt?.toIso8601String(),
      'owner_notes': ownerNotes,
    };
  }
}
