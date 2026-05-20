import 'package:flutter/material.dart';
import '../config/api_config.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'home_screen.dart';
import '../main.dart';
import '../ui/app_background.dart';
import '../widgets/avatar_widget.dart';

class AvatarSetupScreen extends StatefulWidget {
  const AvatarSetupScreen({super.key});

  @override
  State<AvatarSetupScreen> createState() => _AvatarSetupScreenState();
}

class _AvatarSetupScreenState extends State<AvatarSetupScreen> {
  // Sadece ücretsiz seçenekler
  final List<String> _eyeOptions = ['goz_normal', 'goz_anime', 'goz_kedi', 'goz_gozluk', 'goz_kizgin', 'goz_sevinc', 'goz_olu'];
  final List<String> _mouthOptions = ['agiz_mutlu', 'agiz_gulumse', 'agiz_yanyatmis3', 'agiz_blehh', 'agiz_duzblehh', 'agiz_vampir', 'agiz_s', 'agiz_uzgun', 'agiz_roblox', 'agiz_altindis'];
  final List<String?> _headOptions = [null, 'kafa_tac', 'kafa_seytan', 'kafa_boynuz', 'kafa_gentleman', 'kafa_mohawk', 'kafa_kedi', 'kafa_ampul', 'kafa_itsthejuuz', 'kafa_ratatuy'];

  final List<Color> _skinColors = [
    const Color(0xFFFDECE0), const Color(0xFFF5D6BA), const Color(0xFFE8B88A),
    const Color(0xFFD4956B), const Color(0xFFAD7A5B), const Color(0xFF8B5E3C),
    const Color(0xFF614B3A), const Color(0xFFFFD700), const Color(0xFF87CEEB),
    const Color(0xFFB8F5B0), const Color(0xFFE6A8D7), const Color(0xFFD8BFD8),
  ];

  int _selectedEyeIndex = 0;
  int _selectedMouthIndex = 0;
  int _selectedHeadIndex = 0;
  int _selectedSkinIndex = 1;

  final Map<String, String> _displayNames = {
    'goz_normal': 'Normal', 'goz_anime': 'Anime', 'goz_kedi': 'Kedi', 'goz_gozluk': 'Gözlük',
    'goz_kizgin': 'Kızgın', 'goz_sevinc': 'Sevinç', 'goz_olu': 'X_X',
    'agiz_mutlu': 'Mutlu', 'agiz_gulumse': 'Gülümse', 'agiz_yanyatmis3': ':3',
    'agiz_blehh': 'Blehh', 'agiz_duzblehh': 'Düz Blehh', 'agiz_vampir': 'Vampir',
    'agiz_s': 'S', 'agiz_uzgun': 'Üzgün', 'agiz_roblox': 'Roblox', 'agiz_altindis': 'Altın Diş',
    'kafa_tac': 'Taç', 'kafa_seytan': 'Şeytan', 'kafa_boynuz': 'Boynuz',
    'kafa_gentleman': 'Gentleman', 'kafa_mohawk': 'Mohawk', 'kafa_kedi': 'Kedi Kulak',
    'kafa_ampul': 'Ampul', 'kafa_itsthejuuz': 'Juice', 'kafa_ratatuy': 'Ratatuy',
  };

  bool _isLoading = false;

  Future<void> _completeSetup() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final requestBody = jsonEncode({
        'skin': _selectedSkinIndex,
        'eyes': _eyeOptions[_selectedEyeIndex],
        'mouth': _mouthOptions[_selectedMouthIndex],
        'head': _headOptions[_selectedHeadIndex],
      });

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/avatar/save'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: requestBody,
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hata oluştu!')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        useSafeArea: false,
        padding: EdgeInsets.zero,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('Karakterini Oluştur', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.text)),
                    const SizedBox(height: 8),
                    const Text('Hoş geldin! Seni yansıtacak bir avatar seç.', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ).animate().fadeIn(duration: 500.ms),
              _buildAvatarPreview(),
              const SizedBox(height: 16),
              _buildSkinColorPicker(),
              const SizedBox(height: 8),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: DefaultTabController(
                    length: 3,
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                          child: const TabBar(
                            indicatorColor: AppColors.primary,
                            indicatorSize: TabBarIndicatorSize.label,
                            labelColor: AppColors.primary,
                            unselectedLabelColor: AppColors.textSecondary,
                            tabs: [
                              Tab(text: '👀 Gözler'), Tab(text: '👄 Ağız'), Tab(text: '🎩 Kafa'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildPartGrid(_eyeOptions.cast<String?>(), _selectedEyeIndex, (i) => setState(() => _selectedEyeIndex = i), allowNone: false),
                              _buildPartGrid(_mouthOptions.cast<String?>(), _selectedMouthIndex, (i) => setState(() => _selectedMouthIndex = i), allowNone: false),
                              _buildPartGrid(_headOptions, _selectedHeadIndex, (i) => setState(() => _selectedHeadIndex = i), allowNone: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _completeSetup,
                    child: _isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Tamamla ve Başla', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ).animate().slideY(begin: 1.0, duration: 500.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPreview() {
    const double circleSize = 150;
    const double partSize = circleSize * 0.75;
    const double mouthSize = partSize * 0.82;
    const double headSize = circleSize * 1.1;

    return SizedBox(
      width: circleSize + 60,
      height: circleSize + 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 0,
            child: Container(
              width: circleSize, height: circleSize,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _skinColors[_selectedSkinIndex]),
              child: ClipOval(
                child: Stack(
                  children: [
                    Positioned(left: (circleSize - partSize) / 2, top: circleSize * 0.05, child: AvatarWidget.avatarImage(_eyeOptions[_selectedEyeIndex], partSize, partSize)),
                    Positioned(left: (circleSize - mouthSize) / 2, bottom: -circleSize * 0.04, child: AvatarWidget.avatarImage(_mouthOptions[_selectedMouthIndex], mouthSize, mouthSize)),
                  ],
                ),
              ),
            ),
          ),
          if (_headOptions[_selectedHeadIndex] != null)
            Positioned(top: -20, child: AvatarWidget.avatarImage(_headOptions[_selectedHeadIndex]!, headSize, headSize)),
        ],
      ),
    ).animate().scale(duration: 300.ms, curve: Curves.easeOut);
  }

  Widget _buildSkinColorPicker() {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _skinColors.length,
        itemBuilder: (context, index) {
          final color = _skinColors[index];
          final isSelected = _selectedSkinIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedSkinIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              width: 48,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? AppColors.primary : Colors.black12, width: isSelected ? 3 : 1),
                boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)] : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPartGrid(List<String?> options, int selectedIndex, Function(int) onSelect, {required bool allowNone}) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.85),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final isSelected = selectedIndex == index;
        final name = options[index];
        final isNone = name == null;

        return GestureDetector(
          onTap: () => onSelect(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withOpacity(0.15) : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? AppColors.primary : AppColors.textSecondary.withOpacity(0.1), width: isSelected ? 2.5 : 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(child: Padding(padding: const EdgeInsets.all(8), child: isNone ? Icon(Icons.block, color: AppColors.textSecondary.withOpacity(0.3), size: 36) : AvatarWidget.avatarImage(name, 36, 36))),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(isNone ? 'Yok' : (_displayNames[name] ?? name), style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppColors.primary : AppColors.textSecondary), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 300.ms, delay: (index * 30).ms);
      },
    );
  }
}