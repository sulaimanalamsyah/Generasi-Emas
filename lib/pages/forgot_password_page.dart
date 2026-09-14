import 'package:flutter/material.dart';
import '../routes.dart';
import '../services/api_client.dart';
import '../widgets/common.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _phone.dispose();
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

  String? _validatePhone(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Nomor WhatsApp wajib diisi';
    if (s.replaceAll(RegExp(r'\D'), '').length < 8) return 'Min 8 digit';
    return null;
  }

  Future<void> _requestOtp() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _loading = true);
    final phone = _phone.text.trim();

    try {
      await ApiClient().requestPasswordResetOtpWa(phone: phone);

      if (!mounted) return;

      await _showDialogInfo(
        "OTP Terkirim",
        "Kode OTP telah dikirim ke WhatsApp Anda.",
      );

      if (!mounted) return;

      Navigator.pushNamed(
        context,
        Routes.reset,
        arguments: {'presetPhone': phone},
      );
    } catch (e) {
      if (!mounted) return;

      // Handling Error Offline
      if (e is ApiError && e.status == 0) {
        _showDialogInfo("Gagal Kirim", "Tidak ada koneksi internet. Mohon periksa jaringan Anda.", isError: true);
      } else {
        _showDialogInfo("Gagal", e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
                      // Centralized Logo
                      const Center(child: AppLogo(size: 90)),
                      const SizedBox(height: 20),

                      // Headings
                      const Text(
                        'Lupa Password?',
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
                        'Masukkan nomor WhatsApp yang terdaftar untuk menerima kode OTP',
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

                      // Input Field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Nomor WhatsApp",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            validator: _validatePhone,
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: 'Masukkan Nomor WhatsApp',
                              hintStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8), fontSize: 14),
                              prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF475569), size: 20),
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
                      ),

                      const SizedBox(height: 28),

                      // Submit Button
                      SizedBox(
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
                          onPressed: _loading ? null : _requestOtp,
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Kirim OTP'),
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