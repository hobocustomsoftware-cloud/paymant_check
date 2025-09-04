import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:lastsheetapp/owner/owner_review_screen.dart';
import 'package:lastsheetapp/screens/audit_entries/audit_entry_list_screen.dart';
import 'package:lastsheetapp/screens/auth/change_password_screen.dart';
import 'package:lastsheetapp/screens/auth/login_screen.dart';

// ✅ bottom nav မှာရှိခဲ့တဲ့ စာမျက်နှာများကို Drawer ကနေ သွားဖို့ import
import 'package:lastsheetapp/screens/transactions/transaction_list_screen.dart';
import 'package:lastsheetapp/screens/groups/group_list_screen.dart';
import 'package:lastsheetapp/screens/payment_accounts/payment_account_list_screen.dart';
import 'package:lastsheetapp/screens/auditors/auditor_list_screen.dart';

import '../../providers/auth_provider.dart';
import '../../utils/custom_dialogs.dart';
import '../../widgets/audit_entries_summary_widget.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});
  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this); // 0=Review, 1=Audit
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ပိုင်ရှင် Dashboard'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,

        centerTitle: true,
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(color: Colors.white, width: 3),
          ),
          tabs: const [
            Tab(text: 'Review'),
            Tab(text: 'Audit'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ထွက်မည်',
            onPressed: () => _logout(context),
          ),
        ],
      ),

      // ✅ Drawer (sidebar) — bottom nav မှာရှိခဲ့တာတွေ အကုန်ပါ
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
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

            // Tabs
            ListTile(
              leading: const Icon(Icons.fact_check),
              title: const Text('Review Transactions'),
              onTap: () {
                Navigator.pop(context);
                _tab.animateTo(0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Audit Summary'),
              onTap: () {
                Navigator.pop(context);
                _tab.animateTo(1);
              },
            ),

            // Previously in bottomNavigationBar
            const Divider(),
            ListTile(
              leading: const Icon(Icons.receipt_long),
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
              leading: const Icon(Icons.group),
              title: const Text('Groups'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => GroupListScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text('Payment Accounts'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PaymentAccountListScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_pin),
              title: const Text('Auditors'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AuditorUserListScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.view_list),
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
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('ထွက်မည်'),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),

      // Main content: 2 tabs
      body: TabBarView(
        controller: _tab,
        children: const [
          OwnerReviewScreen(),
          SingleChildScrollView(
            padding: EdgeInsets.all(12),
            child: AuditEntriesSummaryWidget(
              title: 'Audit Entries Summary (Owner/Admin)',
            ),
          ),
        ],
      ),
    );
  }
}
