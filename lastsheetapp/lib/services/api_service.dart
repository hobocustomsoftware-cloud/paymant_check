import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  Future<Map<String, String>> _getHeaders({bool includeAuth = true, bool isMultipart = false}) async {
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
      headers.remove('Content-Type'); // Let http package set content-type for multipart
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
      final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      final String token = data['auth_token'];
      await _storage.write(key: 'auth_token', value: token);

      if (data.containsKey('user')) {
        print('DEBUG: User data found in login response: ${data['user']}');
        return User.fromJson(data['user']);
      } else {
        print('WARNING: Login response did not contain "user" data. This might lead to missing user ID.');
        return User(id: -1, username: username, email: '', userType: 'unknown');
      }
    } else {
      final Map<String, dynamic> errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception('Login failed: ${errorData['detail'] ?? 'Unknown error'}');
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
      if (decodedBody is Map && decodedBody.containsKey('results')) { // Check for 'results' key
        Iterable list = decodedBody['results']; // Get the list from 'results'
        return list.map((model) => Group.fromJson(model)).toList();
      } else if (decodedBody is List) { // Fallback for non-paginated responses
        return decodedBody.map((model) => Group.fromJson(model)).toList();
      } else {
        print('ERROR: Unexpected response type for groups list: $decodedBody');
        throw Exception('Failed to load groups: Unexpected response format.');
      }
    } else {
      throw Exception('Failed to load groups: ${jsonDecode(utf8.decode(response.bodyBytes))}');
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
      print('DEBUG: Create Group Error Response: ${utf8.decode(response.bodyBytes)}');
      throw Exception('Failed to create group: ${jsonDecode(utf8.decode(response.bodyBytes))}');
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
      print('DEBUG: Update Group Error Response: ${utf8.decode(response.bodyBytes)}');
      throw Exception('Failed to update group: ${jsonDecode(utf8.decode(response.bodyBytes))}');
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
      if (decodedBody is Map && decodedBody.containsKey('results')) { // Check for 'results' key
        Iterable list = decodedBody['results']; // Get the list from 'results'
        return list.map((model) => PaymentAccount.fromJson(model)).toList();
      } else if (decodedBody is List) { // Fallback for non-paginated responses
        return decodedBody.map((model) => PaymentAccount.fromJson(model)).toList();
      } else {
        print('ERROR: Unexpected response type for payment accounts list: $decodedBody');
        throw Exception('Failed to load payment accounts: Unexpected response format.');
      }
    } else {
      throw Exception('Failed to load payment accounts: ${jsonDecode(utf8.decode(response.bodyBytes))}');
    }
  }

  Future<PaymentAccount> createPaymentAccount(PaymentAccount account) async {
    final response = await http.post(
      Uri.parse(Constants.paymentAccountsUrl),
      headers: await _getHeaders(),
      body: jsonEncode(account.toJson()),
    );
    if (response.statusCode == 201) {
      return PaymentAccount.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      print('DEBUG: Create Payment Account Error Response: ${utf8.decode(response.bodyBytes)}');
      throw Exception('Failed to create payment account: ${jsonDecode(utf8.decode(response.bodyBytes))}');
    }
  }

  Future<PaymentAccount> updatePaymentAccount(PaymentAccount account) async {
    final response = await http.put(
      Uri.parse('${Constants.paymentAccountsUrl}${account.id}/'),
      headers: await _getHeaders(),
      body: jsonEncode(account.toJson()),
    );
    if (response.statusCode == 200) {
      return PaymentAccount.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      print('DEBUG: Update Payment Account Error Response: ${utf8.decode(response.bodyBytes)}');
      throw Exception('Failed to update payment account: ${jsonDecode(utf8.decode(response.bodyBytes))}');
    }
  }

  Future<void> deletePaymentAccount(int id) async {
    final response = await http.delete(
      Uri.parse('${Constants.paymentAccountsUrl}$id/'),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete payment account: ${response.statusCode}');
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
      if (decodedBody is Map && decodedBody.containsKey('results')) { // Check for 'results' key
        Iterable list = decodedBody['results']; // Get the list from 'results'
        return list.map((model) => Transaction.fromJson(model)).toList();
      } else if (decodedBody is List) { // Fallback for non-paginated responses
        return decodedBody.map((model) => Transaction.fromJson(model)).toList();
      } else {
        print('ERROR: Unexpected response type for transactions list: $decodedBody');
        throw Exception('Failed to load transactions: Unexpected response format.');
      }
    } else {
      throw Exception('Failed to load transactions: ${jsonDecode(utf8.decode(response.bodyBytes))}');
    }
  }

  Future<Transaction> createTransaction(Transaction transaction, {File? imageFile}) async {
    var uri = Uri.parse(Constants.transactionsUrl);
    var request = http.MultipartRequest('POST', uri);

    request.headers.addAll(await _getHeaders(isMultipart: true));

    transaction.toJson().forEach((key, value) {
      if (value != null) {
        request.fields[key] = value.toString();
      }
    });

    if (imageFile != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        filename: basename(imageFile.path),
      ));
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      return Transaction.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      print('DEBUG: Create Transaction Error Response: ${utf8.decode(response.bodyBytes)}');
      throw Exception('Failed to create transaction: ${jsonDecode(utf8.decode(response.bodyBytes))}');
    }
  }

  Future<Transaction> updateTransaction(Transaction transaction, {File? imageFile, bool clearImage = false}) async {
    var uri = Uri.parse('${Constants.transactionsUrl}${transaction.id}/');
    var request = http.MultipartRequest('PUT', uri);

    request.headers.addAll(await _getHeaders(isMultipart: true));

    transaction.toJson().forEach((key, value) {
      if (value != null) {
        request.fields[key] = value.toString();
      }
    });

    if (imageFile != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        filename: basename(imageFile.path),
      ));
    } else if (clearImage) {
      request.fields['image'] = '';
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return Transaction.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      print('DEBUG: Update Transaction Error Response: ${utf8.decode(response.bodyBytes)}');
      throw Exception('Failed to update transaction: ${jsonDecode(utf8.decode(response.bodyBytes))}');
    }
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
  Future<Transaction> approveTransaction(int transactionId, {String? ownerNotes}) async {
    final response = await http.post(
      Uri.parse('${Constants.transactionsUrl}$transactionId/approve/'),
      headers: await _getHeaders(),
      body: jsonEncode({'owner_notes': ownerNotes}),
    );
    if (response.statusCode == 200) {
      return Transaction.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      print('DEBUG: Approve Transaction Error Response: ${utf8.decode(response.bodyBytes)}');
      throw Exception('Failed to approve transaction: ${jsonDecode(utf8.decode(response.bodyBytes))}');
    }
  }

  Future<Transaction> rejectTransaction(int transactionId, {String? ownerNotes}) async {
    final response = await http.post(
      Uri.parse('${Constants.transactionsUrl}$transactionId/reject/'),
      headers: await _getHeaders(),
      body: jsonEncode({'owner_notes': ownerNotes}),
    );
    if (response.statusCode == 200) {
      return Transaction.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      print('DEBUG: Reject Transaction Error Response: ${utf8.decode(response.bodyBytes)}');
      throw Exception('Failed to reject transaction: ${jsonDecode(utf8.decode(response.bodyBytes))}');
    }
  }

  // --- Audit Entries ---
  Future<List<AuditEntry>> fetchAuditEntries() async {
    final response = await http.get(
      Uri.parse(Constants.auditEntriesUrl),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
      if (decodedBody is Map && decodedBody.containsKey('results')) { // Check for 'results' key
        Iterable list = decodedBody['results']; // Get the list from 'results'
        return list.map((model) => AuditEntry.fromJson(model)).toList();
      } else if (decodedBody is List) { // Fallback for non-paginated responses
        return decodedBody.map((model) => AuditEntry.fromJson(model)).toList();
      } else {
        print('ERROR: Unexpected response type for audit entries list: $decodedBody');
        throw Exception('Failed to load audit entries: Unexpected response format.');
      }
    } else {
      throw Exception('Failed to load audit entries: ${jsonDecode(utf8.decode(response.bodyBytes))}');
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
      throw Exception('Failed to create audit entry: ${jsonDecode(utf8.decode(response.bodyBytes))}');
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
      throw Exception('Failed to update audit entry: ${jsonDecode(utf8.decode(response.bodyBytes))}');
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
      throw Exception('Failed to load audit summary: ${jsonDecode(utf8.decode(response.bodyBytes))}');
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
      if (decodedBody is Map && decodedBody.containsKey('results')) { // Check for 'results' key
        Iterable list = decodedBody['results']; // Get the list from 'results'
        return list.map((model) => User.fromJson(model)).where((user) => user.userType == 'auditor').toList();
      } else if (decodedBody is List) { // Fallback for non-paginated responses
        return decodedBody.map((model) => User.fromJson(model)).where((user) => user.userType == 'auditor').toList();
      } else {
        print('ERROR: Unexpected response type for users list: $decodedBody');
        throw Exception('Failed to load users: Unexpected response format.');
      }
    } else {
      throw Exception('Failed to load auditors: ${jsonDecode(utf8.decode(response.bodyBytes))}');
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
      print('DEBUG: Create Auditor Error Response: ${utf8.decode(response.bodyBytes)}');
      throw Exception('Failed to create auditor: ${jsonDecode(utf8.decode(response.bodyBytes))}');
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
      print('DEBUG: Update Auditor Error Response: ${utf8.decode(response.bodyBytes)}');
      throw Exception('Failed to update auditor: ${jsonDecode(utf8.decode(response.bodyBytes))}');
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
}
