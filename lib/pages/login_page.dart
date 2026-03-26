import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../core/storage.dart';
import '../core/nav.dart';
import '../routes.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _auth = AuthService();

  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  //Helper Alert Dialog
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

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _pass.text;

    if (email.isEmpty || pass.isEmpty) {
      _showDialogInfo("Input Kosong", "Email dan password wajib diisi.", isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      await _auth.logoutLocal();

      final ok = await _auth.login(email: email, password: pass);

      if (ok) {
        try {
          final api = ApiClient();
          final res = await api.getMyProfile();

          if (res != null && res['profile'] != null) {
            final userObj = res['profile']['user'] ?? {};
            final phone = userObj['phone'] as String?;

            if (phone != null && phone.isNotEmpty) {
              await Prefs.setPhone(phone);
            }

            String? displayName;
            final role = userObj['role'];

            if (role == 'mother') {
              displayName = res['profile']['motherName'] ?? res['profile']['name'];
            }

            if (displayName != null && displayName.isNotEmpty) {
              await Prefs.setDisplayName(displayName);
            }
          }
        } catch (e) {
          debugPrint("Gagal pre-fetch profil: $e");
        }

        if (!mounted) return;
        setState(() => _loading = false);

        final role = await Prefs.getRole();
        if (!mounted) return;
        goHomeByRole(context, role);
      } else {
        if (!mounted) return;
        setState(() => _loading = false);
        _showDialogInfo("Login Gagal", "Email atau password salah.", isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      if (e is ApiError && e.status == 0) {
        _showDialogInfo("Koneksi Bermasalah", "Tidak ada koneksi internet.", isError: true);
      } else {
        _showDialogInfo("Login Gagal", "Terjadi kesalahan: $e", isError: true);
      }
    }
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
            top: 30,
            height: illustrationHeight - 40,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Image.asset(
                  "assets/login-logo.png",
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.lock_person, size: 100, color: Colors.white);
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Login ke Akun Anda',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 24,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.33,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // EMAIL INPUT
                  _FigmaInput(
                    label: "Email",
                    icon: Icons.email_outlined,
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  // PASSWORD INPUT
                  _FigmaInput(
                    label: "Password",
                    icon: Icons.lock_outline,
                    controller: _pass,
                    obscureText: _obscure,
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),

                  const SizedBox(height: 34),

                  // TOMBOL LOGIN
                  _FigmaButton(
                    label: _loading ? "Loading..." : "Login",
                    onTap: _loading ? () {} : _submit,
                  ),

                  const SizedBox(height: 30),

                  // TEXT LINKS
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, Routes.forgot),
                    child: const Text(
                      'Lupa Password?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  GestureDetector(
                    onTap: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      Routes.start,
                          (r) => false,
                    ),
                    child: const Text(
                      'Kembali ke Halaman Awal',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
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
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;

  const _FigmaInput({
    required this.label,
    required this.icon,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
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
            Padding(
              padding: const EdgeInsets.only(left: 36, right: 16),
              child: TextField(
                controller: controller,
                obscureText: obscureText,
                keyboardType: keyboardType,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: label,
                  hintStyle: const TextStyle(color: Colors.black54, fontSize: 13, fontFamily: 'Inter'),
                  contentPadding: const EdgeInsets.only(left: 12, top: 14, bottom: 14),
                  border: InputBorder.none,
                  suffixIcon: suffixIcon,
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

// Widget Button
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