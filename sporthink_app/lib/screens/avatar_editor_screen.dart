import 'package:flutter/material.dart';
import '../config/api_config.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';
import '../ui/app_background.dart';
import '../widgets/avatar_widget.dart';

class AvatarEditorScreen extends StatefulWidget {
  const AvatarEditorScreen({super.key});

  @override
  State<AvatarEditorScreen> createState() => _AvatarEditorScreenState();
}

class _AvatarEditorScreenState extends State<AvatarEditorScreen> {
  // Göz seçenekleri
  final List<String> _eyeOptions = [
    'goz_normal',
    'goz_anime',
    'goz_kalp',
    'goz_kedi',
    'goz_gozluk',
    'goz_kirpma',
    'goz_kizgin',
    'goz_sevinc',
    'goz_uzgun',
    'goz_uyku',
    'goz_olu',
    'goz_didyouseethat',
  ];

  // Ağız seçenekleri
  final List<String> _mouthOptions = [
    'agiz_mutlu',
    'agiz_gulumse',
    'agiz_yanyatmis3',
    'agiz_blehh',
    'agiz_duzblehh',
    'agiz_vampir',
    'agiz_s',
    'agiz_sasir',
    'agiz_uzgun',
    'agiz_roblox',
    'agiz_dissikma',
    'agiz_fermuar',
    'agiz_biyik',
    'agiz_altindis',
    'agiz_ummactually',
  ];

  // Kafa/şapka seçenekleri (none = hiçbiri)
  final List<String?> _headOptions = [
    null, // Hiçbiri
    'kafa_tac',
    'kafa_halo',
    'kafa_seytan',
    'kafa_boynuz',
    'kafa_gentleman',
    'kafa_mohawk',
    'kafa_kedi',
    'kafa_kurdele',
    'kafa_tavsankulak',
    'kafa_huni',
    'kafa_ampul',
    'kafa_broislivin',
    'kafa_itsthejuuz',
    'kafa_ratatuy',
  ];

  // Ten renkleri
  final List<Color> _skinColors = [
    const Color(0xFFFDECE0),
    const Color(0xFFF5D6BA),
    const Color(0xFFE8B88A),
    const Color(0xFFD4956B),
    const Color(0xFFAD7A5B),
    const Color(0xFF8B5E3C),
    const Color(0xFF614B3A),
    const Color(0xFFFFD700),
    const Color(0xFF87CEEB),
    const Color(0xFFB8F5B0),
    const Color(0xFFE6A8D7),
    const Color(0xFFD8BFD8),
  ];

  int _selectedEyeIndex = 0;
  int _selectedMouthIndex = 0;
  int _selectedHeadIndex = 0;
  int _selectedSkinIndex = 1;

  final Map<String, String> _displayNames = {
    'goz_normal': 'Normal',
    'goz_anime': 'Anime',
    'goz_kalp': 'Kalp',
    'goz_kedi': 'Kedi',
    'goz_gozluk': 'Gözlük',
    'goz_kirpma': 'Kırpma',
    'goz_kizgin': 'Kızgın',
    'goz_sevinc': 'Sevinç',
    'goz_uzgun': 'Üzgün',
    'goz_uyku': 'Uykulu',
    'goz_olu': 'X_X',
    'goz_didyouseethat': 'Yan Bakış',
    'agiz_mutlu': 'Mutlu',
    'agiz_gulumse': 'Gülümse',
    'agiz_yanyatmis3': ':3',
    'agiz_blehh': 'Blehh',
    'agiz_duzblehh': 'Düz Blehh',
    'agiz_vampir': 'Vampir',
    'agiz_s': 'S',
    'agiz_sasir': 'Şaşkın',
    'agiz_uzgun': 'Üzgün',
    'agiz_roblox': 'Roblox',
    'agiz_dissikma': 'Diş Sıkma',
    'agiz_fermuar': 'Fermuar',
    'agiz_biyik': 'Bıyık',
    'agiz_altindis': 'Altın Diş',
    'agiz_ummactually': 'Umm..',
    'kafa_tac': 'Taç',
    'kafa_halo': 'Halo',
    'kafa_seytan': 'Şeytan',
    'kafa_boynuz': 'Boynuz',
    'kafa_gentleman': 'Gentleman',
    'kafa_mohawk': 'Mohawk',
    'kafa_kedi': 'Kedi Kulak',
    'kafa_kurdele': 'Kurdele',
    'kafa_tavsankulak': 'Tavşan',
    'kafa_huni': 'Huni',
    'kafa_ampul': 'Ampul',
    'kafa_broislivin': 'Bro',
    'kafa_itsthejuuz': 'Juice',
    'kafa_ratatuy': 'Ratatuy',
  };

