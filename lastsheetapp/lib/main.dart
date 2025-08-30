import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:another_flushbar/flushbar.dart';

import 'providers/auth_provider.dart';
import 'providers/transaction_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/owner_dashboard.dart';
import 'screens/auditor_dashboard.dart';
import 'models/user.dart'; // Make sure this path is correct

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // final _storage = FlutterSecureStorage(); // This is not used here, can be removed if not needed elsewhere

  @override
  void initState() {
    super.initState();
    // WidgetsBinding.instance.addPostFrameCallback ကို အသုံးပြုပြီး
    // UI frame ဆွဲပြီးမှ _checkLoginStatus() ကို ခေါ်ပါ။
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLoginStatus();
    });
  }

  Future<void> _checkLoginStatus() async {
    // listen: false ကို သုံးထားတာ မှန်ကန်ပါတယ်။
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.loadUserFromStorage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sheets App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Inter', // Assuming Inter font is available or default
      ),
      home: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          if (auth.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (auth.isAuthenticated) {
            if (auth.currentUser?.userType == 'owner') {
              return OwnerDashboardScreen();
            } else if (auth.currentUser?.userType == 'auditor') {
              return AuditorDashboardScreen();
            }
            return LoginScreen(); // Fallback if userType is not recognized
          } else {
            return LoginScreen();
          }
        },
      ),
      routes: {
        '/login': (context) => LoginScreen(),
        '/owner_dashboard': (context) => OwnerDashboardScreen(),
        '/auditor_dashboard': (context) => AuditorDashboardScreen(),
      },
    );
  }
}
