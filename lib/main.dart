import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/fcm_service.dart';
import 'app.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("🌙 Background Message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Setup Error Boundary (Fallback UI)
  // Ini akan menangkap error rendering dan menampilkan UI yang lebih bagus daripada layar merah
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 50
            ),
            const SizedBox(height: 20),
            const Text(
              'Terjadi Kesalahan Tampilan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Mohon maaf, terjadi kesalahan teknis pada halaman ini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            // Tampilkan detail error hanya jika diperlukan (berguna saat debug)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300)
              ),
              child: Text(
                details.exception.toString(),
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            )
          ],
        ),
      ),
    );
  };

  // 2. Init Firebase
  await Firebase.initializeApp();

  // 3. Register Handler Notifikasi
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 4. Init Service Notifikasi
  await FcmService().init();

  runApp(const GenerasiEmasApp());
}