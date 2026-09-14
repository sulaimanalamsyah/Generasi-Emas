import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import '../app.dart';
import '../routes.dart';

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final _firebaseMessaging = FirebaseMessaging.instance;
  final _api = ApiClient();

  // Plugin Local Notifications untuk membuat channel & menampilkan notifikasi foreground
  final _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    try {
      // 1. Request Permission
      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // 2. Setup Notification Channel (Wajib untuk Android)
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'daily_channel_id', // ID harus SAMA dengan yang dikirim backend
        'Pengingat Harian', // Nama Channel yang muncul di setting HP
        description: 'Notifikasi rutin harian untuk Ibu & Ayah',
        importance: Importance.max, // MAX agar muncul pop-up (heads-up)
        playSound: true,
      );

      // Inisialisasi local notification settings
      const initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      const initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            _handleNavigation(payload);
          }
        },
      );

      // Buat channel di Android
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // 3. Ambil Token & Kirim ke Backend
      final fcmToken = await _firebaseMessaging.getToken();
      debugPrint("🔥 FCM Token: $fcmToken");
      if (fcmToken != null) {
        await sendCurrentToken();
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _sendTokenToBackend(newToken);
      });

      // 4. Handle Foreground Notification (Saat aplikasi dibuka)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint('🔔 Pesan Foreground: ${message.notification?.title}');

        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;
        final route = message.data['route'] as String?;

        if (notification != null && android != null) {
          await _localNotifications.show(
            id: notification.hashCode,
            title: notification.title,
            body: notification.body,
            payload: route ?? Routes.notifications,
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: '@mipmap/launcher_icon',
                importance: Importance.max,
                priority: Priority.high,
              ),
            ),
          );
        }
      });

      // 5. Handle Background Notification Click (App is running in background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('🔔 Pesan Background di-klik: ${message.data}');
        final route = message.data['route'] as String?;
        _handleNavigation(route ?? Routes.notifications);
      });

      // 6. Handle Terminated Notification Click (App is opened from cold state)
      _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          debugPrint('🔔 Pesan Terminated di-klik: ${message.data}');
          final route = message.data['route'] as String?;
          Future.delayed(const Duration(milliseconds: 500), () {
            _handleNavigation(route ?? Routes.notifications);
          });
        }
      });
    } catch (e) {
      debugPrint("⚠️ FCM Init Error: $e");
    }
  }

  void _handleNavigation(String route) {
    try {
      debugPrint("🚀 Navigating via Notification Deep Link to: $route");
      navigatorKey.currentState?.pushNamed(route);
    } catch (e) {
      debugPrint("⚠️ Error navigating from notification: $e");
    }
  }

  Future<void> sendCurrentToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      debugPrint("⚠️ Gagal ambil token manual: $e");
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      await _api.updateFcmToken(token);
      debugPrint("✅ FCM Token terkirim ke backend");
    } catch (e) {
      debugPrint("⚠️ Gagal kirim token ke backend (Mungkin belum login): $e");
    }
  }

  // Aktifkan Notifikasi (Ambil token & Kirim ke Backend)
  Future<void> enableNotifications() async {
    try {
      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _api.updateFcmToken(token);
        debugPrint("✅ Notifikasi Diaktifkan (Token Sent)");
      }
    } catch (e) {
      debugPrint("❌ Gagal enable notif: $e");
      rethrow;
    }
  }

  // Matikan Notifikasi (Kirim null ke Backend)
  Future<void> disableNotifications() async {
    try {
      await _api.updateFcmToken(null);
      debugPrint("✅ Notifikasi Dinonaktifkan (Token Removed)");
    } catch (e) {
      debugPrint("❌ Gagal disable notif: $e");
      rethrow;
    }
  }
}