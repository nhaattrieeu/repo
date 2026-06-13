import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/ble_constants.dart';
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
  bool _showExperimental = false;
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
    await ble.sendLedOn(lc.id);
    _colorChangeController.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) setState(() => _testingColorId = null);
  }

  Future<void> _onLedOff() async {
    await ble.sendLedOff();
    _colorChangeController.forward(from: 0);
  }

  Color _getCurrentDisplayColor() {
    if (!ble.isLedOn || ble.currentColorId < 0) {
      return const Color(0xFF2D3436);
    }
    // Try to find in known colors
    for (final c in LightstickColor.knownColors) {
      if (c.id == ble.currentColorId) return c.color;
    }
    for (final c in LightstickColor.experimentalColors) {
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
                    _buildInfoCards(),
                    const SizedBox(height: 24),
                    _buildColorSection(
                      'Màu cơ bản',
                      LightstickColor.knownColors,
                      true,
                    ),
                    const SizedBox(height: 20),
                    _buildExperimentalToggle(),
                    if (_showExperimental) ...[
                      const SizedBox(height: 16),
                      _buildColorSection(
                        'Thử nghiệm',
                        LightstickColor.experimentalColors,
                        false,
                      ),
                    ],
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

  Widget _buildColorSection(
      String title, List<LightstickColor> colors, bool isKnown) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!isKnown)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDAA5E).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Chưa xác nhận',
                    style: TextStyle(
                      color: Color(0xFFFDAA5E),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: colors.map((lc) => _buildColorButton(lc)).toList(),
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

  // ==================== EXPERIMENTAL TOGGLE ====================

  Widget _buildExperimentalToggle() {
    return GestureDetector(
      onTap: () => setState(() => _showExperimental = !_showExperimental),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFF1A1F3D),
          border: Border.all(color: const Color(0xFF2D3154)),
        ),
        child: Row(
          children: [
            Icon(
              _showExperimental
                  ? Icons.science
                  : Icons.science_outlined,
              color: const Color(0xFFFDAA5E),
              size: 20,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Màu thử nghiệm (chưa xác nhận)',
                style: TextStyle(
                  color: Color(0xFFFDAA5E),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            AnimatedRotation(
              turns: _showExperimental ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.keyboard_arrow_down,
                color: Color(0xFFFDAA5E),
                size: 20,
              ),
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
        // Secondary buttons row
        Row(
          children: [
            Expanded(
              child: _buildSecondaryButton(
                icon: Icons.battery_std,
                label: 'Đọc pin',
                onTap: () => ble.requestBattery(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSecondaryButton(
                icon: Icons.refresh,
                label: 'Đọc FW',
                onTap: () => ble.requestFirmwareVersion(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSecondaryButton(
                icon: Icons.restart_alt,
                label: 'Reset',
                onTap: () => _showResetConfirm(),
                isDestructive: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color =
        isDestructive ? const Color(0xFFFF6B6B) : const Color(0xFF6C5CE7);
    return GestureDetector(
      onTap: ble.isConnected ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFF1A1F3D),
          border: Border.all(color: const Color(0xFF2D3154)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
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
