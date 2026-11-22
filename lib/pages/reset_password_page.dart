import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import '../routes.dart';
import '../services/api_client.dart';
import '../widgets/common.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    this.token,
    this.presetPhone,
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
  bool _ob1 = true;
  bool _ob2 = true;

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

  String? _validatePhone(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Nomor WhatsApp wajib diisi';
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
    if (v != _pass.text) return 'Kata sandi tidak sama';
    return null;
  }

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

  Future<void> _sendOrResendOtp() async {
    final ok = (_phone.text.trim().isNotEmpty) && (_validatePhone(_phone.text) == null);
    if (!ok) {
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

      showAppInfoDialog(
        context,
        title: 'OTP Terkirim',
        message: 'Kode OTP baru telah dikirim ke WhatsApp Anda. Jika belum masuk dalam 1 menit, coba kirim ulang atau silakan hubungi Admin.',
      );
    } catch (e) {
      if (!mounted) return;
      if (e is ApiError && e.status == 0) {
        showAppInfoDialog(
          context,
          title: 'Gagal Kirim',
          message: 'Tidak ada koneksi internet. Mohon periksa jaringan Anda atau silakan hubungi Admin.',
          isError: true,
        );
      } else {
        showAppInfoDialog(
          context,
          title: 'Gagal Kirim OTP',
          message: '$e — coba beberapa saat lagi atau silakan hubungi Admin.',
          isError: true,
        );
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

      await showAppInfoDialog(
        context,
        title: 'Berhasil',
        message: 'Kata sandi berhasil diubah. Silakan masuk menggunakan kata sandi baru Anda.',
        buttonLabel: 'Masuk Sekarang',
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, Routes.login, (r) => false);
    } catch (e) {
      if (!mounted) return;
      if (e is ApiError && e.status == 0) {
        showAppInfoDialog(
          context,
          title: 'Gagal Reset',
          message: 'Tidak ada koneksi internet. Mohon periksa jaringan Anda atau silakan hubungi Admin.',
          isError: true,
        );
      } else {
        showAppInfoDialog(
          context,
          title: 'Gagal Mengubah Kata Sandi',
          message: '$e — periksa kode OTP Anda atau silakan hubungi Admin.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _cooldown == 0 && !_loading;
    final resendLabel = _sentOnce
        ? (canResend ? 'Kirim Ulang' : 'Tunggu (${_cooldown}s)')
        : (canResend ? 'Kirim Ulang Kode' : 'Tunggu (${_cooldown}s)');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kLightSystemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          systemOverlayStyle: kLightSystemUiOverlayStyle,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 24),
            tooltip: 'Kembali',
            onPressed: () => Navigator.pop(context),
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
                  child: Form(
                    key: _form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: AppLogo(size: 90)),
                        const SizedBox(height: 20),
                        const Text(
                          'Ubah Kata Sandi',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _sentOnce
                              ? 'Masukkan OTP & Kata Sandi Baru'
                              : 'Atur Kata Sandi Baru via OTP',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _sentOnce
                              ? 'Kami telah mengirim kode OTP ke WhatsApp Anda atau silakan hubungi Admin.'
                              : 'Kode OTP akan dikirim ke WhatsApp Anda atau silakan hubungi Admin.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _ResetField(
                          label: 'Nomor Ponsel (WhatsApp)',
                          hintText: 'Masukkan nomor WhatsApp',
                          icon: Icons.phone_android_rounded,
                          controller: _phone,
                          validator: _validatePhone,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        _ResetField(
                          label: 'Kode OTP (6 digit)',
                          hintText: 'Masukkan 6 digit kode OTP',
                          icon: Icons.lock_clock_rounded,
                          controller: _otp,
                          focusNode: _otpFocus,
                          validator: _validateOtp,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _ResetField(
                          label: 'Kata Sandi Baru',
                          hintText: 'Minimal 8 karakter',
                          icon: Icons.lock_outline_rounded,
                          controller: _pass,
                          validator: _validatePass,
                          obscureText: _ob1,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _ob1 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: const Color(0xFF475569),
                            ),
                            onPressed: () => setState(() => _ob1 = !_ob1),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _ResetField(
                          label: 'Konfirmasi Kata Sandi',
                          hintText: 'Ulangi kata sandi baru',
                          icon: Icons.lock_reset_rounded,
                          controller: _pass2,
                          validator: _validateConfirm,
                          obscureText: _ob2,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _ob2 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: const Color(0xFF475569),
                            ),
                            onPressed: () => setState(() => _ob2 = !_ob2),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Builder(
                          builder: (btnCtx) {
                            final isLargeText = MediaQuery.textScalerOf(btnCtx).scale(14) > 19.5;
                            final resendBtn = ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 50),
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  foregroundColor: const Color(0xFF475569),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  textStyle: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: canResend ? _sendOrResendOtp : null,
                                child: Text(resendLabel, textAlign: TextAlign.center),
                              ),
                            );
                            final submitBtn = ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 50),
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  textStyle: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: _loading ? null : _doReset,
                                child: _loading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Ubah Kata Sandi', textAlign: TextAlign.center),
                              ),
                            );
                            if (isLargeText) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  submitBtn,
                                  const SizedBox(height: 10),
                                  resendBtn,
                                ],
                              );
                            }
                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(child: resendBtn),
                                  const SizedBox(width: 12),
                                  Expanded(child: submitBtn),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Text(
                            'Tips: Pastikan nomor aktif & memiliki aplikasi WhatsApp. Jika belum menerima kode, coba kirim ulang setelah 60 detik atau silakan hubungi Admin.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _ResetField extends StatelessWidget {
  final String label;
  final String hintText;
  final IconData icon;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;

  const _ResetField({
    required this.label,
    required this.hintText,
    required this.icon,
    required this.controller,
    this.focusNode,
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
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8), fontSize: 14),
            prefixIcon: Icon(icon, color: const Color(0xFF475569), size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
            ),
            errorStyle: const TextStyle(
              fontFamily: 'Inter',
              color: Color(0xFFEF4444),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
