import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/payment_account.dart';
import '../../utils/custom_dialogs.dart'; // Make sure CustomDialogs is imported
import 'payment_account_form_screen.dart';

class PaymentAccountListScreen extends StatefulWidget {
  @override
  _PaymentAccountListScreenState createState() => _PaymentAccountListScreenState();
}

class _PaymentAccountListScreenState extends State<PaymentAccountListScreen> {
  late Future<List<PaymentAccount>> _paymentAccountsFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadPaymentAccounts();
  }

  void _loadPaymentAccounts() {
    setState(() {
      _paymentAccountsFuture = _apiService.fetchPaymentAccounts();
    });
  }

  Future<void> _deletePaymentAccount(int id) async {
    final confirmed = await CustomDialogs.showConfirmationDialog( // Changed to showConfirmationDialog
      context,
      'ဖျက်မည်လား?',
      'ဤငွေစာရင်းကို ဖျက်ရန် သေချာပါသလား?',
    );
    if (confirmed == true) {
      try {
        await _apiService.deletePaymentAccount(id);
        if (mounted) {
          CustomDialogs.showFlushbar(context, 'Success', 'ငွေစာရင်းကို ဖျက်လိုက်ပါပြီ။', MessageType.success); // Added MessageType
          _loadPaymentAccounts(); // Reload after deletion
        }
      } catch (e) {
        if (mounted) {
          CustomDialogs.showFlushbar(context, 'Error', 'ဖျက်ရာတွင် အမှားအယွင်းရှိခဲ့ပါသည်။: $e', MessageType.error); // Added MessageType
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ငွေပေးချေမှုစာရင်းများ'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<PaymentAccount>>(
        future: _paymentAccountsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('အမှားအယွင်းရှိပါသည်။: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('ငွေစာရင်းများ မရှိသေးပါ။'));
          } else {
            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final account = snapshot.data![index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.paymentAccountName, // Assuming paymentAccountName exists
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 5),
                              Text('အမျိုးအစား: ${account.paymentAccountType}'),
                              Text('ဘဏ်အမည်: ${account.bankName ?? '-'}'),
                              Text('အကောင့်နံပါတ်: ${account.bankAccountNumber ?? '-'}'),
                              Text('ဖုန်းနံပါတ်: ${account.phoneNumber ?? '-'}'),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => PaymentAccountFormScreen(account: account),
                                  ),
                                );
                                _loadPaymentAccounts(); // Reload after edit
                              },
                              tooltip: 'ပြင်ဆင်မည်',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deletePaymentAccount(account.id!),
                              tooltip: 'ဖျက်မည်',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => PaymentAccountFormScreen(account: null,)),
          );
          _loadPaymentAccounts(); // Reload after creation
        },
        label: const Text('ငွေစာရင်းအသစ် ဖန်တီးမည်'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}
