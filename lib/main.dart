import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/ble_service.dart';
import 'screens/scan_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BleService()),
      ],
      child: const LightstickApp(),
    ),
  );
}

class LightstickApp extends StatelessWidget {
  const LightstickApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Light Stick Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E21),
        primaryColor: const Color(0xFF6C5CE7),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C5CE7),
          secondary: Color(0xFFFDAA5E),
          surface: Color(0xFF1A1F3D),
        ),
        useMaterial3: true,
      ),
      home: Consumer<BleService>(
        builder: (context, bleService, child) {
          return ScanScreen(bleService: bleService);
        },
      ),
    );
  }
}
