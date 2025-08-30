import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:flutter/services.dart';

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

  File? _selectedImageFile; // mobile
  Uint8List? _selectedImageBytes; // web
  String? _selectedImageFileName;

  bool _isLoading = false;
  bool _isCheckingDup = false; // transfer id duplicate (6-digit global)
  bool _dupExists = false;
  bool _clearExistingImage = false;

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

    _transferIdController.addListener(_checkDuplicateIfReady);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _transferIdController.dispose();
    _ownerNotesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (picked == null) return;

      final fileName = picked.name.isNotEmpty
          ? picked.name
          : (picked.path.isNotEmpty
                ? picked.path.split('/').last
                : 'upload.jpg');

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedImageFile = null;
          _selectedImageBytes = bytes;
          _selectedImageFileName = fileName;
          _clearExistingImage = false;
        });
      } else {
        setState(() {
          _selectedImageFile = File(picked.path);
          _selectedImageBytes = null;
          _selectedImageFileName = fileName;
          _clearExistingImage = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      CustomDialogs.showFlushbar(
        context,
        'Image Error',
        'ပုံရွေးရာတွင် အမှား: $e',
        MessageType.error,
      );
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImageFile = null;
      _selectedImageBytes = null;
      _selectedImageFileName = null;
      _clearExistingImage = true;
    });
  }

  String _buildImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return '';
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'))
      return imageUrl;
    return '${Constants.baseUrl}$imageUrl';
  }

  // ---------- Duplicate check (global by 6 digits only) ----------
  Future<void> _checkDuplicateIfReady() async {
    final t = _transferIdController.text.trim();
    if (t.length != 6) {
      if (_dupExists || _isCheckingDup) {
        setState(() {
          _dupExists = false;
          _isCheckingDup = false;
        });
      }
      return;
    }
    setState(() => _isCheckingDup = true);
    try {
      final exists = await _apiService.existsTransferId(
        transferIdLast6: t,
        excludeId: widget.transaction?.id, // editing own row won't block
      );
      if (!mounted) return;
      setState(() {
        _dupExists = exists;
        _isCheckingDup = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCheckingDup = false);
    }
  }
  // --------------------------------------------------------------

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;

    if (_dupExists) {
      CustomDialogs.showAlertDialog(
        context,
        'မထည့်ရပါ',
        'ဤ လွှဲပြောင်း ID (၆ လုံး) ကို ရှိပြီးသား ဖြစ်နေပါသည်။ ပြန်စစ်၍ပြင်၍ ထည့်ပါ။',
      );
      return;
    }

    setState(() => _isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;

    if (user == null || user.id == null || user.username == null) {
      CustomDialogs.showAlertDialog(
        context,
        'အမှား',
        'အသုံးပြုသူ အချက်အလက် မရှိပါ။',
      );
      setState(() => _isLoading = false);
      return;
    }
    if (_selectedGroup == null ||
        _selectedPaymentAccount == null ||
        _selectedDate == null ||
        _selectedTransactionType == null) {
      CustomDialogs.showAlertDialog(
        context,
        'အမှား',
        'အဖွဲ့/ငွေစာရင်း/နေ့စွဲ/အမျိုးအစား မပြည့်စုံပါ။',
      );
      setState(() => _isLoading = false);
      return;
    }

    final transferText = _transferIdController.text.trim();
    final amountText = _amountController.text.trim().replaceAll(',', '');
    final amountParsed = double.tryParse(amountText);
    if (amountParsed == null) {
      CustomDialogs.showAlertDialog(
        context,
        'အမှား',
        'ငွေပမာဏ မှန်ကန်မှုမရှိပါ (ဥပမာ 2000.00)',
      );
      setState(() => _isLoading = false);
      return;
    }

    // server-side confirm (create only) – safest
    if (widget.transaction == null) {
      final exists = await _apiService.existsTransferId(
        transferIdLast6: transferText,
      );
      if (exists) {
        CustomDialogs.showAlertDialog(
          context,
          'မထည့်ရပါ',
          'ဤ လွှဲပြောင်း ID (၆ လုံး) ကို ရှိပြီးသား ဖြစ်နေပါသည်။',
        );
        setState(() => _isLoading = false);
        return;
      }
    }

    final tx = Transaction(
      id: widget.transaction?.id,
      transactionDate: _selectedDate!,
      group: _selectedGroup!.id!,
      groupName: _selectedGroup!.name,
      paymentAccount: _selectedPaymentAccount!.id!,
      paymentAccountName: _selectedPaymentAccount!.paymentAccountName,
      transferIdLast6Digits: transferText,
      amount: amountParsed,
      transactionType: _selectedTransactionType!,
      submittedBy: user.id!,
      submittedByUsername: user.username,
      status: widget.transaction?.status ?? 'pending',
      imageUrl: widget.transaction?.imageUrl,
      approvedByOwnerAt: widget.transaction?.approvedByOwnerAt,
      ownerNotes: _ownerNotesController.text.isEmpty
          ? null
          : _ownerNotesController.text,
      submittedAt: widget.transaction?.submittedAt ?? DateTime.now(),
    );

    try {
      if (widget.transaction == null) {
        await _apiService.createTransaction(
          tx,
          imageFile: _selectedImageFile,
          imageBytes: _selectedImageBytes,
          imageFileName: _selectedImageFileName,
        );
        if (!mounted) return;
        CustomDialogs.showFlushbar(
          context,
          'Success',
          'ငွေပေးချေမှုမှတ်တမ်းအသစ် ထည့်သွင်းပြီးပါပြီ။',
          MessageType.success,
          onDismissed: () {
            if (mounted) Navigator.of(context).pop();
          },
        );
      } else {
        await _apiService.updateTransaction(
          tx,
          imageFile: _selectedImageFile,
          imageBytes: _selectedImageBytes,
          imageFileName: _selectedImageFileName,
          clearImage: _clearExistingImage,
        );
        if (!mounted) return;
        CustomDialogs.showFlushbar(
          context,
          'Success',
          'ငွေပေးချေမှုမှတ်တမ်း ပြင်ဆင်ပြီးပါပြီ။',
          MessageType.success,
          onDismissed: () {
            if (mounted) Navigator.of(context).pop();
          },
        );
      }
    } catch (e) {
      if (!mounted) return;
      CustomDialogs.showFlushbar(context, 'Error', '$e', MessageType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.transaction?.imageUrl;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.transaction == null
              ? 'ငွေပေးချေမှုအသစ် ထည့်မည်'
              : 'ငွေပေးချေမှု ပြင်ဆင်မည်',
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // amount
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'ငွေပမာဏ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  if ((v ?? '').isEmpty) return 'ငွေပမာဏ ဖြည့်သွင်းပါ။';
                  return double.tryParse((v ?? '').replaceAll(',', '')) == null
                      ? 'မှန်ကန်သော ပမာဏ ဖြည့်သွင်းပါ။'
                      : null;
                },
              ),
              const SizedBox(height: 15),

              // transfer id
              TextFormField(
                controller: _transferIdController,
                decoration: InputDecoration(
                  labelText: 'လွှဲပြောင်း ID (နောက်ဆုံး ၆ လုံး)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: _isCheckingDup
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _dupExists
                      ? const Icon(Icons.error, color: Colors.red)
                      : null,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                validator: (v) => ((v ?? '').trim().length != 6)
                    ? '၆ လုံး အတိအကျ ထည့်ပါ'
                    : null,
              ),
              if (_dupExists)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'ဤ လွှဲပြောင်း ID (၆ လုံး) ရှိပြီးသား ဖြစ်နေပါတယ်',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),

              const SizedBox(height: 15),

              // type
              DropdownButtonFormField<String>(
                value: _selectedTransactionType,
                decoration: InputDecoration(
                  labelText: 'အမျိုးအစား',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: _transactionTypes
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t == 'income' ? 'ဝင်ငွေ' : 'ထွက်ငွေ'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedTransactionType = v),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'အမျိုးအစား ရွေးချယ်ပါ။' : null,
              ),
              const SizedBox(height: 15),

              // date
              ListTile(
                title: Text(
                  _selectedDate == null
                      ? 'နေ့စွဲ ရွေးချယ်ပါ'
                      : 'ရွေးချယ်ထားသော နေ့စွဲ: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (picked != null && picked != _selectedDate) {
                    setState(() => _selectedDate = picked);
                  }
                },
              ),
              const SizedBox(height: 15),

              // group
              FutureBuilder<List<Group>>(
                future: _groupsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'အဖွဲ့များ load လုပ်ရာတွင် အမှားအယွင်းရှိပါသည်.: ${snapshot.error}',
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('အဖွဲ့များ မရှိသေးပါ။'));
                  } else {
                    final groups = snapshot.data!;
                    if (widget.transaction != null && _selectedGroup == null) {
                      _selectedGroup = groups.firstWhere(
                        (g) => g.id == widget.transaction!.group,
                        orElse: () => groups.first,
                      );
                    }
                    return DropdownButtonFormField<Group>(
                      value: _selectedGroup,
                      decoration: InputDecoration(
                        labelText: 'အဖွဲ့',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: groups
                          .map(
                            (g) =>
                                DropdownMenuItem(value: g, child: Text(g.name)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedGroup = v),
                      validator: (v) => v == null ? 'အဖွဲ့ ရွေးချယ်ပါ။' : null,
                    );
                  }
                },
              ),
              const SizedBox(height: 15),

              // payment account
              FutureBuilder<List<PaymentAccount>>(
                future: _paymentAccountsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'ငွေစာရင်းများ load လုပ်ရာတွင် အမှားအယွင်းရှိပါသည်.: ${snapshot.error}',
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('ငွေစာရင်းများ မရှိသေးပါ။'),
                    );
                  } else {
                    final accounts = snapshot.data!;
                    if (widget.transaction != null &&
                        _selectedPaymentAccount == null) {
                      _selectedPaymentAccount = accounts.firstWhere(
                        (a) => a.id == widget.transaction!.paymentAccount,
                        orElse: () => accounts.first,
                      );
                    }
                    return DropdownButtonFormField<PaymentAccount>(
                      value: _selectedPaymentAccount,
                      decoration: InputDecoration(
                        labelText: 'ငွေစာရင်း',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: accounts
                          .map(
                            (a) => DropdownMenuItem(
                              value: a,
                              child: Text(a.paymentAccountName),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedPaymentAccount = v),
                      validator: (v) =>
                          v == null ? 'ငွေစာရင်း ရွေးချယ်ပါ။' : null,
                    );
                  }
                },
              ),

              const SizedBox(height: 20),

              // image
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ပုံ (ရှိလျှင်)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (kIsWeb && _selectedImageBytes != null)
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Image.memory(
                          _selectedImageBytes!,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: _clearImage,
                        ),
                      ],
                    )
                  else if (!kIsWeb && _selectedImageFile != null)
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Image.file(
                          _selectedImageFile!,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
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
                            Image.network(
                              _buildImageUrl(imageUrl),
                              height: 150,
                              fit: BoxFit.cover,
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: _clearImage,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: _clearImage,
                          icon: const Icon(
                            Icons.delete_forever,
                            color: Colors.white,
                          ),
                          label: const Text('ပုံ ဖျက်မည်'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: (_isLoading || _dupExists) ? null : _saveTransaction,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  elevation: 5,
                ),
                child: Text(
                  widget.transaction == null
                      ? 'မှတ်တမ်း ထည့်မည်'
                      : 'မှတ်တမ်း ပြင်ဆင်မည်',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
