import 'package:intl/intl.dart';

class Transaction {
  final int? id;
  final int submittedBy;
  final String submittedByUsername; // For display purposes
  final DateTime transactionDate;
  final int group;
  final String groupName; // For display purposes
  final int paymentAccount;
  final String paymentAccountName; // For display purposes
  final String transferIdLast6Digits;
  final double amount;
  final String transactionType; // 'income' or 'expense'
  final String status; // 'pending', 'approved', 'rejected'
  final String? imageUrl;
  final DateTime? approvedByOwnerAt;
  final String? ownerNotes;
  final DateTime submittedAt; // Add submittedAt field

  Transaction({
    this.id,
    required this.submittedBy,
    required this.submittedByUsername,
    required this.transactionDate,
    required this.group,
    required this.groupName,
    required this.paymentAccount,
    required this.paymentAccountName,
    required this.transferIdLast6Digits,
    required this.amount,
    required this.transactionType,
    required this.status,
    this.imageUrl,
    this.approvedByOwnerAt,
    this.ownerNotes,
    required this.submittedAt, // Make it required
  });

  // Helper getter for display
  String get transactionTypeDisplay {
    return transactionType == 'income' ? 'ဝင်ငွေ' : 'ထွက်ငွေ';
  }

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'စောင့်ဆိုင်းဆဲ';
      case 'approved':
        return 'အတည်ပြုပြီး';
      case 'rejected':
        return 'ပယ်ချပြီး';
      default:
        return status;
    }
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      submittedBy: json['submitted_by'],
      submittedByUsername: json['submitted_by_username'],
      transactionDate: DateTime.parse(json['transaction_date']),
      group: json['group'],
      groupName: json['group_name'],
      paymentAccount: json['payment_account'],
      paymentAccountName: json['payment_account_name'],
      transferIdLast6Digits: json['transfer_id_last_6_digits'],
      amount: (json['amount'] as num).toDouble(),
      transactionType: json['transaction_type'],
      status: json['status'],
      imageUrl: json['image_url'],
      approvedByOwnerAt: json['approved_by_owner_at'] != null
          ? DateTime.parse(json['approved_by_owner_at'])
          : null,
      ownerNotes: json['owner_notes'],
      submittedAt: DateTime.parse(json['submitted_at']), // Parse submitted_at
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'submitted_by': submittedBy,
      'submitted_by_username': submittedByUsername,
      'transaction_date': transactionDate.toIso8601String(),
      'group': group,
      'group_name': groupName,
      'payment_account': paymentAccount,
      'payment_account_name': paymentAccountName,
      'transfer_id_last_6_digits': transferIdLast6Digits,
      'amount': amount,
      'transaction_type': transactionType,
      'status': status,
      'image_url': imageUrl,
      'approved_by_owner_at': approvedByOwnerAt?.toIso8601String(),
      'owner_notes': ownerNotes,
      'submitted_at': submittedAt.toIso8601String(), // Include submitted_at
    };
  }

  // Helper method to create a copy with updated fields
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
    String? status,
    String? imageUrl,
    DateTime? approvedByOwnerAt,
    String? ownerNotes,
    DateTime? submittedAt,
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
      transferIdLast6Digits: transferIdLast6Digits ?? this.transferIdLast6Digits,
      amount: amount ?? this.amount,
      transactionType: transactionType ?? this.transactionType,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      approvedByOwnerAt: approvedByOwnerAt ?? this.approvedByOwnerAt,
      ownerNotes: ownerNotes ?? this.ownerNotes,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }
}
