class User {
  final int? id;
  final String username;
  final String email;
  final String userType; // 'owner' or 'auditor'
  final String? firstName;
  final String? lastName;
  final String? phoneNumber;
  final bool? isStaff; // <-- nullable ဖြစ်အောင် ? ထည့်ပါ။
  final bool? isActive; // <-- nullable ဖြစ်အောင် ? ထည့်ပါ။
  final DateTime? dateJoined; // <-- nullable ဖြစ်အောင် ? ထည့်ပါ။

  User({
    this.id,
    required this.username,
    required this.email,
    required this.userType,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.isStaff, // <-- constructor မှာလည်း nullable ဖြစ်အောင် ထားပါ။
    this.isActive, // <-- constructor မှာလည်း nullable ဖြစ်အောင် ထားပါ။
    this.dateJoined, // <-- constructor မှာလည်း nullable ဖြစ်အောင် ထားပါ။
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      userType: json['user_type'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      phoneNumber: json['phone_number'],
      isStaff: json['is_staff'], // API က ပြန်ပေးတဲ့အတိုင်း
      isActive: json['is_active'], // API က ပြန်ပေးတဲ့အတိုင်း
      dateJoined: json['date_joined'] != null ? DateTime.parse(json['date_joined']) : null, // API က ပြန်ပေးတဲ့အတိုင်း
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'user_type': userType,
      'first_name': firstName,
      'last_name': lastName,
      'phone_number': phoneNumber,
      // is_staff, is_active, date_joined တွေကို create/update မှာ မပို့သင့်ပါ။
      // Backend က အလိုအလျောက် ကိုင်တွယ်သင့်တဲ့ fields တွေပါ။
      // ဒါပေမယ့် update လုပ်တဲ့အခါ is_active ကို ပို့ချင်ရင်တော့ ထည့်နိုင်ပါတယ်။
      // 'is_staff': isStaff,
      // 'is_active': isActive,
      // 'date_joined': dateJoined?.toIso8601String(),
    };
  }
}
