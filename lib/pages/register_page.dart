import 'package:flutter/material.dart';
import '../routes.dart';
import '../widgets/common.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;
  String _role = 'mother'; // Default: Ibu Pasien
  bool _isConsentChecked = false;

  @override
  void initState() {
    super.initState();
    // Add listeners so the register button updates dynamically as user types
    _name.addListener(_onFieldChanged);
    _email.addListener(_onFieldChanged);
    _phone.addListener(_onFieldChanged);
    _password.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _name.removeListener(_onFieldChanged);
    _email.removeListener(_onFieldChanged);
    _phone.removeListener(_onFieldChanged);
    _password.removeListener(_onFieldChanged);
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  // Dynamic check if required fields are non-empty and consent is checked
  bool get _isFormFilledAndAgreed {
    return _name.text.trim().isNotEmpty &&
        _email.text.trim().isNotEmpty &&
        _phone.text.trim().isNotEmpty &&
        _password.text.isNotEmpty &&
        _isConsentChecked;
  }

  // Modern SnackBar UI Notification
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

  // Enhanced Name Format Validator
  String? _validateName(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Nama lengkap wajib diisi';
    if (s.length < 3) return 'Nama terlalu pendek (min. 3 karakter)';
    
    // Allow alphabetic characters, spaces, apostrophes, hyphens, and dots
    final nameRegex = RegExp(r"^[a-zA-Z\s\.\'\-]+$");
    if (!nameRegex.hasMatch(s)) {
      return 'Nama hanya boleh huruf, titik, atau petik';
    }
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

  void _openConsentReadOnly() {
    Navigator.pushNamed(context, Routes.consentReadOnly);
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar("Mohon lengkapi formulir dengan benar.", isError: true);
      return;
    }

    if (!_isConsentChecked) {
      _showSnackBar("Anda harus mencentang persetujuan Informed Consent untuk mendaftar.", isError: true);
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
    final bool canSubmit = _isFormFilledAndAgreed;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
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
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Centralized Logo
                      const Center(child: AppLogo(size: 90)),
                      const SizedBox(height: 18),

                      // Headings
                      const Text(
                        'Registrasi Akun Anda',
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
                        'Daftar sekarang untuk memulai monitoring si Kecil',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Input: Nama Lengkap
                      _buildLabel('Nama Lengkap'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _name,
                        validator: _validateName,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: Color(0xFF0F172A)),
                        decoration: _buildInputDecoration('Nama lengkap Anda', Icons.person_outline),
                      ),
                      const SizedBox(height: 16),

                      // Input: Email
                      _buildLabel('Email'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _email,
                        validator: _validateEmail,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: Color(0xFF0F172A)),
                        decoration: _buildInputDecoration('nama@email.com', Icons.email_outlined),
                      ),
                      const SizedBox(height: 16),

                      // Input: Nomor Handphone
                      _buildLabel('Nomor Handphone'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phone,
                        validator: _validatePhone,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: Color(0xFF0F172A)),
                        decoration: _buildInputDecoration('081234567890', Icons.phone_android_outlined),
                      ),
                      const SizedBox(height: 16),

                      // Input: Password
                      _buildLabel('Password'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _password,
                        validator: _validatePassword,
                        obscureText: _obscure,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: Color(0xFF0F172A)),
                        decoration: _buildInputDecoration(
                          'Minimal 8 karakter',
                          Icons.lock_outline,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: const Color(0xFF475569),
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Dropdown: Peran / Role
                      _buildLabel('Peran / Hubungan'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _role,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: Color(0xFF0F172A)),
                        decoration: _buildInputDecoration('Pilih peran', Icons.people_outline),
                        items: const [
                          DropdownMenuItem(value: 'mother', child: Text('Ibu Pasien')),
                          DropdownMenuItem(value: 'father', child: Text('Suami / Ayah Pasien')),
                        ],
                        onChanged: (v) => setState(() => _role = v ?? 'mother'),
                      ),
                      const SizedBox(height: 20),

                      // Checkbox Informed Consent
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 48,
                            width: 48,
                            child: Center(
                              child: Checkbox(
                                value: _isConsentChecked,
                                activeColor: const Color(0xFF10B981),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (bool? newValue) {
                                  setState(() {
                                    _isConsentChecked = newValue ?? false;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: GestureDetector(
                                onTap: _openConsentReadOnly,
                                child: RichText(
                                  text: const TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Dengan mendaftar, Anda setuju dengan ',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 13,
                                          color: Color(0xFF475569),
                                          height: 1.4,
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'Informed Consent',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0EA5E9),
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Button: Daftar sekarang
                      SizedBox(
                        height: 50,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: canSubmit ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                            foregroundColor: canSubmit ? Colors.white : const Color(0xFF64748B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: canSubmit ? _onSubmit : null,
                          child: const Text('Daftar sekarang'),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Bottom Link: Sudah punya akun? Masuk
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Sudah punya akun? ',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: Color(0xFF475569),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, Routes.login),
                            child: const Text(
                              'Masuk',
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0F172A),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData prefixIcon, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8), fontSize: 14),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF475569), size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      errorStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Color(0xFFEF4444),
      ),
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
    );
  }
}