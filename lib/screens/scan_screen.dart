import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ble_service.dart';
import 'control_screen.dart';

class ScanScreen extends StatefulWidget {
  final BleService bleService;
  const ScanScreen({super.key, required this.bleService});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;

  BleService get ble => widget.bleService;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    ble.addListener(_onBleStateChanged);
    _requestPermissions();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    ble.removeListener(_onBleStateChanged);
    super.dispose();
  }

  void _onBleStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  Future<void> _startScan() async {
    await _requestPermissions();
    await ble.startScan();
  }

  Future<void> _connectDevice(BluetoothDevice device) async {
    final success = await ble.connectToDevice(device);
    if (success && mounted) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              ControlScreen(bleService: ble),
          transitionsBuilder: (_, animation, __, child) {
            return SlideTransition(
              position: Tween(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isScanning =
        ble.connectionState == LightstickConnectionState.scanning;
    final isConnecting =
        ble.connectionState == LightstickConnectionState.connecting ||
        ble.connectionState ==
            LightstickConnectionState.discoveringServices;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: SafeArea(
        child: Column(
          children: [
            // ===== HEADER =====
            _buildHeader(),

            // ===== SCAN ANIMATION =====
            _buildScanVisual(isScanning),

            // ===== STATUS =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                ble.statusMessage,
                style: TextStyle(
                  color: ble.lastError != null
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFF8899AA),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // ===== DEVICE LIST =====
            Expanded(child: _buildDeviceList(isConnecting)),

            // ===== SCAN BUTTON =====
            _buildScanButton(isScanning, isConnecting),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.bluetooth_searching,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WANNAONE Light Stick',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Điều khiển BLE',
                  style: TextStyle(
                    color: Color(0xFF8899AA),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanVisual(bool isScanning) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = isScanning ? 1.0 + (_pulseController.value * 0.15) : 1.0;
        return Container(
          margin: const EdgeInsets.only(top: 32, bottom: 8),
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ripple circles
              if (isScanning) ...[
                _buildRipple(80, 0.1 + _pulseController.value * 0.08),
                _buildRipple(100, 0.06 + _pulseController.value * 0.05),
                _buildRipple(120, 0.03 + _pulseController.value * 0.03),
              ],
              // Center icon
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isScanning
                          ? [
                              const Color(0xFF6C5CE7),
                              const Color(0xFFA29BFE),
                            ]
                          : [
                              const Color(0xFF2D3436),
                              const Color(0xFF636E72),
                            ],
                    ),
                    boxShadow: isScanning
                        ? [
                            BoxShadow(
                              color:
                                  const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    isScanning
                        ? Icons.bluetooth_searching
                        : Icons.bluetooth,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRipple(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF6C5CE7).withValues(alpha: opacity),
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildDeviceList(bool isConnecting) {
    if (ble.scanResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.devices_other,
              color: Colors.white.withValues(alpha: 0.15),
              size: 64,
            ),
            const SizedBox(height: 12),
            Text(
              'Nhấn "Quét" để tìm Light Stick',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: ble.scanResults.length,
      itemBuilder: (context, index) {
        final result = ble.scanResults[index];
        return _buildDeviceCard(result, isConnecting);
      },
    );
  }

  Widget _buildDeviceCard(ScanResult result, bool isConnecting) {
    final rssi = result.rssi;
    final name = result.device.platformName;
    final signal = rssi > -50
        ? 'Rất mạnh'
        : rssi > -65
            ? 'Mạnh'
            : 'Trung bình';
    final signalColor = rssi > -50
        ? const Color(0xFF00B894)
        : rssi > -65
            ? const Color(0xFFFDAA5E)
            : const Color(0xFFFF7675);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isConnecting ? null : () => _connectDevice(result.device),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1A1F3D),
                  const Color(0xFF16192E),
                ],
              ),
              border: Border.all(
                color: const Color(0xFF2D3154),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // BLE Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline,
                    color: Color(0xFFA29BFE),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.signal_cellular_alt,
                              color: signalColor, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '$signal ($rssi dBm)',
                            style: TextStyle(
                              color: signalColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Connect button
                if (isConnecting)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Color(0xFF6C5CE7)),
                    ),
                  )
                else
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Color(0xFF6C5CE7),
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScanButton(bool isScanning, bool isConnecting) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: isConnecting
              ? null
              : isScanning
                  ? () => ble.stopScan()
                  : _startScan,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: EdgeInsets.zero,
          ),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: isScanning
                  ? const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFEE5A24)],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                    ),
            ),
            child: Container(
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isScanning ? Icons.stop : Icons.search,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isScanning ? 'Dừng quét' : 'Quét thiết bị',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
