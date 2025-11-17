// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/expense_dashboard.dart';
import 'screens/wedding_calls_page.dart';
import 'screens/wedding_theme.dart';
import 'screens/wedding_report_page.dart';
import 'firebase_options.dart'; // ✅ auto-generated file (below added)

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ initialize Firebase for all platforms (including Web)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: weddingBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: weddingSurface,
          elevation: 2,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (ctx) => const ExpenseDashboardPage(),
        '/wedding': (ctx) => const WeddingCallsPage(),
        '/wedding-report': (ctx) => const WeddingReportPage(),
      },
    );
  }
}
