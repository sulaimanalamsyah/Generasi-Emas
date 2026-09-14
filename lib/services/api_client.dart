import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/constants.dart';
import '../core/storage.dart';
import '../app.dart';
import '../routes.dart';

// [BARU] Model untuk Data Skor Evaluasi
// Digunakan untuk parsing data dari field 'evaluationScores' di detail pasien
class EvaluationScore {
  final int id;
  final String type;     // e.g., 'PRE_CO', 'POST_PSS_1'
  final String label;    // e.g., 'Pre-Test Co-Partner'
  final String category; // e.g., 'PRETEST', 'POSTTEST'
  final int score;
  final DateTime? updatedAt;

  EvaluationScore({
    required this.id,
    required this.type,
    required this.label,
    required this.category,
    required this.score,
    this.updatedAt,
  });

  factory EvaluationScore.fromJson(Map<String, dynamic> json) {
    return EvaluationScore(
      id: json['id'] ?? 0,
      type: json['type'] ?? '',
      label: json['label'] ?? '',
      category: json['category'] ?? '',
      score: json['score'] ?? 0,
      updatedAt: ApiClient.parseDate(json['updatedAt']),
    );
  }
}

class ApiError implements Exception {
  final int? status;
  final String message;
  final Object? detail;
  ApiError(this.message, {this.status, this.detail});
  @override
  String toString() => 'ApiError($status): $message';
}

class ApiClient {
  final String base;

  // [FIX] SINGLETON PATTERN YANG BENAR
  static final ApiClient _instance = ApiClient._internal();

  // Lock untuk mencegah multiple refresh token calls
  bool _isRefreshing = false;

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal() : base = kApiBase.replaceAll(RegExp(r'/$'), '');

  // ==========================================================
  // [HELPER & DEBUGGING] DATE FORMATION
  // ==========================================================

  static String? formatDateOnly(DateTime? date) {
    if (date == null) return null;
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return "$y-$m-$d";
  }

  static String? formatDateTimeIso(DateTime? date) {
    if (date == null) return null;
    final utc = DateTime.utc(date.year, date.month, date.day);
    return utc.toIso8601String();
  }

