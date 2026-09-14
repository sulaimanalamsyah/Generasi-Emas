import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

const kAppName = 'ENI Care';
const kPrimary = Color(0xFF00A67E);
const kWarning = Color(0xFFFFB300);
const kDanger  = Color(0xFFE53935);
const kGrey    = Color(0xFF9E9E9E);

const kStartGateHours = 96;
const kOtpResendCooldown = 60;
const kConsentLastUpdated = '2025-08-01';

// === Brainstorm ===
const List<String> kBrainModuleTitleKeys = ['brainstorm', 'orientasi ruangan'];

const String kBrainVideoUrl = '';

const String kBrainTextVisitDaily = '''
Kunjungan harian orang tua berpengaruh pada kestabilan kondisi bayi, keberhasilan menyusui, serta bonding.
''';
const String kBrainTextParentsRole = '''
Peran orang tua di ruang perawatan neonatus: KMC (bila direkomendasikan), dukungan ASI/perah, tindakan sederhana 
(dengan arahan perawat), komunikasi aktif, dan kepatuhan protokol kebersihan.
''';

// ========== Fallback VIDEO (Modul 1 & 4) ==========
const kVideoOrientasiUrl     = '';
const kVideoAsiUrl           = '';
const kVideoMenyusuiUrl      = '';
const kVideoKmcUrl           = '';
const kVideoMemandikanUrl    = '';
const kVideoPijatOksitosinUrl= '';
const kVideoStimulasiUrl     = '';

// ========== Fallback FLIP/PDF (Modul 2) ==========
const kFlipAsiUrl            = '';
const kFlipMenyusuiUrl       = '';
const kFlipKmcUrl            = '';
const kFlipMemandikanUrl     = '';
const kFlipPijatOksitosinUrl = '';
const kFlipStimulasiUrl      = '';

// ========== Dukungan emosional (Modul 3) ==========
const kGroupWaIbuUrl         = '';
const kCopingInfoUrl         = '';

// ========== Dynamic Environment Configuration ==========
class AppEnv {
  /// Base URL of the RESTful API backend
  static String get apiBaseUrl {
    // 1. Prioritize loaded .env file (runtime)
    if (dotenv.isInitialized) {
      final envUrl = dotenv.env['API_BASE_URL'] ?? dotenv.env['API_BASE'];
      if (envUrl != null && envUrl.trim().isNotEmpty) {
        return envUrl.trim();
      }
    }

    // 2. Fallback to compile-time --dart-define flags
    const defineBase = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (defineBase.isNotEmpty) return defineBase;

    const legacyDefine = String.fromEnvironment('API_BASE', defaultValue: '');
    if (legacyDefine.isNotEmpty) return legacyDefine;

    // 3. Smart platform fallback for development
    if (kIsWeb) return 'http://localhost:4000';
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:4000'
        : 'http://localhost:4000';
  }

  /// Application Name
  static String get appName =>
      (dotenv.isInitialized ? dotenv.env['APP_NAME'] : null) ?? kAppName;

  /// Environment mode: 'development', 'staging', or 'production'
  static String get environment =>
      (dotenv.isInitialized ? dotenv.env['APP_ENV'] : null) ?? 'development';

  /// Request timeout in seconds
  static int get apiTimeoutSeconds {
    final raw = dotenv.isInitialized ? dotenv.env['API_TIMEOUT_SECONDS'] : null;
    return (raw != null ? int.tryParse(raw) : null) ?? 10;
  }
}

/// Backward compatibility alias for existing network callers
String get kApiBase => AppEnv.apiBaseUrl;