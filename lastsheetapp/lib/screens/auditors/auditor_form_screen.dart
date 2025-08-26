import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';
import '../../utils/custom_dialogs.dart'; // Make sure CustomDialogs is imported

class AuditorUserFormScreen extends StatefulWidget {
  final User? auditor; // For editing existing auditor

  AuditorUserFormScreen({this.auditor});

  @override
  _AuditorUserFormScreenState createState() => _AuditorUserFormScreenState();
}

class _AuditorUserFormScreenState extends State<AuditorUserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    if (widget.auditor != null) {
      _usernameController.text = widget.auditor!.username;
      _emailController.text = widget.auditor!.email;
      _firstNameController.text = widget.auditor!.firstName ?? '';
      _lastNameController.text = widget.auditor!.lastName ?? '';
      _phoneNumberController.text = widget.auditor!.phoneNumber ?? '';
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneNumberController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveAuditor() async {
    if (_formKey.currentState!.validate()) {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
      });

      final User auditorToSave = User(
        id: widget.auditor?.id,
        username: _usernameController.text,
        email: _emailController.text,
        userType: 'auditor', // Auditors are always 'auditor' type
        firstName: _firstNameController.text.isEmpty ? null : _firstNameController.text,
        lastName: _lastNameController.text.isEmpty ? null : _lastNameController.text,
        phoneNumber: _phoneNumberController.text.isEmpty ? null : _phoneNumberController.text,
      );

      try {
        if (widget.auditor == null) {
          // Create new auditor
          await _apiService.createAuditor(auditorToSave, _passwordController.text);
          if (mounted) {
            CustomDialogs.showFlushbar(
              context,
              'Success', // Title
              'စစ်ဆေးသူအကောင့်အသစ် ဖန်တီးပြီးပါပြီ။', // Message
              MessageType.success, // Type
              onDismissed: () {
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
            );
          }
        } else {
          // Update existing auditor
          await _apiService.updateAuditor(auditorToSave, password: _passwordController.text.isEmpty ? null : _passwordController.text);
          if (mounted) {
            CustomDialogs.showFlushbar(
              context,
              'Success', // Title
              'စစ်ဆေးသူအကောင့်ကို ပြင်ဆင်ပြီးပါပြီ။', // Message
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
        title: Text(widget.auditor == null ? 'စစ်ဆေးသူအသစ် ဖန်တီးမည်' : 'စစ်ဆေးသူ ပြင်ဆင်မည်'),
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
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'အသုံးပြုသူအမည်',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'အသုံးပြုသူအမည် ဖြည့်သွင်းပါ။';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'အီးမေးလ်',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'အီးမေးလ် ဖြည့်သွင်းပါ။';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'မှန်ကန်သော အီးမေးလ် လိပ်စာ ဖြည့်သွင်းပါ။';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: 'အမည် (ရှေ့ပိုင်း)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: 'အမည် (နောက်ပိုင်း)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _phoneNumberController,
                decoration: InputDecoration(
                  labelText: 'ဖုန်းနံပါတ်',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  labelText: widget.auditor == null ? 'လျှို့ဝှက်နံပါတ်' : 'လျှို့ဝှက်နံပါတ် (ပြောင်းလဲလိုလျှင်)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (widget.auditor == null && (value == null || value.isEmpty)) {
                    return 'လျှို့ဝှက်နံပါတ် ဖြည့်သွင်းပါ။';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _saveAuditor,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        elevation: 5,
                      ),
                      child: Text(
                        widget.auditor == null ? 'စစ်ဆေးသူ ဖန်တီးမည်' : 'စစ်ဆေးသူ ပြင်ဆင်မည်',
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
