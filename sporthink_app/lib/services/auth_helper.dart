import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/auth_landing_screen.dart';
import '../main.dart';

/// Token expire olduğunda kullanıcıya bilgi verip login'e yönlendirir
class AuthHelper {
  /// API yanıtının 401 (Unauthorized) olup olmadığını kontrol eder.
  /// 401 ise kullanıcıya mesaj gösterir ve login ekranına yönlendirir.
  /// true döndürürse 401'dir, çağıran fonksiyon return etmelidir.
  static Future<bool> handleUnauthorized(int statusCode, BuildContext context) async {
    if (statusCode == 401) {
      // Token'ı temizle
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('jwt_token');
      await prefs.remove('refresh_token');

      if (!context.mounted) return true;

      // Kullanıcıya bilgi ver
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.lock_clock_rounded, color: Colors.orange.shade400, size: 28),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Oturum Süresi Doldu',
                  style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: const Text(
            'Güvenlik önlemleri gereği oturumunuz sona erdi. Lütfen tekrar giriş yapın.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthLandingScreen()),
                    (route) => false,
                  );
                },
                child: const Text('Giriş Yap'),
              ),
            ),
          ],
        ),
      );
      return true;
    }
    return false;
  }
}
