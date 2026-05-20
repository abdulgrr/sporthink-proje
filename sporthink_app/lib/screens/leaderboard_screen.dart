import 'package:flutter/material.dart';
import '../config/api_config.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'public_profile_screen.dart';
import '../main.dart';
import '../ui/app_background.dart';
import '../ui/app_header.dart';
import '../widgets/avatar_widget.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<dynamic> _leaderboard = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/leaderboard'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _leaderboard = data['data'];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      useSafeArea: false,
      padding: EdgeInsets.zero,
      child: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Sıralama',
              leading: const Icon(Icons.emoji_events_rounded, color: AppColors.accent),
              actions: [
                IconButton(
                  onPressed: _fetchLeaderboard,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Yenile',
                ),
              ],
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _leaderboard.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Bu hafta henüz puan kazanan kimse yok!',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                          itemCount: _leaderboard.length,
                          itemBuilder: (context, index) {
                            final user = _leaderboard[index];
                            final isTop3 = index < 3;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isTop3 ? AppColors.accent.withOpacity(0.3) : AppColors.textSecondary.withOpacity(0.1),
                                ),
                                boxShadow: [
                                  if (isTop3)
                                    BoxShadow(
                                      color: AppColors.accent.withOpacity(0.1),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                onTap: () {
                                  if (user['id'] != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PublicProfileScreen(userId: user['id'].toString()),
                                      ),
                                    );
                                  }
                                },
                                leading: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        gradient: isTop3
                                            ? (index == 0
                                                ? const LinearGradient(colors: [Colors.amber, Colors.orange])
                                                : index == 1
                                                    ? LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade500])
                                                    : LinearGradient(colors: [Colors.brown.shade300, Colors.brown.shade500]))
                                            : null,
                                        color: isTop3 ? null : AppColors.background,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          if (isTop3)
                                            BoxShadow(
                                              color: (index == 0 ? Colors.amber : (index == 1 ? Colors.grey : Colors.brown)).withOpacity(0.4),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                            ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                          color: isTop3 ? Colors.white : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    AvatarWidget(
                                      config: AvatarWidget.parseConfig(user['avatar_url']),
                                      size: 48,
                                      showBorder: false,
                                    ),
                                  ],
                                ),
                                title: Text(
                                  '${user['first_name']} ${user['last_initial']}',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.text),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: (isTop3 ? AppColors.accent : AppColors.secondary).withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    '${user['total_score']} XP',
                                    style: TextStyle(
                                      color: isTop3 ? AppColors.accent : AppColors.secondary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ).animate().fadeIn(duration: 450.ms, delay: (index * 70).ms).slideX(begin: -0.06);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}