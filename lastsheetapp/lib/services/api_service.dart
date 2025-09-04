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

  Future<List<Transaction>> fetchTransactionsFiltered({
    String? last6,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status, // 'pending' for owner review
  }) async {
    final qp = <String, String>{};
    if (last6 != null && last6.length == 6)
      qp['transfer_id_last_6_digits'] = last6;
    if (dateFrom != null)
      qp['transaction_date_after'] = DateFormat('yyyy-MM-dd').format(dateFrom);
    if (dateTo != null)
      qp['transaction_date_before'] = DateFormat('yyyy-MM-dd').format(dateTo);
    if (status != null) qp['status'] = status;

    final uri = Uri.parse(
      Constants.transactionsUrl,
    ).replace(queryParameters: qp);
    final res = await http.get(uri, headers: await _getHeaders());
    final body = utf8.decode(res.bodyBytes);
    if (res.statusCode != 200) throw Exception('Filter fetch failed: $body');

    final decoded = jsonDecode(body);
    final list = (decoded is Map && decoded['results'] is List)
        ? decoded['results'] as List
        : (decoded is List ? decoded : <dynamic>[]);
    return list
        .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();
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
  Future<Transaction> approveTransaction(int id, {String? ownerNotes}) async {
    final uri = Uri.parse('${Constants.transactionsUrl}$id/approve/');
    final headers = await _getHeaders();
    final body = jsonEncode({'owner_notes': ownerNotes});
    var res = await http.patch(uri, headers: headers, body: body);
    if (res.statusCode == 405)
      res = await http.post(uri, headers: headers, body: body);
    if (res.statusCode == 200) {
      return Transaction.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw Exception('Failed to approve: ${utf8.decode(res.bodyBytes)}');
  }

  Future<Transaction> rejectTransaction(int id, {String? ownerNotes}) async {
    final uri = Uri.parse('${Constants.transactionsUrl}$id/reject/');
    final headers = await _getHeaders();
    final body = jsonEncode({'owner_notes': ownerNotes});
    var res = await http.patch(uri, headers: headers, body: body);
    if (res.statusCode == 405)
      res = await http.post(uri, headers: headers, body: body);
    if (res.statusCode == 200) {
      return Transaction.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw Exception('Failed to reject: ${utf8.decode(res.bodyBytes)}');
  }

  Future<Transaction> reSubmitTransaction(int id) async {
    final uri = Uri.parse('${Constants.transactionsUrl}$id/re_submit/');
    final res = await http.post(uri, headers: await _getHeaders());
    final body = utf8.decode(res.bodyBytes);

    if (res.statusCode == 200) {
      return Transaction.fromJson(jsonDecode(body) as Map<String, dynamic>);
    }
    throw Exception('Re-submit failed: $body');
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
  // Future<AuditSummary> fetchAuditSummary() async {
  //   final response = await http.get(
  //     Uri.parse(Constants.auditSummaryUrl),
  //     headers: await _getHeaders(),
  //   );
  //   if (response.statusCode == 200) {
  //     return AuditSummary.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  //   } else {
  //     throw Exception(
  //       'Failed to load audit summary: ${jsonDecode(utf8.decode(response.bodyBytes))}',
  //     );
  //   }
  // }

  // Future<Map<String, dynamic>> fetchAuditSummary({
  //   String? start,
  //   String? end,
  // }) async {
  //   final qp = <String, String>{};
  //   if (start != null && start.isNotEmpty) qp['start'] = start; // 'YYYY-MM-DD'
  //   if (end != null && end.isNotEmpty) qp['end'] = end;

  //   final uri = Uri.parse(
  //     Constants.auditEntriesSummaryUrl,
  //   ).replace(queryParameters: qp);
  //   final res = await http.get(uri, headers: await _getHeaders());
  //   final body = utf8.decode(res.bodyBytes);
  //   if (res.statusCode != 200) {
  //     throw Exception('Audit summary failed: $body');
  //   }
  //   return jsonDecode(body) as Map<String, dynamic>;
  // }

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
  Future<void> changePasswordDjoser({
    required String currentPassword,
    required String newPassword,
  }) async {
    final r = await http.post(
      Uri.parse(Constants.setPasswordUrl),
      headers: await _getHeaders(),
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    final body = utf8.decode(r.bodyBytes);
    if (r.statusCode == 204) return;
    // 👇 ပိုခွဲရှင်းပြီး error ပြ
    throw Exception(
      'Change password failed: ${body.isEmpty ? r.statusCode : body}',
    );
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

  Future<List<Map<String, dynamic>>> fetchAuditEntrySummary({
    required String period, // daily|weekly|monthly|yearly
    DateTime? start,
    DateTime? end,
  }) async {
    final qp = <String, String>{'period': period};
    final fmt = DateFormat('yyyy-MM-dd');
    if (start != null) qp['start'] = fmt.format(start);
    if (end != null) qp['end'] = fmt.format(end);

    final uri = Uri.parse(
      '${Constants.auditEntriesUrl}summary/',
    ).replace(queryParameters: qp);
    final res = await http.get(uri, headers: await _getHeaders());
    final body = utf8.decode(res.bodyBytes);
    if (res.statusCode != 200) {
      throw Exception('Audit summary failed: $body');
    }
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final List results = decoded['results'] as List? ?? [];
    return results.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchAuditSummary({
    String period = 'daily', // 'daily' | 'weekly' | 'monthly' | 'yearly'
    String? start, // 'YYYY-MM-DD'
    String? end, // 'YYYY-MM-DD'
  }) async {
    final qp = <String, String>{'period': period};
    if (start != null && start.isNotEmpty) qp['start'] = start;
    if (end != null && end.isNotEmpty) qp['end'] = end;

    final uri = Uri.parse(
      Constants.auditEntriesSummaryUrl,
    ).replace(queryParameters: qp);

    final res = await http.get(uri, headers: await _getHeaders());
    final body = utf8.decode(res.bodyBytes);

    if (res.statusCode != 200) {
      // helpful debug
      throw Exception(
        'fetchAuditSummary failed '
        '(status: ${res.statusCode}) body: $body',
      );
    }
    final data = jsonDecode(body);
    if (data is Map<String, dynamic>) return data;
    throw Exception('Unexpected summary response: $data');
  }

  Future<void> requestPasswordReset(String email) async {
    final res = await http.post(
      Uri.parse(Constants.resetPasswordUrl),
      headers: await _getHeaders(includeAuth: false), // no auth
      body: jsonEncode({'email': email}),
    );
    if (res.statusCode != 204) {
      throw Exception('Reset request failed: ${utf8.decode(res.bodyBytes)}');
    }
  }

  Future<void> confirmPasswordReset({
    required String uid,
    required String token,
    required String newPassword,
  }) async {
    final res = await http.post(
      Uri.parse(Constants.resetPasswordConfirmUrl),
      headers: await _getHeaders(includeAuth: false),
      body: jsonEncode({
        'uid': uid,
        'token': token,
        'new_password': newPassword,
      }),
    );
    if (res.statusCode != 204) {
      throw Exception('Reset confirm failed: ${utf8.decode(res.bodyBytes)}');
    }
  }

  Future<bool> verifyCurrentPasswordNoPersist({
    required String username,
    required String password,
  }) async {
    final r = await http.post(
      Uri.parse('${Constants.loginUrl}token/login/'),
      headers: await _getHeaders(includeAuth: false),
      body: jsonEncode({'username': username, 'password': password}),
    );
    return r.statusCode == 200;
  }
}
