import 'package:flutter/material.dart';
import '../config/api_config.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';
import '../ui/app_background.dart';
import '../ui/app_header.dart';

class DailyQuestsScreen extends StatefulWidget {
  const DailyQuestsScreen({super.key});

  @override
  State<DailyQuestsScreen> createState() => _DailyQuestsScreenState();
}

class _DailyQuestsScreenState extends State<DailyQuestsScreen> {
  List<dynamic> _quests = [];
  bool _isLoading = true;
  int _xp = 0;
  Map<String, dynamic>? _levelInfo;

  @override
  void initState() {
    super.initState();
    _fetchQuests();
  }

  Future<void> _fetchQuests() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/quests/today'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          _quests = data['quests'] ?? [];
          _xp = data['xp'] ?? 0;
          _levelInfo = data['level'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getQuestIcon(String questType) {
    switch (questType) {
      case 'steps':
        return Icons.directions_walk;
      case 'sync':
        return Icons.sync;
      case 'open_chest':
        return Icons.card_giftcard;
      case 'follow':
        return Icons.person_add;
      case 'shop_buy':
        return Icons.shopping_cart;
      case 'leaderboard':
        return Icons.leaderboard;
      case 'inventory_use':
        return Icons.backpack;
      default:
        return Icons.task_alt;
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.redAccent;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: AppBackground(
          padding: EdgeInsets.zero,
          useSafeArea: true,
          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      );
    }

    final completedCount = _quests.where((q) => q['is_completed'] == true).length;
    final totalCount = _quests.length;

    return AppBackground(
      useSafeArea: false,
      padding: EdgeInsets.zero,
      child: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Günlük görevler',
              leading: const Icon(Icons.task_alt_rounded, color: AppColors.secondary),
              actions: [
                IconButton(
                  onPressed: _fetchQuests,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Yenile',
                ),
              ],
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchQuests,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    if (_levelInfo != null) _buildLevelCard(),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: completedCount == totalCount
                            ? const LinearGradient(
                                colors: [AppColors.secondary, AppColors.success],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: (completedCount == totalCount ? AppColors.secondary : AppColors.primary).withOpacity(0.22),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            completedCount == totalCount ? Icons.emoji_events : Icons.assignment,
                            color: Colors.white,
                            size: 40,
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  completedCount == totalCount ? 'Tüm görevler tamamlandı!' : 'Bugünün görevleri',
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$completedCount / $totalCount tamamlandı',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: totalCount > 0 ? completedCount / totalCount : 0,
                                    backgroundColor: Colors.white24,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                    minHeight: 8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 450.ms).slideY(begin: -0.06),
                    const SizedBox(height: 20),
                    ...List.generate(_quests.length, (index) {
                      final quest = _quests[index];
                      return _buildQuestCard(quest).animate().fadeIn(duration: 450.ms, delay: (index * 70).ms).slideX(begin: -0.06);
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard() {
    final level = _levelInfo!['level'] ?? 1;
    final minXp = _levelInfo!['minXp'] ?? 0;
    final nextXp = _levelInfo!['nextXp'];

    double progress = 0;
    String xpText = '';

    if (nextXp != null) {
      final range = nextXp - minXp;
      final current = _xp - minXp;
      progress = range > 0 ? (current / range).clamp(0.0, 1.0) : 0;
      xpText = '$_xp / $nextXp XP';
    } else {
      progress = 1.0;
      xpText = '$_xp XP (MAX)';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            spreadRadius: 2,
            blurRadius: 15,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          // Level Badge
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: level >= 5
                    ? [Colors.amber.shade600, Colors.orange.shade800]
                    : level >= 3
                        ? [Colors.blue.shade400, Colors.indigo.shade600]
                        : [AppColors.primary, AppColors.secondary],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (level >= 5 ? Colors.amber : (level >= 3 ? Colors.blue : AppColors.primary)).withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$level',
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seviye $level',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.text),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.background,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      level >= 5 ? Colors.amber : (level >= 3 ? Colors.blue : AppColors.primary),
                    ),
                    minHeight: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(xpText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1, duration: 600.ms, curve: Curves.easeOut);
  }

  Widget _buildQuestCard(Map<String, dynamic> quest) {
    final bool isCompleted = quest['is_completed'] == true;
    final int currentValue = quest['current_value'] ?? 0;
    final int targetValue = quest['target_value'] ?? 1;
    final double progress = targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0;
    final Color questColor = _getDifficultyColor(quest['difficulty'] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isCompleted ? AppColors.success.withOpacity(0.05) : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isCompleted ? AppColors.success.withOpacity(0.3) : AppColors.textSecondary.withOpacity(0.1)),
        boxShadow: [
          if (!isCompleted)
            BoxShadow(
              color: AppColors.primary.withOpacity(0.05),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            // İkon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.success.withOpacity(0.15)
                    : questColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompleted ? Icons.check_circle : _getQuestIcon(quest['quest_type'] ?? ''),
                color: isCompleted ? AppColors.success : questColor,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            // Görev Bilgileri
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quest['title'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isCompleted ? AppColors.success : AppColors.text,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (quest['description'] != null && quest['description'].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        quest['description'],
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  const SizedBox(height: 12),
                  // Progress Bar
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: AppColors.background,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isCompleted ? AppColors.success : questColor,
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$currentValue / $targetValue',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isCompleted ? AppColors.success : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Ödül
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCompleted ? AppColors.success.withOpacity(0.1) : AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                isCompleted ? '✅' : '+${quest['reward_points']} XP',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: isCompleted ? AppColors.success : AppColors.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}