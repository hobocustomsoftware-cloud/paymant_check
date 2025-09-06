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
  final _current = TextEditingController();
  final _new1 = TextEditingController();
  final _new2 = TextEditingController();

  bool _submitting = false;
  bool _showCurrent = false;
  bool _showNew1 = false;
  bool _showNew2 = false;

  @override
  void dispose() {
    _current.dispose();
    _new1.dispose();
    _new2.dispose();
    super.dispose();
  }

  String? _pwRule(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Required';
    if (s.length < 8) return 'At least 8 characters';
    return null;
  }

  InputDecoration _dec(
    String label, {
    VoidCallback? onToggle,
    bool shown = false,
  }) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      suffixIcon: onToggle == null
          ? null
          : IconButton(
              onPressed: onToggle,
              icon: Icon(shown ? Icons.visibility_off : Icons.visibility),
            ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      // ❗ Map correctly: current → current_password, new → new_password
      await ApiService().changePasswordDjoser(
        currentPassword: _current.text.trim(),
        newPassword: _new1.text.trim(),
      );

      if (!mounted) return;
      CustomDialogs.showFlushbar(
        context,
        'Success',
        'Password changed',
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

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>(); // keep for future use if needed

    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // 1) Current password
                TextFormField(
                  controller: _current,
                  obscureText: !_showCurrent,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  keyboardType: TextInputType.visiblePassword,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.next,
                  decoration: _dec(
                    'Current password',
                    onToggle: () =>
                        setState(() => _showCurrent = !_showCurrent),
                    shown: _showCurrent,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // 2) New password
                TextFormField(
                  controller: _new1,
                  obscureText: !_showNew1,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  keyboardType: TextInputType.visiblePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  decoration: _dec(
                    'New password',
                    onToggle: () => setState(() => _showNew1 = !_showNew1),
                    shown: _showNew1,
                  ),
                  validator: _pwRule,
                ),
                const SizedBox(height: 12),

                // 3) Confirm new password
                TextFormField(
                  controller: _new2,
                  obscureText: !_showNew2,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  keyboardType: TextInputType.visiblePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (!_submitting) _submit();
                  },
                  decoration: _dec(
                    'Confirm new password',
                    onToggle: () => setState(() => _showNew2 = !_showNew2),
                    shown: _showNew2,
                  ),
                  validator: (v) {
                    final r = _pwRule(v);
                    if (r != null) return r;
                    if (v!.trim() != _new1.text.trim())
                      return 'Passwords do not match';
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
                        : const Text('Change'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
