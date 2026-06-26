import 'package:flutter/material.dart';
import 'screens/vendors_screen.dart';

void main() {
  runApp(const TechNotesApp());
}

class TechNotesApp extends StatelessWidget {
  const TechNotesApp({super.key});

    @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SysAdmin Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFA726), // Светло-оранжевый
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFFE65100), // Темно-оранжевый текст
          elevation: 1,
        ),
        scaffoldBackgroundColor: const Color(0xFFFFFBF5), // Очень светлый кремово-оранжевый фон
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFFFA726),
          foregroundColor: Colors.white,
        ),
      ),
      home: const VendorsScreen(),
    );
  }
}