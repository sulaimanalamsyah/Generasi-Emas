import '../core/storage.dart';
import 'api_client.dart';
import 'fcm_service.dart';

class AuthService {
  final _api = ApiClient();

  // Normalisasi nomor ke 62xxxxxxxx
  String _normalizeIdPhone(String raw) {
    var p = raw.replaceAll(RegExp(r'\D'), '');
    if (p.startsWith('0')) p = '62${p.substring(1)}';
    if (p.startsWith('8')) p = '62$p';
    return p;
  }

  Future<bool> register({
    required String name, // [FIX] Tambahkan parameter name
    required String phone,
    required String email,
    required String password,
    required String role, // 'mother' | 'father'
  }) async {
    final norm = _normalizeIdPhone(phone);
    try {
      // [FIX] Teruskan name ke API
      await _api.register(
          name: name,
          phone: norm,
          email: email,
          password: password,
          role: role
      );
      await Prefs.setPhone(norm);
      return true;
    } catch (e) {
      // Pemanis: treat ACCOUNT_ALREADY_ACTIVE sebagai "sukses"
      if (e is ApiError) {
        final detail = e.detail;
        final code = (detail is Map && detail['code'] is String)
            ? detail['code'] as String
            : null;

        if (code == 'ACCOUNT_ALREADY_ACTIVE') {
          await Prefs.setPhone(norm);
          return true;
        }
      }
      return false;
    }
  }

  /// Kirim OTP aktivasi via WhatsApp
  Future<bool> sendOtp() async {
    final phone = await Prefs.getPhone();
    if (phone == null) return false;
    try {
      await _api.sendOtpWhatsApp(phone, purpose: 'activate');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Verifikasi OTP aktivasi
  Future<bool> verifyOtp(String code) async {
    final phone = await Prefs.getPhone();
    if (phone == null) return false;
    try {
      await _api.verifyOtp(phone: phone, code: code, purpose: 'activate');
      await Prefs.setActivated(true);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Login → simpan token, role, dan display name (diambil dari profil)
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _api.login(email: email, password: password);

      final role = (user['role'] as String?) ?? 'mother';
      await Prefs.setRole(role);

      // [UPDATE] Prioritaskan nama dari user.name jika ada
      String display = (user['name'] as String?) ??
          (user['email'] as String?)?.split('@').first ?? 'Pengguna';

      // Fallback ke profil jika nama di user object kosong (jarang terjadi dgn flow baru)
      try {
        final prof = await _api.getMyProfile();
        if (display == 'Pengguna' || display.contains('@')) {
          display = (prof?['motherName'] as String?) ?? display;
        }
      } catch (_) {/* ignore */}

      await Prefs.setDisplayName(display);

      // [BARU] === TRIGGER KIRIM FCM TOKEN SETELAH LOGIN SUKSES ===
      // Kita panggil tanpa await agar tidak memblokir UI jika internet lambat
      FcmService().sendCurrentToken();

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Lupa password → minta OTP via WhatsApp (purpose: reset)
  Future<bool> requestResetOtp({String? phone}) async {
    final p = phone ?? await Prefs.getPhone();
    if (p == null) return false;
    try {
      final norm = _normalizeIdPhone(p);
      await Prefs.setPhone(norm);
      await _api.requestPasswordReset(phone: norm);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Konfirmasi reset password via OTP WhatsApp
  Future<bool> confirmResetByOtp({
    required String code,
    required String newPassword,
  }) async {
    final phone = await Prefs.getPhone();
    if (phone == null) return false;
    try {
      await _api.resetPasswordByOtp(phone: phone, code: code, newPassword: newPassword);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Logout back-end (opsional) + bersihkan lokal
  Future<void> logout() async {
    try { await _api.logout(); } catch (_) {/* ignore */}
    await Prefs.clearAll();
  }

  /// Alias untuk bersihkan jejak lokal sebelum login/ketika sesi nyangkut.
  Future<void> logoutLocal() async {
    await Prefs.clearAll();
  }
}