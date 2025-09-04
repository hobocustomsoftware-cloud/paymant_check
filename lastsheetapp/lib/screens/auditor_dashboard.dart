import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:lastsheetapp/screens/auth/change_password_screen.dart';
import 'package:lastsheetapp/screens/auth/login_screen.dart';
import 'package:lastsheetapp/screens/transactions/transaction_detail_screen.dart';
import 'package:lastsheetapp/screens/transactions/transaction_form_screen.dart';
import 'package:lastsheetapp/screens/transactions/transaction_list_screen.dart';
import 'package:lastsheetapp/screens/audit_entries/audit_entry_list_screen.dart';

import '../../providers/transaction_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/transaction.dart';
import '../../utils/custom_dialogs.dart';
import '../../utils/constants.dart';
import '../../widgets/audit_entries_summary_widget.dart';

class AuditorDashboardScreen extends StatefulWidget {
  const AuditorDashboardScreen({super.key});
  @override
  State<AuditorDashboardScreen> createState() => _AuditorDashboardScreenState();
}

class _AuditorDashboardScreenState extends State<AuditorDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().fetchTransactions();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _goTab(int i) {
    Navigator.pop(context);
    _tab.animateTo(i);
  }

  Future<void> _logout() async {
    final ok = await CustomDialogs.showConfirmationDialog(
      context,
      'ထွက်မည်လား?',
      'အကောင့်မှ ထွက်ရန် သေချာပါသလား?',
    );
    if (ok == true) {
      await context.read<AuthProvider>().logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _reSubmitTransaction(Transaction t) async {
    if (t.id == null) return;
    if (t.status != 'rejected') {
      CustomDialogs.showFlushbar(
        context,
        'Info',
        'Reject ဖြစ်ထားမှ ပြန်တင်နိုင်ပါသည်။',
        MessageType.info,
      );
      return;
    }
    final ok = await CustomDialogs.showConfirmationDialog(
      context,
      'အတည်ပြုပါ',
      'ပြန်တင်မလား?',
    );
    if (ok != true) return;
    try {
      await context.read<TransactionProvider>().reSubmitTransaction(t.id!);
      if (!mounted) return;
      CustomDialogs.showFlushbar(
        context,
        'Success',
        'ပြန်တင်ပြီးပါပြီ',
        MessageType.success,
      );
      context.read<TransactionProvider>().fetchTransactions();
    } catch (e) {
      CustomDialogs.showFlushbar(context, 'Error', '$e', MessageType.error);
    }
  }

  String _buildImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '${Constants.baseUrl}$url';
  }

  Widget _row(String k, String v, {Color? c}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      children: [
        SizedBox(
          width: 150,
          child: Text(
            '$k:',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(v, style: TextStyle(color: c ?? Colors.black87)),
        ),
      ],
    ),
  );

  Widget _list(
    List<Transaction> items, {
    bool showResubmit = false,
    bool allowEdit = false,
  }) {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('မှတ်တမ်း မရှိပါ'),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final t = items[i];
        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TransactionDetailScreen(transaction: t),
                ),
              );
              if (!mounted) return;
              context.read<TransactionProvider>().fetchTransactions();
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ဖော်ပြချက်: ${t.transactionTypeDisplay ?? t.transactionType} - '
                    '${NumberFormat.currency(locale: "en_US", symbol: "MMK ").format(t.amount)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const Divider(height: 16, thickness: 1),
                  _row(
                    'ပမာဏ',
                    NumberFormat.currency(
                      locale: 'en_US',
                      symbol: 'MMK ',
                    ).format(t.amount),
                  ),
                  _row(
                    'အမျိုးအစား',
                    t.transactionTypeDisplay ??
                        (t.transactionType == 'income' ? 'ဝင်ငွေ' : 'ထွက်ငွေ'),
                  ),
                  _row(
                    'အခြေအနေ',
                    t.statusDisplay ?? t.status,
                    c: t.status == 'pending'
                        ? Colors.orange
                        : (t.status == 'approved' ? Colors.green : Colors.red),
                  ),
                  if ((t.ownerNotes ?? '').isNotEmpty)
                    _row('မှတ်ချက်', t.ownerNotes!),
                  _row(
                    'ရက်စွဲ',
                    DateFormat('yyyy-MM-dd').format(t.transactionDate),
                  ),
                  _row('အဖွဲ့', t.groupName),
                  _row('ငွေပေးချေမှုအကောင့်', t.paymentAccountName),
                  _row('တင်ပြသူ', t.submittedByUsername ?? 'N/A'),
                  if ((t.imageUrl ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Image.network(
                          _buildImageUrl(t.imageUrl),
                          height: 100,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image, size: 100),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (allowEdit && t.status == 'rejected')
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TransactionFormScreen(transaction: t),
                                ),
                              );
                              if (!mounted) return;
                              context
                                  .read<TransactionProvider>()
                                  .fetchTransactions();
                            },
                            icon: const Icon(Icons.edit, color: Colors.white),
                            label: const Text(
                              'ပြင်ဆင်မည်',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                          ),
                        ),
                      if (showResubmit)
                        ElevatedButton.icon(
                          onPressed: () => _reSubmitTransaction(t),
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text(
                            'ပြန်တင်မည်',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('စစ်ဆေးသူ Dashboard'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white, // ✅ white labels
          unselectedLabelColor: Colors.white70, // ✅ faded white
          indicatorColor: Colors.white, // ✅ white underline
          tabs: const [
            Tab(text: 'Transactions'),
            Tab(text: 'Rejected'),
            Tab(text: 'Audit'),
          ],
        ),
      ),

      // ✅ Drawer: tabs + extra menus
      drawer: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                user?.username ?? 'Owner',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(user?.email ?? ''),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 42, color: Colors.indigo),
              ),
              decoration: const BoxDecoration(color: Colors.indigo),
            ),

            // Tab navigation
            ListTile(
              leading: const Icon(Icons.receipt),
              title: const Text('Transactions'),
              onTap: () => _goTab(0),
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Rejected'),
              onTap: () => _goTab(1),
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Audit Summary'),
              onTap: () => _goTab(2),
            ),
            const Divider(),
            // Extra pages (were in bottom nav in owner side)
            ListTile(
              leading: const Icon(Icons.add_box),
              title: const Text('New Transaction'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TransactionFormScreen()),
                );
                if (!mounted) return;
                context.read<TransactionProvider>().fetchTransactions();
              },
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Transactions (All)'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TransactionListScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Audit Entries List'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AuditEntryListScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('စကားဝှက် ပြောင်းမည်'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('ထွက်မည်'),
              onTap: _logout,
            ),
          ],
        ),
      ),

      body: Consumer<TransactionProvider>(
        builder: (_, tp, __) {
          if (tp.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final txs = tp.transactions;
          final list1 = txs
              .where((t) => t.status == 'pending' || t.status == 'approved')
              .toList();
          final list2 = txs.where((t) => t.status == 'rejected').toList();

          return TabBarView(
            controller: _tab,
            children: [
              _list(list1, showResubmit: false, allowEdit: false),
              _list(list2, showResubmit: true, allowEdit: true),
              const SingleChildScrollView(
                padding: EdgeInsets.all(12),
                child: AuditEntriesSummaryWidget(title: 'Audit (Auditor View)'),
              ),
            ],
          );
        },
      ),
      floatingActionButton:
          (auth.currentUser?.userType == 'auditor' ||
              auth.currentUser?.userType == 'owner')
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TransactionFormScreen()),
                );
                if (!mounted) return;
                context.read<TransactionProvider>().fetchTransactions();
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
