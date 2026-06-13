import 'package:flutter/material.dart';

class LightstickColor {
  final int id;
  final Color color;
  final String name;
  final String description;

  const LightstickColor(this.id, this.color, this.name, this.description);
}

const List<LightstickColor> wannaOneColors = [
  LightstickColor(0x00, Color(0xFFFFFFFF), "Trắng", "Điểm bắt đầu dải màu"),
  LightstickColor(0x01, Color(0xFFFF0022), "Đỏ", "Màu đỏ tươi pha ánh hồng"),
  LightstickColor(0x02, Color(0xFFFF4500), "Đỏ cam", "Đỏ pha chút ánh cam đậm"),
  LightstickColor(0x03, Color(0xFFFF8C00), "Cam / Vàng", "Màu cam ấm"),
  LightstickColor(0x04, Color(0xFFFFA500), "Cam vàng", "Màu cam sáng thiên vàng"),
  LightstickColor(0x05, Color(0xFFFFD700), "Vàng nắng", "Màu vàng ấm áp"),
  LightstickColor(0x06, Color(0xFFFFFF00), "Vàng chanh", "Màu vàng nguyên bản"),
  LightstickColor(0x07, Color(0xFFCCFF00), "Xanh chuối nhạt", "Vàng chanh pha chút ánh lục"),
  LightstickColor(0x08, Color(0xFF99FF00), "Xanh lá mạ", "Xanh lục nhạt sáng (Lime Green)"),
  LightstickColor(0x09, Color(0xFF33FF33), "Xanh lục nhạt", "Xanh lá cây nhạt"),
  LightstickColor(0x0A, Color(0xFF00FF00), "Xanh lá cây", "Màu xanh lá chuẩn"),
  LightstickColor(0x0B, Color(0xFF00CC44), "Xanh lá đậm", "Xanh lục bảo (Emerald)"),
  LightstickColor(0x0C, Color(0xFF00B894), "Xanh lục ngọc", "Xanh ngọc lục bảo (Teal)"),
  LightstickColor(0x0D, Color(0xFF00FFCC), "Xanh bạc hà", "Xanh Mint"),
  LightstickColor(0x0E, Color(0xFF00F0FF), "Xanh lam lục nhạt", "Màu xanh nước biển nhạt pha lục"),
  LightstickColor(0x0F, Color(0xFF00FFFF), "Xanh lục lam", "Màu Cyan sáng"),
  LightstickColor(0x10, Color(0xFF00D2FF), "Xanh ngọc lam", "Màu Turquoise"),
  LightstickColor(0x11, Color(0xFF00A2FF), "Xanh da trời nhạt", "Màu xanh da trời nhạt dịu"),
  LightstickColor(0x12, Color(0xFF0080FF), "Xanh da trời", "Sky Blue"),
  LightstickColor(0x13, Color(0xFF0040FF), "Xanh lam trung tính", "Xanh dương pha sáng"),
  LightstickColor(0x14, Color(0xFF0000FF), "Xanh dương", "Màu xanh dương chuẩn"),
  LightstickColor(0x15, Color(0xFF1A00FF), "Xanh dương đậm", "Royal Blue"),
  LightstickColor(0x16, Color(0xFF4B00FF), "Xanh chàm", "Indigo (Xanh dương pha ánh tím)"),
  LightstickColor(0x17, Color(0xFF8000FF), "Hồng nhạt", "Tím Lavender"),
  LightstickColor(0x18, Color(0xFFB300FF), "Tím", "Purple"),
  LightstickColor(0x19, Color(0xFFE600FF), "Tím đậm", "Violet"),
  LightstickColor(0x1A, Color(0xFFFF00E6), "Tím hồng", "Màu Magenta"),
  LightstickColor(0x1B, Color(0xFFFF0099), "Hồng sen / Hồng đậm", "Màu Hot Pink"),
];
