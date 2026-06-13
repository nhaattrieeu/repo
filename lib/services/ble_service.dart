import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../constants/ble_constants.dart';
import '../protocol/lightstick_protocol.dart';
import '../models/lightstick_color.dart';

/// Connection state enum
enum LightstickConnectionState {
  disconnected,
  scanning,
  connecting,
  discoveringServices,
  connected,
  error,
}

/// BLE service that manages scanning, connecting, and communicating
/// with the WANNAONE Light Stick via GATT.
class BleService extends ChangeNotifier {
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _rxCharacteristic; // App → Device
  BluetoothCharacteristic? _txCharacteristic; // Device → App

  LightstickConnectionState _connectionState =
      LightstickConnectionState.disconnected;
  String? _firmwareVersion;
  int? _batteryLevel;
  int _currentColorId = -1;
  bool _ledOn = false;
  String _statusMessage = 'Sẵn sàng quét';
  String? _lastError;

  final List<ScanResult> _scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _notificationSubscription;

  // Effects State
  bool _isAutoRandom = false;
  bool _isSequentialCycle = false;
  int _sequentialIndex = 0;
  int _blinkSpeedMs = 0; // 0 = solid, 500 = slow, 150 = fast
  Timer? _effectTimer;
  bool _blinkStateOn = false;

  // ==================== GETTERS ====================

  LightstickConnectionState get connectionState => _connectionState;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  String? get firmwareVersion => _firmwareVersion;
  int? get batteryLevel => _batteryLevel;
  int get currentColorId => _currentColorId;
  bool get isLedOn => _ledOn;
  bool get isAutoRandom => _isAutoRandom;
  bool get isSequentialCycle => _isSequentialCycle;
  int get blinkSpeedMs => _blinkSpeedMs;
  String get statusMessage => _statusMessage;
  String? get lastError => _lastError;
  List<ScanResult> get scanResults => List.unmodifiable(_scanResults);
  bool get isConnected =>
      _connectionState == LightstickConnectionState.connected;

  // ==================== SCAN ====================

  Future<void> startScan() async {
    _scanResults.clear();
    _lastError = null;
    _connectionState = LightstickConnectionState.scanning;
    _statusMessage = 'Đang quét thiết bị BLE...';
    notifyListeners();

    try {
      // Check Bluetooth adapter state
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _lastError = 'Bluetooth chưa bật. Hãy bật Bluetooth.';
        _connectionState = LightstickConnectionState.error;
        _statusMessage = _lastError!;
        notifyListeners();
        return;
      }

      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
        for (final r in results) {
          // Filter by device name
          final name = r.device.platformName;
          if (name.isEmpty) continue;

          final isMatch = BleConstants.deviceNames.any(
            (n) => name.contains(n),
          );
          if (!isMatch) continue;

          // Filter by RSSI
          if (r.rssi < BleConstants.minRssi) continue;

          // Avoid duplicates
          final exists = _scanResults.any(
            (sr) => sr.device.remoteId == r.device.remoteId,
          );
          if (!exists) {
            _scanResults.add(r);
            _statusMessage =
                'Tìm thấy ${_scanResults.length} thiết bị';
            notifyListeners();
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: BleConstants.scanTimeout,
        androidUsesFineLocation: true,
      );

      // After scan completes
      if (_scanResults.isEmpty) {
        _statusMessage = 'Không tìm thấy thiết bị nào';
      } else {
        _statusMessage =
            'Tìm thấy ${_scanResults.length} thiết bị';
      }
      _connectionState = LightstickConnectionState.disconnected;
      notifyListeners();
    } catch (e) {
      _lastError = 'Lỗi quét: $e';
      _connectionState = LightstickConnectionState.error;
      _statusMessage = _lastError!;
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    _scanSubscription = null;
    if (_connectionState == LightstickConnectionState.scanning) {
      _connectionState = LightstickConnectionState.disconnected;
      notifyListeners();
    }
  }

  // ==================== CONNECT ====================

  Future<bool> connectToDevice(BluetoothDevice device) async {
    _lastError = null;
    _connectionState = LightstickConnectionState.connecting;
    _statusMessage = 'Đang kết nối ${device.platformName}...';
    notifyListeners();

    await stopScan();

    try {
      // Listen for connection state changes
      _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          if (_connectionState == LightstickConnectionState.connected) {
            _handleDisconnect();
          }
        }
      });

