import 'dart:io' show Platform;
// kIsWeb ကို ထည့်ပါ။
import 'package:flutter/foundation.dart' show kIsWeb;

class Constants {
  static const String _localHostAndroid = '10.0.2.2';
  static const String _localHostIOS = 'localhost';
  static const String _physicalDeviceHost = '192.168.1.5';

  static String get _baseHost {
    // Check if the app is running on the web FIRST.
    if (kIsWeb) {
      return 'localhost';
    } else if (Platform.isAndroid) {
      return '10.0.2.2'; // Your Android emulator IP
    } else if (Platform.isIOS) {
      return 'localhost'; // Your iOS simulator IP
    } else {
      // Fallback for other platforms (e.g., desktop)
      return 'localhost';
    }
  }

  // static const String _port = '8000';
  // static const String _apiPath = '/api';

  static String get baseUrl {
    return 'http://${_baseHost}:8000/api';
  }

  static final String loginUrl = '$baseUrl/auth/token/login/';
  static final String logoutUrl = '$baseUrl/auth/token/logout/';
  static final String groupsUrl = '$baseUrl/sheets/groups/';
  static final String paymentAccountsUrl = '$baseUrl/sheets/payment-accounts/';
  static final String usersUrl = '$baseUrl/auth/users/';
  static final String transactionsUrl = '$baseUrl/sheets/transactions/';
  static final String auditEntriesUrl = '$baseUrl/sheets/audit-entries/';
  static final String auditEntriesSummaryUrl =
      '$baseUrl/sheets/audit-entries/summary/';
  static final String changePasswordUrl = '$baseUrl/auth/users/set_password/';
  static String userSetPasswordUrl(int id) =>
      '$baseUrl/auth/users/$id/password/';
  static final String setPasswordUrl = '$baseUrl/auth/users/set_password/';

  static final String resetPasswordUrl = '$baseUrl/auth/users/reset_password/';
  static final String resetPasswordConfirmUrl =
      '$baseUrl/auth/users/reset_password_confirm/';
}
