import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/scan_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/splash_screen.dart';
import 'utils/app_theme.dart';

void main() {
  runApp(const FastDupeFinderApp());
}

class FastDupeFinderApp extends StatelessWidget {
  const FastDupeFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ScanProvider()),
        ChangeNotifierProvider(create: (context) => SettingsProvider()..initialize()),
      ],
      child: MaterialApp(
        title: 'Fast Duplicate Finder',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
