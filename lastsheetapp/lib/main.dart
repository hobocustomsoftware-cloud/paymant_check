import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/transaction_provider.dart'; // Ensure TransactionProvider is imported

// Screens
import 'screens/auditor_dashboard.dart';
import 'screens/auth/login_screen.dart';

import 'screens/owner_dashboard.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()), // Add TransactionProvider
        // Add other providers here if needed
      ],
      child: MaterialApp(
        title: 'Last Sheet App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', ''), // English
          Locale('my', ''), // Burmese
        ],
        home: Consumer<AuthProvider>(
          builder: (context, auth, child) {
            // Check if auth data is still loading (e.g., from SharedPreferences)
            if (auth.isLoading) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            } else if (auth.currentUser != null) { // Check if currentUser exists
              // User is authenticated, navigate to appropriate dashboard
              if (auth.currentUser!.userType == 'owner') {
                return const OwnerDashboardScreen();
              } else if (auth.currentUser!.userType == 'auditor') {
                return const AuditorDashboardScreen();
              } else {
                // Default to login if userType is unknown or not handled
                return LoginScreen();
              }
            } else {
              // User is not authenticated, show login screen
              return LoginScreen();
            }
          },
        ),
        routes: {
          '/login': (context) => LoginScreen(),
          '/owner_dashboard': (context) => const OwnerDashboardScreen(),
          '/auditor_dashboard': (context) => const AuditorDashboardScreen(),
        },
      ),
    );
  }
}
