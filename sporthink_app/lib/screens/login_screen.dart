import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/health_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import '../main.dart';
import '../ui/app_assets.dart';
import '../ui/app_background.dart';
import '../ui/app_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool _obscurePassword = true;

  Future<void> login() async {
    setState(() => isLoading = true);

    try {
      // Device ID al (anti-cheat için)
      final deviceId = await HealthService.getDeviceId();
      final deviceModel = await HealthService.getDeviceModel();

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': emailController.text,
          'password': passwordController.text,
          'device_id': deviceId,
          'device_model': deviceModel,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['accessToken'];

        if (token == null || token.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Token alınamadı. Lütfen tekrar deneyin.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        // Token'ı telefonun hafızasına kaydet
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);

        if (!mounted) return;
        // Başarılıysa Ana Sayfaya yönlendir
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        // Backend'den gelen hata mesajını göster
        final errorData = jsonDecode(response.body);
        final errorMsg = errorData['message'] ?? 'Giriş başarısız. Bilgileri kontrol edin.';
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sunucuya bağlanılamadı: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giriş'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        imageAsset: AppAssets.runningJpg1,
        imageAlignment: Alignment.topCenter,
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
            AppColors.background.withOpacity(0.0),
            AppColors.background.withOpacity(1.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.40, 1.0],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 100, bottom: 24),
          child: Column(
            children: [
              Image.asset(
                'assets/images/sporthink.png',
                width: 100,
                height: 100,
                fit: BoxFit.contain,
              ).animate().fadeIn(duration: 450.ms).scale(
                    duration: 650.ms,
                    curve: Curves.elasticOut,
                  ),
              const SizedBox(height: 24),

              Text(
                'Tekrar hoş geldin',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: AppColors.text),
              )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 120.ms)
                  .slideY(begin: -0.10, duration: 500.ms, curve: Curves.easeOutCubic),
              const SizedBox(height: 8),
              Text(
                'Adımlarına kaldığın yerden devam et.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14, color: AppColors.textSecondary),
              ).animate().fadeIn(duration: 500.ms, delay: 180.ms),

              const SizedBox(height: 32),

              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'E-posta veya kullanıcı adı',
                        hintText: 'ornek@mail.com veya kullanici_adi',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ).animate().fadeIn(duration: 500.ms, delay: 220.ms).slideX(begin: -0.08),

                    const SizedBox(height: 16),

                    TextField(
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      obscureText: _obscurePassword,
                    ).animate().fadeIn(duration: 500.ms, delay: 280.ms).slideX(begin: -0.08),

                    const SizedBox(height: 28),

                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: isLoading
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                            )
                          : SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: login,
                                child: const Text('Giriş Yap', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                              ),
                            ),
                    ).animate().fadeIn(duration: 500.ms, delay: 340.ms).slideY(begin: 0.12),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Hesabın yok mu? ', style: TextStyle(color: AppColors.textSecondary)),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterScreen()),
                      );
                    },
                    child: const Text(
                      'Kayıt Ol',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 500.ms, delay: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}