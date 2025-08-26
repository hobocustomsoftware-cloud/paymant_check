import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

// Corrected import paths
import '../../services/api_service.dart';
import '../../models/transaction.dart';
import '../../models/group.dart';
import '../../models/payment_account.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../utils/custom_dialogs.dart'; // CustomDialogs နှင့် MessageType အတွက်
import '../../utils/constants.dart'; // Constants.baseUrl အတွက်

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> with SingleTickerProviderStateMixin {
  List<Transaction> _allTransactions = [];
  List<Transaction> _filteredTransactions = [];
  bool _isLoading = true;
  String? _errorMessage;
  late TabController _tabController;

  final ApiService _apiService = ApiService();
  User? _currentUser;

  // For Transaction Form
  final _formKey = GlobalKey<FormState>(); // Corrected type: Removed extra <Form>
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _transferIdController = TextEditingController();
  final TextEditingController _ownerNotesController = TextEditingController();
  DateTime? _selectedDate;
  Group? _selectedGroup;
  PaymentAccount? _selectedPaymentAccount;
  String? _selectedTransactionType; // 'income' or 'expense'
  File? _selectedImage;

  List<Group> _groups = [];
  List<PaymentAccount> _paymentAccounts = [];

  Transaction? _editingTransaction; // For editing existing transaction
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _amountController.dispose();
    _transferIdController.dispose();
    _ownerNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    _currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    await _fetchTransactions();
    await _fetchGroupsAndPaymentAccounts();
  }

  Future<void> _fetchTransactions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final fetchedTransactions = await _apiService.fetchTransactions();
      setState(() {
        _allTransactions = fetchedTransactions;
        _applyFilter(); // Apply filter after fetching
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load transactions: $e';
        _isLoading = false;
      });
      CustomDialogs.showFlushbar(context, 'Error', _errorMessage!, MessageType.error);
    }
  }

  Future<void> _fetchGroupsAndPaymentAccounts() async {
    try {
      _groups = await _apiService.fetchGroups();
      _paymentAccounts = await _apiService.fetchPaymentAccounts();
      setState(() {}); // Update UI after fetching dropdown data
    } catch (e) {
      CustomDialogs.showFlushbar(context, 'Error', 'Failed to load groups or payment accounts: $e', MessageType.error);
    }
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      _applyFilter();
    }
  }

  void _applyFilter() {
    setState(() {
      switch (_tabController.index) {
        case 0: // All
          _filteredTransactions = List.from(_allTransactions); // Display all transactions
          break;
        case 1: // Pending
          _filteredTransactions = _allTransactions.where((t) => t.status == 'pending').toList();
          break;
        case 2: // Rejected
          _filteredTransactions = _allTransactions.where((t) => t.status == 'rejected').toList();
          break;
        default:
          _filteredTransactions = List.from(_allTransactions);
      }
    });
  }

  String _getStatusDisplayName(String status) {
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _clearForm() {
    _amountController.clear();
    _transferIdController.clear();
    _ownerNotesController.clear();
    _selectedDate = null;
    _selectedGroup = null;
    _selectedPaymentAccount = null;
    _selectedTransactionType = null;
    _selectedImage = null;
    _editingTransaction = null;
    _isEditing = false;
  }

  // Helper to build the correct image URL
  String _buildImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return '';
    }
    // Check if the imageUrl is already an absolute URL
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    // Otherwise, prepend the base URL
    return '${Constants.baseUrl}$imageUrl';
  }

  void _showTransactionForm({Transaction? transaction}) {
    _clearForm();
    if (transaction != null) {
      _isEditing = true;
      _editingTransaction = transaction;
      _amountController.text = transaction.amount.toString();
      _transferIdController.text = transaction.transferIdLast6Digits;
      _selectedDate = transaction.transactionDate;
      // Find the actual Group and PaymentAccount objects from the fetched lists
      _selectedGroup = _groups.firstWhere((g) => g.id == transaction.group, orElse: () => _groups.first);
      _selectedPaymentAccount = _paymentAccounts.firstWhere((pa) => pa.id == transaction.paymentAccount, orElse: () => _paymentAccounts.first);
      _selectedTransactionType = transaction.transactionType;
      _ownerNotesController.text = transaction.ownerNotes ?? '';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16.0,
            right: 16.0,
            top: 16.0,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_isEditing ? 'Transaction ပြင်ဆင်ခြင်း' : 'Transaction အသစ်ထည့်ရန်', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(labelText: 'ပမာဏ (Amount)'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'ပမာဏ ထည့်သွင်းပါ။';
                      }
                      if (double.tryParse(value) == null) {
                        return 'နံပါတ်သာ ထည့်သွင်းပါ။';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _transferIdController,
                    decoration: const InputDecoration(labelText: 'လွှဲပြောင်းကုတ်နံပါတ် နောက်ဆုံး ၆ လုံး (Transfer ID Last 6 Digits)'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'လွှဲပြောင်းကုတ်နံပါတ် ထည့်သွင်းပါ။';
                      }
                      if (value.length != 6) {
                        return '၆ လုံး ရှိရပါမည်။';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    title: Text(_selectedDate == null
                        ? 'ရက်စွဲ ရွေးပါ'
                        : 'ရက်စွဲ: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          _selectedDate = pickedDate;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<Group>(
                    value: _selectedGroup,
                    decoration: const InputDecoration(labelText: 'အဖွဲ့ (Group)'),
                    items: _groups.map((group) {
                      return DropdownMenuItem<Group>(
                        value: group,
                        child: Text(group.name),
                      );
                    }).toList(),
                    onChanged: (Group? newValue) {
                      setState(() {
                        _selectedGroup = newValue;
                      });
                    },
                    validator: (value) => value == null ? 'အဖွဲ့ ရွေးချယ်ပါ။' : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<PaymentAccount>(
                    value: _selectedPaymentAccount,
                    decoration: const InputDecoration(labelText: 'ငွေစာရင်း (Payment Account)'),
                    items: _paymentAccounts.map((account) {
                      return DropdownMenuItem<PaymentAccount>(
                        value: account,
                        child: Text(account.paymentAccountName),
                      );
                    }).toList(),
                    onChanged: (PaymentAccount? newValue) {
                      setState(() {
                        _selectedPaymentAccount = newValue;
                      });
                    },
                    validator: (value) => value == null ? 'ငွေစာရင်း ရွေးချယ်ပါ။' : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _selectedTransactionType,
                    decoration: const InputDecoration(labelText: 'အမျိုးအစား (Type)'),
                    items: const [
                      DropdownMenuItem(value: 'income', child: Text('ဝင်ငွေ')),
                      DropdownMenuItem(value: 'expense', child: Text('ထွက်ငွေ')),
                    ],
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedTransactionType = newValue;
                      });
                    },
                    validator: (value) => value == null ? 'အမျိုးအစား ရွေးချယ်ပါ။' : null,
                  ),
                  const SizedBox(height: 10),
                  if (_currentUser?.userType == 'owner')
                    TextFormField(
                      controller: _ownerNotesController,
                      decoration: const InputDecoration(labelText: 'Owner မှတ်စု (Owner Notes)'),
                      maxLines: 3,
                    ),
                  const SizedBox(height: 10),
                  _selectedImage != null
                      ? Image.file(_selectedImage!, height: 100)
                      : (_editingTransaction?.imageUrl != null && _editingTransaction!.imageUrl!.isNotEmpty
                          ? Image.network(
                              _buildImageUrl(_editingTransaction!.imageUrl!),
                              height: 100,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 100),
                            )
                          : const Text('ပုံမရှိပါ')),
                  TextButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image),
                    label: const Text('ပုံထည့်ရန်/ပြောင်းရန်'),
                  ),
                  if (_editingTransaction != null && _editingTransaction!.imageUrl != null && _editingTransaction!.imageUrl!.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedImage = null; // Indicate image removal
                        });
                        CustomDialogs.showFlushbar(context, 'Info', 'ပုံကို ဖျက်ရန် ရွေးချယ်ထားပါသည်။', MessageType.info);
                      },
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      label: const Text('ပုံဖျက်ရန်'),
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _submitTransactionForm,
                    child: Text(_isEditing ? 'Transaction ပြင်ဆင်မည်' : 'Transaction ထည့်မည်'),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitTransactionForm() async {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context); // Close the bottom sheet
      CustomDialogs.showLoadingDialog(context);

      try {
        final newTransaction = Transaction(
          id: _editingTransaction?.id,
          submittedBy: _currentUser!.id!,
          submittedByUsername: _currentUser!.username,
          transactionDate: _selectedDate!,
          group: _selectedGroup!.id!,
          groupName: _selectedGroup!.name,
          paymentAccount: _selectedPaymentAccount!.id!,
          paymentAccountName: _selectedPaymentAccount!.paymentAccountName,
          transferIdLast6Digits: _transferIdController.text,
          amount: double.parse(_amountController.text),
          transactionType: _selectedTransactionType!,
          status: _editingTransaction?.status ?? 'pending',
          imageUrl: _editingTransaction?.imageUrl,
          approvedByOwnerAt: _editingTransaction?.approvedByOwnerAt,
          ownerNotes: _ownerNotesController.text.isEmpty ? null : _ownerNotesController.text,
          submittedAt: _editingTransaction?.submittedAt ?? DateTime.now(),
        );

        if (_isEditing) {
          await _apiService.updateTransaction(
            newTransaction,
            imageFile: _selectedImage,
            clearImage: _selectedImage == null && _editingTransaction?.imageUrl != null && _editingTransaction!.imageUrl!.isNotEmpty,
          );
          CustomDialogs.showFlushbar(context, 'Success', 'Transaction ကို ပြင်ဆင်ပြီးပါပြီ။', MessageType.success);
        } else {
          await _apiService.createTransaction(newTransaction, imageFile: _selectedImage);
          CustomDialogs.showFlushbar(context, 'Success', 'Transaction အသစ် ထည့်သွင်းပြီးပါပြီ။', MessageType.success);
        }
        _clearForm();
        await _fetchTransactions(); // Refresh the list
      } catch (e) {
        CustomDialogs.showFlushbar(context, 'Error', 'Transaction လုပ်ဆောင်မှု မအောင်မြင်ပါ: $e', MessageType.error);
      } finally {
        Navigator.pop(context); // Close loading dialog
      }
    }
  }

  Future<void> _deleteTransaction(int id) async {
    final bool? confirm = await CustomDialogs.showConfirmationDialog(
      context,
      'အတည်ပြုပါ',
      'ဒီ transaction ကို ဖျက်မှာ သေချာပါသလား?',
    );
    if (confirm == true) {
      CustomDialogs.showLoadingDialog(context);
      try {
        await _apiService.deleteTransaction(id);
        CustomDialogs.showFlushbar(context, 'Success', 'Transaction ဖျက်ပြီးပါပြီ။', MessageType.success);
        await _fetchTransactions(); // Refresh the list
      } catch (e) {
        CustomDialogs.showFlushbar(context, 'Error', 'Transaction ဖျက်ရာတွင် အမှားအယွင်းရှိခဲ့ပါသည်: $e', MessageType.error);
      } finally {
        Navigator.pop(context); // Close loading dialog
      }
    }
  }

  Future<void> _approveRejectTransaction(int transactionId, String actionType) async {
    final bool? confirm = await CustomDialogs.showConfirmationDialog(
      context,
      'အတည်ပြုပါ',
      'ဒီ transaction ကို $actionType မှာ သေချာပါသလား?',
    );
    if (confirm == true) {
      CustomDialogs.showLoadingDialog(context);
      try {
        if (actionType == 'approve') {
          await _apiService.approveTransaction(transactionId, ownerNotes: _ownerNotesController.text);
          CustomDialogs.showFlushbar(context, 'Success', 'Transaction အတည်ပြုပြီးပါပြီ။', MessageType.success);
        } else {
          await _apiService.rejectTransaction(transactionId, ownerNotes: _ownerNotesController.text);
          CustomDialogs.showFlushbar(context, 'Success', 'Transaction ပယ်ချပြီးပါပြီ။', MessageType.success);
        }
        _clearForm(); // Clear notes after action
        await _fetchTransactions(); // Refresh the list
      } catch (e) {
        CustomDialogs.showFlushbar(context, 'Error', 'Transaction $actionType မအောင်မြင်ပါ: $e', MessageType.error);
      } finally {
        Navigator.pop(context); // Close loading dialog
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _currentUser = Provider.of<AuthProvider>(context).currentUser; // Listen for user changes

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'အားလုံး'),
            Tab(text: 'စောင့်ဆိုင်းဆဲ'),
            Tab(text: 'ပယ်ချထားပြီးသား'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _filteredTransactions.isEmpty
                  ? const Center(child: Text('Transaction မရှိသေးပါ'))
                  : RefreshIndicator(
                      onRefresh: _fetchTransactions,
                      child: ListView.builder(
                        itemCount: _filteredTransactions.length,
                        itemBuilder: (context, index) {
                          final transaction = _filteredTransactions[index];
                          return Card(
                            margin: const EdgeInsets.all(8.0),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${transaction.transactionTypeDisplay}: ${NumberFormat.currency(locale: 'my', symbol: 'MMK ').format(transaction.amount)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: transaction.transactionType == 'income' ? Colors.green[700] : Colors.red[700],
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text('ရက်စွဲ: ${DateFormat('yyyy-MM-dd').format(transaction.transactionDate)}'),
                                  Text('အဖွဲ့: ${transaction.groupName ?? 'N/A'}'),
                                  Text('ငွေစာရင်း: ${transaction.paymentAccountName ?? 'N/A'}'),
                                  Text('လွှဲပြောင်းကုတ်နံပါတ်: ${transaction.transferIdLast6Digits}'),
                                  Text('တင်သွင်းသူ: ${transaction.submittedByUsername ?? 'N/A'}'),
                                  if (transaction.ownerNotes != null && transaction.ownerNotes!.isNotEmpty)
                                    Text('Owner မှတ်စု: ${transaction.ownerNotes!}'),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      Text(
                                        'အခြေအနေ: ${_getStatusDisplayName(transaction.status)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _getStatusColor(transaction.status),
                                        ),
                                      ),
                                      if (transaction.imageUrl != null && transaction.imageUrl!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 8.0),
                                          child: GestureDetector(
                                            onTap: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  content: Image.network(
                                                    _buildImageUrl(transaction.imageUrl!),
                                                    errorBuilder: (context, error, stackTrace) => const Text('ပုံ မတွေ့ပါ'),
                                                  ),
                                                ),
                                              );
                                            },
                                            child: const Icon(Icons.image, color: Colors.blue),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (_currentUser?.userType == 'owner' && transaction.status == 'pending')
                                        IconButton(
                                          icon: const Icon(Icons.check_circle, color: Colors.green),
                                          onPressed: () => _approveRejectTransaction(transaction.id!, 'approve'),
                                          tooltip: 'အတည်ပြုမည်',
                                        ),
                                      if (_currentUser?.userType == 'owner' && transaction.status == 'pending')
                                        IconButton(
                                          icon: const Icon(Icons.cancel, color: Colors.red),
                                          onPressed: () => _approveRejectTransaction(transaction.id!, 'reject'),
                                          tooltip: 'ပယ်ချမည်',
                                        ),
                                      if (_currentUser?.userType == 'auditor' && transaction.status == 'rejected')
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () => _showTransactionForm(transaction: transaction),
                                          tooltip: 'ပြင်ဆင်မည်',
                                        ),
                                      if (_currentUser?.userType == 'owner')
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => _deleteTransaction(transaction.id!),
                                          tooltip: 'ဖျက်မည်',
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: (_currentUser?.userType == 'auditor' || _currentUser?.userType == 'owner')
          ? FloatingActionButton(
              onPressed: () => _showTransactionForm(),
              child: const Icon(Icons.add),
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            )
          : null,
    );
  }
}
