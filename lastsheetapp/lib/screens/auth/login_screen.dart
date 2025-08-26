import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/custom_dialogs.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _login() async {
    print('[_LoginScreenState] _login method entered.');

    if (_formKey.currentState!.validate()) {
      if (!mounted) {
        print('[_LoginScreenState] _login called but widget is not mounted (early exit).');
        return;
      }
      setState(() {
        _isLoading = true;
      });
      print('[_LoginScreenState] Login attempt started for user: ${_usernameController.text}');

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.login(
          _usernameController.text,
          _passwordController.text,
        );

        // Login successful.
        // Before navigating, ensure _isLoading is set to false if still mounted.
        if (mounted) { // Check mounted before setting state
          setState(() {
            _isLoading = false; // Reset loading state
          });
          print('[_LoginScreenState] isLoading set to false after successful login.');
        } else {
          print('[_LoginScreenState] Widget unmounted before isLoading could be set to false.');
          return; // Exit if unmounted
        }
        
        // Now navigate. This should be the last action on success.
        final currentUser = authProvider.currentUser;
        print('[_LoginScreenState] Login successful. Current User: ${currentUser?.username}, Type: ${currentUser?.userType}');

        if (currentUser?.userType == 'owner') {
          Navigator.of(context).pushReplacementNamed('/owner_dashboard');
          print('[_LoginScreenState] Navigating to Owner Dashboard');
        } else if (currentUser?.userType == 'auditor') {
          Navigator.of(context).pushReplacementNamed('/auditor_dashboard');
          print('[_LoginScreenState] Navigating to Auditor Dashboard');
        } else {
          print('[_LoginScreenState] User type not recognized or null. Staying on Login Screen.');
          CustomDialogs.showAlertDialog(context, 'Login Failed', 'အသုံးပြုသူ အမျိုးအစား မှန်ကန်မှုမရှိပါ။');
        }
      } catch (e) {
        // On error, reset _isLoading if mounted, then show dialog.
        if (mounted) { // Check mounted before setting state
          setState(() {
            _isLoading = false;
          });
          print('[_LoginScreenState] isLoading set to false after login error.');
        } else {
          print('[_LoginScreenState] Widget unmounted during login error handling, cannot reset isLoading.');
        }
        print('[_LoginScreenState] Login failed with error: $e');
        // Always show dialog if mounted, as it's a critical error feedback.
        if (mounted) {
          CustomDialogs.showAlertDialog(context, 'Login Failed', e.toString());
        }
      }
      // The finally block is now less critical for setState, as it's handled in try/catch.
      // Removed setState from finally to avoid calling on unmounted widget after navigation.
    } else {
      print('[_LoginScreenState] Form validation failed.');
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
    print('[_LoginScreenState] LoginScreen disposed.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text(
                  'Sheets App Login',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'အသုံးပြုသူအမည်',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'အသုံးပြုသူအမည် ဖြည့်သွင်းပါ။';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'လျှို့ဝှက်နံပါတ်',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'လျှို့ဝှက်နံပါတ် ဖြည့်သွင်းပါ။';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          elevation: 5,
                        ),
                        child: const Text(
                          'ဝင်မည်',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
