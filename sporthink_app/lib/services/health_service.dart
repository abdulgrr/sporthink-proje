import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class HealthService {
  final Health _health = Health();

  /// Cihazın benzersiz ID'sini döndürür
  static Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final android = await deviceInfo.androidInfo;
      return android.id; // Android unique build ID
    } else if (Platform.isIOS) {
      final ios = await deviceInfo.iosInfo;
      return ios.identifierForVendor ?? 'unknown_ios';
    }
    return 'unknown_device';
  }

  /// Cihaz model adını döndürür
  static Future<String> getDeviceModel() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final android = await deviceInfo.androidInfo;
      return '${android.brand} ${android.model}';
    } else if (Platform.isIOS) {
      final ios = await deviceInfo.iosInfo;
      return ios.utsname.machine;
    }
    return 'unknown';
  }

  /// El ile girilen verileri filtreleyen kaynak kontrolü
  /// NOT: com.google.android.apps.fitness'ı engellememeliyiz çünkü
  /// gerçek sensör verileri de bu kaynak adıyla geliyor.
  bool _isManualEntry(HealthDataPoint data) {
    final source = data.sourceName.toLowerCase();
    // Sadece açıkça "user_input" veya "manual" içeren kaynakları filtrele
    if (source.contains('user_input')) return true;
    if (source.contains('manual')) return true;
    return false;
  }

  Future<List<Map<String, dynamic>>> fetchLast7DaysSteps() async {
    // 1. İzinleri İste
    final activityStatus = await Permission.activityRecognition.request();
    print('🔍 Activity Recognition izni: $activityStatus');

    // Sağlık verisi tiplerini belirle (Sadece Adım)
    var types = [HealthDataType.STEPS];

    // Uygulamanın okuma yetkisi var mı kontrol et
    bool? hasPermissions = await _health.hasPermissions(types);
    print('🔍 Health Connect hasPermissions: $hasPermissions');

    // Eğer izin yoksa isteme yapacağız
    if (hasPermissions != true) {
      bool requested = await _health.requestAuthorization(types);
      print('🔍 Health Connect requestAuthorization sonucu: $requested');

      if (!requested) {
        throw Exception("Sağlık verilerine erişim izni verilmedi.");
      }
    }

    // 2. Tarih aralığını belirle (Bu haftanın Pazartesi gününden şu ana kadar)
    final now = DateTime.now();
    
    // Dart'ta DateTime.weekday Pazartesi için 1, Pazar için 7 döner.
    final int daysSinceMonday = now.weekday - 1;
    // Pazartesi gece 00:00:00
    final startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysSinceMonday));
    
    // O günün sonu (veya o an)
    final endTime = DateTime(now.year, now.month, now.day, 23, 59, 59);

    print('🔍 Tarih aralığı: $startDate → $endTime');

    // 3. Adımları Çek
    List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
      types: types,
      startTime: startDate,
      endTime: endTime,
    );

    // DEBUG: Gelen veri kaynaklarını logla
    print('🔍 Health Connect: ${healthData.length} veri noktası geldi');
    final sourceSet = <String>{};
    for (var d in healthData) {
      sourceSet.add(d.sourceName);
    }
    print('🔍 Kaynaklar: $sourceSet');

    // 4. Backend'in istediği formata (steps_array) dönüştür
    // ⚠️ ANTI-CHEAT: El ile girilen verileri + spike verilerini filtrele
    Map<String, int> dailySteps = {};
    int filteredManual = 0;
    int filteredSpike = 0;

    // Spike tespiti: Dakikada 250 adımdan fazla = fiziksel olarak imkansız
    // (Usain Bolt bile ~240 adım/dk yapıyor)
    const double maxStepsPerMinute = 250;

    for (var data in healthData) {
      // El ile girilen veriyi atla
      if (_isManualEntry(data)) {
        filteredManual++;
        print('⚠️ Filtrelendi (manual): kaynak=${data.sourceName}, adım=${data.value}');
        continue;
      }

      int steps = (data.value as NumericHealthValue).numericValue.toInt();

      // Spike analizi: veri noktasının süresine göre adım hızını kontrol et
      final durationMinutes = data.dateTo.difference(data.dateFrom).inMinutes;
      if (durationMinutes > 0 && steps > 0) {
        final stepsPerMin = steps / durationMinutes;
        if (stepsPerMin > maxStepsPerMinute) {
          filteredSpike++;
          print('⚠️ Anti-cheat spike: $steps adım / $durationMinutes dk = ${stepsPerMin.toStringAsFixed(0)} adım/dk (limit: ${maxStepsPerMinute.toInt()})');
          continue; // Bu veri noktasını atla
        }
      }

      // Tarihi YYYY-MM-DD formatına çevir
      String dayStr =
          "${data.dateFrom.year}-${data.dateFrom.month.toString().padLeft(2, '0')}-${data.dateFrom.day.toString().padLeft(2, '0')}";

      if (dailySteps.containsKey(dayStr)) {
        dailySteps[dayStr] = dailySteps[dayStr]! + steps;
      } else {
        dailySteps[dayStr] = steps;
      }
    }

    if (filteredManual > 0 || filteredSpike > 0) {
      print('⚠️ Anti-cheat: $filteredManual el ile girilen + $filteredSpike spike verisi filtrelendi.');
    }

    // Listeye çevir
    List<Map<String, dynamic>> stepsArray = [];
    dailySteps.forEach((key, value) {
      stepsArray.add({"day": key, "step_count": value});
    });

    return stepsArray;
  }
}
