// lib/models/transaction.dart
import 'package:intl/intl.dart';

class Transaction {
  final int? id;
  final int submittedBy;
  final String? submittedByUsername;

  final DateTime transactionDate;

  final int group;
  final String groupName;

  final int paymentAccount;
  final String paymentAccountName;

  final String transferIdLast6Digits;

  final double amount;

  /// 'income' | 'expense'
  final String transactionType;

  /// ✅ Backend: transaction_type_display (read-only) → Flutter: transactionTypeDisplay
  final String? transactionTypeDisplay;

  /// Backend: 'image' file/url → map to imageUrl
  final String? imageUrl;

  final DateTime submittedAt;

  /// 'pending' | 'approved' | 'rejected'
  final String status;

  /// ✅ Backend: status_display (read-only) → Flutter: statusDisplay
  final String? statusDisplay;

  final DateTime? approvedByOwnerAt;
  final String? ownerNotes;

  Transaction({
    this.id,
    required this.submittedBy,
    this.submittedByUsername,
    required this.transactionDate,
    required this.group,
    required this.groupName,
    required this.paymentAccount,
    required this.paymentAccountName,
    required this.transferIdLast6Digits,
    required this.amount,
    required this.transactionType,
    this.transactionTypeDisplay,
    this.imageUrl,
    required this.submittedAt,
    required this.status,
    this.statusDisplay,
    this.approvedByOwnerAt,
    this.ownerNotes,
  });

  factory Transaction.fromJson(Map<String, dynamic> j) {
    // Date-only or datetime-safe parsing
    DateTime _parseDate(String? s) {
      if (s == null || s.isEmpty) return DateTime.now();
      return DateTime.parse(s);
    }

    double _toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    return Transaction(
      id: j['id'] as int?,
      submittedBy: j['submitted_by'] as int? ?? -1,
      submittedByUsername: j['submitted_by_username'] as String?,
      transactionDate: _parseDate(j['transaction_date'] as String?),
      group: j['group'] as int? ?? -1,
      groupName: (j['group_name'] ?? '') as String,
      paymentAccount: j['payment_account'] as int? ?? -1,
      paymentAccountName: (j['payment_account_name'] ?? '') as String,
      transferIdLast6Digits: (j['transfer_id_last_6_digits'] ?? '') as String,
      amount: _toDouble(j['amount']),
      transactionType: (j['transaction_type'] ?? '') as String,

      // ✅ map read-only display labels
      transactionTypeDisplay: j['transaction_type_display'] as String?,
      statusDisplay: j['status_display'] as String?,

      // image → imageUrl
      imageUrl: j['image'] as String?,

      submittedAt: _parseDate(j['submitted_at'] as String?),
      status: (j['status'] ?? '') as String,
      approvedByOwnerAt: j['approved_by_owner_at'] != null
          ? _parseDate(j['approved_by_owner_at'] as String?)
          : null,
      ownerNotes: j['owner_notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    // Server မလိုတဲ့ read-only fields မထည့်ပါ (display fields/imageUrl)
    return {
      if (id != null) 'id': id,
      'submitted_by': submittedBy,
      'transaction_date': DateFormat('yyyy-MM-dd').format(transactionDate),
      'group': group,
      'payment_account': paymentAccount,
      'transfer_id_last_6_digits': transferIdLast6Digits,
      'amount': amount, // server accepts number
      'transaction_type': transactionType,
      'status': status,
      if (ownerNotes != null) 'owner_notes': ownerNotes,
    };
  }

  Transaction copyWith({
    int? id,
    int? submittedBy,
    String? submittedByUsername,
    DateTime? transactionDate,
    int? group,
    String? groupName,
    int? paymentAccount,
    String? paymentAccountName,
    String? transferIdLast6Digits,
    double? amount,
    String? transactionType,
    String? transactionTypeDisplay,
    String? imageUrl,
    DateTime? submittedAt,
    String? status,
    String? statusDisplay,
    DateTime? approvedByOwnerAt,
    String? ownerNotes,
  }) {
    return Transaction(
      id: id ?? this.id,
      submittedBy: submittedBy ?? this.submittedBy,
      submittedByUsername: submittedByUsername ?? this.submittedByUsername,
      transactionDate: transactionDate ?? this.transactionDate,
      group: group ?? this.group,
      groupName: groupName ?? this.groupName,
      paymentAccount: paymentAccount ?? this.paymentAccount,
      paymentAccountName: paymentAccountName ?? this.paymentAccountName,
      transferIdLast6Digits:
          transferIdLast6Digits ?? this.transferIdLast6Digits,
      amount: amount ?? this.amount,
      transactionType: transactionType ?? this.transactionType,
      transactionTypeDisplay:
          transactionTypeDisplay ?? this.transactionTypeDisplay,
      imageUrl: imageUrl ?? this.imageUrl,
      submittedAt: submittedAt ?? this.submittedAt,
      status: status ?? this.status,
      statusDisplay: statusDisplay ?? this.statusDisplay,
      approvedByOwnerAt: approvedByOwnerAt ?? this.approvedByOwnerAt,
      ownerNotes: ownerNotes ?? this.ownerNotes,
    );
  }
}