  static DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    final dt = DateTime.tryParse(value.toString());
    return dt?.toLocal();
  }
  // ==========================================================

  Future<void> _checkConnection() async {
    final result = await Connectivity().checkConnectivity();
    if (result.contains(ConnectivityResult.none)) {
      throw ApiError('Tidak ada koneksi internet. Mohon periksa jaringan Anda.', status: 0);
    }
  }

  Future<Map<String, String>> _headers({bool auth = false}) async {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final t = await Prefs.getToken();
      if (t != null) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  // [UPDATE] _handle sekarang hanya parsing JSON, logika 401 dipindah ke _withRetry
  Future<dynamic> _handle(http.Response r) async {
    final txt = r.body.isEmpty ? '{}' : r.body;
    dynamic j;
    try {
      j = json.decode(txt);
    } catch (_) {
      j = {'raw': txt};
    }

    if (r.statusCode >= 200 && r.statusCode < 300) return j;

    // Jika masih masuk sini dengan 401, berarti retry gagal atau endpoint non-auth
    if (r.statusCode == 401) {
      throw ApiError('Unauthorized', status: 401, detail: j);
    }

    throw ApiError(
      j is Map && j['message'] is String ? j['message'] : 'Request gagal',
      status: r.statusCode,
      detail: j,
    );
  }

  String _normalizeIdPhone(String raw) {
    var p = raw.replaceAll(RegExp(r'\D'), '');
    if (p.startsWith('0')) p = '62${p.substring(1)}';
    if (p.startsWith('8')) p = '62$p';
    return p;
  }

  // ==========================================================
  // [BARU] LOGIKA RETRY & REFRESH TOKEN
  // ==========================================================

  Future<dynamic> _withRetry(Future<http.Response> Function() requestFn) async {
    await _checkConnection();
    try {
      // 1. Coba Request Pertama
      final response = await requestFn().timeout(Duration(seconds: AppEnv.apiTimeoutSeconds));

      // Jika sukses, return hasil via _handle
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _handle(response);
      }

      // 2. Jika 401 Unauthorized -> Coba Refresh Token
      if (response.statusCode == 401) {
        if (_isRefreshing) {
          throw ApiError("Sedang memperbarui sesi...", status: 401);
        }

        _isRefreshing = true;
        debugPrint("🔄 Token Expired (401). Mencoba Refresh Token...");
        final success = await _attemptRefreshToken();
        _isRefreshing = false;

        if (success) {
          debugPrint("✅ Refresh Berhasil. Mengulang Request...");
          // 3. Ulangi Request dengan Token Baru
          final retryResponse = await requestFn().timeout(Duration(seconds: AppEnv.apiTimeoutSeconds));
          return _handle(retryResponse);
        } else {
          debugPrint("❌ Refresh Gagal. Logout Paksa.");
          await _forceLogout();
          throw ApiError("Sesi berakhir, silakan login kembali.", status: 401);
        }
      }

      // Jika error lain, lempar ke _handle
      return _handle(response);

    } on TimeoutException {
      throw ApiError('Koneksi timeout.', status: 408);
    } catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError('Gagal menghubungi server: $e', status: 0);
    }
  }

  Future<bool> _attemptRefreshToken() async {
    try {
      final cookie = await Prefs.getCookie();
      if (cookie == null) return false;

      // Panggil endpoint refresh backend (Kirim cookie di header)
      final response = await http.post(
        Uri.parse('$base/api/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': cookie,
        },
      );

      if (response.statusCode == 200) {
        final j = jsonDecode(response.body);
        final newToken = j['token'];

        // Simpan Token Baru
        if (newToken != null) await Prefs.setToken(newToken);

        // Simpan Cookie Baru (jika ada rotasi refresh token)
        _saveCookieFromResponse(response);

        return true;
      }
    } catch (e) {
      debugPrint("Error Refresh Token: $e");
    }
    return false;
  }

  Future<void> _forceLogout() async {
    await Prefs.clearAll();
    navigatorKey.currentState?.pushNamedAndRemoveUntil(Routes.login, (route) => false);
  }

  // Helper Simpan Cookie
  void _saveCookieFromResponse(http.Response r) {
    String? rawCookie = r.headers['set-cookie'];
    if (rawCookie != null) {
      // Ambil bagian sebelum ; pertama
      int index = rawCookie.indexOf(';');
      String cookieVal = (index == -1) ? rawCookie : rawCookie.substring(0, index);
      Prefs.setCookie(cookieVal);
      debugPrint("🍪 Cookie disimpan: $cookieVal");
    }
  }

  // --- WRAPPER IMPLEMENTATION ---

  Future<dynamic> _post(String url, Map<String, dynamic> body, {bool auth = false}) {
    return _withRetry(() async {
      return await http.post(
        Uri.parse(url),
        headers: await _headers(auth: auth),
        body: jsonEncode(body),
      );
    });
  }

  Future<dynamic> _get(String url, {bool auth = false}) {
    return _withRetry(() async {
      return await http.get(
        Uri.parse(url),
        headers: await _headers(auth: auth),
      );
    });
  }

  Future<dynamic> _put(String url, Map<String, dynamic> body, {bool auth = false}) {
    return _withRetry(() async {
      return await http.put(
        Uri.parse(url),
        headers: await _headers(auth: auth),
        body: jsonEncode(body),
      );
    });
  }

  Future<dynamic> _delete(String url, {bool auth = false, Map<String, dynamic>? body}) {
    return _withRetry(() async {
      final req = http.Request('DELETE', Uri.parse(url));
      req.headers.addAll(await _headers(auth: auth));
      if (body != null) req.body = jsonEncode(body);
      final streamed = await req.send();
      return await http.Response.fromStream(streamed);
    });
  }

  /* ========== AUTH METHODS ========== */

  // [UPDATE] Login harus simpan Cookie secara manual sebelum _handle
  Future<Map<String, dynamic>> login({required String email, required String password}) async {
    await _checkConnection();
    final r = await http.post(
      Uri.parse('$base/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    // Tangkap Cookie dari header response
    _saveCookieFromResponse(r);

    final j = await _handle(r);
    final token = j['token'] as String?;
    if (token != null) await Prefs.setToken(token);

    return (j['user'] as Map).cast<String, dynamic>();
  }

  // [NOTE] Register tidak perlu simpan cookie karena biasanya setelah register harus login ulang
  // atau backend tidak kirim cookie saat register.
  Future<void> register({required String name, required String phone, required String email, required String password, required String role}) async {
    final r = await http.post(Uri.parse('$base/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'phone': _normalizeIdPhone(phone), 'email': email, 'password': password, 'role': role}));
    await _handle(r);
  }

  Future<void> sendOtp({required String phone}) async {
    await _post('$base/api/auth/otp/send', {'phone': _normalizeIdPhone(phone), 'purpose': 'activate'});
  }
  Future<void> sendOtpWhatsApp(String phone, {String purpose = 'activate'}) async {
    await _post('$base/api/auth/otp/send', {'phone': _normalizeIdPhone(phone), 'purpose': purpose});
  }
  Future<void> verifyOtp({required String phone, required String code, String purpose = 'activate'}) async {
    await _post('$base/api/auth/otp/verify', {'phone': _normalizeIdPhone(phone), 'code': code, 'purpose': purpose});
  }

  // [UPDATE] Logout juga harus clear cookie
  Future<void> logout() async {
    try { await _post('$base/api/auth/logout', {}, auth: true); } catch (_) {} finally { await Prefs.clearAll(); }
  }

  Future<void> requestPasswordReset({String? email, String? phone}) async {
    if (email != null && email.isNotEmpty) { await _post('$base/api/auth/password/forgot', {'email': email}); return; }
    if (phone != null && phone.isNotEmpty) { await _post('$base/api/auth/password/reset/request-otp', {'phone': _normalizeIdPhone(phone)}); return; }
    throw ApiError('Harus mengirim email ATAU phone');
  }
  Future<void> requestPasswordResetOtpWa({required String phone}) async {
    await _post('$base/api/auth/password/reset/request-otp', {'phone': _normalizeIdPhone(phone)});
  }
  Future<void> resetPassword({String? token, String? newPassword, String? phone, String? code}) async {
    if ((newPassword == null) || newPassword.isEmpty) throw ApiError('newPassword wajib diisi');
    if (token != null && token.isNotEmpty) { await _post('$base/api/auth/password/reset', {'token': token, 'new_password': newPassword}); return; }
    if (phone != null && code != null) { await resetPasswordByOtp(phone: phone, code: code, newPassword: newPassword); return; }
    throw ApiError('Kirim (token) ATAU (phone + code)');
  }
  Future<void> resetPasswordByOtp({required String phone, required String code, required String newPassword}) async {
    await _post('$base/api/auth/password/reset/confirm', {'phone': _normalizeIdPhone(phone), 'code': code, 'new_password': newPassword});
  }
  Future<void> confirmPasswordResetOtpWa({required String phone, required String code, required String newPassword}) {
    return resetPasswordByOtp(phone: phone, code: code, newPassword: newPassword);
  }

  /* ========== PUBLIC CONTENT ========== */
  // Semua method ini otomatis menggunakan _get/_post yang sudah dibungkus _withRetry

  Future<List<dynamic>> getContent(String type, String audience) async {
    try {
      final j = await _get('$base/api/public/content/$type?audience=$audience');
      if (j is Map && j.containsKey('items')) return j['items'] as List<dynamic>;
      if (j is List) return j;
      return [];
    } catch (e) {
      if (e is ApiError && e.status != 401) rethrow;
      return [];
    }
  }

  Future<List<dynamic>> getModules() async => getContent('MODULE', 'MOTHER');
  Future<List<dynamic>> getReferences() async => getContent('REFERENCE', 'MOTHER');
  Future<List<dynamic>> getContacts() async {
    final j = await _get('$base/api/public/contacts');
    return j is List ? j : [];
  }
  Future<Map<String, dynamic>> getConsentData() async {
    try {
      final j = await _get('$base/api/public/consent-text');
      return {'text': j['text'] as String? ?? '', 'updatedAt': j['updatedAt'] as String?};
    } catch (_) {}
    return {};
  }
  Future<Map<String, dynamic>> getPrivacyPolicy() async {
    try {
      final j = await _get('$base/api/public/privacy-policy');
      return {'text': j['text'] as String? ?? '', 'updatedAt': j['updatedAt'] as String?};
    } catch (e) { debugPrint("Gagal load privacy policy: $e"); }
    return {};
  }

  // Method ini tidak perlu retry karena dipanggil di awal (Splash)
  Future<Map<String, dynamic>> getAppVersionConfig() async {
    try {
      final r = await http.get(Uri.parse('$base/api/public/version')).timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint("⚠️ Gagal cek versi aplikasi: $e");
    }
    return {};
  }

  /* ========== PASIEN (authed) ========== */
  Future<Map<String, dynamic>?> getMyProfile() async {
    final j = await _get('$base/api/patient/me/profile', auth: true);
    return j as Map<String, dynamic>;
  }
  Future<Map<String, dynamic>> upsertMyProfile(Map<String, dynamic> data) async {
    final j = await _put('$base/api/patient/me/profile', data, auth: true);
    return (j['profile'] as Map).cast<String, dynamic>();
  }
  Future<Map<String, dynamic>> upsertInfant(Map<String, dynamic> data) async {
    final j = await _put('$base/api/patient/me/infant', data, auth: true);
    return (j['infant'] as Map).cast<String, dynamic>();
  }
  Future<void> createLogbook({required DateTime date, int? durationMinutes, bool coTargetMet = false, String? note}) async {
    await _post('$base/api/patient/me/logbook', {
      'date': formatDateOnly(date),
      'durationMinutes': durationMinutes,
      'coTargetMet': coTargetMet,
      'note': note,
    }, auth: true);
  }
  Future<void> deleteLogbook(DateTime date) async {
    await _delete('$base/api/patient/me/logbook', auth: true, body: {'date': formatDateOnly(date)});
  }
  Future<Map<String, dynamic>> getLogbook() async {
    final j = await _get('$base/api/patient/me/logbook', auth: true);
    if (j is Map) return j.cast<String, dynamic>();
    return {};
  }
  Future<void> createBabyJournal({required DateTime date, required String summary}) async {
    await _post('$base/api/patient/me/journal', {'date': formatDateOnly(date), 'summary': summary}, auth: true);
  }
  Future<void> deleteBabyJournal({required DateTime date}) async {
    await _delete('$base/api/patient/me/journal', auth: true, body: {'date': formatDateOnly(date)});
  }
  Future<List<dynamic>> getBabyJournal() async {
    final j = await _get('$base/api/patient/me/journal', auth: true);
    return (j['items'] as List?) ?? [];
  }
  Future<void> markFormDone({required String type, String? url}) async {
    await _post('$base/api/patient/me/pretests/complete', {'type': type, 'url': url}, auth: true);
  }
  Future<void> linkPartner(String motherPhone) async {
    await _post('$base/api/patient/link-partner', {'motherPhone': motherPhone}, auth: true);
  }

  // Nurse
  Future<List<dynamic>> nurseGetPatients() async {
    final j = await _get('$base/api/nurse/patients', auth: true);
    return (j['items'] as List?) ?? [];
  }

  Future<Map<String, dynamic>> nurseGetPatientDetail(String patientId) async {
    final j = await _get('$base/api/nurse/patients/$patientId', auth: true);
    // [NOTE] Response sekarang mengandung field 'evaluationScores'
    // yang bisa diparsing menggunakan EvaluationScore.fromJson di UI Page
    return (j is Map ? j : {'data': j})['data']?.cast<String, dynamic>() ?? (j as Map).cast<String, dynamic>();
  }

  Future<List<dynamic>> nurseGetPatientLogbook(String patientId) async {
    final j = await _get('$base/api/nurse/patients/$patientId/logbook', auth: true);
    return (j['items'] as List?) ?? [];
  }
  Future<List<dynamic>> nurseGetPatientJournal(String patientId) async {
    final j = await _get('$base/api/nurse/patients/$patientId/journal', auth: true);
    return (j['items'] as List?) ?? [];
  }
  Future<List<dynamic>> nurseGetAssignablePatients({String? q}) async {
    final uri = '$base/api/nurse/assignable-patients${q != null && q.isNotEmpty ? '?q=${Uri.encodeComponent(q)}' : ''}';
    final j = await _get(uri, auth: true);
    return (j['items'] as List?) ?? [];
  }
  Future<void> nurseAssignPatient(String patientId) async {
    await _post('$base/api/nurse/patients/$patientId/assign', {}, auth: true);
  }
  Future<void> nurseUnassignPatient(String patientId) async {
    await _delete('$base/api/nurse/patients/$patientId/assign', auth: true);
  }

  // [BARU] Endpoint untuk Sinkronisasi Manual Skor
  // Digunakan di menu Perawat untuk trigger update dari Google Sheets
  Future<Map<String, dynamic>> nurseSyncScores() async {
    final j = await _post('$base/api/nurse/sync-scores', {}, auth: true);
    return (j as Map).cast<String, dynamic>();
  }

  // Pretest
  Future<List<dynamic>> getPretests() async {
    final j = await _get('$base/api/patient/me/pretests', auth: true);
    return (j['items'] as List?) ?? [];
  }
  Future<Map<String, dynamic>> completePretest({required String type, String? url, int? score}) async {
    final j = await _post('$base/api/patient/me/pretests/complete', {'type': type, if (url != null) 'url': url, if (score != null) 'score': score}, auth: true);
    return (j as Map).cast<String, dynamic>();
  }
  // Posttest
  Future<Map<String, dynamic>> getPosttests() async {
    final j = await _get('$base/api/patient/me/posttests', auth: true);
    return (j as Map).cast<String, dynamic>();
  }
  Future<void> completePosttest({required int n, required String type, String? url, int? score}) async {
    await _post('$base/api/patient/me/posttests/complete', {'n': n, 'type': type, if (url != null) 'url': url, if (score != null) 'score': score}, auth: true);
  }
  // Infant
  Future<Map<String, dynamic>?> getInfant() async {
    try {
      final j = await _get('$base/api/patient/me/infant', auth: true);
      return j['infant'] as Map<String, dynamic>?;
    } catch (e) {
      if (e is ApiError && e.status == 404) return null;
      rethrow;
    }
  }
  // Form Scores
  Future<List<dynamic>> getMyFormScores() async {
    final j = await _get('$base/api/forms/me', auth: true);
    return (j['items'] as List?) ?? [];
  }
  Future<Map<String, dynamic>?> getMyFormScore(String kind) async {
    final j = await _get('$base/api/forms/me/$kind', auth: true);
    return (j['item'] as Map?)?.cast<String, dynamic>();
  }
  // Config
  Future<Map<String, dynamic>> getFormConfig() async {
    try {
      final r = await http.get(Uri.parse('$base/api/public/config/forms')).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        return jsonDecode(r.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("Gagal load config form: $e");
    }
    return {};
  }
  // FCM
  Future<void> updateFcmToken(String? token) async {
    try {
      await _put('$base/api/me/fcm-token', {'fcmToken': token}, auth: true);
    } catch (_) {}
  }

  // Notifications History
  Future<Map<String, dynamic>> getNotifications() async {
    final res = await _get('$base/api/me/notifications', auth: true);
    if (res is Map<String, dynamic>) {
      return res;
    }
    return {'notifications': [], 'unreadCount': 0};
  }

  Future<void> markNotificationAsRead(int id) async {
    try {
      await _put('$base/api/me/notifications/$id/read', {}, auth: true);
    } catch (_) {}
  }

  Future<void> markAllNotificationsAsRead() async {
    try {
      await _put('$base/api/me/notifications/read-all', {}, auth: true);
    } catch (_) {}
  }

  // Banner Carousel
  Future<List<Map<String, String>>> getBanners() async {
    try {
      final r = await http.get(Uri.parse('$base/api/public/banners')).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        if (decoded is List) {
          return decoded.map<Map<String, String>>((item) {
            final map = (item as Map).cast<String, dynamic>();
            return {
              'title': (map['title'] ?? '').toString(),
              'image': (map['image'] ?? '').toString(),
              'url': (map['url'] ?? '').toString(),
            };
          }).where((b) => b['image']!.isNotEmpty).toList();
        }
      }
    } catch (e) {
      debugPrint("Gagal load banners: $e");
    }
    return [];
  }
}