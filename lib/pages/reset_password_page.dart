import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../routes.dart';
import '../services/api_client.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    this.token,          // DIABAIKAN
    this.presetPhone,    // prefill
  });

  final String? token;
  final String? presetPhone;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();

  final _otpFocus = FocusNode();

  bool _loading = false;
  bool _ob1 = true, _ob2 = true;

  // resend state
  bool _sentOnce = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if ((widget.presetPhone ?? '').isNotEmpty) {
      _phone.text = widget.presetPhone!;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (_phone.text.isEmpty) {
      if (args is String) {
        _phone.text = args;
      } else if (args is Map) {
        final m = args.cast<String, dynamic>();
        final p = m['presetPhone'] as String?;
        if ((p ?? '').isNotEmpty) _phone.text = p!;
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpFocus.dispose();
    _phone.dispose();
    _otp.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  // [HELPER] Dialog Info
  Future<void> _showDialogInfo(String title, String message, {bool isError = false, String btnText = "OK", VoidCallback? onBtnPressed}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: isError ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(color: isError ? Colors.red : Colors.green, fontSize: 16),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: onBtnPressed ?? () => Navigator.pop(ctx),
            child: Text(btnText),
          ),
        ],
      ),
    );
  }

  /* =========================
     Validators
     ========================= */

  String? _validatePhone(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Wajib diisi';
    if (s.replaceAll(RegExp(r'\D'), '').length < 8) return 'Min 8 digit';
    return null;
  }

  String? _validateOtp(String? v) {
    final s = (v ?? '').trim();
    if (s.length != 6 || !RegExp(r'^\d{6}$').hasMatch(s)) return 'Harus 6 digit';
    return null;
  }

  String? _validatePass(String? v) {
    final s = v ?? '';
    if (s.length < 8) return 'Min 8 karakter';
    if (!RegExp(r'[A-Z]').hasMatch(s)) return 'Wajib huruf besar';
    if (!RegExp(r'[a-z]').hasMatch(s)) return 'Wajib huruf kecil';
    if (!RegExp(r'[0-9]').hasMatch(s)) return 'Wajib angka';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(s)) return 'Wajib simbol';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v != _pass.text) return 'Password tidak sama';
    return null;
  }

  /* =========================
     Cooldown
     ========================= */

  void _startCooldown([int sec = 60]) {
    _timer?.cancel();
    setState(() => _cooldown = sec);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  /* =========================
     Actions
     ========================= */

  Future<void> _sendOrResendOtp() async {
    // Validasi phone saja
    final ok = (_phone.text.trim().isNotEmpty) && (_validatePhone(_phone.text) == null);
    if (!ok) {
      // Trigger validasi visual form
      _form.currentState!.validate();
      return;
    }

    setState(() => _loading = true);
    try {
      await ApiClient().requestPasswordResetOtpWa(phone: _phone.text.trim());
      if (!mounted) return;

      setState(() => _sentOnce = true);
      _startCooldown(60);
      FocusScope.of(context).requestFocus(_otpFocus);

      _showDialogInfo("OTP Terkirim", "Kode OTP baru telah dikirim ke WhatsApp Anda.");

    } catch (e) {
      if (!mounted) return;
      if (e is ApiError && e.status == 0) {
        _showDialogInfo("Gagal Kirim", "Tidak ada koneksi internet.", isError: true);
      } else {
        _showDialogInfo("Gagal", e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _doReset() async {
    if (!_form.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await ApiClient().confirmPasswordResetOtpWa(
        phone: _phone.text.trim(),
        code: _otp.text.trim(),
        newPassword: _pass.text,
      );

      if (!mounted) return;

      await _showDialogInfo(
          "Berhasil",
          "Password berhasil diubah. Silakan login.",
          btnText: "Login",
          onBtnPressed: () {
            Navigator.pop(context);
            Navigator.pushNamedAndRemoveUntil(context, Routes.login, (r) => false);
          }
      );

    } catch (e) {
      if (!mounted) return;
      if (e is ApiError && e.status == 0) {
        _showDialogInfo("Gagal Reset", "Tidak ada koneksi internet.", isError: true);
      } else {
        _showDialogInfo("Gagal", e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Logic Button State
    final canResend = _cooldown == 0 && !_loading;
    final resendLabel = _sentOnce
        ? (canResend ? 'Kirim Ulang' : 'Tunggu (${_cooldown}s)')
        : (canResend ? 'Kirim Kode' : 'Tunggu (${_cooldown}s)');

    // Responsive Size
    final size = MediaQuery.of(context).size;
    final double illustrationHeight = size.height * 0.35;
    final double cardTop = illustrationHeight - 30;

    return Scaffold(
      backgroundColor: const Color(0xFF14AE5C),
      body: Stack(
        children: [
          // 1. ILUSTRASI
          Positioned(
            left: 0,
            right: 0,
            top: 25,
            height: illustrationHeight - 40,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Image.asset(
                  "assets/forgot-reset-logo.png", // Ganti dengan ilustrasi reset password
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.lock_reset, size: 100, color: Colors.white);
                  },
                ),
              ),
            ),
          ),

          // 2. CARD BACKGROUND
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: cardTop,
            child: Container(
              decoration: const ShapeDecoration(
                gradient: LinearGradient(
                  begin: Alignment(0.50, -0.00),
                  end: Alignment(0.50, 1.00),
                  colors: [Color(0xFFDADADA), Color(0x9914AE5C)],
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(35),
                    topRight: Radius.circular(35),
                  ),
                ),
              ),
            ),
          ),

          // 3. CONTENT FORM
          Positioned.fill(
            top: cardTop + 20,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // JUDUL
                    const Text(
                      'Reset Password',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.33,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      _sentOnce
                          ? 'Masukkan OTP & Password Baru'
                          : 'Atur Password Baru via OTP',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _sentOnce
                          ? 'Kami telah mengirim OTP ke WhatsApp Anda'
                          : 'Kode OTP akan dikirim ke WhatsApp Anda',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),

                    const SizedBox(height: 30),

                    // INPUT: WHATSAPP
                    _FigmaInput(
                      label: "Nomor WhatsApp",
                      icon: Icons.phone_android_outlined,
                      controller: _phone,
                      validator: _validatePhone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    // INPUT: OTP
                    _FigmaInput(
                      label: "Kode OTP (6 digit)",
                      icon: Icons.lock_clock_outlined,
                      controller: _otp,
                      validator: _validateOtp,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // INPUT: PASSWORD BARU
                    _FigmaInput(
                      label: "Password Baru",
                      icon: Icons.lock_outline,
                      controller: _pass,
                      validator: _validatePass,
                      obscureText: _ob1,
                      suffixIcon: IconButton(
                        icon: Icon(_ob1 ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setState(() => _ob1 = !_ob1),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // INPUT: KONFIRMASI PASSWORD
                    _FigmaInput(
                      label: "Konfirmasi Password",
                      icon: Icons.lock_reset,
                      controller: _pass2,
                      validator: _validateConfirm,
                      obscureText: _ob2,
                      suffixIcon: IconButton(
                        icon: Icon(_ob2 ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setState(() => _ob2 = !_ob2),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // TOMBOL AKSI (KIRIM KODE & GANTI PASSWORD)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Tombol Kirim Kode
                        Expanded(
                          child: _FigmaButton(
                            label: resendLabel,
                            onTap: canResend ? _sendOrResendOtp : () {},
                            isDisabled: !canResend, // Visual abu-abu jika cooldown
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Tombol Ganti Password
                        Expanded(
                          child: _FigmaButton(
                            label: _loading ? "..." : "Ganti Password",
                            onTap: _loading ? () {} : _doReset,
                            isPrimary: true, // Biru
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // KEMBALI KE LOGIN
                    GestureDetector(
                      onTap: () => Navigator.pushNamedAndRemoveUntil(context, Routes.login, (r) => false),
                      child: const Text(
                        'Kembali ke Login',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Tips: Pastikan nomor aktif & memiliki aplikasi WhatsApp. Jika belum menerima kode, coba kirim ulang setelah jeda 60 detik.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// [WIDGET] Input Field Konsisten
class _FigmaInput extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;

  const _FigmaInput({
    required this.label,
    required this.icon,
    required this.controller,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Container(
              height: 50,
              decoration: ShapeDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                shadows: const [BoxShadow(color: Color(0x3F000000), blurRadius: 4, offset: Offset(0, 4))],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 36, right: 16),
              child: TextFormField(
                controller: controller,
                obscureText: obscureText,
                keyboardType: keyboardType,
                inputFormatters: inputFormatters,
                validator: validator,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: label,
                  hintStyle: const TextStyle(color: Colors.black54, fontSize: 13, fontFamily: 'Inter'),
                  contentPadding: const EdgeInsets.only(left: 12, top: 14, bottom: 14),
                  border: InputBorder.none,
                  suffixIcon: suffixIcon,
                  errorStyle: const TextStyle(
                    color: Color.fromARGB(255, 185, 0, 0),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 13,
              child: Icon(icon, color: Colors.grey, size: 24),
            ),
          ],
        ),
      ],
    );
  }
}

// [WIDGET] Tombol Konsisten
class _FigmaButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDisabled;
  final bool isPrimary;

  const _FigmaButton({
    required this.label,
    required this.onTap,
    this.isDisabled = false,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final Decoration decoration = isDisabled
        ? BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(15))
        : isPrimary
        ? ShapeDecoration(
      gradient: const LinearGradient(
        begin: Alignment(0.0, 0.5),
        end: Alignment(1.0, 0.5),
        colors: [Color(0xFF27AAE1), Color(0xFF155C7B)],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      shadows: const [BoxShadow(color: Color(0x3F000000), blurRadius: 3, offset: Offset(0, 4))],
    )
        : ShapeDecoration(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      shadows: const [BoxShadow(color: Color(0x3F000000), blurRadius: 3, offset: Offset(0, 4))],
    );

    final Color textColor = isDisabled
        ? Colors.white70
        : isPrimary ? Colors.white : Colors.black87;

    return Container(
      width: double.infinity,
      height: 40,
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: isDisabled ? null : onTap,
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}