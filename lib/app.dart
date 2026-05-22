import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';

class MarkdownViewerApp extends StatefulWidget {
  const MarkdownViewerApp({super.key});

  @override
  State<MarkdownViewerApp> createState() => _MarkdownViewerAppState();
}

class _MarkdownViewerAppState extends State<MarkdownViewerApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Markdown Viewer',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: HomeScreen(
        themeMode: _themeMode,
        onToggleTheme: toggleTheme,
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4A6CF7),
        brightness: Brightness.light,
        surface: const Color(0xFFF7F7F5),
        onSurface: const Color(0xFF1A1A2E),
      ),
      scaffoldBackgroundColor: const Color(0xFFF7F7F5),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4A6CF7),
        brightness: Brightness.dark,
        surface: const Color(0xFF111118),
        onSurface: const Color(0xFFE8E8F0),
      ),
      scaffoldBackgroundColor: const Color(0xFF111118),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    );
  }
}
