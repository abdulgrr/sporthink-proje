import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/health_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import '../main.dart';
import '../ui/app_assets.dart';
import '../ui/app_background.dart';
import '../ui/app_logo.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  bool isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;



  Future<void> register() async {
    if (!_formKey.currentState!.validate()) return;

    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Şifreler eşleşmiyor!'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Device ID al (anti-cheat için)
      final deviceId = await HealthService.getDeviceId();
      final deviceModel = await HealthService.getDeviceModel();

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': usernameController.text.trim(),
          'first_name': firstNameController.text.trim(),
          'last_name': lastNameController.text.trim(),
          'phone_number': phoneController.text.trim().replaceAll(' ', ''),
          'email': emailController.text.trim(),
          'password': passwordController.text,
          'device_id': deviceId,
          'device_model': deviceModel,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        if (!mounted) return;
        // JWT token'ları kaydet
        if (data['accessToken'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', data['accessToken']);
          if (data['refreshToken'] != null) {
            await prefs.setString('refresh_token', data['refreshToken']);
          }
        }

        // Kayıt başarılı, onboarding ekranına yönlendir
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Kayıt başarısız.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sunucuya bağlanılamadı: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    usernameController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kayıt Ol'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        imageAsset: AppAssets.runningJpg2,
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
          stops: const [0.38, 1.0],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 100, bottom: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/images/sporthink.png',
                    width: 90,
                    height: 90,
                    fit: BoxFit.contain,
                  )
                      .animate()
                      .fadeIn(duration: 450.ms)
                      .scale(duration: 650.ms, curve: Curves.elasticOut),
                ),
                const SizedBox(height: 24),

              // Başlık
              Text(
                'Hesap oluştur',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: AppColors.text),
              )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 120.ms)
                  .slideY(begin: -0.10, duration: 500.ms, curve: Curves.easeOutCubic),
              const SizedBox(height: 8),
              Text(
                'Bilgilerini doldur, hemen başlayalım.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14, color: AppColors.textSecondary),
              ).animate().fadeIn(duration: 500.ms, delay: 170.ms),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [


                    // Kullanıcı Adı
                    TextFormField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Kullanıcı adı',
                        hintText: 'ornek_kullanici',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Kullanıcı adı gerekli';
                        if (value.trim().length < 3) return 'En az 3 karakter olmalı';
                        if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
                          return 'Sadece harf, rakam ve alt çizgi kullanılabilir';
                        }
                        return null;
                      },
                    ).animate().fadeIn(
                      duration: 600.ms,
                      delay: 300.ms,
                    ).slideX(
                      begin: -0.08,
                      duration: 600.ms,
                      curve: Curves.easeOut,
                    ),
                    const SizedBox(height: 16),

                    // Ad
                    TextFormField(
                      controller: firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'Ad',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Ad gerekli';
                        return null;
                      },
                    ).animate().fadeIn(duration: 600.ms, delay: 350.ms).slideX(begin: -0.08),
                    const SizedBox(height: 16),

                    // Soyad
                    TextFormField(
                      controller: lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Soyad',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Soyad gerekli';
                        return null;
                      },
                    ).animate().fadeIn(duration: 600.ms, delay: 400.ms).slideX(begin: -0.08),
                    const SizedBox(height: 16),

                    // Telefon
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Telefon numarası',
                        hintText: '05XX XXX XX XX',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Telefon numarası gerekli';
                        final cleaned = value.replaceAll(' ', '');
                        if (!RegExp(r'^05\d{9}$').hasMatch(cleaned)) {
                          return 'Geçerli bir telefon numarası giriniz (05XX XXX XX XX)';
                        }
                        return null;
                      },
                    ).animate().fadeIn(duration: 600.ms, delay: 450.ms).slideX(begin: -0.08),
                    const SizedBox(height: 16),

                    // E-posta
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-posta',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'E-posta gerekli';
                        if (!value.contains('@')) return 'Geçerli bir e-posta giriniz';
                        return null;
                      },
                    ).animate().fadeIn(duration: 600.ms, delay: 500.ms).slideX(begin: -0.08),
                    const SizedBox(height: 16),

                    // Şifre
                    TextFormField(
                      controller: passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppColors.primary),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Şifre gerekli';
                        if (value.length < 6) return 'Şifre en az 6 karakter olmalı';
                        return null;
                      },
                    ).animate().fadeIn(duration: 600.ms, delay: 550.ms).slideX(begin: -0.08),
                    const SizedBox(height: 16),

                    // Şifre Tekrar
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Şifre Tekrar',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: AppColors.primary),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Şifre tekrarı gerekli';
                        return null;
                      },
                    ).animate().fadeIn(duration: 600.ms, delay: 600.ms).slideX(begin: -0.08),
                    const SizedBox(height: 32),

                    // Kayıt Ol Butonu
                    isLoading
                        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                        : SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Kayıt Ol',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ).animate().fadeIn(
                            duration: 600.ms,
                            delay: 650.ms,
                          ).slideY(
                            begin: 0.12,
                            duration: 600.ms,
                            curve: Curves.easeOut,
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Zaten hesabın var mı?
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Zaten hesabın var mı? ', style: TextStyle(color: AppColors.textSecondary)),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                    child: const Text(
                      'Giriş Yap',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(
                duration: 600.ms,
                delay: 750.ms,
              ),
              const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}