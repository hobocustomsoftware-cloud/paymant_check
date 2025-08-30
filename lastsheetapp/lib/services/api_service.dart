import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:async/async.dart';

import '../utils/constants.dart';
import '../models/user.dart';
import '../models/group.dart';
import '../models/payment_account.dart';
import '../models/transaction.dart';
import '../models/audit_entry.dart';
import '../models/audit_summary.dart';

class ApiService {
  final _storage = const FlutterSecureStorage();

  Future<Map<String, String>> _getHeaders({
    bool includeAuth = true,
    bool isMultipart = false,
  }) async {
    Map<String, String> headers = {
      'Content-Type': 'application/json; charset=UTF-8',
    };
    if (includeAuth) {
      String? token = await _storage.read(key: 'auth_token');
      if (token != null) {
        headers['Authorization'] = 'Token $token';
      }
    }
    if (isMultipart) {
      headers.remove(
        'Content-Type',
      ); // Let http package set content-type for multipart
    }
    return headers;
  }

  Future<User?> login(String username, String password) async {
    final response = await http.post(
      Uri.parse(Constants.loginUrl),
      headers: await _getHeaders(includeAuth: false).then((headers) {
        headers['Content-Type'] = 'application/json';
        return headers;
      }),
      body: jsonEncode({'username': username, 'password': password}),
    );

    print('DEBUG: Login Response Status Code: ${response.statusCode}');
    print('DEBUG: Login Response Body: ${utf8.decode(response.bodyBytes)}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(
        utf8.decode(response.bodyBytes),
      );
      final String token = data['auth_token'];
      await _storage.write(key: 'auth_token', value: token);

      if (data.containsKey('user')) {
        print('DEBUG: User data found in login response: ${data['user']}');
        return User.fromJson(data['user']);
      } else {
        print(
          'WARNING: Login response did not contain "user" data. This might lead to missing user ID.',
        );
        return User(id: -1, username: username, email: '', userType: 'unknown');
      }
    } else {
      final Map<String, dynamic> errorData = jsonDecode(
        utf8.decode(response.bodyBytes),
      );
      throw Exception(
        'Login failed: ${errorData['detail'] ?? 'Unknown error'}',
      );
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
  }

  // --- Groups ---
  Future<List<Group>> fetchGroups() async {
    final response = await http.get(
      Uri.parse(Constants.groupsUrl),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
      if (decodedBody is Map && decodedBody.containsKey('results')) {
        // Check for 'results' key
        Iterable list = decodedBody['results']; // Get the list from 'results'
        return list.map((model) => Group.fromJson(model)).toList();
      } else if (decodedBody is List) {
        // Fallback for non-paginated responses
        return decodedBody.map((model) => Group.fromJson(model)).toList();
      } else {
        print('ERROR: Unexpected response type for groups list: $decodedBody');
        throw Exception('Failed to load groups: Unexpected response format.');
      }
    } else {
      throw Exception(
        'Failed to load groups: ${jsonDecode(utf8.decode(response.bodyBytes))}',
      );
    }
  }

  Future<Group> createGroup(Group group) async {
    final response = await http.post(
      Uri.parse(Constants.groupsUrl),
      headers: await _getHeaders(),
      body: jsonEncode(group.toJson()),
    );
    if (response.statusCode == 201) {
      return Group.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      print(
        'DEBUG: Create Group Error Response: ${utf8.decode(response.bodyBytes)}',
      );
      throw Exception(
        'Failed to create group: ${jsonDecode(utf8.decode(response.bodyBytes))}',
      );
    }
  }

  Future<Group> updateGroup(Group group) async {
    final response = await http.put(
      Uri.parse('${Constants.groupsUrl}${group.id}/'),
      headers: await _getHeaders(),
      body: jsonEncode(group.toJson()),
    );
    if (response.statusCode == 200) {
      return Group.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      print(
        'DEBUG: Update Group Error Response: ${utf8.decode(response.bodyBytes)}',
      );
      throw Exception(
        'Failed to update group: ${jsonDecode(utf8.decode(response.bodyBytes))}',
      );
    }
  }

  Future<void> deleteGroup(int id) async {
    final response = await http.delete(
      Uri.parse('${Constants.groupsUrl}$id/'),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete group: ${response.statusCode}');
    }
  }

