import 'dart:convert';
import '../config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../ui/app_background.dart';
import '../widgets/avatar_widget.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isOwnProfile = false;

  @override
  void initState() {
    super.initState();
    _fetchPublicProfile();
  }

  Future<void> _fetchPublicProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    
    if (token == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // JWT'den kendi user_id'mizi çıkar
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
        final payloadMap = jsonDecode(payload);
        if (payloadMap['id']?.toString() == widget.userId) {
          _isOwnProfile = true;
        }
      }
    } catch (_) {}

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/profile/public/${widget.userId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _user = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Sunucu ${response.statusCode} döndürdü. ID: ${widget.userId}';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_user == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) return;

    final isFollowing = _user!['is_following'];
    final endpoint = isFollowing ? '/api/profile/unfollow' : '/api/profile/follow';

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'target_id': widget.userId}),
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _user!['is_following'] = !isFollowing;
          _user!['followers_count'] += isFollowing ? -1 : 1;
        });
      }
    } catch (e) {
      // Hata
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: AppBackground(
          padding: EdgeInsets.zero,
          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      );
    }

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profil Bulunamadı'),
          elevation: 0,
          flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.primaryGradient)),
        ),
        body: AppBackground(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Kullanıcı bilgileri yüklenemedi.\nHata: ${_errorMessage ?? ''}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    final user = _user!;

    return Scaffold(
      appBar: AppBar(
        title: Text('@${user['username'] ?? 'kullanici'}'),
        elevation: 0,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.primaryGradient)),
      ),
      body: AppBackground(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Column(
            children: [
              Center(
                child: AvatarWidget(
                  config: AvatarWidget.parseConfig(user['avatar_url']),
                  size: 120,
                  showBorder: false,
                ),
              ).animate().fadeIn(duration: 450.ms).scale(duration: 650.ms, curve: Curves.elasticOut),
              const SizedBox(height: 14),
              Text(
                '${user['first_name']} ${user['last_name']}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.text),
              ).animate().fadeIn(duration: 450.ms, delay: 120.ms).slideY(begin: -0.08),
              const SizedBox(height: 6),
              Text(
                '@${user['username'] ?? 'kullaniciadi'}',
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ).animate().fadeIn(duration: 450.ms, delay: 170.ms),
              const SizedBox(height: 14),
              if (!_isOwnProfile)
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _toggleFollow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: user['is_following'] ? AppColors.textSecondary : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      user['is_following'] ? 'Takiptesin' : 'Takip Et',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ).animate().fadeIn(duration: 450.ms, delay: 220.ms).slideY(begin: 0.08),
              const SizedBox(height: 20),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatColumn('Seri', '${user['current_streak']}g', AppColors.accent),
                      _buildStatColumn('Takipçi', '${user['followers_count']}', AppColors.primary),
                      _buildStatColumn('Takip', '${user['following_count']}', AppColors.secondary),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 450.ms, delay: 280.ms),
              const SizedBox(height: 16),
              if (user['level_info'] != null) _buildLevelXpBar(user),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Rozetler',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 12),
              if (user['badges'].isEmpty)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text('Henüz rozet kazanmadı.', style: TextStyle(color: AppColors.textSecondary)),
                ),
              if (user['badges'].isNotEmpty)
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

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), spreadRadius: 1, blurRadius: 5)],
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
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
              child: Text('$level', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Seviye $level', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text)),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.background,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      level >= 5 ? Colors.amber : (level >= 3 ? Colors.blue : Colors.grey.shade600),
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(xpText, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(
      duration: 600.ms,
      delay: 700.ms,
    ).slideX(
      begin: -20,
      duration: 600.ms,
      curve: Curves.easeOut,
    );
  }
}