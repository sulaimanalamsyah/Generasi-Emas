import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Prefs {
  static Future<SharedPreferences> get _p async => SharedPreferences.getInstance();

  // Secure storage for sensitive credentials (JWT, cookie)
  // Uses Android Keystore (API 23+) / iOS Keychain automatically
  static const _secure = FlutterSecureStorage();

  // --- KEYS ---
  static const _kLastStartSeenMs = 'last_start_seen_ms';
  static const _kActivated = 'activated';
  static const _kDisplayName = 'display_name';
  static const _kRole = 'role';
  static const _kPretestDone = 'pretest_done';
  static const _kPretestDateMs = 'pretest_date_ms';
  static const _kPhone = 'phone';
  static const _kToken = 'jwt';
  static const _kFormLinks = 'FORM_LINKS';
  static const _kCookie = 'auth_cookie';

  // --- TOKEN (stored in Android Keystore / iOS Keychain) ---
  static Future<void> setToken(String v) async => _secure.write(key: _kToken, value: v);
  static Future<String?> getToken() async => _secure.read(key: _kToken);

  // --- COOKIE (stored securely) ---
  static Future<void> setCookie(String v) async => _secure.write(key: _kCookie, value: v);
  static Future<String?> getCookie() async => _secure.read(key: _kCookie);

  static Future<void> clearToken() async {
    await _secure.delete(key: _kToken);
    await _secure.delete(key: _kCookie);
    final p = await _p;
    await p.remove(_kRole);
    await p.remove(_kDisplayName);
  }

  // --- APP STATE ---
  static Future<void> setLastStartSeenNow() async => (await _p).setInt(_kLastStartSeenMs, DateTime.now().millisecondsSinceEpoch);
  static Future<int?> getLastStartSeenMs() async => (await _p).getInt(_kLastStartSeenMs);

  static Future<void> setActivated(bool v) async => (await _p).setBool(_kActivated, v);
  static Future<bool> getActivated() async => (await _p).getBool(_kActivated) ?? false;

  // --- USER DATA ---
  static Future<void> setDisplayName(String v) async => (await _p).setString(_kDisplayName, v);
  static Future<String?> getDisplayName() async => (await _p).getString(_kDisplayName);

  static Future<void> setRole(String v) async => (await _p).setString(_kRole, v);
  static Future<String?> getRole() async => (await _p).getString(_kRole);

  static Future<void> setPretestDone(bool v) async => (await _p).setBool(_kPretestDone, v);
  static Future<bool> getPretestDone() async => (await _p).getBool(_kPretestDone) ?? false;

  static Future<void> setPretestDateMs(int ms) async => (await _p).setInt(_kPretestDateMs, ms);
  static Future<int?> getPretestDateMs() async => (await _p).getInt(_kPretestDateMs);

  static Future<void> setPhone(String v) async => (await _p).setString(_kPhone, v);
  static Future<String?> getPhone() async => (await _p).getString(_kPhone);

  // --- GENERIC HELPERS ---
  static Future<bool?> getBool(String key) async {
    final sp = await _p;
    if (!sp.containsKey(key)) return null;
    return sp.getBool(key);
  }

  static Future<void> setBool(String key, bool value) async {
    final sp = await _p;
    await sp.setBool(key, value);
  }

  static Future<void> clearAll() async {
    final p = await _p;
    await p.clear();
  }

  static Future<void> setFormLinks(Map<String, dynamic> links) async {
    final p = await _p;
    final jsonString = jsonEncode(links);
    await p.setString(_kFormLinks, jsonString);
    debugPrint("💾 Storage: Saved ${links.length} form links.");
  }

  static Future<Map<String, String>> getFormLinks() async {
    final p = await _p;
    final s = p.getString(_kFormLinks);

    if (s == null) {
      debugPrint("💾 Storage: No form links found (NULL).");
      return {};
    }

    try {
      final decoded = jsonDecode(s);
      if (decoded is Map) {
        final result = decoded.map((key, value) => MapEntry(key.toString(), value.toString()));
        debugPrint("💾 Storage: Read ${result.length} form links successfully.");
        return Map<String, String>.from(result);
      }
    } catch (e) {
      debugPrint("❌ Storage: Error decoding form links: $e");
    }
    return {};
  }

  static Future<bool> getNotificationEnabled() async {
    final p = await _p;
    return p.getBool('notif_enabled') ?? true;
  }

  static Future<void> setNotificationEnabled(bool val) async {
    final p = await _p;
    await p.setBool('notif_enabled', val);
  }
}