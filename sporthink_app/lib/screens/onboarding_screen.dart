import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../main.dart';
import '../ui/app_background.dart';
import '../ui/app_assets.dart';
import 'avatar_setup_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      icon: Icons.directions_walk_rounded,
      iconColor: Color(0xFF00E676),
      title: 'Adım At, Puan Kazan!',
      description:
          'Günlük adımların otomatik olarak Health Connect üzerinden okunur ve puana çevrilir. Ne kadar çok yürürsen o kadar çok puan!',
      gradient: [Color(0xFF00E676), Color(0xFF00BFA5)],
    ),
    _OnboardingPage(
      icon: Icons.leaderboard_rounded,
      iconColor: Color(0xFFFFD740),
      title: 'Sıralamada Yarış!',
      description:
          'Haftalık sıralamada diğer kullanıcılarla yarış. Hafta sonunda en çok adım atan ilk 3 kişi ödül kazanır! Sıralama her Pazar sıfırlanır.',
      gradient: [Color(0xFFFFD740), Color(0xFFFF9100)],
    ),
    _OnboardingPage(
      icon: Icons.store_rounded,
      iconColor: Color(0xFF448AFF),
      title: 'Dükkan & Avatar',
      description:
          'Kazandığın puanlarla dükkandan sandık aç, avatarın için parçalar kazan! Avatarını kişiselleştir ve profilini öne çıkar.',
      gradient: [Color(0xFF448AFF), Color(0xFF7C4DFF)],
    ),
    _OnboardingPage(
      icon: Icons.shield_rounded,
      iconColor: Color(0xFFFF5252),
      title: 'Adil Oyun!',
      description:
          'Hile önleme sistemimiz sayesinde herkes eşit şartlarda yarışır. Her hesap haftada yalnızca bir cihaza bağlıdır. Sahte adım verileri otomatik filtrelenir.',
      gradient: [Color(0xFFFF5252), Color(0xFFFF1744)],
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      // Son sayfa — avatar kurulumuna git
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AvatarSetupScreen()),
      );
    }
  }

  void _skip() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AvatarSetupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        imageAsset: AppAssets.runningHeroPng,
        imageAlignment: Alignment.center,
        imageOpacity: 0.06,
        padding: EdgeInsets.zero,
        child: SafeArea(
          child: Column(
            children: [
              // Skip butonu
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 16),
                  child: TextButton(
                    onPressed: _skip,
                    child: Text(
                      'Atla',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              // Sayfalar
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Animated icon container
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: page.gradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(36),
                              boxShadow: [
                                BoxShadow(
                                  color: page.gradient[0].withValues(alpha: 0.4),
                                  blurRadius: 30,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              page.icon,
                              size: 56,
                              color: Colors.white,
                            ),
                          )
                              .animate(key: ValueKey('icon_$index'))
                              .fadeIn(duration: 400.ms)
                              .scale(
                                begin: const Offset(0.5, 0.5),
                                end: const Offset(1.0, 1.0),
                                duration: 500.ms,
                                curve: Curves.elasticOut,
                              ),

                          const SizedBox(height: 40),

                          // Başlık
                          Text(
                            page.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppColors.text,
                              letterSpacing: -0.5,
                            ),
                          )
                              .animate(key: ValueKey('title_$index'))
                              .fadeIn(delay: 150.ms, duration: 400.ms)
                              .slideY(begin: 0.3, end: 0, duration: 400.ms),

                          const SizedBox(height: 20),

                          // Açıklama
                          Text(
                            page.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                              .animate(key: ValueKey('desc_$index'))
                              .fadeIn(delay: 300.ms, duration: 400.ms)
                              .slideY(begin: 0.3, end: 0, duration: 400.ms),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Alt kısım: Dot indicator + buton
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                child: Column(
                  children: [
                    // Dot indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: _currentPage == index
                                ? LinearGradient(
                                    colors: _pages[_currentPage].gradient,
                                  )
                                : null,
                            color: _currentPage == index
                                ? null
                                : AppColors.textSecondary.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Sonraki / Başla butonu
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: ElevatedButton(
                          key: ValueKey(_currentPage == _pages.length - 1),
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _pages[_currentPage].gradient[0],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 8,
                            shadowColor: _pages[_currentPage].gradient[0].withValues(alpha: 0.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentPage == _pages.length - 1
                                    ? 'Hadi Başlayalım!'
                                    : 'Devam Et',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _currentPage == _pages.length - 1
                                    ? Icons.rocket_launch_rounded
                                    : Icons.arrow_forward_rounded,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final List<Color> gradient;

  const _OnboardingPage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.gradient,
  });
}
