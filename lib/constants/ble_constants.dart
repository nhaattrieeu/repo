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


