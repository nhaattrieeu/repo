import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'services/ble_service.dart';
import 'screens/scan_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      title: 'Make Color',
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
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _deviceUuid;
  bool _showRegistration = false;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<String> _getOrCreateUuid() async {
    final prefs = await SharedPreferences.getInstance();
    String? uuid = prefs.getString('device_uuid');
    if (uuid == null) {
      uuid = const Uuid().v4();
      await prefs.setString('device_uuid', uuid);
    }
    return uuid;
  }

  Future<void> _checkStatus() async {
    try {
      // Get device UUID
      final deviceUuid = await _getOrCreateUuid();

      // Check users list
      final usersResponse = await http.get(Uri.parse(
          'https://raw.githubusercontent.com/nhaattrieeu/temp_storage/refs/heads/main/users'));
      if (usersResponse.statusCode == 200) {
        final List<dynamic> users = jsonDecode(usersResponse.body);
        final usersList = users.map((e) => e.toString().trim()).toList();
        if (usersList.contains(deviceUuid)) {
          _navigateToApp();
          return;
        }
      }

      // UUID not found → show UUID screen
      if (mounted) {
        setState(() {
          _deviceUuid = deviceUuid;
          _showRegistration = true;
        });
      }
    } catch (e) {
      debugPrint('Check failed: $e');
      _exitApp();
    }
  }

  void _navigateToApp() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => Consumer<BleService>(
            builder: (context, bleService, child) {
              return ScanScreen(bleService: bleService);
            },
          ),
        ),
      );
    }
  }

  void _exitApp() {
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else {
      exit(0);
    }
  }

  void _copyUuid() {
    if (_deviceUuid != null) {
      Clipboard.setData(ClipboardData(text: _deviceUuid!));
      setState(() {
        _copied = true;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _copied = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showRegistration && _deviceUuid != null) {
      return _buildRegistrationScreen();
    }
    return const Scaffold(
      backgroundColor: Color(0xFF0A0E21),
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Color(0xFF6C5CE7)),
        ),
      ),
    );
  }

  Widget _buildRegistrationScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // UUID display
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFF1A1F3D),
                    border: Border.all(color: const Color(0xFF2D3154)),
                  ),
                  child: SelectableText(
                    _deviceUuid!,
                    style: const TextStyle(
                      color: Color(0xFF00B894),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),

                // Copy button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _copyUuid,
                    icon: Icon(
                      _copied ? Icons.check : Icons.copy,
                      color: Colors.white,
                    ),
                    label: Text(
                      _copied ? 'Đã sao chép!' : 'Sao chép',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _copied
                          ? const Color(0xFF00B894)
                          : const Color(0xFF6C5CE7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
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

