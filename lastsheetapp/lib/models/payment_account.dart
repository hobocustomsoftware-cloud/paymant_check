class PaymentAccount {
  final int? id;
  final int owner; // owner ID
  final String? ownerUsername;
  final String paymentAccountName;
  final String paymentAccountType;
  final String? bankName;
  final String? bankAccountNumber;
  final String? phoneNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PaymentAccount({
    this.id,
    required this.owner,
    this.ownerUsername,
    required this.paymentAccountName,
    required this.paymentAccountType,
    this.bankName,
    this.bankAccountNumber,
    this.phoneNumber,
    this.createdAt,
    this.updatedAt,
  });

  factory PaymentAccount.fromJson(Map<String, dynamic> json) {
    return PaymentAccount(
      id: json['id'],
      owner: json['owner'],
      ownerUsername: json['owner_username'],
      paymentAccountName: json['payment_account_name'],
      paymentAccountType: json['payment_account_type'],
      bankName: json['bank_name'],
      bankAccountNumber: json['bank_account_number'],
      phoneNumber: json['phone_number'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner': owner,
      'payment_account_name': paymentAccountName,
      'payment_account_type': paymentAccountType,
      'bank_name': bankName,
      'bank_account_number': bankAccountNumber,
      'phone_number': phoneNumber,
    };
  }
}