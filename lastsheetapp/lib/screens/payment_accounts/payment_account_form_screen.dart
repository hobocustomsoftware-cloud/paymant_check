import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import provider
import '../../services/api_service.dart';
import '../../models/payment_account.dart';
import '../../models/user.dart'; // Import User model for owner ID
import '../../providers/auth_provider.dart'; // Import AuthProvider
import '../../utils/custom_dialogs.dart'; // Make sure CustomDialogs is imported

class PaymentAccountFormScreen extends StatefulWidget {
  final PaymentAccount? account; // For editing existing account

  PaymentAccountFormScreen({this.account});

  @override
  _PaymentAccountFormScreenState createState() => _PaymentAccountFormScreenState();
}

class _PaymentAccountFormScreenState extends State<PaymentAccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _paymentAccountNameController = TextEditingController();
  final _paymentAccountTypeController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _bankAccountNumberController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  bool _isLoading = false;

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    if (widget.account != null) {
      _paymentAccountNameController.text = widget.account!.paymentAccountName;
      _paymentAccountTypeController.text = widget.account!.paymentAccountType;
      _bankNameController.text = widget.account!.bankName ?? '';
      _bankAccountNumberController.text = widget.account!.bankAccountNumber ?? '';
      _phoneNumberController.text = widget.account!.phoneNumber ?? '';
    }
  }

  @override
  void dispose() {
    _paymentAccountNameController.dispose();
    _paymentAccountTypeController.dispose();
    _bankNameController.dispose();
    _bankAccountNumberController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _savePaymentAccount() async {
    if (_formKey.currentState!.validate()) {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null || currentUser.id == null) {
        if (mounted) {
          CustomDialogs.showAlertDialog(context, 'အမှား', 'အသုံးပြုသူ အချက်အလက် မရှိပါ။');
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final accountToSave = PaymentAccount(
        id: widget.account?.id,
        paymentAccountName: _paymentAccountNameController.text,
        paymentAccountType: _paymentAccountTypeController.text,
        bankName: _bankNameController.text.isEmpty ? null : _bankNameController.text,
        bankAccountNumber: _bankAccountNumberController.text.isEmpty ? null : _bankAccountNumberController.text,
        phoneNumber: _phoneNumberController.text.isEmpty ? null : _phoneNumberController.text,
        owner: currentUser.id!, // Corrected: Pass current user's ID (int)
        ownerUsername: currentUser.username, // Assuming ownerUsername is needed for creation/update
        createdAt: widget.account?.createdAt ?? DateTime.now(), // Use existing or current date
        updatedAt: DateTime.now(), // Always update updatedAt
      );

      try {
        if (widget.account == null) {
          // Create new account
          await _apiService.createPaymentAccount(accountToSave);
          if (mounted) {
            CustomDialogs.showFlushbar(
              context,
              'Success', // Title
              'ငွေစာရင်းအသစ် ဖန်တီးပြီးပါပြီ။', // Message
              MessageType.success, // Type
              onDismissed: () {
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
            );
          }
        } else {
          // Update existing account
          await _apiService.updatePaymentAccount(accountToSave);
          if (mounted) {
            CustomDialogs.showFlushbar(
              context,
              'Success', // Title
              'ငွေစာရင်းကို ပြင်ဆင်ပြီးပါပြီ။', // Message
              MessageType.success, // Type
              onDismissed: () {
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
            );
          }
        }
      } catch (e) {
        if (mounted) {
          CustomDialogs.showFlushbar(context, 'Error', 'အမှားအယွင်းရှိခဲ့ပါသည်။: $e', MessageType.error); // Added MessageType
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account == null ? 'ငွေစာရင်းအသစ် ဖန်တီးမည်' : 'ငွေစာရင်း ပြင်ဆင်မည်'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                controller: _paymentAccountNameController,
                decoration: InputDecoration(
                  labelText: 'ငွေစာရင်းအမည်',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'ငွေစာရင်းအမည် ဖြည့်သွင်းပါ။';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _paymentAccountTypeController,
                decoration: InputDecoration(
                  labelText: 'အမျိုးအစား (ဥပမာ: CB Pay, AYA)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'အမျိုးအစား ဖြည့်သွင်းပါ။';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _bankNameController,
                decoration: InputDecoration(
                  labelText: 'ဘဏ်အမည် (ရှိလျှင်)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _bankAccountNumberController,
                decoration: InputDecoration(
                  labelText: 'ဘဏ်အကောင့်နံပါတ် (ရှိလျှင်)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _phoneNumberController,
                decoration: InputDecoration(
                  labelText: 'ဖုန်းနံပါတ် (ရှိလျှင်)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _savePaymentAccount,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        elevation: 5,
                      ),
                      child: Text(
                        widget.account == null ? 'ငွေစာရင်း ဖန်တီးမည်' : 'ငွေစာရင်း ပြင်ဆင်မည်',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
