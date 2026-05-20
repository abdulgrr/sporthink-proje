import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Zaman dilimi ayarlarını başlat (Türkiye saati için)
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    // Android başlatma ayarları
    const AndroidInitializationSettings initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS başlatma ayarları
    const DarwinInitializationSettings initSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsIOS,
    );

    await _notificationsPlugin.initialize(settings: initSettings);
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Android 13+ için bildirim izni iste
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  Future<void> scheduleDailyNoonWalk() async {
    await _notificationsPlugin.zonedSchedule(
      id: 1,
      title: 'Öğle Molası! 🚶‍♂️',
      body: 'Öğle molasında biraz yürüyüş yapmaya ne dersin? Hem sindirime yardımcı olur hem de puan kazandırır!',
      scheduledDate: _nextInstanceOfTime(13, 0), // Her gün 13:00
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_walk_channel',
          'Günlük Yürüyüş Hatırlatması',
          channelDescription: 'Öğle saatlerinde yürüyüş hatırlatması yapar',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Her gün aynı saatte tekrarla
    );
  }

  Future<void> scheduleSundayPointsReminder() async {
    await _notificationsPlugin.zonedSchedule(
      id: 2,
      title: 'Hafta Bitiyor! ⏳',
      body: 'Pazar akşamına girdik. Adımlarını sıfırlanmadan önce puana çevirmeyi unutma!',
      scheduledDate: _nextInstanceOfSunday(20, 0), // Her Pazar 20:00
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_points_channel',
          'Haftalık Puan Hatırlatması',
          channelDescription: 'Pazar akşamları adım çevirme hatırlatması yapar',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // Her hafta aynı gün ve saatte
    );
  }

  Future<void> showInstantNotification(String title, String body) async {
    await _notificationsPlugin.show(
      id: DateTime.now().millisecond, // Random ID
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'admin_alerts',
          'Yönetici Duyuruları',
          channelDescription: 'Admin panelinden gelen anlık duyurular',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
      ),
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfSunday(int hour, int minute) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);
    while (scheduledDate.weekday != DateTime.sunday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
