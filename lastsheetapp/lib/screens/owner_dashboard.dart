import 'package:flutter/material.dart';
import 'package:lastsheetapp/screens/audit_entries/audit_summary_screen.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/custom_dialogs.dart';

// Import other screens
import 'auth/login_screen.dart';
import 'groups/group_list_screen.dart';
import 'payment_accounts/payment_account_list_screen.dart';
import 'auditors/auditor_list_screen.dart';
import 'transactions/transaction_list_screen.dart'; // Corrected import path


class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    // Each screen will manage its own data fetching
    const TransactionListScreen(), // Removed isOwnerView: true
    GroupListScreen(),
    PaymentAccountListScreen(),
    AuditorUserListScreen(),
    AuditSummaryScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ပိုင်ရှင် Dashboard'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final bool? confirm = await CustomDialogs.showConfirmationDialog(
                context,
                'ထွက်မည်လား?',
                'သင်အကောင့်မှ ထွက်ရန် သေချာပါသလား?',
              );
              if (confirm == true) {
                await authProvider.logout();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => LoginScreen()), // Assuming LoginScreen is available
                    (Route<dynamic> route) => false,
                  );
                }
              }
            },
            tooltip: 'ထွက်မည်',
          ),
        ],
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Groups',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Payment Accounts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_pin),
            label: 'Auditors',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Audit Summary',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Ensure all items are visible
      ),
    );
  }
}
