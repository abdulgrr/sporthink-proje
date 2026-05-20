import 'package:flutter/material.dart';
import '../config/api_config.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'profile_edit_screen.dart';
import 'search_users_screen.dart';
import 'public_profile_screen.dart';
import 'avatar_editor_screen.dart';
import '../main.dart';
import '../ui/app_background.dart';
import '../ui/app_assets.dart';
import '../ui/app_header.dart';
import '../widgets/avatar_widget.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _profileData = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showFollowList(String type) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return FutureBuilder(
          future: http.get(Uri.parse('${ApiConfig.baseUrl}/api/profile/$type'), headers: {'Authorization': 'Bearer $token'}),
          builder: (context, AsyncSnapshot<http.Response> snapshot) {
            if (!snapshot.hasData) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
            if (snapshot.data!.statusCode != 200) return const Center(child: Text('Hata oluştu.', style: TextStyle(color: AppColors.error)));

            final List<dynamic> users = jsonDecode(snapshot.data!.body);
            if (users.isEmpty) return const Center(child: Text('Liste boş.', style: TextStyle(color: AppColors.textSecondary)));

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final u = users[index];
                return ListTile(
                  onTap: () {
                    Navigator.pop(context); // Kapat bottom sheet'i
                    if (u['id'] != null) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => PublicProfileScreen(userId: u['id'])));
                    }
                  },
                  leading: AvatarWidget(
                    config: AvatarWidget.parseConfig(u['avatar_url']),
                    size: 40,
                    showBorder: false,
                  ),
                  title: Text('${u['first_name'] ?? ''} ${u['last_name'] ?? ''}', style: const TextStyle(color: AppColors.text)),
                );
              },
            );
          },
        );
      }
    );
  }

  Widget _buildStatColumn(String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_profileData == null) return const Center(child: Text('Profil yüklenemedi.'));

    final user = _profileData!;

    return AppBackground(
      useSafeArea: false,
      padding: EdgeInsets.zero,
      imageAsset: AppAssets.runningJpg2,
      imageAlignment: Alignment.topCenter,
      imageOpacity: 0.22,
      overlayOpacity: 0.06,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchProfile,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            children: [
              AppHeader(
                title: 'Profil',
                leading: const Icon(Icons.person_rounded, color: AppColors.primary),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search_rounded),
                    tooltip: 'Kullanıcı ara',
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchUsersScreen())).then((_) => _fetchProfile()),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    tooltip: 'Düzenle',
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileEditScreen(currentData: user))).then((_) => _fetchProfile()),
                  ),
                ],
              ),

              // Hero card
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar & Basic Info
                        Expanded(
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const AvatarEditorScreen()),
                                  ).then((_) => _fetchProfile());
                                },
                                child: Stack(
                                  children: [
                                    AvatarWidget(
                                      config: AvatarWidget.parseConfig(user['avatar_url']),
                                      size: 68,
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.edit, color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${user['first_name']} ${user['last_name']}',
                                      style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w900, fontSize: 20),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '@${user['username'] ?? 'kullaniciadi'}',
                                      style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Logo
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/sporthink.png',
                            width: 48,
                            height: 48,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn('Takipçiler', '${user['followers_count']}', onTap: () => _showFollowList('followers')),
                        Container(width: 1, height: 40, color: AppColors.textSecondary.withOpacity(0.2)),
                        _buildStatColumn('Takip', '${user['following_count']}', onTap: () => _showFollowList('following')),
                        Container(width: 1, height: 40, color: AppColors.textSecondary.withOpacity(0.2)),
                        // Flame Streak
                        Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.local_fire_department, color: AppColors.accent, size: 28),
                                const SizedBox(width: 4),
                                Text('${user['current_streak']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.text)),
                              ],
                            ),
                            const Text('Seri', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.06),

              const SizedBox(height: 14),

              if (user['level_info'] != null) _buildLevelXpBar(user),

              const SizedBox(height: 18),

              // Badges Section
              Row(
                children: [
                  const Icon(Icons.military_tech, color: AppColors.secondary, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kazanılan Rozetler',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20),
                    ),
                  ),
                  if ((user['badges'] as List).isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(user['badges'] as List).length}',
                        style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w900),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if ((user['badges'] as List).isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.textSecondary.withOpacity(0.1)),
                  ),
                  child: const Center(
                    child: Text('Henüz rozet kazanmadınız.', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  ),
                )
              else
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: user['badges'].length,
                    itemBuilder: (context, index) {
                      final badge = user['badges'][index];
                      return Container(
                        width: 120,
                        margin: EdgeInsets.only(right: index == user['badges'].length - 1 ? 0 : 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                          boxShadow: [
                            BoxShadow(color: AppColors.primary.withOpacity(0.05), blurRadius: 10, spreadRadius: 2),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.network(
                              '${ApiConfig.baseUrl}${badge['iconUrl'] ?? ''}',
                              width: 50,
                              height: 50,
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, color: AppColors.textSecondary, size: 40),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              badge['title']?.toString() ?? 'Rozet',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.text),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: (index * 50).ms).scale(begin: const Offset(0.9, 0.9));
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelXpBar(Map<String, dynamic> user) {
    final levelInfo = user['level_info'];
    final int level = levelInfo['level'] ?? 1;
    final int minXp = levelInfo['minXp'] ?? 0;
    final nextXp = levelInfo['nextXp'];
    final int xp = user['xp'] ?? 0;

    double progress = 0;
    String xpText = '';

    if (nextXp != null) {
      final range = nextXp - minXp;
      final current = xp - minXp;
      progress = range > 0 ? (current / range).clamp(0.0, 1.0) : 0;
      xpText = '$xp / $nextXp XP';
    } else {
      progress = 1.0;
      xpText = '$xp XP';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), spreadRadius: 1, blurRadius: 5)],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: level >= 5
                    ? [Colors.amber.shade600, Colors.orange.shade800]
                    : level >= 3
                        ? [Colors.blue.shade400, Colors.indigo.shade600]
                        : [Colors.grey.shade400, Colors.grey.shade600],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$level', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Seviye $level', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.background,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      level >= 5 ? Colors.amber : (level >= 3 ? Colors.blue : Colors.grey.shade600),
                    ),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(xpText, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(
      duration: 600.ms,
      delay: 500.ms,
    ).slideX(
      begin: -20,
      duration: 600.ms,
      curve: Curves.easeOut,
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
        ],
      ),
    );
  }
}