  // --- Payment Accounts ---
  Future<List<PaymentAccount>> fetchPaymentAccounts() async {
    final response = await http.get(
      Uri.parse(Constants.paymentAccountsUrl),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
      if (decodedBody is Map && decodedBody.containsKey('results')) {
        // Check for 'results' key
        Iterable list = decodedBody['results']; // Get the list from 'results'
        return list.map((model) => PaymentAccount.fromJson(model)).toList();
      } else if (decodedBody is List) {
        // Fallback for non-paginated responses
        return decodedBody
            .map((model) => PaymentAccount.fromJson(model))
            .toList();
      } else {
        print(
          'ERROR: Unexpected response type for payment accounts list: $decodedBody',
        );
        throw Exception(
          'Failed to load payment accounts: Unexpected response format.',
        );
      }
    } else {
      throw Exception(
        'Failed to load payment accounts: ${jsonDecode(utf8.decode(response.bodyBytes))}',
      );
    }
  }

  Future<PaymentAccount> createPaymentAccount(PaymentAccount account) async {
    final response = await http.post(
      Uri.parse(Constants.paymentAccountsUrl),
      headers: await _getHeaders(),
      body: jsonEncode(account.toJson()),
    );
    if (response.statusCode == 201) {
      return PaymentAccount.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)),
      );
    } else {
      print(
        'DEBUG: Create Payment Account Error Response: ${utf8.decode(response.bodyBytes)}',
      );
      throw Exception(
        'Failed to create payment account: ${jsonDecode(utf8.decode(response.bodyBytes))}',
      );
    }
  }

  Future<PaymentAccount> updatePaymentAccount(PaymentAccount account) async {
    final response = await http.put(
      Uri.parse('${Constants.paymentAccountsUrl}${account.id}/'),
      headers: await _getHeaders(),
      body: jsonEncode(account.toJson()),
    );
    if (response.statusCode == 200) {
      return PaymentAccount.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)),
      );
    } else {
      print(
        'DEBUG: Update Payment Account Error Response: ${utf8.decode(response.bodyBytes)}',
      );
      throw Exception(
        'Failed to update payment account: ${jsonDecode(utf8.decode(response.bodyBytes))}',
      );
    }
  }

  Future<void> deletePaymentAccount(int id) async {
    final response = await http.delete(
      Uri.parse('${Constants.paymentAccountsUrl}$id/'),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 204) {
      throw Exception(
        'Failed to delete payment account: ${response.statusCode}',
      );
    }
  }

  // --- Transactions ---
  Future<List<Transaction>> fetchTransactions() async {
    final response = await http.get(
      Uri.parse(Constants.transactionsUrl),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
      if (decodedBody is Map && decodedBody.containsKey('results')) {
        // Check for 'results' key
        Iterable list = decodedBody['results']; // Get the list from 'results'
        return list.map((model) => Transaction.fromJson(model)).toList();
      } else if (decodedBody is List) {
        // Fallback for non-paginated responses
        return decodedBody.map((model) => Transaction.fromJson(model)).toList();
      } else {
        print(
          'ERROR: Unexpected response type for transactions list: $decodedBody',
        );
        throw Exception(
          'Failed to load transactions: Unexpected response format.',
        );
      }
    } else {
      throw Exception(
        'Failed to load transactions: ${jsonDecode(utf8.decode(response.bodyBytes))}',
      );
    }
  }

  Future<List<Transaction>> searchTransactionsByLast6(String last6) async {
    final uri = Uri.parse(
      '${Constants.transactionsUrl}?transfer_id_last_6_digits=$last6',
    );
    final res = await http.get(uri, headers: await _getHeaders());
    if (res.statusCode != 200) {
      throw Exception('Search failed: ${utf8.decode(res.bodyBytes)}');
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    final list = (decoded is Map && decoded['results'] != null)
        ? decoded['results'] as List
        : (decoded is List ? decoded : <dynamic>[]);
    return list
        .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Transaction> createTransaction(
    Transaction tx, {
    File? imageFile,
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    final uri = Uri.parse(Constants.transactionsUrl);
    final req = http.MultipartRequest('POST', uri);
    req.headers.addAll(await _getHeaders(isMultipart: true));

    req.fields.addAll({
      'transaction_date': DateFormat('yyyy-MM-dd').format(tx.transactionDate),
      'group': tx.group.toString(),
      'payment_account': tx.paymentAccount.toString(),
      'transfer_id_last_6_digits': tx.transferIdLast6Digits,
      'amount': tx.amount.toString(),
      'transaction_type': tx.transactionType,
      'submitted_by': tx.submittedBy.toString(),
      if (tx.ownerNotes != null) 'owner_notes': tx.ownerNotes!,
    });

    if (imageBytes != null) {
      req.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: imageFileName ?? 'upload.jpg',
        ),
      );
    } else if (imageFile != null) {
      req.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          filename: basename(imageFile.path),
        ),
      );
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode == 201) {
      return Transaction.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw Exception(
      'Failed to create transaction: ${utf8.decode(res.bodyBytes)}',
    );
  }

  Future<Transaction> updateTransaction(
    Transaction tx, {
    File? imageFile,
    bool clearImage = false,
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    final uri = Uri.parse('${Constants.transactionsUrl}${tx.id}/');
    final req = http.MultipartRequest('PUT', uri);
    req.headers.addAll(await _getHeaders(isMultipart: true));

    req.fields.addAll({
      'transaction_date': DateFormat('yyyy-MM-dd').format(tx.transactionDate),
      'group': tx.group.toString(),
      'payment_account': tx.paymentAccount.toString(),
      'transfer_id_last_6_digits': tx.transferIdLast6Digits,
      'amount': tx.amount.toString(),
      'transaction_type': tx.transactionType,
      'submitted_by': tx.submittedBy.toString(),
      if (tx.ownerNotes != null) 'owner_notes': tx.ownerNotes!,
      if (clearImage) 'clear_image': '1',
    });

    if (imageBytes != null) {
      req.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: imageFileName ?? 'upload.jpg',
        ),
      );
    } else if (imageFile != null) {
      req.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          filename: basename(imageFile.path),
        ),
      );
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode == 200) {
      return Transaction.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw Exception(
      'Failed to update transaction: ${utf8.decode(res.bodyBytes)}',
    );
  }

  Future<void> deleteTransaction(int id) async {
    final response = await http.delete(
      Uri.parse('${Constants.transactionsUrl}$id/'),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete transaction: ${response.statusCode}');
    }
  }

  // --- Transaction Actions (Approve/Reject) ---
  Future<Transaction> approveTransaction(
    int transactionId, {
    String? ownerNotes,
  }) async {
    final res = await http.patch(
      // <- patch
      Uri.parse('${Constants.transactionsUrl}$transactionId/approve/'),
      headers: await _getHeaders(), // Content-Type: application/json ရှိတယ်
      body: jsonEncode({'owner_notes': ownerNotes}),
    );
    if (res.statusCode == 200) {
      return Transaction.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw Exception(
      'Failed to approve transaction: ${utf8.decode(res.bodyBytes)}',
    );
  }

  Future<Transaction> rejectTransaction(
    int transactionId, {
    String? ownerNotes,
  }) async {
    final res = await http.patch(
      // <- patch
      Uri.parse('${Constants.transactionsUrl}$transactionId/reject/'),
      headers: await _getHeaders(),
      body: jsonEncode({'owner_notes': ownerNotes}),
    );
    if (res.statusCode == 200) {
      return Transaction.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw Exception(
      'Failed to reject transaction: ${utf8.decode(res.bodyBytes)}',
    );
  }

  // ---- Duplicate check (GLOBAL by 6 digits only) ----
  Future<bool> existsTransferId({
    required String transferIdLast6,
    int? excludeId,
  }) async {
    final uri = Uri.parse(
      '${Constants.transactionsUrl}?transfer_id_last_6_digits=$transferIdLast6',
    );
    final res = await http.get(uri, headers: await _getHeaders());
    if (res.statusCode != 200) return false;

    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    List items;
    if (decoded is Map && decoded['results'] != null) {
      items = List.from(decoded['results']);
    } else if (decoded is List) {
      items = List.from(decoded);
    } else {
      return false;
    }
    if (excludeId != null) {
      items = items
          .where(
            (e) => (e is Map && e['id'] != null) ? e['id'] != excludeId : true,
          )
          .toList();
    }
    return items.isNotEmpty;
  }

  // --- Audit Entries ---
  Future<List<AuditEntry>> fetchAuditEntries() async {
    final response = await http.get(
      Uri.parse(Constants.auditEntriesUrl),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
      if (decodedBody is Map && decodedBody.containsKey('results')) {
        // Check for 'results' key
        Iterable list = decodedBody['results']; // Get the list from 'results'
        return list.map((model) => AuditEntry.fromJson(model)).toList();
      } else if (decodedBody is List) {
        // Fallback for non-paginated responses
        return decodedBody.map((model) => AuditEntry.fromJson(model)).toList();
      } else {
        print(
          'ERROR: Unexpected response type for audit entries list: $decodedBody',
        );
        throw Exception(
          'Failed to load audit entries: Unexpected response format.',
        );
      }
    } else {
      throw Exception(
        'Failed to load audit entries: ${jsonDecode(utf8.decode(response.bodyBytes))}',
      );
    }
  }

  Future<AuditEntry> createAuditEntry(AuditEntry entry) async {
    final response = await http.post(
      Uri.parse(Constants.auditEntriesUrl),
      headers: await _getHeaders(),
      body: jsonEncode(entry.toJson()),
    );
    if (response.statusCode == 201) {
      return AuditEntry.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception(
        'Failed to create audit entry: ${jsonDecode(utf8.decode(response.bodyBytes))}',
      );
    }
  }

  Future<AuditEntry> updateAuditEntry(AuditEntry entry) async {
    final response = await http.put(
      Uri.parse('${Constants.auditEntriesUrl}${entry.id}/'),
      headers: await _getHeaders(),
      body: jsonEncode(entry.toJson()),
    );
    if (response.statusCode == 200) {
      return AuditEntry.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception(
        'Failed to update audit entry: ${jsonDecode(utf8.decode(response.bodyBytes))}',
      );
    }
  }

  Future<void> deleteAuditEntry(int id) async {
    final response = await http.delete(
      Uri.parse('${Constants.auditEntriesUrl}$id/'),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete audit entry: ${response.statusCode}');
    }
  }

  // --- Audit Summary (Owner Only) ---
  Future<AuditSummary> fetchAuditSummary() async {
    final response = await http.get(
      Uri.parse(Constants.auditSummaryUrl),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return AuditSummary.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception(
        'Failed to load audit summary: ${jsonDecode(utf8.decode(response.bodyBytes))}',
      );
    }
  }

  // --- User Management (Auditors) ---
  Future<List<User>> fetchAuditors() async {
    final response = await http.get(
      Uri.parse(Constants.usersUrl),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
      if (decodedBody is Map && decodedBody.containsKey('results')) {
        // Check for 'results' key
        Iterable list = decodedBody['results']; // Get the list from 'results'
        return list
            .map((model) => User.fromJson(model))
            .where((user) => user.userType == 'auditor')
            .toList();
      } else if (decodedBody is List) {
        // Fallback for non-paginated responses
        return decodedBody
            .map((model) => User.fromJson(model))
            .where((user) => user.userType == 'auditor')
            .toList();
      } else {
        print('ERROR: Unexpected response type for users list: $decodedBody');
        throw Exception('Failed to load users: Unexpected response format.');
      }
    } else {
      throw Exception(
        'Failed to load auditors: ${jsonDecode(utf8.decode(response.bodyBytes))}',
      );
    }
  }

  Future<User> createAuditor(User user, String password) async {
    final response = await http.post(
      Uri.parse(Constants.usersUrl),
      headers: await _getHeaders(),
      body: jsonEncode({
        ...user.toJson(),
        'password': password,
        'user_type': 'auditor',
      }),
    );
    if (response.statusCode == 201) {
      return User.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      print(
        'DEBUG: Create Auditor Error Response: ${utf8.decode(response.bodyBytes)}',
      );
      throw Exception(
        'Failed to create auditor: ${jsonDecode(utf8.decode(response.bodyBytes))}',
      );
    }
  }

  Future<User> updateAuditor(User user, {String? password}) async {
    final Map<String, dynamic> body = user.toJson();
    if (password != null && password.isNotEmpty) {
      body['password'] = password;
    }
    final response = await http.put(
      Uri.parse('${Constants.usersUrl}${user.id}/'),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      print(
        'DEBUG: Update Auditor Error Response: ${utf8.decode(response.bodyBytes)}',
      );
      throw Exception(
        'Failed to update auditor: ${jsonDecode(utf8.decode(response.bodyBytes))}',
      );
    }
  }

  Future<void> deleteAuditor(int id) async {
    final response = await http.delete(
      Uri.parse('${Constants.usersUrl}$id/'),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete auditor: ${response.statusCode}');
    }
  }

  /// User self-change password (requires old_password). Returns new token.
  Future<String> changePassword({
    required String oldPassword,
    required String newPassword,
    required String newPassword2,
  }) async {
    final res = await http.post(
      Uri.parse(Constants.changePasswordUrl),
      headers: await _getHeaders(),
      body: jsonEncode({
        'old_password': oldPassword,
        'new_password': newPassword,
        'new_password2': newPassword2,
      }),
    );

    final body = utf8.decode(res.bodyBytes);
    if (res.statusCode == 200) {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final newToken = data['auth_token'] as String?;
      if (newToken != null && newToken.isNotEmpty) {
        // rotate token locally
        await _storage.write(key: 'auth_token', value: newToken);
      }
      return newToken ?? '';
    } else {
      // surface server-side validation errors
      throw Exception('Change password failed: $body');
    }
  }

  /// Owner/Admin set password for user <id>. No token return.
  Future<void> setUserPassword({
    required int userId,
    required String newPassword,
    required String newPassword2,
  }) async {
    final res = await http.post(
      Uri.parse(Constants.userSetPasswordUrl(userId)),
      headers: await _getHeaders(),
      body: jsonEncode({
        'new_password': newPassword,
        'new_password2': newPassword2,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception(
        'Set user password failed: ${utf8.decode(res.bodyBytes)}',
      );
    }
  }
}
