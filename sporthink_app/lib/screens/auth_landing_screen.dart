import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import '../main.dart';
import '../ui/app_assets.dart';
import '../ui/app_background.dart';
import '../ui/app_logo.dart';

class AuthLandingScreen extends StatelessWidget {
  const AuthLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        imageAsset: AppAssets.runningHeroPng,
        imageAlignment: Alignment.bottomCenter,
        imageOpacity: 0.25,
        overlayOpacity: 0,
        showBlobs: true,
        backgroundGradient: LinearGradient(
          colors: [AppColors.background, AppColors.surface],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        imageOverlayGradient: LinearGradient(
          colors: [
            AppColors.background.withOpacity(0.0), // transparent
            AppColors.background.withOpacity(1.0), // readable area near bottom
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.50, 1.0],
        ),
        child: Column(
          children: [
            const Spacer(flex: 2),

            Image.asset(
              'assets/images/sporthink.png',
              width: 140,
              height: 140,
              fit: BoxFit.contain,
            ).animate().fadeIn(duration: 500.ms).scale(
                  duration: 650.ms,
                  curve: Curves.elasticOut,
                ),
            const SizedBox(height: 16),

            Text(
              'Adımlarını say, puanlarını topla,\narkadaşlarınla yarış!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.4, color: AppColors.textSecondary),
            )
                .animate()
                .fadeIn(duration: 550.ms, delay: 200.ms)
                .slideY(begin: -0.12, duration: 550.ms, curve: Curves.easeOutCubic),

            const Spacer(flex: 2),

            // Bottom sheet-like area so the hero photo stays visible behind it
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
                      child: const Text('Giriş Yap', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary.withOpacity(0.5), width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterScreen()),
                        );
                      },
                      child: const Text('Kayıt Ol', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 520.ms, delay: 240.ms)
                .slideY(begin: 0.22, duration: 520.ms, curve: Curves.easeOutCubic),

            const SizedBox(height: 16),
            Text(
              'Devam ederek kullanım koşullarını kabul etmiş olursun.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary.withOpacity(0.7)),
            ).animate().fadeIn(duration: 500.ms, delay: 380.ms),

            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}