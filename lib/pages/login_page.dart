import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import '../services/fcm_service.dart';
import '../core/storage.dart';
import '../routes.dart';
import '../widgets/common.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _api = ApiClient();

  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  // Modern SnackBar UI Notification replacing modal dialogs
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
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
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _pass.text;

    if (email.isEmpty && pass.isEmpty) {
      _showSnackBar("Email dan password wajib diisi.", isError: true);
      return;
    }
    if (email.isEmpty) {
      _showSnackBar("Email wajib diisi.", isError: true);
      return;
    }
    if (pass.isEmpty) {
      _showSnackBar("Password wajib diisi.", isError: true);
      return;
    }

    final emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _showSnackBar("Format email tidak valid. Contoh: nama@email.com", isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      await Prefs.clearAll();

      final user = await _api.login(email: email, password: pass);
      final role = (user['role'] as String?) ?? 'mother';
      await Prefs.setRole(role);

      final phone = user['phone'] as String?;
      if (phone != null && phone.isNotEmpty) {
        await Prefs.setPhone(phone);
      }

      String display = (user['name'] as String?) ??
          (user['email'] as String?)?.split('@').first ?? 'Pengguna';

      // Pre-fetch profil pasien HANYA jika akun adalah Ibu atau Ayah
      // Akun Perawat/Admin tidak memiliki record di /api/patient/me/profile sehingga memicu HTTP 403 & force logout
      if (role == 'mother' || role == 'father') {
        try {
          final res = await _api.getMyProfile();
          if (res != null && res['profile'] != null) {
            final userObj = res['profile']['user'] ?? {};
            final pPhone = userObj['phone'] as String?;
            if (pPhone != null && pPhone.isNotEmpty) {
              await Prefs.setPhone(pPhone);
            }

            final profileRole = userObj['role'];
            if (profileRole == 'mother') {
              final motherName = res['profile']['motherName'] ?? res['profile']['name'];
              if (motherName != null && motherName.toString().isNotEmpty) {
                display = motherName.toString();
              }
            }
          }
        } catch (e) {
          debugPrint("Gagal pre-fetch profil pasien: $e");
        }
      }

      await Prefs.setDisplayName(display);
      FcmService().sendCurrentToken();

      if (!mounted) return;
      setState(() => _loading = false);

      _goHomeByRole(role);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      if (e is ApiError) {
        if (e.status == 0) {
          _showSnackBar("Tidak dapat terhubung ke server. Periksa koneksi internet Anda.", isError: true);
        } else if (e.status == 401 ||
            e.status == 404 ||
            e.message.toLowerCase().contains('unauthorized') ||
            e.message.toLowerCase().contains('kredensial')) {
          _showSnackBar("Email atau kata sandi salah. Silakan periksa kembali.", isError: true);
        } else if (e.status == 429) {
          _showSnackBar("Terlalu banyak percobaan masuk. Mohon tunggu beberapa saat dan coba lagi.", isError: true);
        } else if (e.status == 408) {
          _showSnackBar("Waktu permintaan habis. Periksa koneksi internet Anda dan coba lagi.", isError: true);
        } else {
          _showSnackBar(e.message, isError: true);
        }
      } else {
        _showSnackBar("Terjadi kesalahan saat masuk. Silakan coba lagi.", isError: true);
      }
    }
  }

  void _goHomeByRole(String? role) {
    switch ((role ?? 'mother').toLowerCase()) {
      case 'nurse':
        Navigator.pushNamedAndRemoveUntil(context, Routes.nurseHome, (_) => false);
        break;
      case 'mother':
      case 'father':
      default:
        Navigator.pushNamedAndRemoveUntil(context, Routes.homePatient, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, Routes.start);
              }
            },
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0F0F172A),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Centralized Logo
                      const Center(child: AppLogo(size: 90)),
                      const SizedBox(height: 20),

                      // Headings
                      const Text(
                        'Masuk ke Akun Anda',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Masuk untuk mulai monitoring si Kecil',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Input Field: Email
                      const Text(
                        'Email',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'nama@email.com',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Input Field: Password
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Password',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          // Inline "Lupa Password?" link aligned right with label
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, Routes.forgot),
                            child: const Text(
                              'Lupa Password?',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0EA5E9),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _pass,
                        obscureText: _obscure,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Masukkan password Anda',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF94A3B8)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: const Color(0xFF94A3B8),
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Primary Button: Masuk
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Masuk',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Bottom Link: Belum punya akun? Daftar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Belum punya akun? ',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: Color(0xFF475569),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, Routes.register),
                            child: const Text(
                              'Daftar',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}