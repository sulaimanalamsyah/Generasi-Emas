import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // [TAMBAHAN]
import 'package:flutter/foundation.dart';
import 'api_client.dart';

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final _firebaseMessaging = FirebaseMessaging.instance;
  final _api = ApiClient();

  // [TAMBAHAN] Plugin Local Notifications untuk membuat channel & menampilkan notifikasi foreground
  final _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // 1. Request Permission
    await _firebaseMessaging.requestPermission(
      alert: true, badge: true, sound: true,
    );

    // [TAMBAHAN] 2. Setup Notification Channel (Wajib untuk Android)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'daily_channel_id', // ID harus SAMA dengan yang dikirim backend
      'Pengingat Harian', // Nama Channel yang muncul di setting HP
      description: 'Notifikasi rutin harian untuk Ibu & Ayah',
      importance: Importance.max, // MAX agar muncul pop-up (heads-up)
      playSound: true,
    );

    // Buat channel di Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
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
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔔 Pesan Foreground: ${message.notification?.title}');

      // [TAMBAHAN] Tampilkan notifikasi manual saat app sedang dibuka
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: '@mipmap/ic_launcher', // Pastikan icon ada
              // Penting agar heads-up notification muncul
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    });
  }

  // ... (Sisa fungsi sendCurrentToken & _sendTokenToBackend TETAP SAMA) ...
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

  // [BARU] Aktifkan Notifikasi (Ambil token & Kirim ke Backend)
  Future<void> enableNotifications() async {
    try {
      // Pastikan izin dulu
      await _firebaseMessaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _api.updateFcmToken(token); // Kirim token
        debugPrint("✅ Notifikasi Diaktifkan (Token Sent)");
      }
    } catch (e) {
      debugPrint("❌ Gagal enable notif: $e");
      rethrow; // Lempar error agar UI tahu
    }
  }

  // [BARU] Matikan Notifikasi (Kirim null ke Backend)
  Future<void> disableNotifications() async {
    try {
      await _api.updateFcmToken(null); // Hapus token di DB
      debugPrint("bw Notifikasi Dinonaktifkan (Token Removed)");
    } catch (e) {
      debugPrint("❌ Gagal disable notif: $e");
      rethrow;
    }
  }
}