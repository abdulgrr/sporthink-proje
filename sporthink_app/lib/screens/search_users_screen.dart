import 'package:flutter/material.dart';
import '../config/api_config.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'public_profile_screen.dart';
import '../main.dart';
import '../ui/app_background.dart';
import '../widgets/avatar_widget.dart';

class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final _searchController = TextEditingController();
  List<dynamic> _results = [];
  bool _isLoading = false;
  Timer? _debounce;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.length < 2) {
      if (mounted) setState(() => _results = []);
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/profile/search?q=$query'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) setState(() => _results = jsonDecode(response.body));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow(int index, String targetId, bool isCurrentlyFollowing) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final endpoint = isCurrentlyFollowing ? 'unfollow' : 'follow';

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/profile/$endpoint'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'target_id': targetId}),
    );

    if (response.statusCode == 200) {
      setState(() {
        _results[index]['is_following'] = !isCurrentlyFollowing;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.primaryGradient)),
        title: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Kullanıcı ara...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          autofocus: true,
        ),
      ),
      body: AppBackground(
        padding: EdgeInsets.zero,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search, size: 80, color: AppColors.textSecondary.withOpacity(0.22)),
                          const SizedBox(height: 14),
                          Text(
                            'Kullanıcı aramak için en az 2 karakter gir.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final user = _results[index];
                      final isFollowing = user['is_following'];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PublicProfileScreen(userId: user['id'].toString()),
                              ),
                            );
                          },
                          leading: AvatarWidget(
                            config: AvatarWidget.parseConfig(user['avatar_url']),
                            size: 40,
                            showBorder: false,
                          ),
                          title: Text(
                            '${user['first_name']} ${user['last_name']}',
                            style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.text),
                          ),
                          subtitle: Text('@${user['username'] ?? 'kullaniciadi'}', style: const TextStyle(color: AppColors.textSecondary)),
                          trailing: SizedBox(
                            height: 36,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFollowing ? AppColors.textSecondary : AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              onPressed: () => _toggleFollow(index, user['id'], isFollowing),
                              child: Text(isFollowing ? 'Takiptesin' : 'Takip Et', style: const TextStyle(fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ),
                      ).animate().fadeIn(duration: 450.ms, delay: (index * 70).ms).slideX(begin: -0.06);
                    },
                  ),
      ),
    );
  }
}