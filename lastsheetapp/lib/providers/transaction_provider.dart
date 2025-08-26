import 'dart:io';

import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';

class TransactionProvider with ChangeNotifier {
  List<Transaction> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;

  final ApiService _apiService = ApiService();

  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Fetch all transactions from the API
  Future<void> fetchTransactions() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // Notify listeners that loading has started

    try {
      _transactions = await _apiService.fetchTransactions();
      _transactions.sort((a, b) => b.submittedAt.compareTo(a.submittedAt)); // Sort by submittedAt descending
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners(); // Notify listeners that loading has finished
    }
  }

  // Update an existing transaction
  Future<void> updateTransaction(Transaction updatedTransaction, {File? imageFile, bool clearImage = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final Transaction responseTransaction = await _apiService.updateTransaction(
        updatedTransaction,
        imageFile: imageFile,
        clearImage: clearImage,
      );

      // Update the list with the new transaction data
      final index = _transactions.indexWhere((t) => t.id == responseTransaction.id);
      if (index != -1) {
        _transactions[index] = responseTransaction;
      } else {
        // If for some reason it's not in the list (e.g., new transaction that was created and then updated)
        _transactions.add(responseTransaction);
      }
      _transactions.sort((a, b) => b.submittedAt.compareTo(a.submittedAt)); // Re-sort
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create a new transaction
  Future<void> createTransaction(Transaction newTransaction, {File? imageFile}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final Transaction responseTransaction = await _apiService.createTransaction(newTransaction, imageFile: imageFile);
      _transactions.add(responseTransaction);
      _transactions.sort((a, b) => b.submittedAt.compareTo(a.submittedAt)); // Re-sort
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete a transaction
  Future<void> deleteTransaction(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.deleteTransaction(id);
      _transactions.removeWhere((t) => t.id == id);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
