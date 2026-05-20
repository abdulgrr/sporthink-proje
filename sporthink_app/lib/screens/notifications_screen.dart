import 'package:flutter/material.dart';
import '../config/api_config.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';
import '../ui/app_background.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  String _filter = 'all'; // 'all', 'system', 'interaction'

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _markAllRead();
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk önce';
    if (diff.inHours < 24) return '${diff.inHours}s önce';
    if (diff.inDays < 7) return '${diff.inDays}g önce';
    return '${(diff.inDays / 7).floor()}h önce';
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/notifications?filter=$_filter'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 && mounted) {
        setState(() { _notifications = jsonDecode(response.body); _isLoading = false; });
      }
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _markAllRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/notifications/read-all'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (e) {}
  }

  Future<void> _deleteNotification(String id, int index) async {
    final removed = _notifications[index];
    setState(() => _notifications.removeAt(index));
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/notifications/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200 && mounted) {
        setState(() => _notifications.insert(index, removed));
      }
    } catch (e) {
      if (mounted) setState(() => _notifications.insert(index, removed));
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'system': return Icons.campaign_rounded;
      case 'leaderboard': return Icons.emoji_events_rounded;
      case 'quest': return Icons.task_alt_rounded;
      case 'like': return Icons.favorite_rounded;
      case 'comment': return Icons.chat_bubble_rounded;
      case 'reaction': return Icons.emoji_emotions_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'system': return AppColors.primary;
      case 'leaderboard': return AppColors.accent;
      case 'quest': return AppColors.secondary;
      case 'like': return Colors.red;
      case 'comment': return Colors.blue;
      case 'reaction': return Colors.orange;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.primaryGradient)),
      ),
      body: AppBackground(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // Filtre
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Container(
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    _buildFilterChip('all', 'Tümü'),
                    _buildFilterChip('system', 'Sistem'),
                    _buildFilterChip('interaction', 'Etkileşim'),
                  ],
                ),
              ),
            ),

            // Liste
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _notifications.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_off_rounded, size: 72, color: AppColors.textSecondary.withValues(alpha: 0.25)),
                                const SizedBox(height: 16),
                                Text(
                                  _filter == 'interaction' ? 'Henüz etkileşim bildirimi yok.' : _filter == 'system' ? 'Henüz sistem bildirimi yok.' : 'Henüz bir bildirimin yok.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchNotifications,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                            itemCount: _notifications.length,
                            itemBuilder: (context, index) {
                              final notif = _notifications[index];
                              final type = notif['type'] ?? '';
                              final isRead = notif['is_read'] == 1 || notif['is_read'] == true;
                              final color = _getColor(type);

                              return Dismissible(
                                key: Key(notif['id'].toString()),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.delete_rounded, color: Colors.red),
                                ),
                                onDismissed: (_) => _deleteNotification(notif['id'].toString(), index),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isRead ? AppColors.surface : AppColors.primary.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isRead ? AppColors.textSecondary.withValues(alpha: 0.08) : color.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 42, height: 42,
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(_getIcon(type), color: color, size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    notif['title'] ?? '',
                                                    style: TextStyle(fontWeight: isRead ? FontWeight.w600 : FontWeight.w800, fontSize: 14, color: AppColors.text),
                                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Text(
                                                  _timeAgo(notif['created_at']?.toString()),
                                                  style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 11),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              notif['message'] ?? '',
                                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3),
                                              maxLines: 2, overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ).animate().fadeIn(duration: 350.ms, delay: (index * 40).ms).slideX(begin: -0.04);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isActive = _filter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () { if (_filter != value) { setState(() => _filter = value); _fetchNotifications(); } },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isActive ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ),
    );
  }
}