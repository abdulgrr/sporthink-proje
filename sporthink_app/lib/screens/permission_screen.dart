import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'auth_landing_screen.dart';
import '../main.dart';
import '../ui/app_assets.dart';
import '../ui/app_background.dart';
import '../ui/app_logo.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

// WidgetsBindingObserver ekleyerek uygulama hareketlerini (arka plan/ön plan) izliyoruz
class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Gözlemciyi başlat
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Gözlemciyi kaldır
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Kullanıcı ayarlardan geri döndüğünde burası tetiklenir
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Uygulama ön plana geldi, izinleri sessizce tekrar kontrol et
      checkPermissionsSilently();
    }
  }

  // Butona basıldığında veya geri dönüldüğünde çalışan kontrol mekanizması
  Future<void> checkPermissionsSilently() async {
    final health = Health();
    var types = [HealthDataType.STEPS];

    // Health Connect izni var mı? (Sadece kontrol, popup açmaz)
    bool? hasPermissions = await health.hasPermissions(types);

    if (hasPermissions == true) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthLandingScreen()),
      );
    }
  }

  Future<void> requestPermissions() async {
    setState(() => _isLoading = true);

    try {
      // 1. Sensör İzni
      await Permission.activityRecognition.request();

      // 2. Health Connect İzni
      final health = Health();
      var types = [HealthDataType.STEPS];

      bool authorized = await health.requestAuthorization(types);

      if (authorized) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthLandingScreen()),
        );
      } else {
        if (!mounted) return;
        _showManualPermissionDialog();
      }
    } catch (e) {
      _showManualPermissionDialog();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showManualPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Kullanıcı izni vermeden kapatamasın
      builder: (context) => AlertDialog(
        title: const Text("İzin Gerekli"),
        content: const Text(
          "Uygulamanın çalışması için Sağlık (Health Connect) izinlerine ihtiyaç var.\n\n"
          "1. Ayarları Aç butonuna basın.\n"
          "2. İzinler -> Health Connect yolunu izleyin.\n"
          "3. 'Tümüne İzin Ver' seçeneğini işaretleyin.",
        ),
        actions: [
          TextButton(
            onPressed: () => openAppSettings(),
            child: const Text("Ayarları Aç"),
          ),
          // Kullanıcı manuel kontrol etmek isterse diye bir buton
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              checkPermissionsSilently();
            },
            child: const Text("İzni Kontrol Et"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        imageAsset: AppAssets.runningHeroPng,
        imageAlignment: Alignment.center,
        imageOpacity: 0.14,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const Spacer(),
            const AppLogo(size: 104).animate().fadeIn(duration: 450.ms).scale(duration: 650.ms, curve: Curves.elasticOut),
            const SizedBox(height: 18),
            Text(
              "İzin gerekiyor",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              "Adımlarını okuyup sana puan verebilmemiz için Health Connect iznine ihtiyacımız var. İzinleri dilediğin zaman ayarlardan yönetebilirsin.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.35),
            ),
            const SizedBox(height: 18),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: const [
                    _PermissionStepRow(index: 1, text: "Sensör (activity recognition) iznini ver"),
                    SizedBox(height: 10),
                    _PermissionStepRow(index: 2, text: "Health Connect üzerinden adım verisine izin ver"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.orange.shade300, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Telefonunuzda Google Fit ve Health Connect uygulamalarının yüklü olması gerekiyor.",
                      style: TextStyle(
                        color: Colors.orange.shade200,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: requestPermissions,
                        icon: const Icon(Icons.lock_open_rounded),
                        label: const Text("İzin ver ve başla", style: TextStyle(fontSize: 16)),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => openAppSettings(),
                icon: const Icon(Icons.settings_outlined),
                label: const Text("Ayarları aç"),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _PermissionStepRow extends StatelessWidget {
  const _PermissionStepRow({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
          ),
        ),
      ],
    );
  }
}