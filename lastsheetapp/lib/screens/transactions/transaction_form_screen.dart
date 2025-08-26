import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../models/transaction.dart';
import '../../models/group.dart';
import '../../models/payment_account.dart';
import '../../providers/auth_provider.dart';
import '../../utils/custom_dialogs.dart';
import '../../utils/constants.dart';

class TransactionFormScreen extends StatefulWidget {
  final Transaction? transaction;

  TransactionFormScreen({this.transaction});

  @override
  _TransactionFormScreenState createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _transferIdController = TextEditingController();
  final _ownerNotesController = TextEditingController();
  DateTime? _selectedDate;
  Group? _selectedGroup;
  PaymentAccount? _selectedPaymentAccount;
  String? _selectedTransactionType;
  File? _selectedImage;
  bool _isLoading = false;

  final ApiService _apiService = ApiService();
  late Future<List<Group>> _groupsFuture;
  late Future<List<PaymentAccount>> _paymentAccountsFuture;

  final List<String> _transactionTypes = ['income', 'expense'];

  @override
  void initState() {
    super.initState();
    _groupsFuture = _apiService.fetchGroups();
    _paymentAccountsFuture = _apiService.fetchPaymentAccounts();

    if (widget.transaction != null) {
      _amountController.text = widget.transaction!.amount.toString();
      _transferIdController.text = widget.transaction!.transferIdLast6Digits;
      _selectedDate = widget.transaction!.transactionDate;
      _selectedTransactionType = widget.transaction!.transactionType;
      _ownerNotesController.text = widget.transaction!.ownerNotes ?? '';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _transferIdController.dispose();
    _ownerNotesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  // Helper to build the correct image URL
  String _buildImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return '';
    }
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    return '${Constants.baseUrl}$imageUrl';
  }

