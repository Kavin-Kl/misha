import 'package:flutter/material.dart';
import 'home.dart'; // Correct import for home.dart
import 'display.dart'; // Correct import for display.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Misha',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        // DisplayScreen retrieves arguments via ModalRoute, so no parameters needed here
        '/display': (context) => const DisplayScreen(),
      },
    );
  }
}