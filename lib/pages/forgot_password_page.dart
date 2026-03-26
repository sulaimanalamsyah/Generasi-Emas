import 'package:flutter/material.dart';
import '../routes.dart';
import '../services/api_client.dart';

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

  String? _validatePhone(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Wajib diisi';
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
          "Kode OTP telah dikirim ke WhatsApp Anda."
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
    // Ukuran Layar Responsive
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
            top:25,
            height: illustrationHeight - 40,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Image.asset(
                  "assets/forgot-reset-logo.png",
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
                      'Lupa Password?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.33,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // SUB-JUDUL
                    const Text(
                      'Minta OTP via WhatsApp',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.33,
                      ),
                    ),
                    const SizedBox(height: 14),

                    const Text(
                      'Masukkan nomor WhatsApp yang terdaftar untuk menerima OTP',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.33,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // INPUT NOMOR HP
                    _FigmaInput(
                      label: "Nomor WhatsApp",
                      icon: Icons.phone_android_outlined,
                      controller: _phone,
                      validator: _validatePhone,
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 40),

                    // TOMBOL KIRIM OTP
                    _FigmaButton(
                      label: _loading ? "Mengirim..." : "Kirim OTP",
                      onTap: _loading ? () {} : _requestOtp,
                    ),

                    const SizedBox(height: 24),

                    // TOMBOL KEMBALI
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Kembali',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.underline,
                          letterSpacing: -0.33,
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

// WIDGET
class _FigmaInput extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  const _FigmaInput({
    required this.label,
    required this.icon,
    required this.controller,
    this.validator,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            // Background Box
            Container(
              height: 50,
              decoration: ShapeDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                shadows: const [BoxShadow(color: Color(0x3F000000), blurRadius: 4, offset: Offset(0, 4))],
              ),
            ),
            // Input Field
            Padding(
              padding: const EdgeInsets.only(left: 36, right: 16),
              child: TextFormField(
                controller: controller,
                keyboardType: keyboardType,
                validator: validator,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: label,
                  hintStyle: const TextStyle(color: Colors.black54, fontSize: 13, fontFamily: 'Inter'),
                  contentPadding: const EdgeInsets.only(left: 12, top: 14, bottom: 14),
                  border: InputBorder.none,
                  errorStyle: const TextStyle(
                    color: Color.fromARGB(255, 185, 0, 0),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            // Icon
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

// WIDGET
class _FigmaButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FigmaButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 40,
      decoration: ShapeDecoration(
        gradient: const LinearGradient(
          begin: Alignment(0.0, 0.5),
          end: Alignment(1.0, 0.5),
          colors: [Color(0xFF27AAE1), Color(0xFF155C7B)],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        shadows: const [BoxShadow(color: Color(0x3F000000), blurRadius: 3, offset: Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
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