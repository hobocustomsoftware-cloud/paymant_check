import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../utils/custom_dialogs.dart';
import '../../providers/auth_provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _old = TextEditingController();
  final _new1 = TextEditingController();
  final _new2 = TextEditingController();

  bool _submitting = false;
  bool _showOld = false;
  bool _showNew1 = false;
  bool _showNew2 = false;

  @override
  void dispose() {
    _old.dispose();
    _new1.dispose();
    _new2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final api = ApiService();
      final newToken = await api.changePassword(
        oldPassword: _old.text,
        newPassword: _new1.text,
        newPassword2: _new2.text,
      );

      // (optional) refresh auth provider user if needed
      final auth = context.read<AuthProvider>();
      // auth.currentUser is unchanged; token already rotated in ApiService

      if (!mounted) return;
      CustomDialogs.showFlushbar(
        context,
        'Success',
        'စကားဝှက် ပြောင်းပြီးပါပြီ (token ပြောင်းပြီး)',
        MessageType.success,
        onDismissed: () {
          if (!mounted) return;
          Navigator.of(context).pop();
        },
      );
    } catch (e) {
      if (!mounted) return;
      CustomDialogs.showFlushbar(context, 'Error', '$e', MessageType.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _pwRule(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'မဖြစ်မနေ ဖြည့်ရန်လိုအပ်ပါတယ်';
    if (s.length < 8) return 'အနည်းဆုံး ၈ လုံး';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('စကားဝှက် ပြောင်းမည်')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _old,
                obscureText: !_showOld,
                decoration: InputDecoration(
                  labelText: 'ဟောင်း စကားဝှက်',
                  border: inputBorder,
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _showOld = !_showOld),
                    icon: Icon(
                      _showOld ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'ဖြည့်ပါ' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _new1,
                obscureText: !_showNew1,
                decoration: InputDecoration(
                  labelText: 'စကားဝှက် အသစ်',
                  border: inputBorder,
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _showNew1 = !_showNew1),
                    icon: Icon(
                      _showNew1 ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
                validator: _pwRule,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _new2,
                obscureText: !_showNew2,
                decoration: InputDecoration(
                  labelText: 'စကားဝှက် အသစ် ထပ်ရေး',
                  border: inputBorder,
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _showNew2 = !_showNew2),
                    icon: Icon(
                      _showNew2 ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
                validator: (v) {
                  final r = _pwRule(v);
                  if (r != null) return r;
                  if (v!.trim() != _new1.text.trim()) return 'တူညီရပါမည်';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('ပြောင်းမည်'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
