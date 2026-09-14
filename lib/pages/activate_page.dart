import 'dart:async';
import 'package:flutter/material.dart';
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

  // Helper Alert Dialog
  Future<void> _showDialogInfo(String title, String message, {bool isError = false}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 15, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "OK",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF10B981),
              ),
            ),
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

    return Scaffold(
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
                child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Centralized Logo
                      const Center(child: AppLogo(size: 90)),
                      const SizedBox(height: 20),

                      // Headings
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
                        'Silakan melakukan aktivasi akun Anda\ndengan menginputkan Kode Token\nyang didapat melalui WhatsApp',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF475569),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),

                      _FigmaInput(
                        label: "Nomor WhatsApp",
                        icon: Icons.phone_android_rounded,
                        controller: _phoneCtrl,
                        validator: _validatePhone,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),

                      _FigmaInput(
                        label: "Kode OTP (6 digit)",
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
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  foregroundColor: const Color(0xFF475569),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: canResend ? _resendOtp : null,
                                child: Text(
                                  canResend
                                      ? 'Kirim Ulang Kode'
                                      : 'Kirim Ulang (${_cooldown}s)',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Aktivasi'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Center(
                        child: SizedBox(
                          height: 48,
                          child: TextButton(
                            onPressed: () => Navigator.pushNamedAndRemoveUntil(
                              context,
                              Routes.start,
                              (r) => false,
                            ),
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
    );
  }
}

// Widget Input Field Refactored
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