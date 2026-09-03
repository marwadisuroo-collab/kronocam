import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'provider/theme_provider.dart';
import 'screens/home_screen.dart';
import 'services/ad_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Don't block app startup on ad init — it loads in the background.
  AdService.instance.initialize();
  runApp(const KronoCamApp());
}

class KronoCamApp extends StatelessWidget {
  const KronoCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: 'KronoCam',
            debugShowCheckedModeBanner: false,
            themeMode: theme.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(
              brightness: Brightness.light,
              scaffoldBackgroundColor: const Color(0xFFF3F4F6),
              colorScheme: ColorScheme.fromSeed(
                seedColor: ThemeProvider.accent,
                brightness: Brightness.light,
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF0E0E10),
              colorScheme: ColorScheme.fromSeed(
                seedColor: ThemeProvider.accent,
                brightness: Brightness.dark,
              ),
            ),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
