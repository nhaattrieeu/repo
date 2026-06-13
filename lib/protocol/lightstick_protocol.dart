import 'dart:typed_data';

/// BLE command protocol reverse-engineered from the WANNAONE Light Stick APK.
/// All commands follow the frame format: FF [CMD] [LEN] [DATA...] FF
class LightstickProtocol {
  static const int frameStart = 0xFF;
  static const int frameEnd = 0xFF;

  // ===================== LED COMMANDS =====================

  /// Turn LED on with a specific color ID.
  /// Original: `requestA5` in ConnectActivity.java
  /// Format: FF A5 02 [colorID] 02 FF
  static Uint8List ledOn(int colorId) {
    return Uint8List.fromList([
      frameStart,
      0xA5,
      0x02,
      colorId & 0xFF,
      0x02,
      frameEnd,
    ]);
  }

  /// Turn LED off.
  /// Original: `requestLedOff` in ConnectActivity.java
  /// Format: FF A2 00 FF
  static Uint8List ledOff() {
    return Uint8List.fromList([frameStart, 0xA2, 0x00, frameEnd]);
  }

  // ===================== DEVICE INFO =====================

  /// Request battery level.
  /// Original: `doBattery` in MainActivity.java
  /// Format: FF B2 00 FF
  static Uint8List getBattery() {
    return Uint8List.fromList([frameStart, 0xB2, 0x00, frameEnd]);
  }

  /// Request firmware version.
  /// Original: `getFirmwareVersion` in MainActivity.java
  /// Format: FF B4 00 FF
  static Uint8List getFirmwareVersion() {
    return Uint8List.fromList([frameStart, 0xB4, 0x00, frameEnd]);
  }

  /// Request extended info (firmware + PIN info).
  /// Original: `requestB7` in ConnectActivity.java
  /// Format: FF B7 00 FF
  static Uint8List getExtendedInfo() {
    return Uint8List.fromList([frameStart, 0xB7, 0x00, frameEnd]);
  }

  /// Reset the device.
  /// Original: `doCheerbongReset` in MainActivity.java
  /// Format: FF B3 00 FF
  static Uint8List resetDevice() {
    return Uint8List.fromList([frameStart, 0xB3, 0x00, frameEnd]);
  }

  // ===================== PIN / AUTH =====================

  /// Register new PIN.
  /// Original: `requestADReg` in ConnectActivity.java
  /// Format: FF AD 03 01 00 00 FF
  static Uint8List registerPin() {
    return Uint8List.fromList([
      frameStart, 0xAD, 0x03, 0x01, 0x00, 0x00, frameEnd,
    ]);
  }

  /// Confirm PIN.
  /// Original: `requestADConfirm` in ConnectActivity.java
  /// Format: FF AD 03 02 [pin1] [pin2] FF
  static Uint8List confirmPin(int pin1, int pin2) {
    return Uint8List.fromList([
      frameStart, 0xAD, 0x03, 0x02,
      pin1 & 0xFF, pin2 & 0xFF,
      frameEnd,
    ]);
  }

  // ===================== RESPONSE PARSER =====================

  /// Parse raw BLE notification data into a structured response.
  static BleResponse? parseResponse(List<int> rawData) {
    if (rawData.length < 4) return null;

    final hexParts = rawData
        .map((b) => (b & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase())
        .toList();
    final cmd = hexParts[1];

    switch (cmd) {
      case 'B4': // Firmware version
        if (rawData.length >= 5) {
          final major = int.parse(hexParts[3][1], radix: 16);
          final minor = int.parse(hexParts[4][1], radix: 16);
          return BleResponse(
            type: ResponseType.firmwareVersion,
            data: {'version': '$major.$minor', 'raw': major * 10 + minor},
          );
        }
      case 'B2': // Battery
        if (rawData.length >= 4) {
          final battery = int.parse(hexParts[3], radix: 16);
          return BleResponse(
            type: ResponseType.battery,
            data: {'level': battery},
          );
        }
      case 'B7': // Extended info
        if (rawData.length >= 12) {
          final fields = <int>[];
          for (int i = 3; i < 12 && i < rawData.length - 1; i++) {
            fields.add(int.parse(hexParts[i], radix: 16));
          }
          return BleResponse(
            type: ResponseType.extendedInfo,
            data: {
              'fields': fields,
              'pin1': fields.length > 7 ? fields[7] : 0,
              'pin2': fields.length > 8 ? fields[8] : 0,
            },
          );
        }
      case 'AD': // PIN response
        if (rawData.length >= 7) {
          return BleResponse(
            type: ResponseType.pinResponse,
            data: {
              'result': int.parse(hexParts[3], radix: 16),
              'step': int.parse(hexParts[4], radix: 16),
              'pin1': int.parse(hexParts[5], radix: 16),
              'pin2': int.parse(hexParts[6], radix: 16),
            },
          );
        }
    }

    // Return raw hex for unknown commands
    return BleResponse(
      type: ResponseType.unknown,
      data: {'cmd': cmd, 'hex': hexParts.join(' ')},
    );
  }

  /// Helper: format bytes as hex string for debugging
  static String bytesToHex(List<int> bytes) {
    return bytes
        .map((b) => (b & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }
}

enum ResponseType {
  firmwareVersion,
  battery,
  extendedInfo,
  pinResponse,
  unknown,
}

class BleResponse {
  final ResponseType type;
  final Map<String, dynamic> data;

  const BleResponse({required this.type, required this.data});

  @override
  String toString() => 'BleResponse($type, $data)';
}
