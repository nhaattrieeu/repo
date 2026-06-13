import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/ble_constants.dart';
import '../models/lightstick_color.dart';
import '../services/ble_service.dart';

class ControlScreen extends StatefulWidget {
  final BleService bleService;
  const ControlScreen({super.key, required this.bleService});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _colorChangeController;
  int? _testingColorId;

  BleService get ble => widget.bleService;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _colorChangeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    ble.addListener(_onBleChanged);
  }

  @override
  void dispose() {
    _glowController.dispose();
    _colorChangeController.dispose();
    ble.removeListener(_onBleChanged);
    super.dispose();
  }

  void _onBleChanged() {
    if (mounted) {
      setState(() {});
      // Navigate back if disconnected
      if (!ble.isConnected) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _onColorTap(LightstickColor lc) async {
    setState(() => _testingColorId = lc.id);
    ble.setStaticColor(lc.id);
    _colorChangeController.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) setState(() => _testingColorId = null);
  }

  void _onLedOff() {
    ble.turnOffAll();
    _colorChangeController.forward(from: 0);
  }

  Color _getCurrentDisplayColor() {
    if (!ble.isLedOn || ble.currentColorId < 0) {
      return const Color(0xFF2D3436);
    }
    for (final c in wannaOneColors) {
      if (c.id == ble.currentColorId) return c.color;
    }
    return const Color(0xFFDFE6E9);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildLightStickVisual(),
                    const SizedBox(height: 24),
                    _buildEffectControls(),
                    const SizedBox(height: 24),
                    _buildColorSection(),
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== APP BAR ====================

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              await ble.disconnect();
            },
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ble.connectedDevice?.platformName ?? 'Light Stick',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  ble.statusMessage,
                  style: const TextStyle(
                    color: Color(0xFF8899AA),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Connection indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: ble.isConnected
                  ? const Color(0xFF00B894).withValues(alpha: 0.15)
                  : const Color(0xFFFF6B6B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ble.isConnected
                        ? const Color(0xFF00B894)
                        : const Color(0xFFFF6B6B),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  ble.isConnected ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: ble.isConnected
                        ? const Color(0xFF00B894)
                        : const Color(0xFFFF6B6B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== LIGHT STICK VISUAL ====================

  Widget _buildLightStickVisual() {
    final displayColor = _getCurrentDisplayColor();
    final isOn = ble.isLedOn;

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowAmount = isOn ? 0.3 + _glowController.value * 0.4 : 0.0;
        return Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1A1F3D),
                isOn
                    ? displayColor.withValues(alpha: 0.08)
                    : const Color(0xFF0F1225),
              ],
            ),
            border: Border.all(
              color: isOn
                  ? displayColor.withValues(alpha: 0.3)
                  : const Color(0xFF2D3154),
              width: 1,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow effect
              if (isOn)
                Container(
                  width: 120 + glowAmount * 40,
                  height: 120 + glowAmount * 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: displayColor.withValues(alpha: glowAmount * 0.6),
                        blurRadius: 60,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                ),
              // Light bulb icon
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOn
                          ? displayColor.withValues(alpha: 0.2)
                          : const Color(0xFF2D3436).withValues(alpha: 0.3),
                      boxShadow: isOn
                          ? [
                              BoxShadow(
                                color: displayColor.withValues(alpha: 0.4),
                                blurRadius: 30,
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      isOn ? Icons.lightbulb : Icons.lightbulb_outline,
                      size: 48,
                      color: isOn ? displayColor : const Color(0xFF636E72),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      color: isOn ? displayColor : const Color(0xFF636E72),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                    child: Text(isOn ? 'ON' : 'OFF'),
                  ),
                  if (isOn)
                    Text(
                      'Color ID: ${ble.currentColorId}',
                      style: TextStyle(
                        color: displayColor.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== INFO CARDS ====================

  Widget _buildInfoCards() {
    return Row(
      children: [
        Expanded(child: _buildInfoCard(
          icon: Icons.memory,
          label: 'Firmware',
          value: ble.firmwareVersion ?? '---',
          color: const Color(0xFF6C5CE7),
        )),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: ble.isConnected ? () => ble.requestBattery() : null,
            child: _buildInfoCard(
              icon: Icons.battery_std,
              label: 'Pin',
              value: ble.batteryLevel != null ? '${ble.batteryLevel}%' : 'Nhấn để đọc',
              color: _getBatteryColor(),
            ),
          ),
        ),
      ],
    );
  }

  Color _getBatteryColor() {
    final level = ble.batteryLevel;
    if (level == null) return const Color(0xFF636E72);
    if (level > 60) return const Color(0xFF00B894);
    if (level > 20) return const Color(0xFFFDAA5E);
    return const Color(0xFFFF6B6B);
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1A1F3D),
        border: Border.all(color: const Color(0xFF2D3154)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF8899AA),
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== COLOR SECTION ====================

  // ==================== EFFECTS SECTION ====================

  Widget _buildEffectControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hiệu ứng',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => ble.setBlinkSpeed(0),
                child: _buildEffectButton('Sáng tĩnh', ble.blinkSpeedMs == 0),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => ble.setBlinkSpeed(500),
                child: _buildEffectButton('Nháy chậm', ble.blinkSpeedMs == 500),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => ble.setBlinkSpeed(150),
                child: _buildEffectButton('Nháy nhanh', ble.blinkSpeedMs == 150),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Random toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFF1A1F3D),
            border: Border.all(
              color: ble.isAutoRandom ? const Color(0xFF00B894) : const Color(0xFF2D3154),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.shuffle, color: ble.isAutoRandom ? const Color(0xFF00B894) : const Color(0xFF8899AA)),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Tự động Random', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              ),
              Switch(
                value: ble.isAutoRandom,
                onChanged: (val) => ble.setAutoRandom(val),
                activeColor: const Color(0xFF00B894),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Sequential cycle toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFF1A1F3D),
            border: Border.all(
              color: ble.isSequentialCycle ? const Color(0xFF00B894) : const Color(0xFF2D3154),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.palette, color: ble.isSequentialCycle ? const Color(0xFF00B894) : const Color(0xFF8899AA)),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Chạy màu lần lượt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              ),
              Switch(
                value: ble.isSequentialCycle,
                onChanged: (val) => ble.setSequentialCycle(val),
                activeColor: const Color(0xFF00B894),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEffectButton(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF6C5CE7).withValues(alpha: 0.2) : const Color(0xFF1A1F3D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isActive ? const Color(0xFF6C5CE7) : const Color(0xFF2D3154)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? const Color(0xFF6C5CE7) : const Color(0xFF8899AA),
          fontSize: 12,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }

  // ==================== COLOR SECTION ====================

  Widget _buildColorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Bảng dải màu (28 màu)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 0.85,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: wannaOneColors.length,
          itemBuilder: (context, index) {
            return _buildColorButton(wannaOneColors[index]);
          },
        ),
      ],
    );
  }

  Widget _buildColorButton(LightstickColor lc) {
    final isActive = ble.isLedOn && ble.currentColorId == lc.id;
    final isTesting = _testingColorId == lc.id;

    return GestureDetector(
      onTap: ble.isConnected ? () => _onColorTap(lc) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isActive
              ? lc.color.withValues(alpha: 0.15)
              : const Color(0xFF1A1F3D),
          border: Border.all(
            color: isActive
                ? lc.color.withValues(alpha: 0.6)
                : isTesting
                    ? lc.color.withValues(alpha: 0.3)
                    : const Color(0xFF2D3154),
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: lc.color.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: lc.color,
                boxShadow: [
                  BoxShadow(
                    color: lc.color.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              lc.name,
              style: TextStyle(
                color: isActive ? lc.color : const Color(0xFF8899AA),
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ACTION BUTTONS ====================

  Widget _buildActionButtons() {
    return Column(
      children: [
        // LED OFF button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed:
                ble.isConnected && ble.isLedOn ? _onLedOff : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: const Color(0xFF1A1F3D),
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: ble.isLedOn
                      ? const Color(0xFFFF6B6B).withValues(alpha: 0.5)
                      : const Color(0xFF2D3154),
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.power_settings_new,
                  color: ble.isLedOn
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFF636E72),
                ),
                const SizedBox(width: 8),
                Text(
                  'Tắt LED',
                  style: TextStyle(
                    color: ble.isLedOn
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFF636E72),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: ble.isConnected ? () => _showResetConfirm() : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: const Color(0xFF1A1F3D),
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFF2D3154)),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.restart_alt, color: Color(0xFFFF6B6B)),
                SizedBox(width: 8),
                Text(
                  'Reset',
                  style: TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showResetConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Reset Light Stick?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Thao tác này sẽ reset thiết bị về trạng thái mặc định. Bạn có chắc chắn?',
          style: TextStyle(color: Color(0xFF8899AA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Hủy',
              style: TextStyle(color: Color(0xFF8899AA)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ble.resetDevice();
            },
            child: const Text(
              'Reset',
              style: TextStyle(
                  color: Color(0xFFFF6B6B), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
