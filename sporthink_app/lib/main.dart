import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/permission_screen.dart';
import 'screens/auth_landing_screen.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'ui/app_assets.dart';
import 'ui/app_background.dart';
import 'ui/app_logo.dart';

// Modern Renk Paleti (Sporthink: Siyah & Koyu Kırmızı)
class AppColors {
  static const Color primary = Color(0xFFDC2626); // Koyu Kırmızı
  static const Color secondary = Color(0xFFB91C1C); // Daha Koyu Kırmızı
  static const Color accent = Color(0xFFF87171); // Açık Kırmızı / Vurgu
  static const Color background = Color(0xFF0A0A0A); // Siyah
  static const Color surface = Color(0xFF1A1A1A); // Koyu Gri Kart Arka Plan
  static const Color text = Color(0xFFF8FAFC); // Off-White
  static const Color textSecondary = Color(0xFF9CA3AF); // Gri
  static const Color error = Color(0xFFEF4444); // Red
  static const Color success = Color(0xFF10B981); // Green
  static const Color warning = Color(0xFFF59E0B); // Amber

  // Gradient Renkler
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFF991B1B)], // Kırmızı to Koyu Kırmızı
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFFB91C1C), Color(0xFF7F1D1D)], // Koyu Kırmızı to Bordo
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFF87171), Color(0xFFEF4444)], // Açık Kırmızı to Kırmızı
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Health Connect'i konfigure et
  Health().configure();

  // Bildirim servisini başlat ve zamanlanmış bildirimleri kur
  final notifService = NotificationService();
  await notifService.init();
  await notifService.scheduleDailyNoonWalk();
  await notifService.scheduleSundayPointsReminder();

  runApp(const SporthinkApp());
}

class SporthinkApp extends StatelessWidget {
  const SporthinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sporthink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          error: AppColors.error,
          background: AppColors.background,
        ),
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,

        // AppBar Teması
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor:
              AppColors.background, // Match background for a seamless look
          foregroundColor: AppColors.text,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
            letterSpacing: 0.5,
          ),
          iconTheme: IconThemeData(color: AppColors.text, size: 24),
        ),

        // Card Teması
        cardTheme: CardThemeData(
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          color: AppColors.surface,
        ),

        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
          contentTextStyle: const TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),

        // ElevatedButton Teması
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: AppColors.primary.withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),

        // TextButton Teması
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.secondary,
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.secondary,
            side: const BorderSide(color: AppColors.secondary, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Icon Teması
        iconTheme: const IconThemeData(color: AppColors.primary, size: 24),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          labelStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
          hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
        ),

        // Text Teması
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: AppColors.text,
            letterSpacing: -0.5,
          ),
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
            letterSpacing: -0.5,
          ),
          bodyLarge: TextStyle(fontSize: 16, color: AppColors.text),
          bodyMedium: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),

        // BottomNavigationBar Teması
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.background,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),

        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surface,
          contentTextStyle: const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.textSecondary.withOpacity(0.2)),
          ),
          elevation: 8,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

/// Uygulama açılışında izinleri ve oturumu otomatik kontrol eden ekran.
/// İzinler varsa ve token varsa → HomeScreen
/// İzinler varsa ama token yoksa → AuthLandingScreen
/// İzinler yoksa → PermissionScreen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAndNavigate();
  }

  Future<void> _checkAndNavigate() async {
    // Kısa bir gecikme - splash hissi için
    await Future.delayed(const Duration(milliseconds: 500));

    // 1. Sağlık izinleri var mı kontrol et
    final health = Health();
    var types = [HealthDataType.STEPS];
    bool? hasPermissions = await health.hasPermissions(types);

    if (!mounted) return;

    if (hasPermissions != true) {
      // İzinler yok → İzin ekranına git
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PermissionScreen()),
      );
      return;
    }

    // 2. İzinler var, token var mı kontrol et
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      // Token var → Direkt ana sayfaya
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      // Token yok → Giriş/Kayıt sayfasına
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthLandingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        imageAsset: AppAssets.runningHeroPng,
        imageAlignment: Alignment.center,
        imageOpacity: 0.12,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppLogo(size: 120)
                  .animate()
                  .fadeIn(duration: 450.ms)
                  .scale(duration: 700.ms, curve: Curves.elasticOut),
              const SizedBox(height: 22),
              Text(
                'Sporthink',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Adımlarını puana dönüştür',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
