import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../routes.dart';
import '../services/api_client.dart';

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
    if (arg is String && _phoneCtrl.text.isEmpty) {
      _phoneCtrl.text = arg;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  // Helper Alert Dialog
  Future<void> _showDialogInfo(String title, String message, {bool isError = false}) {
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
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
      _showDialogInfo("Peringatan", "Nomor WhatsApp belum diisi", isError: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiClient().sendOtp(phone: phone);
      if (!mounted) return;

      await _showDialogInfo("OTP Terkirim", "Kode OTP baru telah dikirim ke WhatsApp Anda.");

      _startCooldown(60);
    } catch (e) {
      if (!mounted) return;

      if (e is ApiError && e.status == 0) {
        _showDialogInfo("Gagal Kirim", "Tidak ada koneksi internet. Mohon periksa jaringan Anda.", isError: true);
      } else {
        _showDialogInfo("Gagal", "Gagal mengirim OTP: $e", isError: true);
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

      await _showDialogInfo("Aktivasi Berhasil", "Akun Anda telah aktif. Silakan login.");

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(context, Routes.login, (r) => false);
    } catch (e) {
      if (!mounted) return;

      if (e is ApiError && e.status == 0) {
        _showDialogInfo("Gagal Aktivasi", "Tidak ada koneksi internet. Mohon periksa jaringan Anda.", isError: true);
      } else {
        _showDialogInfo("Aktivasi Gagal", e.toString(), isError: true);
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

    final size = MediaQuery.of(context).size;
    final double illustrationHeight = size.height * 0.35;
    final double cardTop = illustrationHeight - 30;

    return Scaffold(
      backgroundColor: const Color(0xFF14AE5C),
      body: Stack(
        children: [
          Positioned(
            left: 30,
            right: 0,
            top: 40,
            height: illustrationHeight - 40,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Image.asset(
                  "assets/activate-logo.png",
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.verified_user, size: 100, color: Colors.white);
                  },
                ),
              ),
            ),
          ),

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

          Positioned.fill(
            top: cardTop + 20,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Aktivasi Akun Anda',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.33,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 4),
                            blurRadius: 3,
                            color: Color.fromRGBO(0, 0, 0, 0.25),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    const Text(
                      'Silakan melakukan aktivasi akun Anda\ndengan menginputkan Kode Token\nyang didapat melalui Whatsapp',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 30),

                    _FigmaInput(
                      label: "Nomor WhatsApp",
                      icon: Icons.phone_android_outlined,
                      controller: _phoneCtrl,
                      validator: _validatePhone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    _FigmaInput(
                      label: "Kode OTP (6 digit)",
                      icon: Icons.lock_clock_outlined,
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _FigmaButton(
                            label: canResend
                                ? 'Kirim Ulang Kode'
                                : 'Kirim Ulang (${_cooldown}s)',
                            onTap: canResend ? _resendOtp : () {},
                            isDisabled: !canResend,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FigmaButton(
                            label: _submitting ? '...' : 'Aktivasi',
                            onTap: (canActivate && !_submitting) ? _activate : () {},
                            isDisabled: !(canActivate && !_submitting),
                            isPrimary: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    TextButton(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        Routes.start,
                            (r) => false,
                      ),
                      child: const Text(
                        'Kembali ke Halaman Awal',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.underline,
                        ),
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

// Widget Input Field
class _FigmaInput extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final void Function(String)? onChanged;

  const _FigmaInput({
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
        Stack(
          children: [
            Container(
              height: 50,
              decoration: ShapeDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                shadows: const [
                  BoxShadow(color: Color(0x3F000000), blurRadius: 4, offset: Offset(0, 4))
                ],
              ),
            ),
            TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              validator: validator,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              decoration: InputDecoration(
                hintText: label,
                hintStyle: const TextStyle(color: Colors.black54, fontSize: 13, fontFamily: 'Inter'),
                contentPadding: const EdgeInsets.only(left: 48, right: 16, top: 14, bottom: 14),
                border: InputBorder.none,
                errorStyle: const TextStyle(
                  color: Color.fromARGB(255, 200, 0, 0),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
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

// Widget Tombol Custom
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
        ? BoxDecoration(
      color: Colors.grey.shade400,
      borderRadius: BorderRadius.circular(15),
    )
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
        : isPrimary
        ? Colors.white
        : Colors.black87;

    return Container(
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