      // Connect with timeout
      await device.connect(
        license: License.nonprofit,
        timeout: BleConstants.connectionTimeout,
        autoConnect: false,
      );

      _connectedDevice = device;
      _connectionState = LightstickConnectionState.discoveringServices;
      _statusMessage = 'Đang tìm dịch vụ BLE...';
      notifyListeners();

      // Delay for Android GATT to settle
      if (!kIsWeb && Platform.isAndroid) {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Discover services
      final services = await device.discoverServices();

      // Find our UART service
      BluetoothService? uartService;
      for (final s in services) {
        if (s.uuid.toString().toLowerCase() ==
            BleConstants.serviceUuid.toLowerCase()) {
          uartService = s;
          break;
        }
      }

      if (uartService == null) {
        _lastError = 'Không tìm thấy UART service. Thiết bị không tương thích.';
        _connectionState = LightstickConnectionState.error;
        _statusMessage = _lastError!;
        notifyListeners();
        
        debugPrint('--- DISCOVERED SERVICES ---');
        for (final s in services) {
          debugPrint('Service: ${s.uuid}');
        }
        
        await device.disconnect();
        return false;
      }

      // Find RX and TX characteristics
      for (final c in uartService.characteristics) {
        final uuid = c.uuid.toString().toLowerCase();
        debugPrint('Found characteristic: $uuid'); // log for debugging
        if (uuid.contains('92a4')) {
          _rxCharacteristic = c;
        } else if (uuid.contains('92a5')) {
          _txCharacteristic = c;
        }
      }

      if (_rxCharacteristic == null) {
        _lastError = 'Không tìm thấy Write characteristic (92a4).';
        _connectionState = LightstickConnectionState.error;
        _statusMessage = _lastError!;
        notifyListeners();
        
        debugPrint('--- DISCOVERED CHARACTERISTICS FOR UART ---');
        for (final c in uartService.characteristics) {
          debugPrint('Char: ${c.uuid} - props: ${c.properties}');
        }
        
        await device.disconnect();
        return false;
      }

      // Try to enable TX notification (optional - like the web version)
      if (_txCharacteristic != null) {
        try {
          await _txCharacteristic!.setNotifyValue(true);
          _notificationSubscription?.cancel();
          _notificationSubscription =
              _txCharacteristic!.onValueReceived.listen(_handleNotification);
          debugPrint('TX notification enabled successfully');
        } catch (e) {
          debugPrint('TX notification skipped (will retry after auth): $e');
          // Not fatal - we'll retry after sending auth command
        }
      }

      _connectionState = LightstickConnectionState.connected;
      _statusMessage =
          'Đã kết nối ${device.platformName}';
      notifyListeners();

      // Send auth/unlock command first (like pressing "MỞ KHÓA BẢO MẬT" in web version)
      await Future.delayed(BleConstants.commandDelay);
      await sendAuth();

      // Retry TX notification after auth (device may allow it now)
      if (_txCharacteristic != null && _notificationSubscription == null) {
        try {
          await Future.delayed(const Duration(milliseconds: 300));
          await _txCharacteristic!.setNotifyValue(true);
          _notificationSubscription =
              _txCharacteristic!.onValueReceived.listen(_handleNotification);
          debugPrint('TX notification enabled after auth');
        } catch (e) {
          debugPrint('TX notification still unavailable after auth: $e');
        }
      }

      // Read firmware version
      await Future.delayed(BleConstants.commandDelay);
      await requestFirmwareVersion();

      return true;
    } catch (e) {
      _lastError = 'Lỗi kết nối: $e';
      _connectionState = LightstickConnectionState.error;
      _statusMessage = _lastError!;
      notifyListeners();
      return false;
    }
  }

  // ==================== DISCONNECT ====================

  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      // Turn LED off before disconnect
      if (_ledOn) {
        await sendLedOff();
        await Future.delayed(BleConstants.commandDelay);
      }
      await _connectedDevice!.disconnect();
    }
    _handleDisconnect();
  }

  void _handleDisconnect() {
    _notificationSubscription?.cancel();
    _connectionSubscription?.cancel();
    _effectTimer?.cancel();
    _connectedDevice = null;
    _rxCharacteristic = null;
    _txCharacteristic = null;
    _firmwareVersion = null;
    _batteryLevel = null;
    _ledOn = false;
    _currentColorId = -1;
    _isAutoRandom = false;
    _blinkSpeedMs = 0;
    _connectionState = LightstickConnectionState.disconnected;
    _statusMessage = 'Đã ngắt kết nối';
    notifyListeners();
  }

  // ==================== NOTIFICATION HANDLER ====================

  void _handleNotification(List<int> data) {
    debugPrint('BLE RX: ${LightstickProtocol.bytesToHex(data)}');

    final response = LightstickProtocol.parseResponse(data);
    if (response == null) return;

    switch (response.type) {
      case ResponseType.firmwareVersion:
        _firmwareVersion = response.data['version'] as String;
        _statusMessage =
            'Firmware: $_firmwareVersion';
        break;
      case ResponseType.battery:
        _batteryLevel = response.data['level'] as int;
        _statusMessage = 'Pin: $_batteryLevel%';
        break;
      case ResponseType.extendedInfo:
        final fields = response.data['fields'] as List<int>;
        debugPrint('Extended info: $fields');
        break;
      case ResponseType.pinResponse:
        debugPrint('PIN response: ${response.data}');
        break;
      case ResponseType.unknown:
        debugPrint('Unknown response: ${response.data}');
        break;
    }
    notifyListeners();
  }

  // ==================== COMMANDS ====================

  Future<void> _sendCommand(List<int> data) async {
    if (_rxCharacteristic == null || !isConnected) {
      _lastError = 'Chưa kết nối thiết bị';
      notifyListeners();
      return;
    }
    debugPrint('BLE TX: ${LightstickProtocol.bytesToHex(data)}');
    await _rxCharacteristic!.write(data, withoutResponse: false);
  }

  /// Send auth/unlock command (same as "MỞ KHÓA BẢO MẬT" in web version)
  /// This must be sent first after connection before other commands work.
  Future<void> sendAuth() async {
    await _sendCommand(LightstickProtocol.registerPin());
    _statusMessage = 'Đã gửi lệnh mở khóa';
    notifyListeners();
  }

  /// Turn LED on with a specific color ID
  Future<void> sendLedOn(int colorId, {bool isInternal = false}) async {
    await _sendCommand(LightstickProtocol.ledOn(colorId));
    if (!isInternal) {
      _currentColorId = colorId;
      _ledOn = true;
      _statusMessage = 'LED bật - Color ID: $colorId';
      notifyListeners();
    }
  }

  /// Turn LED off
  Future<void> sendLedOff({bool isInternal = false}) async {
    await _sendCommand(LightstickProtocol.ledOff());
    if (!isInternal) {
      _ledOn = false;
      _currentColorId = -1;
      _statusMessage = 'LED tắt';
      notifyListeners();
    }
  }

  // ==================== EFFECTS (RANDOM & BLINK) ====================

  void setStaticColor(int colorId) {
    _isAutoRandom = false;
    _currentColorId = colorId;
    _ledOn = true;
    _restartEffectTimer();
    notifyListeners();
  }

  void setAutoRandom(bool isAuto) {
    _isAutoRandom = isAuto;
    _isSequentialCycle = false;
    if (isAuto) _ledOn = true;
    _restartEffectTimer();
    notifyListeners();
  }

  void setSequentialCycle(bool isOn) {
    _isSequentialCycle = isOn;
    _isAutoRandom = false;
    _sequentialIndex = 0;
    if (isOn) _ledOn = true;
    _restartEffectTimer();
    notifyListeners();
  }

  void setBlinkSpeed(int speedMs) {
    _blinkSpeedMs = speedMs;
    _restartEffectTimer();
    notifyListeners();
  }
  
  void turnOffAll() {
    _effectTimer?.cancel();
    _isAutoRandom = false;
    _isSequentialCycle = false;
    _blinkSpeedMs = 0;
    sendLedOff();
  }

  void _restartEffectTimer() {
    _effectTimer?.cancel();
    _effectTimer = null;
    
    // Solid color (not blinking, not random, not sequential)
    if (_blinkSpeedMs == 0 && !_isAutoRandom && !_isSequentialCycle) {
      if (_currentColorId >= 0) {
        sendLedOn(_currentColorId);
      }
      return;
    }
    
    // Blinking or Random
    int interval = _blinkSpeedMs > 0 ? _blinkSpeedMs : 1000; 
    
    _blinkStateOn = true;
    _effectTimer = Timer.periodic(Duration(milliseconds: interval), (timer) {
      _tickEffect();
    });
    
    _tickEffect();
  }

  void _tickEffect() {
    if (_isSequentialCycle) {
      final colors = wannaOneColors.where((c) => c.id >= 0x01 && c.id <= 0x1B).toList();
      if (colors.isEmpty) return;
      if (_blinkSpeedMs == 0) {
        _sequentialIndex = _sequentialIndex % colors.length;
        _currentColorId = colors[_sequentialIndex].id;
        sendLedOn(_currentColorId, isInternal: true);
        _statusMessage = 'Chạy lần lượt - ${colors[_sequentialIndex].name} (${_sequentialIndex + 1}/${colors.length})';
        _sequentialIndex++;
        notifyListeners();
      } else {
        if (_blinkStateOn) {
           _sequentialIndex = _sequentialIndex % colors.length;
           _currentColorId = colors[_sequentialIndex].id;
           sendLedOn(_currentColorId, isInternal: true);
           _statusMessage = 'Chạy lần lượt - ${colors[_sequentialIndex].name} (${_sequentialIndex + 1}/${colors.length})';
           _sequentialIndex++;
           notifyListeners();
        } else {
           sendLedOff(isInternal: true);
        }
        _blinkStateOn = !_blinkStateOn;
      }
    } else if (_isAutoRandom) {
      if (_blinkSpeedMs == 0) {
        _currentColorId = wannaOneColors[Random().nextInt(wannaOneColors.length)].id;
        sendLedOn(_currentColorId, isInternal: true);
        _statusMessage = 'Auto Random - Color ID: $_currentColorId';
        notifyListeners();
      } else {
        if (_blinkStateOn) {
           _currentColorId = wannaOneColors[Random().nextInt(wannaOneColors.length)].id;
           sendLedOn(_currentColorId, isInternal: true);
        } else {
           sendLedOff(isInternal: true);
        }
        _blinkStateOn = !_blinkStateOn;
      }
    } else {
      // Blinking static color
      if (_blinkStateOn) {
         sendLedOn(_currentColorId, isInternal: true);
      } else {
         sendLedOff(isInternal: true);
      }
      _blinkStateOn = !_blinkStateOn;
    }
  }

  // ==================== OTHER COMMANDS ====================

  /// Request battery level
  Future<void> requestBattery() async {
    await _sendCommand(LightstickProtocol.getBattery());
  }

  /// Request firmware version
  Future<void> requestFirmwareVersion() async {
    await _sendCommand(LightstickProtocol.getFirmwareVersion());
  }

  /// Reset device
  Future<void> resetDevice() async {
    await _sendCommand(LightstickProtocol.resetDevice());
    _statusMessage = 'Đã gửi lệnh reset';
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _notificationSubscription?.cancel();
    _effectTimer?.cancel();
    super.dispose();
  }
}