  bool _isLoading = true;
  bool _isSaving = false;
  
  // API'den gelen öğeler: { item_key: { price, owned, display_name } }
  Map<String, dynamic> _itemsData = {};

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/avatar/items'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'];
        final config = data['current_config'] ?? {};

        // Veriyi dönüştür
        final Map<String, dynamic> mappedData = {};
        
        // API'den gelen parçalarla listeleri güncelle
        final List<String> apiEyes = [];
        final List<String> apiMouths = [];
        final List<String?> apiHeads = [null]; // null = "Hiçbiri" her zaman ilk
        
        for (final item in (items['eyes'] ?? [])) {
          apiEyes.add(item['item_key']);
          mappedData[item['item_key']] = item;
          // Display name'i güncelle
          _displayNames[item['item_key']] = item['display_name'] ?? item['item_key'];
        }
        
        for (final item in (items['mouth'] ?? [])) {
          apiMouths.add(item['item_key']);
          mappedData[item['item_key']] = item;
          _displayNames[item['item_key']] = item['display_name'] ?? item['item_key'];
        }
        
        for (final item in (items['head'] ?? [])) {
          apiHeads.add(item['item_key']);
          mappedData[item['item_key']] = item;
          _displayNames[item['item_key']] = item['display_name'] ?? item['item_key'];
        }

        if (mounted) {
          setState(() {
            _itemsData = mappedData;
            
            // Listeleri API verisiyle güncelle (boş değilse)
            if (apiEyes.isNotEmpty) {
              _eyeOptions.clear();
              _eyeOptions.addAll(apiEyes);
            }
            if (apiMouths.isNotEmpty) {
              _mouthOptions.clear();
              _mouthOptions.addAll(apiMouths);
            }
            if (apiHeads.length > 1) {
              _headOptions.clear();
              _headOptions.addAll(apiHeads);
            }
            
            // Mevcut config'i seçili yap
            if (config['skin'] != null) _selectedSkinIndex = int.tryParse(config['skin'].toString()) ?? 1;
            if (config['eyes'] != null) _selectedEyeIndex = _eyeOptions.indexOf(config['eyes']).clamp(0, _eyeOptions.length - 1);
            if (config['mouth'] != null) _selectedMouthIndex = _mouthOptions.indexOf(config['mouth']).clamp(0, _mouthOptions.length - 1);
            if (config['head'] != null) {
              final headIdx = _headOptions.indexOf(config['head']);
              _selectedHeadIndex = headIdx != -1 ? headIdx : 0;
            }
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAvatar() async {
    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final requestBody = jsonEncode({
        'skin': _selectedSkinIndex,
        'eyes': _eyeOptions[_selectedEyeIndex],
        'mouth': _mouthOptions[_selectedMouthIndex],
        'head': _headOptions[_selectedHeadIndex],
      });

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/avatar/save'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: requestBody,
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avatar kaydedildi!'), backgroundColor: AppColors.success));
        Navigator.pop(context);
      } else {
        if (!mounted) return;
        final err = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err['message'] ?? 'Hata oluştu!'), backgroundColor: AppColors.error));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _buyItem(String itemKey, String name, int price) async {
    // Onay dialogu
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Satın Al', style: TextStyle(color: AppColors.text)),
        content: Text('$name parçasını $price puan karşılığında satın almak istiyor musun?', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Satın Al'),
          ),
        ],
      )
    );

    if (confirm != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/avatar/buy'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'item_key': itemKey}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: AppColors.success));
        _fetchItems(); // Verileri yenile
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: AppColors.error));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        useSafeArea: false,
        padding: EdgeInsets.zero,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.face, color: AppColors.accent),
                    const SizedBox(width: 8),
                    const Text(
                      'Avatar Editörü',
                      style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const Spacer(),
                    if (_isSaving)
                      const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      TextButton.icon(
                        onPressed: _saveAvatar,
                        icon: const Icon(Icons.check, color: AppColors.primary),
                        label: const Text('Kaydet', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
              else
                Expanded(
                  child: Column(
                    children: [

              // --- AVATAR ÖNİZLEME ---
              _buildAvatarPreview(),

              const SizedBox(height: 16),

              // --- TEN RENGİ ---
              _buildSkinColorPicker(),

              const SizedBox(height: 8),

              // --- PARÇA SEÇİCİ (3 Tab) ---
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: DefaultTabController(
                    length: 3,
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const TabBar(
                            indicatorColor: AppColors.primary,
                            indicatorSize: TabBarIndicatorSize.label,
                            labelColor: AppColors.primary,
                            unselectedLabelColor: AppColors.textSecondary,
                            dividerColor: Colors.transparent,
                            labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            tabs: [
                              Tab(text: '👀 Gözler'),
                              Tab(text: '👄 Ağız'),
                              Tab(text: '🎩 Kafa'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildPartGrid(_eyeOptions.cast<String?>(), _selectedEyeIndex, (i) {
                                setState(() => _selectedEyeIndex = i);
                              }, allowNone: false),
                              _buildPartGrid(_mouthOptions.cast<String?>(), _selectedMouthIndex, (i) {
                                setState(() => _selectedMouthIndex = i);
                              }, allowNone: false),
                              _buildPartGrid(_headOptions, _selectedHeadIndex, (i) {
                                setState(() => _selectedHeadIndex = i);
                              }, allowNone: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPreview() {
    const double circleSize = 170;
    const double partSize = circleSize * 0.75;
    const double mouthSize = partSize * 0.82;
    const double headSize = circleSize * 1.1;

    return SizedBox(
      width: circleSize + 60,
      height: circleSize + 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 0,
            child: Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _skinColors[_selectedSkinIndex],
                boxShadow: [
                  BoxShadow(
                    color: _skinColors[_selectedSkinIndex].withOpacity(0.4),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: ClipOval(
                child: Stack(
                  children: [
                    Positioned(
                      left: (circleSize - partSize) / 2,
                      top: circleSize * 0.05,
                      child: AvatarWidget.avatarImage(_eyeOptions[_selectedEyeIndex], partSize, partSize),
                    ),
                    Positioned(
                      left: (circleSize - mouthSize) / 2,
                      bottom: -circleSize * 0.04,
                      child: AvatarWidget.avatarImage(_mouthOptions[_selectedMouthIndex], mouthSize, mouthSize),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_headOptions[_selectedHeadIndex] != null)
            Positioned(
              top: -22,
              child: AvatarWidget.avatarImage(_headOptions[_selectedHeadIndex]!, headSize, headSize),
            ),
        ],
      ),
    ).animate().scale(duration: 300.ms, curve: Curves.easeOut);
  }

  Widget _buildSkinColorPicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ten Rengi',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _skinColors.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedSkinIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedSkinIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: _skinColors[index],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8)]
                          : [],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartGrid(List<String?> options, int selectedIndex, Function(int) onSelect, {required bool allowNone}) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final isSelected = selectedIndex == index;
        final name = options[index];
        final isNone = name == null;
        
        bool isOwned = true;
        int price = 0;
        if (!isNone && _itemsData.containsKey(name)) {
          isOwned = _itemsData[name]['owned'] == true;
          price = _itemsData[name]['price'] ?? 0;
        }

        return GestureDetector(
          onTap: () {
            if (isNone || isOwned) {
              onSelect(index);
            } else {
              _buyItem(name, _displayNames[name] ?? name, price);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected 
                  ? AppColors.primary.withOpacity(0.15) 
                  : (isOwned ? AppColors.surface : AppColors.surface.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.textSecondary.withOpacity(0.1),
                width: isSelected ? 2.5 : 1,
              ),
            ),
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: isNone
                            ? Icon(Icons.block, color: AppColors.textSecondary.withOpacity(0.3), size: 36)
                            : Opacity(
                                opacity: isOwned ? 1.0 : 0.4,
                                child: AvatarWidget.avatarImage(name, 36, 36),
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        isNone ? 'Yok' : (_displayNames[name] ?? name),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (!isNone && !isOwned)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock, size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 300.ms, delay: (index * 30).ms);
      },
    );
  }
}