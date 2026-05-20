import 'package:flutter/material.dart';
import '../config/api_config.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';
import '../ui/app_background.dart';

class ProfileEditScreen extends StatefulWidget {
  final Map<String, dynamic> currentData;
  const ProfileEditScreen({super.key, required this.currentData});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _firstNameController.text = widget.currentData['first_name'] ?? '';
    _lastNameController.text = widget.currentData['last_name'] ?? '';
    _usernameController.text = widget.currentData['username'] ?? '';
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/profile/update'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'username': _usernameController.text,
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
      }),
    );

    if (!mounted) return;
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Profil güncellendi!'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.pop(context);
    } else {
      final errData = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(errData['message'] ?? 'Güncelleme hatası.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profili Düzenle'),
        elevation: 0,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.primaryGradient)),
      ),
      body: AppBackground(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Kullanıcı adı',
                  prefixText: '@',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ).animate().fadeIn(duration: 450.ms, delay: 120.ms).slideX(begin: -0.06),
              const SizedBox(height: 14),
              TextField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'Ad',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Soyad',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  child: const Text('Kaydet', style: TextStyle(fontSize: 18)),
                ),
              ).animate().fadeIn(duration: 450.ms, delay: 200.ms).slideY(begin: 0.10),
            ],
          ),
        ),
      ),
    );
  }
}