  Future<void> _saveTransaction() async {
    if (_formKey.currentState!.validate()) {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null || currentUser.id == null || currentUser.username == null) {
        if (mounted) {
          CustomDialogs.showAlertDialog(context, 'အမှား', 'အသုံးပြုသူ အချက်အလက် မရှိပါ။');
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      if (_selectedGroup == null || _selectedPaymentAccount == null || _selectedDate == null || _selectedTransactionType == null) {
        if (mounted) {
          CustomDialogs.showAlertDialog(context, 'အမှား', 'လိုအပ်သော အချက်အလက်များ ဖြည့်သွင်းပါ။ (အဖွဲ့၊ ငွေစာရင်း၊ နေ့စွဲ၊ အမျိုးအစား)');
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final transactionToSave = Transaction(
        id: widget.transaction?.id,
        transactionDate: _selectedDate!,
        group: _selectedGroup!.id!,
        groupName: _selectedGroup!.name,
        paymentAccount: _selectedPaymentAccount!.id!,
        paymentAccountName: _selectedPaymentAccount!.paymentAccountName,
        transferIdLast6Digits: _transferIdController.text,
        amount: double.parse(_amountController.text),
        transactionType: _selectedTransactionType!,
        submittedBy: currentUser.id!,
        submittedByUsername: currentUser.username, // Pass submittedByUsername
        status: widget.transaction?.status ?? 'pending',
        imageUrl: widget.transaction?.imageUrl,
        approvedByOwnerAt: widget.transaction?.approvedByOwnerAt,
        ownerNotes: _ownerNotesController.text.isEmpty ? null : _ownerNotesController.text,
        submittedAt: widget.transaction?.submittedAt ?? DateTime.now(),
      );

      try {
        bool clearImageOnBackend = _selectedImage == null && widget.transaction!.imageUrl != null && widget.transaction!.imageUrl!.isNotEmpty;

        if (widget.transaction == null) {
          await _apiService.createTransaction(transactionToSave, imageFile: _selectedImage);
          if (mounted) {
            CustomDialogs.showFlushbar(
              context,
              'Success',
              'ငွေပေးချေမှုမှတ်တမ်းအသစ် ထည့်သွင်းပြီးပါပြီ။',
              MessageType.success,
              onDismissed: () {
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
            );
          }
        } else {
          await _apiService.updateTransaction(
            transactionToSave,
            imageFile: _selectedImage,
            clearImage: clearImageOnBackend,
          );
          if (mounted) {
            CustomDialogs.showFlushbar(
              context,
              'Success',
              'ငွေပေးချေမှုမှတ်တမ်း ပြင်ဆင်ပြီးပါပြီ။',
              MessageType.success,
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
          CustomDialogs.showFlushbar(context, 'Error', 'အမှားအယွင်းရှိခဲ့ပါသည်။: $e', MessageType.error);
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
    final String? imageUrl = widget.transaction?.imageUrl;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transaction == null ? 'ငွေပေးချေမှုအသစ် ထည့်မည်' : 'ငွေပေးချေမှု ပြင်ဆင်မည်'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'ငွေပမာဏ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'ငွေပမာဏ ဖြည့်သွင်းပါ။';
                  }
                  if (double.tryParse(value) == null) {
                    return 'မှန်ကန်သော ပမာဏ ဖြည့်သွင်းပါ။';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _transferIdController,
                decoration: InputDecoration(
                  labelText: 'လွှဲပြောင်း ID (နောက်ဆုံး ၆ လုံး)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'လွှဲပြောင်း ID ဖြည့်သွင်းပါ။';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _selectedTransactionType,
                decoration: InputDecoration(
                  labelText: 'အမျိုးအစား',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: _transactionTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type == 'income' ? 'ဝင်ငွေ' : 'ထွက်ငွေ'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTransactionType = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'အမျိုးအစား ရွေးချယ်ပါ။';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              ListTile(
                title: Text(
                  _selectedDate == null
                      ? 'နေ့စွဲ ရွေးချယ်ပါ'
                      : 'ရွေးချယ်ထားသော နေ့စွဲ: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (picked != null && picked != _selectedDate) {
                    setState(() {
                      _selectedDate = picked;
                    });
                  }
                },
              ),
              const SizedBox(height: 15),
              FutureBuilder<List<Group>>(
                future: _groupsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('အဖွဲ့များ load လုပ်ရာတွင် အမှားအယွင်းရှိပါသည်။: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('အဖွဲ့များ မရှိသေးပါ။'));
                  } else {
                    List<Group> groups = snapshot.data!;
                    if (widget.transaction != null && _selectedGroup == null) {
                      _selectedGroup = groups.firstWhere(
                        (group) => group.id == widget.transaction!.group,
                        orElse: () => groups.first,
                      );
                    }
                    return DropdownButtonFormField<Group>(
                      value: _selectedGroup,
                      decoration: InputDecoration(
                        labelText: 'အဖွဲ့',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: groups.map((group) {
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
                      validator: (value) {
                        if (value == null) {
                          return 'အဖွဲ့ ရွေးချယ်ပါ။';
                        }
                        return null;
                      },
                    );
                  }
                },
              ),
              const SizedBox(height: 15),
              FutureBuilder<List<PaymentAccount>>(
                future: _paymentAccountsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('ငွေစာရင်းများ load လုပ်ရာတွင် အမှားအယွင်းရှိပါသည်။: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('ငွေစာရင်းများ မရှိသေးပါ။'));
                  } else {
                    List<PaymentAccount> accounts = snapshot.data!;
                    if (widget.transaction != null && _selectedPaymentAccount == null) {
                      _selectedPaymentAccount = accounts.firstWhere(
                        (account) => account.id == widget.transaction!.paymentAccount,
                        orElse: () => accounts.first,
                      );
                    }
                    return DropdownButtonFormField<PaymentAccount>(
                      value: _selectedPaymentAccount,
                      decoration: InputDecoration(
                        labelText: 'ငွေစာရင်း',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: accounts.map((account) {
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
                      validator: (value) {
                        if (value == null) {
                          return 'ငွေစာရင်း ရွေးချယ်ပါ။';
                        }
                        return null;
                      },
                    );
                  }
                },
              ),
              const SizedBox(height: 20),
              // Image Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ပုံ (ရှိလျှင်)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (_selectedImage != null)
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Image.file(_selectedImage!, height: 150, fit: BoxFit.cover),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: _clearImage,
                        ),
                      ],
                    )
                  else if (imageUrl != null && imageUrl.isNotEmpty)
                    Column(
                      children: [
                        Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Image.network(_buildImageUrl(imageUrl), height: 150, fit: BoxFit.cover),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: _clearImage,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: _clearImage,
                          icon: const Icon(Icons.delete_forever, color: Colors.white),
                          label: const Text('ပုံ ဖျက်မည်'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image),
                      label: const Text('ပုံ ရွေးချယ်မည်'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _saveTransaction,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        elevation: 5,
                      ),
                      child: Text(
                        widget.transaction == null ? 'မှတ်တမ်း ထည့်မည်' : 'မှတ်တမ်း ပြင်ဆင်မည်',
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
