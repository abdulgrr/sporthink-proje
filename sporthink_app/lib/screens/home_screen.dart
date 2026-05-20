import 'package:flutter/material.dart';
import '../config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/health_service.dart';
import '../services/auth_helper.dart';
import 'auth_landing_screen.dart';
import 'shop_screen.dart';
import 'profile_screen.dart';
import 'social_screen.dart';
import 'daily_quests_screen.dart';
import 'notifications_screen.dart';
import 'inventory_screen.dart';
import '../services/notification_service.dart';
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math' as math;
import 'package:confetti/confetti.dart';
import '../main.dart';
import '../ui/app_assets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isSyncing = false;
  String _syncStatus = "Adımlarınızı senkronize ediliyor...";
  int _unreadNotifications = 0;
  Timer? _notificationTimer;
  String _currentTip = '';
  List<Map<String, dynamic>> _pendingSteps = [];
  bool _isLoadingPending = false;
  int _totalSteps = 0; // Bu hafta toplam adımlar
  int _todaySteps = 0; // Bugünkü adımlar
  int _currentStreak = 0; // Mevcut Seri (Streak)
  int _streakMinSteps = 5000; // Seri için gereken günlük adım
  bool _isLoadingTotal = false; // Toplam adımlar yükleniyor
  bool _hasAutoSynced = false; // Otomatik senkronizasyon yapıldı mı
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _fetchUnreadCount();
    _fetchTip();
    _fetchPendingSteps();
    _fetchTotalSteps(); // Toplam adımları çek

    // Uygulama açılınca otomatik senkronizasyon
    _autoSyncSteps();

    // Uygulama açıkken her 15 saniyede bir yeni bildirim var mı diye kontrol et
    _notificationTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _fetchUnreadCount();
    });
  }

  Future<void> _fetchTip() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null || token.isEmpty) {
        return; // Token yoksa işlem yapma
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/tips/random'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          _currentTip = data['tip'] ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchPendingSteps() async {
    setState(() {
      _isLoadingPending = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/steps/pending'),
        headers: {'Authorization': 'Bearer $token'},
      );

      // Token expire kontrolü
      if (mounted && await AuthHelper.handleUnauthorized(response.statusCode, context)) {
        return;
      }

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          _pendingSteps = List<Map<String, dynamic>>.from(data['pending_steps'] ?? []);
          _isLoadingPending = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingPending = false;
      });
    }
  }

  // Bu haftanın toplam adımlarını çek
  Future<void> _fetchTotalSteps() async {
    setState(() {
      _isLoadingTotal = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/steps/total'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        final int oldTodaySteps = _todaySteps;
        final int newTodaySteps = data['today_steps'] ?? 0;
        
        setState(() {
          _totalSteps = data['total_steps'] ?? 0;
          _todaySteps = newTodaySteps;
          _currentStreak = data['current_streak'] ?? 0;
          _streakMinSteps = data['streak_min_steps'] ?? 5000;
          _isLoadingTotal = false;
        });

        if (oldTodaySteps >= 0 && newTodaySteps > oldTodaySteps) {
          if (oldTodaySteps < 2500 && newTodaySteps >= 2500) _confettiController.play();
          else if (oldTodaySteps < 5000 && newTodaySteps >= 5000) _confettiController.play();
          else if (oldTodaySteps < 7500 && newTodaySteps >= 7500) _confettiController.play();
          else if (oldTodaySteps < 10000 && newTodaySteps >= 10000) _confettiController.play();
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingTotal = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTotal = false;
        });
      }
    }
  }

  // Otomatik senkronizasyon
  Future<void> _autoSyncSteps() async {
    if (_hasAutoSynced) return; // Zaten yapıldıysa tekrar yapma

    try {
      await Future.delayed(const Duration(seconds: 1)); // Kısa bekleme
      await syncSteps();
      setState(() {
        _hasAutoSynced = true;
      });
    } catch (e) {
      // Hata durumunda sessizce geç
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/notifications/unread-count'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        int unread = data['count'] ?? 0;
        
        setState(() {
          _unreadNotifications = unread;
        });
      }
    } catch (e) {
      // Sessizce yut
    }
  }

  // Hata gösterme fonksiyonu
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.surface,
                AppColors.background,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hata ikonu
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.error, Color(0xFFDC2626)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.error.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),

              // Başlık
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Mesaj
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Buton
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Tamam',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Çıkış Yapma
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthLandingScreen()),
    );
  }

  // BÜYÜK OPERASYON: Adımları Çek ve Sunucuya Gönder
  Future<void> syncSteps() async {
    setState(() {
      _isSyncing = true;
      _syncStatus = "Google Fit verileri okunuyor...";
    });

    try {
      // 1. Telefondan Adımları Al
      final healthService = HealthService();
      final stepsArray = await healthService.fetchLast7DaysSteps();

      if (stepsArray.isEmpty) {
        setState(() {
          _syncStatus = "Yeni adım verisi yok.";
          _isSyncing = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('📊 Henüz yeni adım verisi yok. Biraz yürüyüp tekrar deneyin!'),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      setState(() => _syncStatus = "Adımlar sunucuya gönderiliyor...");

      // 2. Token ve Device ID'yi Hazırla
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final deviceId = await HealthService.getDeviceId();
      final deviceModel = await HealthService.getDeviceModel();

      // 3. Backend'in İstediği Paketi (Batch) Oluştur
      final batchId = "batch_${DateTime.now().millisecondsSinceEpoch}";
      final now = DateTime.now();

      // 4. API İsteği At
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/steps/sync'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "client_batch_id": batchId,
          "source": "GoogleFit",
          "device_id": deviceId,
          "device_model": deviceModel,
          "period_start": now
              .subtract(const Duration(days: 7))
              .toIso8601String(),
          "period_end": now.toIso8601String(),
          "steps_array": stepsArray,
        }),
      );

      // 5. Sunucu Yanıtını İşle
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _syncStatus = "Adımlar başarıyla senkronize edildi!";
        });

        if (!mounted) return;

        // 1. STREAK POPUP
        if (data['streak_extended'] == true) {
          if (!mounted) return;
          _confettiController.play();
          await showDialog(
            context: context,
            builder: (context) => _buildAnimatedDialog(
              icon: Icons.local_fire_department,
              iconColor: Colors.orange,
              title: 'Harika!',
              content: 'Bugünkü hedefini tamamladın ve serini başarıyla uzattın!',
            ),
          );
        }

        // 2. LEVEL UP POPUP
        if (data['level_up'] != null) {
          if (!mounted) return;
          _confettiController.play();
          await showDialog(
            context: context,
            builder: (context) => _buildAnimatedDialog(
              icon: Icons.star,
              iconColor: Colors.yellow,
              title: 'Seviye Atladın!',
              content: 'Tebrikler! Yeni seviyeye ulaştın: Level ${data['level_up']['new_level']}\nÖdül: ${data['level_up']['bonus_points']} Puan!',
            ),
          );
        }

        // 3. YENİ ROZET POPUP
        if (data['new_badges'] != null && (data['new_badges'] as List).isNotEmpty) {
          if (!mounted) return;
          _confettiController.play();
          await showDialog(
            context: context,
            builder: (context) => _buildAnimatedDialog(
              icon: Icons.military_tech,
              iconColor: Colors.amber,
              title: 'Yeni Rozet Kazandın!',
              content: 'Tebrikler! Harika bir iş çıkardın ve şu rozetleri kazandın:\n\n${(data['new_badges'] as List).join(", ")}',
            ),
          );
        }

        // Görev ilerlemelerini kontrol et
        try {
          await http.post(
            Uri.parse('${ApiConfig.baseUrl}/api/quests/check'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );
        } catch (_) {}

        // Verileri güncelle
        _fetchTip();
        _fetchPendingSteps();
        _fetchTotalSteps();
      } else if (response.statusCode == 403) {
        // Anti-cheat hatası — backend'den gelen mesajı göster
        final errorData = jsonDecode(response.body);
        final errorMsg = errorData['message'] ?? 'Erişim engellendi.';
        setState(() => _syncStatus = errorMsg);
        if (mounted) {
          _showErrorDialog('Güvenlik Uyarısı', errorMsg);
        }
      } else {
        setState(() => _syncStatus = "Sunucu Hatası: ${response.statusCode}");
        if (mounted) {
          _showErrorDialog(
            'Sunucu Hatası',
            'Sunucuya bağlanırken bir hata oluştu. Lütfen daha sonra tekrar deneyin.',
          );
        }
      }
    } catch (e) {
      setState(() => _syncStatus = "Bir hata oluştu:\n$e");
      if (mounted) {
        _showErrorDialog(
          'Bağlantı Hatası',
          'İnternet bağlantınızı kontrol edip tekrar deneyin.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  // Adımları Puana Çevir
  Future<void> convertStepsToPoints() async {
    setState(() {
      _isSyncing = true;
      _syncStatus = "Adımlar puana çevriliyor...";
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/steps/convert'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _syncStatus = "Adımlar başarıyla puana çevrildi!";
        });

        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.surface,
                    AppColors.background,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Başarı ikonu
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppColors.secondaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Başlık
                  const Text(
                    'Mükemmel!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Alt başlık
                  const Text(
                    'Adımlar Puana Çevrildi',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // İstatistikler
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.textSecondary.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.directions_walk,
                              color: AppColors.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${data['total_steps_converted']}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'adım',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.stars,
                              color: AppColors.accent,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '+${data['total_points_earned']}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'puan',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Buton
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Tamam',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        // Görev ilerlemelerini kontrol et
        try {
          await http.post(
            Uri.parse('${ApiConfig.baseUrl}/api/quests/check'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );
        } catch (_) {}

        // Verileri güncelle
        _fetchPendingSteps();
        _fetchTotalSteps();
      } else {
        setState(() => _syncStatus = "Sunucu Hatası: ${response.statusCode}");
        if (mounted) {
          _showErrorDialog(
            'Sunucu Hatası',
            'Adımları puana çevirirken bir hata oluştu. Lütfen daha sonra tekrar deneyin.',
          );
        }
      }
    } catch (e) {
      setState(() => _syncStatus = "Bir hata oluştu:\n$e");
      if (mounted) {
        _showErrorDialog(
          'Bağlantı Hatası',
          'İnternet bağlantınızı kontrol edip tekrar deneyin.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  // SADECE "ADIMLAR" (0. İNDEX) EKRANI İÇİN İÇERİK
  Widget _buildStepsView() {
    int currentTarget = 10000;

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchTotalSteps();
        await _fetchPendingSteps();
        await syncSteps();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // İpucu Kartı
            if (_currentTip.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 3,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Dekoratif daireler
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      bottom: -10,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    // İçerik
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          // İkon
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.lightbulb_outline,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Metin
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Günün İpucu',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _currentTip,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Kapat butonu
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _currentTip = '';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate()
                  .fadeIn(duration: 600.ms)
                  .slideX(begin: -0.2, duration: 600.ms)
                  .then()
                  .shimmer(duration: 1500.ms, color: Colors.white.withOpacity(0.3)),

            const SizedBox(height: 24),

            // Mevcut Seri (Streak) Kartı
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _todaySteps >= _streakMinSteps ? AppColors.success.withOpacity(0.1) : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _todaySteps >= _streakMinSteps ? AppColors.success.withOpacity(0.5) : AppColors.textSecondary.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      _todaySteps >= _streakMinSteps 
                        ? '$_currentStreak Günlük Seri - Hedefe Ulaşıldı!'
                        : '$_currentStreak Seri - Hedefe ${_streakMinSteps - _todaySteps} adım',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _todaySteps >= _streakMinSteps ? AppColors.success : AppColors.text,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms),
            ),
            const SizedBox(height: 24),

            // Bu Hafta Toplam ve Bugünkü Adımlar - Yan Yana
            // Animated Step Gauge
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: (_todaySteps / currentTarget).clamp(0.0, 1.0)),
                  duration: 1500.ms,
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return SizedBox(
                      width: 240,
                      height: 240,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Background Arc (270 degrees, starting at 225 degrees / bottom-left)
                          Transform.rotate(
                            angle: 1.25 * math.pi,
                            child: CircularProgressIndicator(
                              value: 0.75,
                              strokeWidth: 24,
                              color: AppColors.background,
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          // Progress Arc
                          Transform.rotate(
                            angle: 1.25 * math.pi,
                            child: CircularProgressIndicator(
                              value: value * 0.75,
                              strokeWidth: 24,
                              strokeCap: StrokeCap.round,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                          // Marker at 25% (2500 steps)
                          Transform.rotate(
                            angle: 1.625 * math.pi,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Container(width: 4, height: 16, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(2))),
                            ),
                          ),
                          // Marker at 50% (5000 steps)
                          Transform.rotate(
                            angle: 2.0 * math.pi, // Top Center
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Container(width: 6, height: 20, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(3))),
                            ),
                          ),
                          // Marker at 75% (7500 steps)
                          Transform.rotate(
                            angle: 0.375 * math.pi,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Container(width: 4, height: 16, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(2))),
                            ),
                          ),
                          // Etiket: 0 (Başlangıç)
                          const Align(
                            alignment: Alignment(-0.65, 0.85),
                            child: Text('0', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                          ),
                          // Etiket: 2500
                          const Align(
                            alignment: Alignment(-0.75, -0.3),
                            child: Text('2500', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                          ),
                          // Etiket: 5000
                          const Align(
                            alignment: Alignment(0, -0.75),
                            child: Text('5000', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                          ),
                          // Etiket: 7500
                          const Align(
                            alignment: Alignment(0.75, -0.3),
                            child: Text('7500', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                          ),
                          // Etiket: 10.000 (Bitiş)
                          const Align(
                            alignment: Alignment(0.65, 0.85),
                            child: Text('10.000', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                          ),
                          // Inner Content
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.directions_walk, size: 40, color: AppColors.secondary),
                                const SizedBox(height: 8),
                                Text(
                                  '$_todaySteps',
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.text,
                                    height: 1,
                                  ),
                                ).animate(target: _todaySteps > 0 ? 1 : 0).shimmer(duration: 2.seconds, color: AppColors.secondary),
                                const SizedBox(height: 4),
                                const Text(
                                  'Bugün',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Hedef: $currentTarget',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary.withOpacity(0.8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ).animate().scale(duration: 800.ms, curve: Curves.easeOutBack),

            const SizedBox(height: 24),

            // Weekly Total Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 4,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.secondaryGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Haftalık Toplam',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_totalSteps Adım',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.calendar_today, color: Colors.white, size: 28),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.2),

            const SizedBox(height: 24),

            // Senkronize Edilmemiş Adımlar Başlığı
            const Text(
              'Puana Çevrilmemiş Adımlar',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ).animate().fadeIn().slideX(),

            const SizedBox(height: 16),

            // Puana Çevrilmemiş Adımlar Listesi
            if (_isLoadingPending)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.05),
                      AppColors.background,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    // Yükleme animasyonu
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Adımlar yükleniyor...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Lütfen bekleyin',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // İlerleme çubu
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.7, // %70 ilerleme
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate()
                  .fadeIn(duration: 600.ms)
                  .scale(begin: const Offset(0.9, 0.9), duration: 600.ms)
            else if (_pendingSteps.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.success.withOpacity(0.1),
                      AppColors.success.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_outline,
                        size: 48,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Harika!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tüm adımlar puana çevrildi',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.celebration,
                            color: AppColors.success,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Mükemmel iş!',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate()
                  .fadeIn(duration: 600.ms)
                  .scale(begin: const Offset(0.8, 0.8), duration: 600.ms)
            else
              Column(
                children: [
                  ..._pendingSteps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final step = entry.value;
                    return Dismissible(
                      key: Key(step['day'] ?? index.toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          gradient: AppColors.secondaryGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.surface,
                                AppColors.background,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Adım ikonu
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.accentGradient,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.accent.withOpacity(0.3),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.directions_walk,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Adım bilgisi
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Puana çevrilmeyi bekliyor',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppColors.text,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Adım sayısı
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.accentGradient,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.accent.withOpacity(0.3),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.directions_walk,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${step['total_steps']}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ).animate()
                        .fadeIn(duration: 500.ms, delay: Duration(milliseconds: index * 100))
                        .slideX(begin: 0.1, duration: 500.ms, delay: Duration(milliseconds: index * 100))
                        .then()
                        .shimmer(duration: 1000.ms, color: AppColors.accent.withOpacity(0.1));
                  }).toList(),
                ],
              ),

            const SizedBox(height: 24),

            // Durum Mesajı
            if (_syncStatus.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isSyncing
                      ? AppColors.primary.withOpacity(0.1)
                      : AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isSyncing
                        ? AppColors.primary.withOpacity(0.3)
                        : AppColors.success.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    if (_isSyncing)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      )
                    else
                      Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 20,
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _syncStatus,
                        style: TextStyle(
                          fontSize: 14,
                          color: _isSyncing ? AppColors.primary : AppColors.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(),

            const SizedBox(height: 24),

            // Adımları Puana Çevir Butonu
            if (_pendingSteps.isNotEmpty)
              Container(
                width: double.infinity,
                height: 64,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _isSyncing ? null : convertStepsToPoints,
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.stars, size: 28),
                  label: Text(
                    _isSyncing ? 'İşleniyor...' : 'Adımları Puana Çevir',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ).animate()
                  .fadeIn(duration: 600.ms)
                  .scale(begin: const Offset(0.9, 0.9), duration: 600.ms)
                  .then()
                  .shimmer(duration: 2000.ms, color: Colors.white.withOpacity(0.2)),

            const SizedBox(height: 16),

            // Manuel Senkronizasyon Butonu
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              child: OutlinedButton.icon(
                onPressed: _isSyncing ? null : syncSteps,
                icon: _isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      )
                    : const Icon(Icons.sync, size: 22),
                label: Text(
                  _isSyncing ? 'Senkronize ediliyor...' : 'Adımları Senkronize Et',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor: Colors.transparent,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ).animate()
                .fadeIn(duration: 500.ms, delay: 200.ms)
                .slideX(begin: 0.1, duration: 500.ms, delay: 200.ms),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Çıkış Yap',
          onPressed: logout,
        ),
        title: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/sporthink.png',
            width: 120,
            height: 120,
            fit: BoxFit.contain,
            errorBuilder: (c, e, s) => const Icon(Icons.directions_run_rounded, size: 28),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: 'Kuponlarım',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const InventoryScreen()));
            },
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: _unreadNotifications > 0
                      ? AppColors.primary.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                    );
                    _fetchUnreadCount(); // Geri dönünce sayıyı güncelle
                  },
                  tooltip: 'Bildirimler',
                ),
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.error, Color(0xFFDC2626)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.error.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    child: Text(
                      _unreadNotifications > 99 ? '99+' : '$_unreadNotifications',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          _selectedIndex == 0
              ? _buildStepsView()
              : _selectedIndex == 1
                  ? const SocialScreen()
                  : _selectedIndex == 2
                      ? const DailyQuestsScreen()
                      : _selectedIndex == 3
                          ? const ShopScreen()
                          : const ProfileScreen(),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        elevation: 8,
        backgroundColor: Colors.transparent,
        shape: const CircleBorder(),
        onPressed: () => setState(() => _selectedIndex = 0),
        child: Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.primaryGradient,
          ),
          child: const Center(
            child: Icon(Icons.directions_walk, size: 32, color: Colors.white),
          ),
        ),
      ).animate(target: _selectedIndex == 0 ? 1 : 0).scale(end: const Offset(1.1, 1.1)),
      bottomNavigationBar: BottomAppBar(
        color: AppColors.surface,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(1, Icons.people_alt_rounded, 'Sosyal'),
              _buildNavItem(2, Icons.assignment, 'Görevler'),
              const SizedBox(width: 48), // Space for FAB
              _buildNavItem(3, Icons.store, 'Dükkan'),
              _buildNavItem(4, Icons.person, 'Profil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: TweenAnimationBuilder(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        tween: Tween<double>(begin: 0.0, end: 1.0),
        builder: (context, double value, child) {
          return Transform.scale(
            scale: value,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.surface, AppColors.background],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withOpacity(0.3),
                    blurRadius: 20 * value,
                    spreadRadius: 5 * value,
                  ),
                ],
                border: Border.all(color: iconColor.withOpacity(0.5), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 48),
                  ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    content,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        'Harika!',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      customBorder: const CircleBorder(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            size: isSelected ? 28 : 24,
          ).animate(target: isSelected ? 1 : 0).scale(end: const Offset(1.1, 1.1)),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}