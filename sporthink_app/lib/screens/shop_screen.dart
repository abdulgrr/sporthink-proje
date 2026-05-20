import 'package:flutter/material.dart';
import '../config/api_config.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'inventory_screen.dart';
import '../main.dart';
import '../ui/app_background.dart';
import '../ui/app_header.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _userPoints = 0;
  List<dynamic> _products = [];
  Map<String, dynamic> _chestPrices = {'daily': 0, 'weekly': 500};
  DateTime? _lastDailyChest;
  DateTime? _lastWeeklyChest;
  Timer? _cooldownTimer;
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchShopData();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchShopData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/shop'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _userPoints = data['user_points'];
          _products = data['products'] ?? [];
          _chestPrices = data['chest_prices'] ?? {'daily': 0, 'weekly': 500};
          
          final cooldowns = data['chest_cooldowns'];
          if (cooldowns != null) {
            _lastDailyChest = cooldowns['daily'] != null ? DateTime.parse(cooldowns['daily']).toLocal() : null;
            _lastWeeklyChest = cooldowns['weekly'] != null ? DateTime.parse(cooldowns['weekly']).toLocal() : null;
          }
        });
      } else {
        setState(() => _error = 'Dükkan verileri yüklenemedi.');
      }
    } catch (e) {
      setState(() => _error = 'Bağlantı hatası: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _buyProduct(int productId, String productName, int price) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    // Onay Kutusu
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Satın Alma Onayı'),
        content: Text('$productName ürününü $price puana almak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Satın Al', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)));

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/shop/buy_product'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'product_id': productId}),
      );

      if (!mounted) return;
      Navigator.pop(context); // loading kapat

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _userPoints = data['new_balance']);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Satın alma başarılı! Envanterinize eklendi.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errorData['message'] ?? 'Hata oluştu'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Bağlantı hatası.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _openChest(String chestType) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    int price = chestType == 'daily' ? _chestPrices['daily'] : _chestPrices['weekly'];

    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sandık Açılışı'),
        content: Text(price == 0 ? 'Bu sandığı ücretsiz açmak ister misin?' : 'Bu sandığı $price puana açmak istediğine emin misin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aç', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)));

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/shop/open_chest'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'chest_type': chestType}),
      );

      if (!mounted) return;
      Navigator.pop(context); // loading kapat

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Puanı güncelle (sunucudan gelmiyorsa tekrar fetch yapalım)
        await _fetchShopData();

        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('🎉 Sandık Sonucu!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  data['drop_type'] == 'points' ? Icons.monetization_on : Icons.card_giftcard,
                  color: AppColors.accent,
                  size: 60
                ),
                const SizedBox(height: 15),
                Text(data['message'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Süper!', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        );

      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errorData['message'] ?? 'Hata oluştu'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Bağlantı hatası.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  String? _getCooldownString(String type) {
    if (type == 'daily' && _lastDailyChest != null) {
      final unlockTime = _lastDailyChest!.add(const Duration(days: 1));
      final remaining = unlockTime.difference(DateTime.now());
      if (remaining.isNegative) return null;
      return '${remaining.inHours.toString().padLeft(2, '0')}:${(remaining.inMinutes % 60).toString().padLeft(2, '0')}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';
    } else if (type == 'weekly' && _lastWeeklyChest != null) {
      final unlockTime = _lastWeeklyChest!.add(const Duration(days: 7));
      final remaining = unlockTime.difference(DateTime.now());
      if (remaining.isNegative) return null;
      return '${remaining.inDays} Gün ${remaining.inHours % 24} Saat ${(remaining.inMinutes % 60).toString().padLeft(2, '0')} Dk';
    }
    return null;
  }

  Widget _buildProductsTab() {
    if (_products.isEmpty) {
      return const Center(child: Text('Şu an hiç ürün yok.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final item = _products[index];
        String imageUrl = item['image_url'] ?? '';
        if (imageUrl.isNotEmpty && imageUrl.startsWith('/')) {
          imageUrl = '${ApiConfig.baseUrl}$imageUrl';
        }

        return GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.network(imageUrl, height: 150, fit: BoxFit.cover),
                      ),
                    const SizedBox(height: 15),
                    Text(
                      item['description']?.toString() ?? 'Açıklama bulunmuyor.',
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      '${item['price_points']} Puan',
                      style: const TextStyle(color: AppColors.accent, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Kapat', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _buyProduct(item['id'], item['name'], item['price_points']);
                    },
                    child: const Text('Satın Al', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.05),
                  spreadRadius: 2,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: imageUrl.isNotEmpty
                        ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: AppColors.background, child: const Icon(Icons.image_not_supported, size: 50, color: AppColors.textSecondary)))
                        : Container(color: AppColors.background, child: const Icon(Icons.shopping_bag, size: 50, color: AppColors.textSecondary)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    children: [
                      Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Text('${item['price_points']} Puan', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () => _buyProduct(item['id'], item['name'], item['price_points']),
                          child: const Text('Satın Al', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ).animate().fadeIn(
            duration: 600.ms,
            delay: (index * 80).ms,
          ).scale(
            begin: const Offset(0.9, 0.9),
            end: const Offset(1.0, 1.0),
            duration: 600.ms,
            curve: Curves.easeOutBack,
          ),
        );
      },
    );
  }

  Widget _buildChestsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Daily Chest
        Container(
          decoration: BoxDecoration(
            gradient: AppColors.secondaryGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: AppColors.secondary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 64),
              ),
              const SizedBox(height: 16),
              const Text('Günlük Sandık', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Text(_chestPrices['daily'] == 0 ? 'Ücretsiz!' : '${_chestPrices['daily']} Puan', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getCooldownString('daily') == null ? Colors.white : Colors.white.withOpacity(0.5),
                    foregroundColor: AppColors.secondary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _getCooldownString('daily') == null ? () => _openChest('daily') : null,
                  child: Text(_getCooldownString('daily') ?? 'Şimdi Aç', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, duration: 600.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 24),
        // Weekly Chest
        Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.star_rounded, color: Colors.amber, size: 64),
              ),
              const SizedBox(height: 16),
              const Text('Haftalık Sandık', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Text('${_chestPrices['weekly']} Puan', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getCooldownString('weekly') == null ? Colors.amber : Colors.amber.withOpacity(0.5),
                    foregroundColor: const Color(0xFF5B21B6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _getCooldownString('weekly') == null ? () => _openChest('weekly') : null,
                  child: Text(_getCooldownString('weekly') ?? 'Şimdi Aç', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 100.ms).slideY(begin: 0.1, duration: 600.ms, curve: Curves.easeOutBack),
      ],
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
            AppHeader(
              title: 'Dükkan',
              leading: const Icon(Icons.storefront_rounded, color: AppColors.primary),
              actions: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.textSecondary.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on, color: AppColors.accent, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '$_userPoints',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 420.ms).slideY(begin: -0.06),
                const SizedBox(width: 16),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.70),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.textSecondary.withOpacity(0.10)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  tabs: const [
                    Tab(icon: Icon(Icons.store_rounded), text: 'Ürünler'),
                    Tab(icon: Icon(Icons.card_giftcard_rounded), text: 'Sandıklar'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _error.isNotEmpty
                      ? Center(child: Text(_error, style: const TextStyle(color: AppColors.error)))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildProductsTab(),
                            _buildChestsTab(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}