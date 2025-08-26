import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/transaction.dart';
import '../../utils/custom_dialogs.dart';
import 'package:intl/intl.dart';

// Screens for navigation

import '../../utils/constants.dart';
import 'audit_entries/audit_entry_list_screen.dart';
import 'audit_entries/audit_summary_screen.dart';
import 'auth/login_screen.dart';
import 'transactions/transaction_detail_screen.dart';
import 'transactions/transaction_form_screen.dart'; // For Constants.baseUrl

class AuditorDashboardScreen extends StatefulWidget {
  const AuditorDashboardScreen({super.key});

  @override
  State<AuditorDashboardScreen> createState() => _AuditorDashboardScreenState();
}

class _AuditorDashboardScreenState extends State<AuditorDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TransactionProvider>(context, listen: false).fetchTransactions();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _reSubmitTransaction(Transaction transaction) async {
    final bool? confirm = await CustomDialogs.showConfirmationDialog(
      context,
      'အတည်ပြုပါ',
      'ဤငွေကြေးလွှဲပြောင်းမှုကို ပြန်တင်လိုပါသလား။',
    );

    if (confirm == true) {
      try {
        final updatedTransaction = transaction.copyWith(
          status: 'pending',
          ownerNotes: null,
          approvedByOwnerAt: null,
        );

        await Provider.of<TransactionProvider>(context, listen: false)
            .updateTransaction(updatedTransaction);

        CustomDialogs.showFlushbar(context, 'Success', 'ငွေကြေးလွှဲပြောင်းမှုကို ပြန်တင်ပြီးပါပြီ။', MessageType.success);
      } catch (e) {
        CustomDialogs.showFlushbar(context, 'Error', 'ငွေကြေးလွှဲပြောင်းမှုကို ပြန်တင်မရပါ။: $e', MessageType.error);
      }
    }
  }

  String _buildImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return '';
    }
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    return '${Constants.baseUrl}$imageUrl';
  }

  Widget _buildTransactionList(List<Transaction> transactions, {bool showReSubmitButton = false, bool allowEdit = false}) {
    if (transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            showReSubmitButton ? 'ငွေကြေးလွှဲပြောင်းမှု ငြင်းပယ်ခံရသည်များ မရှိပါ။' : 'ငွေကြေးလွှဲပြောင်းမှုများ မရှိပါ။',
            style: const TextStyle(fontSize: 18, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 3,
          child: InkWell(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TransactionDetailScreen(transaction: transaction),
                ),
              );
              Provider.of<TransactionProvider>(context, listen: false).fetchTransactions();
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ဖော်ပြချက်: ${transaction.transactionTypeDisplay} - ${NumberFormat.currency(locale: 'en_US', symbol: 'MMK ').format(transaction.amount)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey),
                  ),
                  const Divider(height: 16, thickness: 1),
                  _buildInfoRow('ပမာဏ', NumberFormat.currency(locale: 'en_US', symbol: 'MMK ').format(transaction.amount)),
                  _buildInfoRow('အမျိုးအစား', transaction.transactionTypeDisplay),
                  _buildInfoRow('အခြေအနေ', transaction.statusDisplay,
                      color: transaction.status == 'pending'
                          ? Colors.orange
                          : (transaction.status == 'approved' ? Colors.green : Colors.red)),
                  if (transaction.ownerNotes != null && transaction.ownerNotes!.isNotEmpty)
                    _buildInfoRow('မှတ်ချက်', transaction.ownerNotes!),
                  _buildInfoRow('ရက်စွဲ', DateFormat('yyyy-MM-dd').format(transaction.transactionDate)),
                  _buildInfoRow('အဖွဲ့', transaction.groupName ?? 'N/A'),
                  _buildInfoRow('ငွေပေးချေမှုအကောင့်', transaction.paymentAccountName ?? 'N/A'),
                  _buildInfoRow('တင်ပြသူ', transaction.submittedByUsername ?? 'N/A'),
                  if (transaction.imageUrl != null && transaction.imageUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ပုံ:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Center(
                            child: Image.network(
                              _buildImageUrl(transaction.imageUrl!),
                              height: 100,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 100),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (allowEdit && transaction.status == 'rejected')
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => TransactionFormScreen(transaction: transaction),
                                ),
                              );
                              Provider.of<TransactionProvider>(context, listen: false).fetchTransactions();
                            },
                            icon: const Icon(Icons.edit, color: Colors.white),
                            label: const Text('ပြင်ဆင်မည်', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                            ),
                          ),
                        ),
                      if (showReSubmitButton)
                        ElevatedButton.icon(
                          onPressed: () => _reSubmitTransaction(transaction),
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text('ပြန်တင်မည်', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                            elevation: 5,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: color ?? Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('စစ်ဆေးသူ Dashboard'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.teal[100],
          tabs: const [
            Tab(text: 'ငွေပေးချေမှုများ'),
            Tab(text: 'ငြင်းပယ်ခံရသည်များ'),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            UserAccountsDrawerHeader(
              accountName: Text(currentUser?.username ?? 'Auditor', style: const TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text(currentUser?.email ?? 'auditor@example.com'),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 50, color: Colors.teal),
              ),
              decoration: const BoxDecoration(
                color: Colors.teal,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.receipt),
              title: const Text('Audit မှတ်တမ်းများ'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => AuditEntryListScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.summarize),
              title: const Text('Audit Summary'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => AuditSummaryScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('ထွက်မည်'),
              onTap: () async {
                final bool? confirm = await CustomDialogs.showConfirmationDialog(
                  context,
                  'ထွက်မည်လား?',
                  'သင်အကောင့်မှ ထွက်ရန် သေချာပါသလား?',
                );
                if (confirm == true) {
                  await authProvider.logout();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                      (Route<dynamic> route) => false,
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, transactionProvider, child) {
          if (transactionProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final pendingApprovedTransactions = transactionProvider.transactions
              .where((t) => t.status == 'pending' || t.status == 'approved')
              .toList();
          final rejectedTransactions = transactionProvider.transactions
              .where((t) => t.status == 'rejected')
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildTransactionList(pendingApprovedTransactions, showReSubmitButton: false, allowEdit: false),
              _buildTransactionList(rejectedTransactions, showReSubmitButton: true, allowEdit: true),
            ],
          );
        },
      ),
      floatingActionButton: (currentUser?.userType == 'auditor' || currentUser?.userType == 'owner')
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => TransactionFormScreen()),
                );
                Provider.of<TransactionProvider>(context, listen: false).fetchTransactions();
              },
              child: const Icon(Icons.add),
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            )
          : null,
    );
  }
}
