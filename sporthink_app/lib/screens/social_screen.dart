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

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});
  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _leaderboard = [];
  bool _isLoadingLeaderboard = true;
  String _leaderboardFilter = 'global';
  List<dynamic> _feed = [];
  bool _isLoadingFeed = true;
  String? _myUserId;

  static const _reactionEmojis = {
    'fire': '🔥', 'muscle': '💪', 'party': '🎉', 'clap': '👏', 'wow': '😮',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (_tabController.index == 0) _fetchFeed(); else _fetchLeaderboard();
    });
    _fetchFeed();
    _fetchLeaderboard();
    _loadMyUserId();
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  // ─── Zaman formatı ───
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

  // ─── DATA FETCH ───
  Future<void> _fetchLeaderboard() async {
    setState(() => _isLoadingLeaderboard = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/leaderboard?filter=$_leaderboardFilter'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 && mounted) {
        setState(() { _leaderboard = jsonDecode(response.body)['data']; _isLoadingLeaderboard = false; });
      }
    } catch (e) { if (mounted) setState(() => _isLoadingLeaderboard = false); }
  }

  Future<void> _fetchFeed() async {
    setState(() => _isLoadingFeed = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/social/feed'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 && mounted) {
        setState(() { _feed = jsonDecode(response.body)['data']; _isLoadingFeed = false; });
      }
    } catch (e) { if (mounted) setState(() => _isLoadingFeed = false); }
  }

  Future<void> _loadMyUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) return;
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
        final data = jsonDecode(payload);
        _myUserId = data['id']?.toString();
      }
    } catch (_) {}
  }

  Future<void> _deleteComment(String commentId, int feedIndex, int commentIndex) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/social/comment/$commentId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          final comments = List<dynamic>.from(_feed[feedIndex]['recent_comments'] ?? []);
          comments.removeAt(commentIndex);
          _feed[feedIndex]['recent_comments'] = comments;
          _feed[feedIndex]['comments_count'] = (_feed[feedIndex]['comments_count'] ?? 1) - 1;
        });
      }
    } catch (e) {}
  }

  // ─── LIKE ───
  Future<void> _toggleLike(int index) async {
    final item = _feed[index];
    final wasLiked = item['is_liked'] == true;
    // Optimistic update
    setState(() {
      item['is_liked'] = !wasLiked;
      item['likes_count'] = (item['likes_count'] ?? 0) + (wasLiked ? -1 : 1);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/social/like'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'feed_id': item['id'].toString()}),
      );
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() => item['likes_count'] = data['likes_count']);
      }
    } catch (e) {
      // Revert
      if (mounted) setState(() { item['is_liked'] = wasLiked; item['likes_count'] = (item['likes_count'] ?? 0) + (wasLiked ? 1 : -1); });
    }
  }

  // ─── REACTION ───
  Future<void> _toggleReaction(String feedId, String reactionType, int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/social/react'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'feed_id': feedId, 'reaction_type': reactionType}),
      );
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          final item = _feed[index];
          if (data['action'] == 'removed') {
            item['my_reaction'] = null;
            item['total_reactions'] = (item['total_reactions'] ?? 1) - 1;
          } else if (data['action'] == 'added') {
            item['my_reaction'] = reactionType;
            item['total_reactions'] = (item['total_reactions'] ?? 0) + 1;
          } else {
            item['my_reaction'] = reactionType;
          }
        });
      }
    } catch (e) {}
  }

  // ─── COMMENT ───
  Future<void> _addComment(int index, String content) async {
    if (content.trim().isEmpty) return;
    final item = _feed[index];
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/social/comment'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'feed_id': item['id'].toString(), 'content': content.trim()}),
      );
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          final comments = List<dynamic>.from(item['recent_comments'] ?? []);
          comments.insert(0, data['comment']);
          if (comments.length > 2) comments.removeLast();
          item['recent_comments'] = comments;
          item['comments_count'] = data['comments_count'];
        });
      }
    } catch (e) {}
  }

  void _showReactionPicker(BuildContext context, String feedId, int index, RenderBox box) {
    final overlay = Overlay.of(context);
    final pos = box.localToGlobal(Offset.zero);
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (ctx) {
      return Stack(
        children: [
          GestureDetector(onTap: () => entry.remove(), child: Container(color: Colors.transparent, width: double.infinity, height: double.infinity)),
          Positioned(
            left: pos.dx - 40,
            top: pos.dy - 52,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _reactionEmojis.entries.map((e) {
                    final isSelected = _feed[index]['my_reaction'] == e.key;
                    return GestureDetector(
                      onTap: () { entry.remove(); _toggleReaction(feedId, e.key, index); },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(e.value, style: const TextStyle(fontSize: 22)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ).animate().fadeIn(duration: 150.ms).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 200.ms, curve: Curves.easeOut),
          ),
        ],
      );
    });
    overlay.insert(entry);
  }

  void _showCommentSheet(int index) {
    final controller = TextEditingController();
    final item = _feed[index];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 16, left: 16, right: 16, top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Yorumlar', style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            if ((item['recent_comments'] as List?)?.isNotEmpty == true)
              ...List.generate((item['recent_comments'] as List).length, (i) {
                final c = item['recent_comments'][i];
                final isPostOwner = _myUserId != null && item['user_id']?.toString() == _myUserId;
                final isCommentOwner = _myUserId != null && c['user_id']?.toString() == _myUserId;
                final canDelete = isPostOwner || isCommentOwner;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AvatarWidget(config: c['avatar_config'] != null ? Map<String, dynamic>.from(c['avatar_config']) : null, size: 28, showBorder: false),
                      const SizedBox(width: 8),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${c['first_name']} ${c['last_initial'] ?? ''}', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(c['content'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      )),
                      if (canDelete)
                        GestureDetector(
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: ctx,
                              builder: (d) => AlertDialog(
                                backgroundColor: AppColors.surface,
                                title: const Text('Yorumu Sil', style: TextStyle(color: AppColors.text)),
                                content: const Text('Bu yorumu silmek istediğine emin misin?', style: TextStyle(color: AppColors.textSecondary)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('İptal')),
                                  TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Sil', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              _deleteComment(c['id'].toString(), index, i);
                              if (ctx.mounted) Navigator.pop(ctx);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red.withValues(alpha: 0.5)),
                          ),
                        ),
                    ],
                  ),
                );
              })
            else
              Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('Henüz yorum yok.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    maxLength: 100,
                    style: const TextStyle(color: AppColors.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Yorum yaz...',
                      hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (controller.text.trim().isNotEmpty) {
                      _addComment(index, controller.text);
                      Navigator.pop(ctx);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ─── FEED TAB ───
  Widget _buildFeedTab() {
    if (_isLoadingFeed) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_feed.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Henüz bir hareket yok. Biraz adım atıp rozet kazanmaya ne dersin?', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium)));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _feed.length,
      itemBuilder: (context, index) {
        final item = _feed[index];
        final eventType = item['event_type'];
        final data = item['event_data'];

        IconData eventIcon = Icons.star;
        Color eventColor = Colors.orange;
        String eventTitle = '', eventDescription = '';

        if (eventType == 'badge') { eventIcon = Icons.military_tech; eventColor = Colors.amber; eventTitle = 'Yeni Rozet!'; eventDescription = '${item['first_name']} bir rozet kazandı: ${data['badge_name']}'; }
        else if (eventType == 'level') { eventIcon = Icons.star; eventColor = Colors.orange; eventTitle = 'Seviye Atladı!'; eventDescription = '${item['first_name']}, Seviye ${data['level']} oldu!'; }
        else if (eventType == 'streak') { eventIcon = Icons.local_fire_department; eventColor = Colors.deepOrange; eventTitle = 'Yeni Seri!'; eventDescription = '${item['first_name']}, tam ${data['streak']} gündür hedefini tutturuyor! 🔥'; }
        else if (eventType == 'weekly_rank') { eventIcon = Icons.emoji_events; eventColor = Colors.purple; eventTitle = 'Sıralama Başarısı!'; eventDescription = '${item['first_name']}, geçen haftayı ${data['rank_text']}'; }
        else if (eventType == 'follower_milestone') { eventIcon = Icons.people_rounded; eventColor = Colors.teal; eventTitle = 'Popülerlik!'; eventDescription = '${item['first_name']}, ${data['followers']} takipçiye ulaştı! 🎉'; }
        else { return const SizedBox.shrink(); }

        final isLiked = item['is_liked'] == true;
        final likesCount = item['likes_count'] ?? 0;
        final commentsCount = item['comments_count'] ?? 0;
        final myReaction = item['my_reaction'];
        final reactionBreakdown = List<dynamic>.from(item['reaction_breakdown'] ?? []);

        return GestureDetector(
          onDoubleTap: () { if (!isLiked) _toggleLike(index); },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: eventColor.withValues(alpha: 0.2)),
              boxShadow: [BoxShadow(color: AppColors.textSecondary.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Üst: Avatar + İçerik + Zaman
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () { if (item['user_id'] != null) Navigator.push(context, MaterialPageRoute(builder: (c) => PublicProfileScreen(userId: item['user_id'].toString()))); },
                      child: AvatarWidget(config: item['avatar_config'] ?? AvatarWidget.parseConfig(item['avatar_url']), size: 48, showBorder: false),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(eventIcon, color: eventColor, size: 18),
                          const SizedBox(width: 5),
                          Text(eventTitle, style: TextStyle(color: eventColor, fontWeight: FontWeight.bold, fontSize: 13)),
                          const Spacer(),
                          Text(_timeAgo(item['created_at']?.toString()), style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 11)),
                        ]),
                        const SizedBox(height: 4),
                        Text(eventDescription, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    )),
                  ],
                ),

                const SizedBox(height: 12),

                // Tepki baloncukları (sadece atılmış olanlar)
                if (reactionBreakdown.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 6,
                      children: reactionBreakdown.map<Widget>((r) {
                        final emoji = _reactionEmojis[r['reaction_type']] ?? '❓';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                          child: Text('$emoji ${r['count']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        );
                      }).toList(),
                    ),
                  ),

                // Alt bar: ❤️ Beğeni | 😊 Tepki | 💬 Yorum
                Container(
                  padding: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.1)))),
                  child: Row(
                    children: [
                      // ❤️ Beğeni
                      _ActionButton(
                        icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isLiked ? Colors.red : AppColors.textSecondary,
                        label: likesCount > 0 ? '$likesCount' : '',
                        onTap: () => _toggleLike(index),
                      ),
                      const SizedBox(width: 16),

                      // 😊 Tepki
                      Builder(builder: (ctx) {
                        return _ActionButton(
                          icon: null,
                          emoji: myReaction != null ? _reactionEmojis[myReaction] : '😊',
                          color: myReaction != null ? AppColors.primary : AppColors.textSecondary,
                          label: '',
                          onTap: () {
                            final box = ctx.findRenderObject() as RenderBox;
                            _showReactionPicker(context, item['id'].toString(), index, box);
                          },
                        );
                      }),
                      const SizedBox(width: 16),

                      // 💬 Yorum
                      _ActionButton(
                        icon: Icons.chat_bubble_outline_rounded,
                        color: AppColors.textSecondary,
                        label: commentsCount > 0 ? '$commentsCount' : '',
                        onTap: () => _showCommentSheet(index),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: (index * 50).ms).slideX(begin: 0.1);
      },
    );
  }

  // ─── LEADERBOARD TAB ───
  Widget _buildLeaderboardTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _buildFilterButton('global', 'Global'),
                _buildFilterButton('friends', 'Arkadaşlar'),
              ],
            ),
          ),
        ),
        Expanded(
          child: _isLoadingLeaderboard
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _leaderboard.isEmpty
                  ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_leaderboardFilter == 'friends' ? 'Takip ettiğin kimse henüz adım atmamış!' : 'Bu hafta henüz adım atan kimse yok!', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                      itemCount: _leaderboard.length,
                      itemBuilder: (context, index) {
                        final user = _leaderboard[index];
                        final isTop3 = index < 3;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.surface, borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: isTop3 ? AppColors.accent.withValues(alpha: 0.3) : AppColors.textSecondary.withValues(alpha: 0.1)),
                            boxShadow: [if (isTop3) BoxShadow(color: AppColors.accent.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            onTap: () { if (user['id'] != null) Navigator.push(context, MaterialPageRoute(builder: (c) => PublicProfileScreen(userId: user['id'].toString()))); },
                            leading: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  gradient: isTop3 ? (index == 0 ? const LinearGradient(colors: [Colors.amber, Colors.orange]) : index == 1 ? LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade500]) : LinearGradient(colors: [Colors.brown.shade300, Colors.brown.shade500])) : null,
                                  color: isTop3 ? null : AppColors.background, shape: BoxShape.circle,
                                  boxShadow: [if (isTop3) BoxShadow(color: (index == 0 ? Colors.amber : (index == 1 ? Colors.grey : Colors.brown)).withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 1)],
                                ),
                                alignment: Alignment.center,
                                child: Text('${index + 1}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isTop3 ? Colors.white : AppColors.textSecondary)),
                              ),
                              const SizedBox(width: 14),
                              AvatarWidget(config: AvatarWidget.parseConfig(user['avatar_url']), size: 48, showBorder: false),
                            ]),
                            title: Text('${user['first_name']} ${user['last_initial']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.text)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(color: (isTop3 ? AppColors.accent : AppColors.secondary).withValues(alpha: 0.10), borderRadius: BorderRadius.circular(16)),
                              child: Text('${user['total_score']} Adım', style: TextStyle(color: isTop3 ? AppColors.accent : AppColors.secondary, fontWeight: FontWeight.w900, fontSize: 14)),
                            ),
                          ),
                        ).animate().fadeIn(duration: 450.ms, delay: (index * 70).ms).slideX(begin: -0.06);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterButton(String value, String label) {
    return Expanded(
      child: GestureDetector(
        onTap: () { if (_leaderboardFilter != value) { setState(() => _leaderboardFilter = value); _fetchLeaderboard(); } },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: _leaderboardFilter == value ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(12)),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: _leaderboardFilter == value ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      useSafeArea: false,
      padding: EdgeInsets.zero,
      child: SafeArea(
        child: Column(
          children: [
            AppHeader(title: 'Sosyal', leading: const Icon(Icons.people_alt_rounded, color: AppColors.accent), actions: [
              IconButton(onPressed: () { if (_tabController.index == 0) _fetchFeed(); else _fetchLeaderboard(); }, icon: const Icon(Icons.refresh_rounded), tooltip: 'Yenile'),
            ]),
            TabBar(controller: _tabController, indicatorColor: AppColors.primary, labelColor: AppColors.primary, unselectedLabelColor: AppColors.textSecondary, tabs: const [Tab(text: 'Akış', icon: Icon(Icons.dynamic_feed)), Tab(text: 'Sıralama', icon: Icon(Icons.leaderboard))]),
            Expanded(child: TabBarView(controller: _tabController, children: [_buildFeedTab(), _buildLeaderboardTab()])),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData? icon;
  final String? emoji;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({this.icon, this.emoji, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          if (icon != null) Icon(icon, color: color, size: 22),
          if (emoji != null) Text(emoji!, style: const TextStyle(fontSize: 20)),
          if (label.isNotEmpty) ...[const SizedBox(width: 4), Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700))],
        ],
      ),
    );
  }
}