import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'services/fcm_service.dart';
import 'core/constants.dart';
import 'app.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("🌙 Background Message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);

  // Load environment variables safely
  try {
    await dotenv.load(fileName: ".env");
    debugPrint("✅ Environment loaded: ${AppEnv.environment} (API: ${AppEnv.apiBaseUrl})");
  } catch (e) {
    debugPrint("ℹ️ .env file not loaded. Falling back to compile-time definitions / defaults ($e).");
  }

  // 1. Setup Error Boundary (Fallback UI)
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
              size: 50,
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                details.exception.toString(),
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  };

  // 2. Init Firebase with platform options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

// 3. Only initialize FCM on mobile platforms
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await FcmService().init();
  }

  runApp(const GenerasiEmasApp());
}