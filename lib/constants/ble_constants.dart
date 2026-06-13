import 'package:flutter/material.dart';

class BleConstants {
  // ===== SERVICE & CHARACTERISTIC UUIDs =====
  /// Main UART custom service
  static const String serviceUuid = "87011111-ffcc-2222-0000-000000008888";

  /// App → Device (write commands)
  static const String rxCharUuid = "000092a4-0000-1000-8000-00805f9b34fb";

  /// Device → App (receive responses via notification)
  static const String txCharUuid = "000092a5-0000-1000-8000-00805f9b34fb";

  /// Advertised UUID for scanning filter
  static const String advertiseUuid = "00005500-d102-11e1-9b23-00025b00a5a5";

  // ===== DEVICE NAMES =====
  static const List<String> deviceNames = [
    "WANNAONE Light Stick",
    "WANNAONE OTA",
    "ISCheerBong",
  ];

  // ===== RSSI =====
  static const int minRssi = -80;

  // ===== TIMEOUTS =====
  static const Duration scanTimeout = Duration(seconds: 10);
  static const Duration connectionTimeout = Duration(seconds: 15);
  static const Duration commandDelay = Duration(milliseconds: 300);
  static const int maxRetryCount = 3;
}

/// Predefined colors extracted from the original APK
class LightstickColor {
  final int id;
  final String name;
  final Color color;
  final IconData? icon;

  const LightstickColor({
    required this.id,
    required this.name,
    required this.color,
    this.icon,
  });

  /// 4 known colors from original code
  static const List<LightstickColor> knownColors = [
    LightstickColor(id: 1, name: 'Đỏ', color: Color(0xFFFF0000)),
    LightstickColor(id: 3, name: 'Vàng', color: Color(0xFFFFFF00)),
    LightstickColor(id: 10, name: 'Xanh lá', color: Color(0xFF00FF00)),
    LightstickColor(id: 20, name: 'Xanh dương', color: Color(0xFF0000FF)),
  ];

  /// Extra color IDs to experiment with
  static const List<LightstickColor> experimentalColors = [
    LightstickColor(id: 0, name: 'ID 0', color: Color(0xFF808080)),
    LightstickColor(id: 2, name: 'ID 2', color: Color(0xFFFF8800)),
    LightstickColor(id: 4, name: 'ID 4', color: Color(0xFFFF00FF)),
    LightstickColor(id: 5, name: 'ID 5', color: Color(0xFF00FFFF)),
    LightstickColor(id: 6, name: 'ID 6', color: Color(0xFFFF44AA)),
    LightstickColor(id: 7, name: 'ID 7', color: Color(0xFFAA44FF)),
    LightstickColor(id: 8, name: 'ID 8', color: Color(0xFF44FFAA)),
    LightstickColor(id: 9, name: 'ID 9', color: Color(0xFFAAAA00)),
    LightstickColor(id: 15, name: 'ID 15', color: Color(0xFFFF6600)),
    LightstickColor(id: 25, name: 'ID 25', color: Color(0xFF6600FF)),
    LightstickColor(id: 30, name: 'ID 30', color: Color(0xFF00FF66)),
  ];
}
