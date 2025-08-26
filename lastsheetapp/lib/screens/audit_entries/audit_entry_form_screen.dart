import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import provider
import '../../services/api_service.dart';
import '../../models/audit_entry.dart';
import '../../models/group.dart'; // Import Group model
import '../../models/user.dart'; // Import User model
import '../../providers/auth_provider.dart'; // Import AuthProvider
import '../../utils/custom_dialogs.dart'; // Make sure CustomDialogs is imported
import 'package:intl/intl.dart';

class AuditEntryFormScreen extends StatefulWidget {
  final AuditEntry? auditEntry; // For editing existing audit entry

  AuditEntryFormScreen({this.auditEntry});

  @override
  _AuditEntryFormScreenState createState() => _AuditEntryFormScreenState();
}

class _AuditEntryFormScreenState extends State<AuditEntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _receivableAmountController = TextEditingController(); // Changed from _incomeController
  final _payableAmountController = TextEditingController();    // Changed from _expenseController
  final _remarksController = TextEditingController();         // Changed from _notesController
  DateTime? _selectedCreatedAt; // Changed from _selectedAuditDate
  Group? _selectedGroup; // For selecting group
  bool _isLoading = false;

  final ApiService _apiService = ApiService();
  late Future<List<Group>> _groupsFuture; // To fetch groups for dropdown

  @override
  void initState() {
    super.initState();
    _groupsFuture = _apiService.fetchGroups(); // Fetch groups for dropdown

    if (widget.auditEntry != null) {
      _receivableAmountController.text = widget.auditEntry!.receivableAmount.toString();
      _payableAmountController.text = widget.auditEntry!.payableAmount.toString();
      _remarksController.text = widget.auditEntry!.remarks ?? '';
      _selectedCreatedAt = widget.auditEntry!.createdAt; // Use createdAt
    }
  }

  @override
  void dispose() {
    _receivableAmountController.dispose();
    _payableAmountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _saveAuditEntry() async {
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

      if (_selectedGroup == null || _selectedCreatedAt == null) {
        if (mounted) {
          CustomDialogs.showAlertDialog(context, 'အမှား', 'လိုအပ်သော အချက်အလက်များ ဖြည့်သွင်းပါ။ (အဖွဲ့၊ ဖန်တီးသည့်နေ့စွဲ)');
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final auditEntryToSave = AuditEntry(
        id: widget.auditEntry?.id,
        group: _selectedGroup!.id!, // Group ID
        groupName: _selectedGroup!.name, // Group Name
        auditor: currentUser.id!, // Auditor User ID
        auditorUsername: currentUser.username, // Auditor Username
        receivableAmount: double.parse(_receivableAmountController.text),
        payableAmount: double.parse(_payableAmountController.text),
        remarks: _remarksController.text.isEmpty ? null : _remarksController.text,
        createdAt: _selectedCreatedAt!, // Use selected createdAt
        lastUpdated: DateTime.now(), // Always update lastUpdated
      );

      try {
        if (widget.auditEntry == null) {
          // Create new audit entry
          await _apiService.createAuditEntry(auditEntryToSave);
          if (mounted) {
            CustomDialogs.showFlushbar(
              context,
              'Success',
              'Audit မှတ်တမ်းအသစ် ထည့်သွင်းပြီးပါပြီ။',
              MessageType.success, // Added MessageType
              onDismissed: () {
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
            );
          }
        } else {
          // Update existing audit entry
          await _apiService.updateAuditEntry(auditEntryToSave);
          if (mounted) {
            CustomDialogs.showFlushbar(
              context,
              'Success',
              'Audit မှတ်တမ်း ပြင်ဆင်ပြီးပါပြီ။',
              MessageType.success, // Added MessageType
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
        title: Text(widget.auditEntry == null ? 'Audit မှတ်တမ်းအသစ်' : 'Audit မှတ်တမ်း ပြင်ဆင်မည်'),
        backgroundColor: Colors.green,
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
                controller: _receivableAmountController, // Changed to receivableAmountController
                decoration: InputDecoration(
                  labelText: 'ရရန်ပမာဏ (Receivable Amount)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'ရရန်ပမာဏ ဖြည့်သွင်းပါ။';
                  }
                  if (double.tryParse(value) == null) {
                    return 'မှန်ကန်သော ပမာဏ ဖြည့်သွင်းပါ။';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _payableAmountController, // Changed to payableAmountController
                decoration: InputDecoration(
                  labelText: 'ပေးရန်ပမာဏ (Payable Amount)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'ပေးရန်ပမာဏ ဖြည့်သွင်းပါ။';
                  }
                  if (double.tryParse(value) == null) {
                    return 'မှန်ကန်သော ပမာဏ ဖြည့်သွင်းပါ။';
                  }
                  return null;
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
                    if (widget.auditEntry != null && _selectedGroup == null) {
                      _selectedGroup = groups.firstWhere(
                        (group) => group.id == widget.auditEntry!.group,
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
                          child: Text(group.name), // Changed to group.name
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
              ListTile(
                title: Text(
                  _selectedCreatedAt == null
                      ? 'ဖန်တီးသည့်နေ့စွဲ ရွေးချယ်ပါ' // Changed label
                      : 'ရွေးချယ်ထားသော နေ့စွဲ: ${DateFormat('yyyy-MM-dd').format(_selectedCreatedAt!)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedCreatedAt ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (picked != null && picked != _selectedCreatedAt) {
                    setState(() {
                      _selectedCreatedAt = picked;
                    });
                  }
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _remarksController, // Changed to _remarksController
                decoration: InputDecoration(
                  labelText: 'မှတ်ချက် (ရှိလျှင်)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _saveAuditEntry,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        elevation: 5,
                      ),
                      child: Text(
                        widget.auditEntry == null ? 'မှတ်တမ်း ထည့်မည်' : 'မှတ်တမ်း ပြင်ဆင်မည်',
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
