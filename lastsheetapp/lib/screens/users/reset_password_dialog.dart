import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/custom_dialogs.dart';

class ResetPasswordDialog extends StatefulWidget {
  final int userId;
  final String displayName; // show who we're resetting
  const ResetPasswordDialog({
    super.key,
    required this.userId,
    required this.displayName,
  });

  @override
  State<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  bool _show1 = false, _show2 = false, _submitting = false;

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  String? _pwRule(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'မဖြစ်မနေ ဖြည့်ရန်လိုအပ်';
    if (s.length < 8) return 'အနည်းဆုံး ၈ လုံး';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_p1.text.trim() != _p2.text.trim()) {
      CustomDialogs.showFlushbar(
        context,
        'Error',
        'တူညီရပါမည်',
        MessageType.error,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiService().setUserPassword(
        userId: widget.userId,
        newPassword: _p1.text.trim(),
        newPassword2: _p2.text.trim(),
      );
      if (!mounted) return;
      CustomDialogs.showFlushbar(
        context,
        'Success',
        'အသုံးပြုသူ ${widget.displayName} ၏ စကားဝှက် ပြောင်းပြီးပါပြီ',
        MessageType.success,
        onDismissed: () {
          if (!mounted) return;
          Navigator.of(context).pop(true); // return true to caller
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
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(10));
    return AlertDialog(
      title: Text('Reset Password – ${widget.displayName}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _p1,
              obscureText: !_show1,
              decoration: InputDecoration(
                labelText: 'စကားဝှက် အသစ်',
                border: border,
                suffixIcon: IconButton(
                  icon: Icon(_show1 ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _show1 = !_show1),
                ),
              ),
              validator: _pwRule,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _p2,
              obscureText: !_show2,
              decoration: InputDecoration(
                labelText: 'စကားဝှက် အသစ် ထပ်ရေး',
                border: border,
                suffixIcon: IconButton(
                  icon: Icon(_show2 ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _show2 = !_show2),
                ),
              ),
              validator: _pwRule,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('ပယ်ဖျက်'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('သတ်မှတ်'),
        ),
      ],
    );
  }
}
