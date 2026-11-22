import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import '../routes.dart';
import '../services/api_client.dart';
import '../widgets/common.dart';

class ActivatePage extends StatefulWidget {
  const ActivatePage({super.key});

  @override
  State<ActivatePage> createState() => _ActivatePageState();
}

class _ActivatePageState extends State<ActivatePage> {
  final _form = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  bool _submitting = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (_phoneCtrl.text.isEmpty) {
      if (arg is String && arg.isNotEmpty) {
        _phoneCtrl.text = arg;
      } else if (arg is Map) {
        final phone = arg['phone'] ?? arg['payload']?['phone'];
        if (phone is String && phone.isNotEmpty) {
          _phoneCtrl.text = phone;
        }
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
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

  Future<void> _resendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      showAppInfoDialog(
        context,
        title: 'Peringatan',
        message: 'Nomor ponsel WhatsApp belum diisi.',
        isError: true,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiClient().sendOtp(phone: phone);
      if (!mounted) return;

      await showAppInfoDialog(
        context,
        title: 'OTP Terkirim',
        message: 'Kode OTP baru telah dikirim ke WhatsApp Anda. Jika belum menerima kode dalam beberapa menit, coba kirim ulang atau silakan hubungi Admin.',
      );

      _startCooldown(60);
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
          message: 'Gagal mengirim OTP ($e). Coba beberapa saat lagi atau silakan hubungi Admin.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _activate() async {
    if (!_form.currentState!.validate()) return;
    final phone = _phoneCtrl.text.trim();
    final code = _otpCtrl.text.trim();

    setState(() => _submitting = true);
    try {
      await ApiClient().verifyOtp(phone: phone, code: code);
      if (!mounted) return;

      await showAppInfoDialog(
        context,
        title: 'Aktivasi Berhasil',
        message: 'Akun Anda telah aktif. Silakan masuk menggunakan email dan kata sandi Anda.',
      );

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, Routes.login, (r) => false);
    } catch (e) {
      if (!mounted) return;

      if (e is ApiError && e.status == 0) {
        showAppInfoDialog(
          context,
          title: 'Gagal Aktivasi',
          message: 'Tidak ada koneksi internet. Mohon periksa jaringan Anda atau silakan hubungi Admin.',
          isError: true,
        );
      } else {
        showAppInfoDialog(
          context,
          title: 'Aktivasi Gagal',
          message: '$e — periksa kembali kode OTP Anda atau silakan hubungi Admin.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _validatePhone(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Nomor WhatsApp wajib diisi';
    if (s.replaceAll(RegExp(r'\D'), '').length < 8) return 'Nomor terlalu pendek';
    return null;
  }

  String? _validateOtp(String? v) {
    final s = (v ?? '').trim();
    if (s.length != 6 || !RegExp(r'^\d{6}$').hasMatch(s)) return 'OTP harus 6 digit';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _cooldown == 0 && !_submitting;
    final canActivate = !_submitting && _otpCtrl.text.trim().length == 6;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kLightSystemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
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
                          'Aktivasi Akun Anda',
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
                          'Silakan aktifkan akun Anda dengan memasukkan Kode OTP 6 digit yang dikirim melalui WhatsApp, atau silakan hubungi Admin.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: Color(0xFF475569),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _ActivateField(
                          label: 'Nomor WhatsApp',
                          icon: Icons.phone_android_rounded,
                          controller: _phoneCtrl,
                          validator: _validatePhone,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        _ActivateField(
                          label: 'Kode OTP (6 digit)',
                          icon: Icons.lock_clock_rounded,
                          controller: _otpCtrl,
                          validator: _validateOtp,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 50),
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                    foregroundColor: const Color(0xFF475569),
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    textStyle: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  onPressed: canResend ? _resendOtp : null,
                                  child: Text(
                                    canResend ? 'Kirim Ulang Kode' : 'Kirim Ulang (${_cooldown}s)',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 50),
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    textStyle: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  onPressed: (canActivate && !_submitting) ? _activate : null,
                                  child: _submitting
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text('Aktivasi', textAlign: TextAlign.center),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: TextButton(
                              onPressed: () => Navigator.pushNamedAndRemoveUntil(context, Routes.start, (r) => false),
                              child: const Text(
                                'Kembali ke Halaman Awal',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: Color(0xFF475569),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
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

class _ActivateField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final void Function(String)? onChanged;

  const _ActivateField({
    required this.label,
    required this.icon,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
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
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          onChanged: onChanged,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: 'Masukkan $label',
            hintStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8), fontSize: 14),
            prefixIcon: Icon(icon, color: const Color(0xFF475569), size: 20),
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
