import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/api_config.dart';

/// Yeniden kullanılabilir avatar widget'ı.
/// JSON config alıp göz + ağız + kafa katmanlarıyla avatar render eder.
class AvatarWidget extends StatelessWidget {
  final Map<String, dynamic>? config;
  final double size;
  final bool showBorder;
  final Color? borderColor;

  const AvatarWidget({
    super.key,
    required this.config,
    this.size = 60,
    this.showBorder = true,
    this.borderColor,
  });

  static const List<Color> skinColors = [
    Color(0xFFFDECE0),
    Color(0xFFF5D6BA),
    Color(0xFFE8B88A),
    Color(0xFFD4956B),
    Color(0xFFAD7A5B),
    Color(0xFF8B5E3C),
    Color(0xFF614B3A),
    Color(0xFFFFD700),
    Color(0xFF87CEEB),
    Color(0xFFB8F5B0),
    Color(0xFFE6A8D7),
    Color(0xFFD8BFD8),
  ];

  // Yerel asset'te olmadığı bilinen parçalar cache'i
  static final Set<String> _knownMissingAssets = {};

  /// JSON string veya Map'ten config parse et
  static Map<String, dynamic>? parseConfig(dynamic avatarUrl) {
    if (avatarUrl == null) return null;
    if (avatarUrl is Map) return Map<String, dynamic>.from(avatarUrl);
    if (avatarUrl is String && avatarUrl.startsWith('{')) {
      try {
        return Map<String, dynamic>.from(jsonDecode(avatarUrl));
      } catch (_) {}
    }
    return null;
  }

  /// Avatar parçası resmi: önce yerel asset, yoksa sunucudan
  static Widget avatarImage(String partKey, double w, double h) {
    final assetPath = 'assets/avatar/$partKey.png';
    final networkUrl = '${ApiConfig.baseUrl}/avatar-assets/$partKey.png';

    // Daha önce bulamadıysak direkt sunucudan
    if (_knownMissingAssets.contains(partKey)) {
      return Image.network(
        networkUrl,
        width: w, height: h, fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => SizedBox(width: w, height: h),
      );
    }

    // Önce asset dene, hata verirse sunucudan yükle
    return Image.asset(
      assetPath,
      width: w, height: h, fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        _knownMissingAssets.add(partKey);
        return Image.network(
          networkUrl,
          width: w, height: h, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => SizedBox(width: w, height: h),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cfg = config ?? {'skin': 1, 'eyes': 'goz_normal', 'mouth': 'agiz_mutlu', 'head': null};

    final int skinIndex = _parseInt(cfg['skin'], 1).clamp(0, skinColors.length - 1);
    final String eyes = cfg['eyes'] ?? 'goz_normal';
    final String mouth = cfg['mouth'] ?? 'agiz_mutlu';
    final String? head = cfg['head'];

    final Color skinColor = skinColors[skinIndex];
    final bool hasHead = head != null && head.isNotEmpty;

    // Şapka varken yüzü küçült, toplam boyut aynı kalsın
    final double faceSize = hasHead ? size * 0.72 : size;
    final double partSize = faceSize * 0.75;
    final double mouthSize = partSize * 0.82;
    final double headSize = size * 0.85;

    Widget face = Container(
      width: faceSize,
      height: faceSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: skinColor,
      ),
      child: ClipOval(
        child: Stack(
          children: [
            Positioned(
              left: (faceSize - partSize) / 2,
              top: faceSize * 0.05,
              child: avatarImage(eyes, partSize, partSize),
            ),
            Positioned(
              left: (faceSize - mouthSize) / 2,
              bottom: -faceSize * 0.04,
              child: avatarImage(mouth, mouthSize, mouthSize),
            ),
          ],
        ),
      ),
    );

    // Şapka varsa Stack ile birleştir — toplam boyut ≈ size
    Widget avatar;
    if (hasHead) {
      avatar = SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned(bottom: 0, child: face),
            Positioned(
              top: -size * 0.18,
              child: avatarImage(head!, headSize, headSize),
            ),
          ],
        ),
      );
    } else {
      avatar = face;
    }

    if (showBorder) {
      return Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: borderColor != null
              ? null
              : const LinearGradient(colors: [Color(0xFF00E676), Color(0xFF00BFA5)]),
          color: borderColor,
        ),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF1A1A2E),
          ),
          child: avatar,
        ),
      );
    }

    return avatar;
  }

  static int _parseInt(dynamic val, int fallback) {
    if (val is int) return val;
    if (val is String) return int.tryParse(val) ?? fallback;
    return fallback;
  }
}
