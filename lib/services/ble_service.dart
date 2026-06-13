import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../constants/ble_constants.dart';
import '../protocol/lightstick_protocol.dart';

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

  // ==================== GETTERS ====================

  LightstickConnectionState get connectionState => _connectionState;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  String? get firmwareVersion => _firmwareVersion;
  int? get batteryLevel => _batteryLevel;
  int get currentColorId => _currentColorId;
  bool get isLedOn => _ledOn;
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
        await device.disconnect();
        return false;
      }

      // Find RX and TX characteristics
      for (final c in uartService.characteristics) {
        final uuid = c.uuid.toString().toLowerCase();
        if (uuid == BleConstants.rxCharUuid.toLowerCase()) {
          _rxCharacteristic = c;
        } else if (uuid == BleConstants.txCharUuid.toLowerCase()) {
          _txCharacteristic = c;
        }
      }

      if (_rxCharacteristic == null || _txCharacteristic == null) {
        _lastError = 'Không tìm thấy RX/TX characteristics.';
        _connectionState = LightstickConnectionState.error;
        _statusMessage = _lastError!;
        notifyListeners();
        await device.disconnect();
        return false;
      }

      // Enable TX notification (CRITICAL - must be done BEFORE sending commands)
      await _txCharacteristic!.setNotifyValue(true);
      _notificationSubscription?.cancel();
      _notificationSubscription =
          _txCharacteristic!.onValueReceived.listen(_handleNotification);

      _connectionState = LightstickConnectionState.connected;
      _statusMessage =
          'Đã kết nối ${device.platformName}';
      notifyListeners();

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
    _connectedDevice = null;
    _rxCharacteristic = null;
    _txCharacteristic = null;
    _firmwareVersion = null;
    _batteryLevel = null;
    _ledOn = false;
    _currentColorId = -1;
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

  /// Turn LED on with a specific color ID
  Future<void> sendLedOn(int colorId) async {
    await _sendCommand(LightstickProtocol.ledOn(colorId));
    _currentColorId = colorId;
    _ledOn = true;
    _statusMessage = 'LED bật - Color ID: $colorId';
    notifyListeners();
  }

  /// Turn LED off
  Future<void> sendLedOff() async {
    await _sendCommand(LightstickProtocol.ledOff());
    _ledOn = false;
    _currentColorId = -1;
    _statusMessage = 'LED tắt';
    notifyListeners();
  }

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
    super.dispose();
  }
}
