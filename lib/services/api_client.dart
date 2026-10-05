import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../core/constants.dart';
import '../core/storage.dart';
import '../core/link_utils.dart';
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

  String get userFriendlyMessage {
    if (status == 408) {
      return 'Waktu Permintaan Habis: Sambungan ke server memerlukan waktu terlalu lama. Silakan periksa jaringan internet Anda dan coba lagi.';
    }
    if (status == 0) {
      return 'Tidak ada koneksi internet. Mohon periksa jaringan Anda.';
    }
    return message;
  }

  @override
  String toString() => 'ApiError($status): $message';
}

class ApiClient {
  final String base;

  // [FIX] SINGLETON PATTERN YANG BENAR
  static final ApiClient _instance = ApiClient._internal();

  // Lock untuk mencegah multiple refresh token calls
  bool _isRefreshing = false;
  // Lock untuk mencegah multiple force logout / session eviction calls
  bool _isEvictingSession = false;

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

  // [UPDATE] _handle sekarang hanya parsing JSON dan memformat pesan error yang ramah
  Future<dynamic> _handle(http.Response r) async {
    final txt = r.body.isEmpty ? '{}' : r.body;
    dynamic j;
    try {
      j = json.decode(txt);
    } catch (_) {
      j = {'raw': txt};
    }

    if (r.statusCode >= 200 && r.statusCode < 300) return j;

    String? serverMsg;
    if (j is Map) {
      if (j['issues'] is List && (j['issues'] as List).isNotEmpty) {
        final first = (j['issues'] as List).first;
        if (first is Map && first['message'] is String && (first['message'] as String).trim().isNotEmpty) {
          serverMsg = (first['message'] as String).trim();
        }
      }
      if (serverMsg == null && j['message'] is String && (j['message'] as String).trim().isNotEmpty) {
        serverMsg = (j['message'] as String).trim();
      }
    }

    if (r.statusCode == 401) {
      final msg = serverMsg ?? 'Email atau kata sandi salah. Silakan periksa kembali.';
      throw ApiError(msg, status: 401, detail: j);
    }

    if (r.statusCode == 403) {
      final msg = serverMsg ?? 'Akses ditolak atau akun belum diaktivasi.';
      throw ApiError(msg, status: 403, detail: j);
    }

    if (r.statusCode == 404) {
      final msg = serverMsg ?? 'Data atau layanan tidak ditemukan.';
      throw ApiError(msg, status: 404, detail: j);
    }

    if (r.statusCode == 429) {
      final msg = serverMsg ?? 'Terlalu banyak percobaan. Silakan coba beberapa saat lagi.';
      throw ApiError(msg, status: 429, detail: j);
    }

    throw ApiError(
      serverMsg ?? 'Terjadi kesalahan pada server (${r.statusCode}).',
      status: r.statusCode,
      detail: j,
    );
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
          await _forceLogout(message: "Sesi berakhir, silakan login kembali.");
          throw ApiError("Sesi berakhir, silakan login kembali.", status: 401);
        }
      }

      // 3. Jika 403 Forbidden -> Sesi Invalid / Akses Ditolak -> Logout Paksa
      if (response.statusCode == 403) {
        debugPrint("⛔ Akses Ditolak / Sesi Tidak Valid (403). Logout Paksa.");
        await _forceLogout(message: "Sesi Anda telah berakhir atau tidak memiliki izin akses. Silakan masuk kembali.");
        throw ApiError("Sesi Anda telah berakhir atau tidak memiliki izin akses. Silakan masuk kembali.", status: 403);
      }

      // Jika error lain, lempar ke _handle
      return _handle(response);

    } on TimeoutException catch (e) {
      debugPrint("⏱️ [HTTP 408 Timeout] Request timed out after ${AppEnv.apiTimeoutSeconds}s: $e");
      throw ApiError('Waktu Permintaan Habis: Sambungan ke server memerlukan waktu terlalu lama. Silakan periksa jaringan internet Anda dan coba lagi.', status: 408);
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

  Future<void> _forceLogout({String? message}) async {
    if (_isEvictingSession) return;
    _isEvictingSession = true;
    try {
      String? currentToken;
      try {
        currentToken = await FirebaseMessaging.instance.getToken();
      } catch (_) {}
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}

      await Prefs.clearAll();

      if (currentToken != null && currentToken.isNotEmpty) {
        await Prefs.setPendingFcmRevocation(currentToken);
      }

      navigatorKey.currentState?.pushNamedAndRemoveUntil(Routes.login, (route) => false);
      if (message != null && message.isNotEmpty) {
        scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error saat force logout: $e");
    } finally {
      Future.delayed(const Duration(seconds: 1), () {
        _isEvictingSession = false;
      });
    }
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
    try {
      final r = await http.post(
        Uri.parse('$base/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(Duration(seconds: AppEnv.apiTimeoutSeconds));

      // Tangkap Cookie dari header response
      _saveCookieFromResponse(r);

      final j = await _handle(r);
      final token = j['token'] as String?;
      if (token != null) await Prefs.setToken(token);

      return (j['user'] as Map).cast<String, dynamic>();
    } on TimeoutException {
      throw ApiError(
        'Waktu permintaan habis: Sambungan ke server memerlukan waktu terlalu lama. Silakan periksa jaringan internet Anda dan coba lagi.',
        status: 408,
      );
    }
  }

  // [NOTE] Register tidak perlu simpan cookie karena biasanya setelah register harus login ulang
  // atau backend tidak kirim cookie saat register.
  Future<dynamic> register({required String name, required String phone, required String email, required String password, required String role}) async {
    final r = await http.post(Uri.parse('$base/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'phone': normalizeIdPhone(phone), 'email': email, 'password': password, 'role': role}));
    return await _handle(r);
  }

  Future<void> sendOtp({required String phone}) async {
    await _post('$base/api/auth/otp/send', {'phone': normalizeIdPhone(phone), 'purpose': 'activate'});
  }
  Future<void> sendOtpWhatsApp(String phone, {String purpose = 'activate'}) async {
    await _post('$base/api/auth/otp/send', {'phone': normalizeIdPhone(phone), 'purpose': purpose});
  }
  Future<void> verifyOtp({required String phone, required String code, String purpose = 'activate'}) async {
    await _post('$base/api/auth/otp/verify', {'phone': normalizeIdPhone(phone), 'code': code, 'purpose': purpose});
  }

  Future<void> revokeFcmTokenPublic(String token) async {
    await _post('$base/api/public/revoke-fcm-token', {'fcmToken': token}, auth: false);
  }

  // [UPDATE] Logout aman online/offline: membersihkan sesi & menangani deferred FCM revocation
  Future<void> logout() async {
    String? currentToken;
    try {
      currentToken = await FirebaseMessaging.instance.getToken();
    } catch (_) {}

    bool serverSuccess = false;
    try {
      await _post('$base/api/auth/logout', {}, auth: true);
      serverSuccess = true;
    } catch (_) {
      // Offline: backend tidak dapat dihubungi saat ini
    }

    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}

    await Prefs.clearAll();

    // JIKA logout server gagal (offline) dan token ada, simpan penanda agar di-revoke saat online
    if (!serverSuccess && currentToken != null && currentToken.isNotEmpty) {
      await Prefs.setPendingFcmRevocation(currentToken);
    }
  }

  Future<void> requestPasswordReset({String? email, String? phone}) async {
    if (email != null && email.isNotEmpty) { await _post('$base/api/auth/password/forgot', {'email': email}); return; }
    if (phone != null && phone.isNotEmpty) { await _post('$base/api/auth/password/reset/request-otp', {'phone': normalizeIdPhone(phone)}); return; }
    throw ApiError('Harus mengirim email ATAU phone');
  }
  Future<void> requestPasswordResetOtpWa({required String phone}) async {
    await _post('$base/api/auth/password/reset/request-otp', {'phone': normalizeIdPhone(phone)});
  }
  Future<void> resetPassword({String? token, String? newPassword, String? phone, String? code}) async {
    if ((newPassword == null) || newPassword.isEmpty) throw ApiError('newPassword wajib diisi');
    if (token != null && token.isNotEmpty) { await _post('$base/api/auth/password/reset', {'token': token, 'new_password': newPassword}); return; }
    if (phone != null && code != null) { await resetPasswordByOtp(phone: phone, code: code, newPassword: newPassword); return; }
    throw ApiError('Kirim (token) ATAU (phone + code)');
  }
  Future<void> resetPasswordByOtp({required String phone, required String code, required String newPassword}) async {
    await _post('$base/api/auth/password/reset/confirm', {'phone': normalizeIdPhone(phone), 'code': code, 'new_password': newPassword});
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

  Future<Map<String, dynamic>> requestLinkPartner(String motherPhone) async {
    final j = await _post('$base/api/patient/partner/request', {'motherPhone': motherPhone}, auth: true);
    return (j is Map) ? j.cast<String, dynamic>() : {};
  }

  Future<Map<String, dynamic>> getPartnerStatus() async {
    final j = await _get('$base/api/patient/partner/status', auth: true);
    return (j is Map) ? j.cast<String, dynamic>() : {};
  }

  Future<Map<String, dynamic>> respondPartnerRequest({required String requestId, required bool approve}) async {
    final j = await _post('$base/api/patient/partner/respond', {
      'requestId': requestId,
      'action': approve ? 'APPROVE' : 'REJECT',
    }, auth: true);
    return (j is Map) ? j.cast<String, dynamic>() : {};
  }

  Future<void> unlinkPartner() async {
    await _post('$base/api/patient/partner/unlink', {}, auth: true);
  }

  Future<void> cancelPartnerRequest() async {
    await _delete('$base/api/patient/partner/cancel', auth: true);
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

  Future<Map<String, dynamic>> nurseGetPatientLogbook(String patientId) async {
    final j = await _get('$base/api/nurse/patients/$patientId/logbook', auth: true);
    if (j is Map) return j.cast<String, dynamic>();
    if (j is List) return {'items': j};
    return {'items': []};
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

  // [ISOLASI DOMAIN] Endpoint Brainstorming Khusus Perawat
  // Mengambil materi brainstorming perawat dari admin web secara eksklusif
  Future<List<dynamic>> getNurseBrainstorming() async {
    final j = await _get('$base/api/nurse/brainstorming', auth: true);
    if (j is List) return j;
    if (j is Map && j.containsKey('items')) return j['items'] as List<dynamic>;
    return [];
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

  // ==========================================
  // INFANT ANALYTICS & GROWTH MEASUREMENTS
  // ==========================================

  Future<Map<String, dynamic>> getInfantAnalytics([String? infantId]) async {
    final targetId = (infantId != null && infantId.isNotEmpty) ? infantId : 'me';
    final j = await _get('$base/api/analytics/infant/$targetId', auth: true);
    if (j is Map<String, dynamic>) {
      return j;
    }
    return {};
  }

  Future<Map<String, dynamic>> addGrowthMeasurement(String infantId, Map<String, dynamic> data) async {
    final j = await _post('$base/api/analytics/infant/$infantId/measurement', data, auth: true);
    if (j is Map<String, dynamic>) {
      return j;
    }
    return {};
  }

  Future<Map<String, dynamic>> updateGrowthMeasurement(String infantId, int measurementId, Map<String, dynamic> data) async {
    final j = await _put('$base/api/analytics/infant/$infantId/measurement/$measurementId', data, auth: true);
    if (j is Map<String, dynamic>) {
      return j;
    }
    return {};
  }

  Future<Map<String, dynamic>> reviewGrowthMeasurement(String infantId, int measurementId, Map<String, dynamic> data) async {
    final j = await _put('$base/api/analytics/infant/$infantId/measurement/$measurementId/review', data, auth: true);
    if (j is Map<String, dynamic>) {
      return j;
    }
    return {};
  }

  Future<void> deleteGrowthMeasurement(String infantId, int measurementId) async {
    await _delete('$base/api/analytics/infant/$infantId/measurement/$measurementId', auth: true);
  }

  Future<Map<String, dynamic>> addNurseReview(String infantId, Map<String, dynamic> data) async {
    final j = await _post('$base/api/analytics/infant/$infantId/nurse-review', data, auth: true);
    if (j is Map<String, dynamic>) {
      return j;
    }
    return {};
  }

  Future<Map<String, dynamic>> updateNurseReview(String infantId, int reviewId, Map<String, dynamic> data) async {
    final j = await _put('$base/api/analytics/infant/$infantId/nurse-review/$reviewId', data, auth: true);
    if (j is Map<String, dynamic>) {
      return j;
    }
    return {};
  }

  Future<void> deleteNurseReview(String infantId, int reviewId) async {
    await _delete('$base/api/analytics/infant/$infantId/nurse-review/$reviewId', auth: true);
  }
}