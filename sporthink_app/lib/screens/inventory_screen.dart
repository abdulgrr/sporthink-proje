import 'package:flutter/material.dart';
import '../config/api_config.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../main.dart';
import '../ui/app_background.dart';
import '../ui/app_header.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<dynamic> _inventory = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/shop/inventory'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _inventory = jsonDecode(response.body);
        });
      } else {
        setState(() {
          _error = 'Envanter yüklenirken hata oluştu.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Bağlantı hatası: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _useItem(String inventoryId, String itemName) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Eşyayı Kullan'),
            content: Text(
              '$itemName adlı eşyayı/kuponu kullanmak istediğinize emin misiniz? (Bu işlem geri alınamaz)',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Kullan',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/shop/use_item'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'inventory_id': inventoryId}),
      );

      if (!mounted) return;
      Navigator.pop(context); // loading kapat

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _fetchInventory(); // listeyi guncelle

        // Kodu Göster
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Kupon Kodunuz 🎉'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Bu kodu kasada veya ödeme ekranında kullanabilirsiniz:',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  child: SelectableText(
                    data['coupon_code'],
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Tamam',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['message'] ?? 'Hata oluştu'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bağlantı hatası.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
              title: 'Envanterim & Kuponlarım',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _error.isNotEmpty
                      ? Center(child: Text(_error, style: const TextStyle(color: AppColors.error)))
                      : _inventory.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Henüz hiç eşya/kupon yok.\nDükkana göz at!',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _inventory.length,
                              itemBuilder: (context, index) {
                                final item = _inventory[index];
                                final date = DateTime.parse(item['created_at']);
                                final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(date);
                                final isUsed = item['status'] == 'used';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: AppColors.textSecondary.withOpacity(0.1)),
                                    boxShadow: [
                                      BoxShadow(color: AppColors.primary.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            gradient: isUsed ? null : AppColors.accentGradient,
                                            color: isUsed ? AppColors.textSecondary.withOpacity(0.2) : null,
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Icon(Icons.card_giftcard, color: isUsed ? AppColors.textSecondary : Colors.white, size: 28),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['name'] ?? 'Ödül',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 16,
                                                  color: isUsed ? AppColors.textSecondary : AppColors.text,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                formattedDate,
                                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                              ),
                                              if (isUsed && item['coupon_code'] != null)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 8),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      'Kod: ${item['coupon_code']}',
                                                      style: const TextStyle(
                                                        color: AppColors.primary,
                                                        fontWeight: FontWeight.w900,
                                                        fontSize: 13,
                                                        letterSpacing: 1.2,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              margin: EdgeInsets.only(bottom: isUsed ? 0 : 12),
                                              decoration: BoxDecoration(
                                                color: (isUsed ? AppColors.textSecondary : AppColors.success).withOpacity(0.10),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                isUsed ? 'Kullanıldı' : 'Aktif',
                                                style: TextStyle(
                                                  color: isUsed ? AppColors.textSecondary : AppColors.success,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            if (!isUsed)
                                              SizedBox(
                                                height: 38,
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: AppColors.primary,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  ),
                                                  onPressed: () => _useItem(item['id'], item['name'] ?? 'Ödül'),
                                                  child: const Text('Kullan', style: TextStyle(fontWeight: FontWeight.w900)),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
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