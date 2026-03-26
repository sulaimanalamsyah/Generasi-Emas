import 'package:flutter/material.dart';
import '../routes.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();

  // Controller
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;
  String _role = 'mother'; // Default: Ibu Pasien

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  // --- [RESTORED] HELPER DIALOG ---
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
          )
        ],
      ),
    );
  }

  // --- [RESTORED] VALIDATORS LENGKAP ---
  String? _validateName(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Nama lengkap wajib diisi';
    if (s.length < 3) return 'Nama terlalu pendek';
    return null;
  }

  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email wajib diisi';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
    if (!ok) return 'Email tidak valid';
    return null;
  }

  String? _validatePhone(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Nomor WhatsApp wajib diisi';
    if (s.replaceAll(RegExp(r'\D'), '').length < 8) {
      return 'Nomor terlalu pendek';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Password wajib diisi';
    if (s.length < 8) return 'Minimal 8 karakter';
    if (!RegExp(r'[A-Z]').hasMatch(s)) return 'Wajib ada huruf besar (A-Z)';
    if (!RegExp(r'[a-z]').hasMatch(s)) return 'Wajib ada huruf kecil (a-z)';
    if (!RegExp(r'[0-9]').hasMatch(s)) return 'Wajib ada angka (0-9)';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(s)) return 'Wajib ada simbol (mis. !@#\$%_)';
    return null;
  }

  // --- ACTIONS ---
  void _openConsentReadOnly() {
    Navigator.pushNamed(context, Routes.consentReadOnly);
  }

  Future<void> _onSubmit() async {
    if (!_form.currentState!.validate()) {
      _showDialogInfo("Data Tidak Valid", "Mohon lengkapi formulir dengan benar.", isError: true);
      return;
    }

    FocusScope.of(context).unfocus();

    final payload = <String, dynamic>{
      'name': _name.text.trim(),
      'email': _email.text.trim().toLowerCase(),
      'phone': _phone.text.trim(),
      'password': _password.text,
      'role': _role,
    };

    Navigator.pushNamed(
      context,
      Routes.consentRegister,
      arguments: {'payload': payload},
    );
  }

  @override
  Widget build(BuildContext context) {
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
            top: 40,
            height: illustrationHeight - 40,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Image.asset(
                  "assets/register-logo.png",
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.app_registration, size: 100, color: Colors.white);
                  },
                ),
              ),
            ),
          ),

          // 2. CARD FORM (Layer Bawah)
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

          // 3. CONTENT FORM (Layer Atas)
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
                      'Registrasi Akun Anda',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.33,
                      ),
                    ),
                    const SizedBox(height: 30),

                    _FigmaInput(
                      label: "Nama Lengkap",
                      icon: Icons.person_outline,
                      controller: _name,
                      validator: _validateName,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),

                    _FigmaInput(
                      label: "Email",
                      icon: Icons.email_outlined,
                      controller: _email,
                      validator: _validateEmail,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),

                    _FigmaInput(
                      label: "Nomor Handphone",
                      icon: Icons.phone_android_outlined,
                      controller: _phone,
                      validator: _validatePhone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    _FigmaInput(
                      label: "Password",
                      icon: Icons.lock_outline,
                      controller: _password,
                      validator: _validatePassword,
                      obscureText: _obscure,
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // INPUT: ROLE (DROPDOWN)
                    // Menggunakan Container biasa (bukan Stack) agar error text muat jika ada
                    Stack(
                        clipBehavior: Clip.none, // Allow overflow if needed
                        children: [
                          Container(
                            height: 50,
                            decoration: ShapeDecoration(
                              color: Colors.white.withValues(alpha: 0.8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              shadows: const [
                                BoxShadow(
                                  color: Color(0x3F000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 4),
                                  spreadRadius: 0,
                                )
                              ],
                            ),
                          ),
                          // Padding untuk konten dropdown agar tidak nabrak icon
                          Padding(
                            padding: const EdgeInsets.only(left: 36, right: 16),
                            child: DropdownButtonFormField<String>(
                              initialValue: _role,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.only(left: 12, top: 14, bottom: 14),
                              ),
                              icon: const Icon(Icons.arrow_drop_down),
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                                fontFamily: 'Inter',
                              ),
                              items: const [
                                DropdownMenuItem(value: 'mother', child: Text('Ibu Pasien')),
                                DropdownMenuItem(value: 'father', child: Text('Suami/Ayah Pasien')),
                              ],
                              onChanged: (v) => setState(() => _role = v ?? 'mother'),
                            ),
                          ),
                          const Positioned(
                            left: 12,
                            top: 13,
                            child: Icon(Icons.people_outline, color: Colors.grey, size: 24),
                          ),
                        ]
                    ),

                    const SizedBox(height: 24),

                    GestureDetector(
                      onTap: _openConsentReadOnly,
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'Dengan mendaftar, anda setuju dengan\n',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(
                              text: 'Informed Consent',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w800,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _FigmaButton(
                          label: "Kembali",
                          width: 120,
                          onTap: () => Navigator.pop(context),
                        ),
                        _FigmaButton(
                          label: "Daftar",
                          width: 120,
                          onTap: _onSubmit,
                        ),
                      ],
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

// [FIX] Widget Input (Diperbarui untuk mengatasi masalah layout error & padding text)
class _FigmaInput extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final TextCapitalization textCapitalization;

  const _FigmaInput({
    required this.label,
    required this.icon,
    required this.controller,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none, // Agar pesan error bisa muncul di luar box jika perlu
      children: [
        // 1. Background Box (Putih + Shadow)
        Container(
          height: 50,
          decoration: ShapeDecoration(
            // [OPTIONAL] Gunakan .withValues(alpha: 0.8) jika Flutter terbaru,
            // tapi withOpacity masih aman untuk sekarang.
            color: Colors.white.withValues(alpha: 0.8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            shadows: const [
              BoxShadow(
                color: Color(0x3F000000),
                blurRadius: 4,
                offset: Offset(0, 4),
                spreadRadius: 0,
              )
            ],
          ),
        ),

        // 2. TextFormField dengan Padding Luar
        Padding(
          // [FIX UTAMA] Padding kiri 36 agar teks & error bergeser ke kanan (tidak menabrak pinggir)
          padding: const EdgeInsets.only(left: 36, right: 16),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            validator: validator,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            decoration: InputDecoration(
              hintText: label,
              hintStyle: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
                fontFamily: 'Inter',
              ),
              // [FIX] Content padding disesuaikan
              contentPadding: const EdgeInsets.only(left: 12, top: 14, bottom: 14),
              border: InputBorder.none,
              suffixIcon: suffixIcon,

              // [FIX UTAMA] Styling Error Text
              errorStyle: const TextStyle(
                color: Color.fromARGB(255, 185, 0, 0), // Merah jelas
                fontSize: 12,
                fontWeight: FontWeight.bold,
                height: 1.2, // [PENTING] Memberi jarak vertikal agar tidak nempel box
              ),
            ),
          ),
        ),

        // 3. Icon di Kiri (Positioned Absolute)
        Positioned(
          left: 12,
          top: 13,
          child: Icon(icon, color: Colors.grey, size: 24),
        ),
      ],
    );
  }
}

// [HELPER WIDGET] Tombol Biru Gradient (Tetap sama)
class _FigmaButton extends StatelessWidget {
  final String label;
  final double width;
  final VoidCallback onTap;

  const _FigmaButton({
    required this.label,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 35,
      decoration: ShapeDecoration(
        gradient: const LinearGradient(
          begin: Alignment(0.00, 0.50),
          end: Alignment(1.00, 0.50),
          colors: [Color(0xFF27AAE1), Color(0xFF155C7B)],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        shadows: const [
          BoxShadow(
            color: Color(0x3F000000),
            blurRadius: 3,
            offset: Offset(0, 4),
            spreadRadius: 0,
          )
        ],
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
                fontSize: 13,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                letterSpacing: -0.33,
              ),
            ),
          ),
        ),
      ),
    );
  }
}