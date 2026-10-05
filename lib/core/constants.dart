import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const kAppName = 'ENI Care';
const kPrimary = Color(0xFF00A67E);
const kConsentLastUpdated = '2025-08-01';

// ========== Dynamic Environment Configuration (Native Dart Define) ==========
class AppEnv {
  /// Base URL of the RESTful API backend
  static String get apiBaseUrl {
    const defineBase = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (defineBase.isNotEmpty) return defineBase;

    const legacyDefine = String.fromEnvironment('API_BASE', defaultValue: '');
    if (legacyDefine.isNotEmpty) return legacyDefine;

    // Smart platform fallback for development
    if (kIsWeb) return 'http://localhost:4000';
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:4000'
        : 'http://localhost:4000';
  }

  /// Application Name
  static const appName = String.fromEnvironment('APP_NAME', defaultValue: kAppName);

  /// Environment mode: 'development', 'staging', or 'production'
  static const environment = String.fromEnvironment('APP_ENV', defaultValue: 'development');

  /// Request timeout in seconds
  static const apiTimeoutSeconds = int.fromEnvironment('API_TIMEOUT_SECONDS', defaultValue: 10);
}

/// Backward compatibility alias for existing network callers
String get kApiBase => AppEnv.apiBaseUrl;