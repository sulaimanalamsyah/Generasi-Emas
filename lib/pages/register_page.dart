import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../routes.dart';
import '../widgets/common.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  // Drives ONLY the submit button state to prevent 60Hz full-form keystroke rebuilds
  final ValueNotifier<bool> _canSubmit = ValueNotifier<bool>(false);

  bool _obscure = true;
  String _role = 'mother';
  bool _isConsentChecked = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(_recomputeCanSubmit);
    _email.addListener(_recomputeCanSubmit);
    _phone.addListener(_recomputeCanSubmit);
    _password.addListener(_recomputeCanSubmit);
  }

  void _recomputeCanSubmit() {
    final ready = _name.text.trim().isNotEmpty &&
        _email.text.trim().isNotEmpty &&
        _phone.text.trim().isNotEmpty &&
        _password.text.isNotEmpty &&
        _isConsentChecked;
    if (_canSubmit.value != ready) {
      _canSubmit.value = ready;
    }
  }

  @override
  void dispose() {
    _name.removeListener(_recomputeCanSubmit);
    _email.removeListener(_recomputeCanSubmit);
    _phone.removeListener(_recomputeCanSubmit);
    _password.removeListener(_recomputeCanSubmit);
    _canSubmit.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validateName(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Nama lengkap wajib diisi';
    if (s.length < 3) return 'Nama terlalu pendek (min. 3 karakter)';
    final nameRegex = RegExp(r"^[a-zA-Z\s\.\'\-]+$");
    if (!nameRegex.hasMatch(s)) return 'Nama hanya boleh huruf, titik, atau petik';
    return null;
  }

  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email wajib diisi';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) return 'Format email tidak valid';
    return null;
  }

  String? _validatePhone(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Nomor ponsel WhatsApp wajib diisi';
    if (s.replaceAll(RegExp(r'\D'), '').length < 8) return 'Nomor terlalu pendek';
    return null;
  }

  String? _validatePassword(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Kata sandi wajib diisi';
    if (s.length < 8) return 'Minimal 8 karakter';
    if (!RegExp(r'[A-Z]').hasMatch(s)) return 'Wajib ada huruf besar (A-Z)';
    if (!RegExp(r'[a-z]').hasMatch(s)) return 'Wajib ada huruf kecil (a-z)';
    if (!RegExp(r'[0-9]').hasMatch(s)) return 'Wajib ada angka (0-9)';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(s)) return 'Wajib ada simbol (mis. !@#\$%_)';
    return null;
  }

  Future<void> _showRoleSelectorSheet() async {
    FocusScope.of(context).unfocus();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: sheetBottomPadding(ctx, horizontal: 20, top: 14, extra: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const Text(
                'Pilih Peran / Hubungan',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pilih peran Anda dalam pemantauan bayi pada program Model I-FINC.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              _RoleOptionCard(
                value: 'mother',
                selected: _role == 'mother',
                title: 'Ibu Pasien',
                subtitle: 'Pengelola utama data bayi, logbook harian, jurnal, dan evaluasi.',
                icon: Icons.pregnant_woman_rounded,
                badgeBg: const Color(0xFFD1FAE5),
                badgeFg: const Color(0xFF059669),
                onTap: () => Navigator.pop(ctx, 'mother'),
              ),
              const SizedBox(height: 12),
              _RoleOptionCard(
                value: 'father',
                selected: _role == 'father',
                title: 'Suami / Ayah Pasien',
                subtitle: 'Pemantau perkembangan bayi dan pendamping Ibu (terhubung ke akun Ibu).',
                icon: Icons.family_restroom_rounded,
                badgeBg: const Color(0xFFE0F2FE),
                badgeFg: const Color(0xFF0284C7),
                onTap: () => Navigator.pop(ctx, 'father'),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _role = selected);
    }
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) {
      showAppSnackBar(context, message: 'Mohon lengkapi formulir dengan benar.', isError: true);
      return;
    }
    if (!_isConsentChecked) {
      showAppSnackBar(
        context,
        message: 'Anda harus menyetujui Informed Consent untuk mendaftar.',
        isError: true,
      );
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
    final roleLabel = _role == 'father' ? 'Suami / Ayah Pasien' : 'Ibu Pasien';

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
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
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
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: AppLogo(size: 90)),
                        const SizedBox(height: 18),
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
                          'Daftar sekarang untuk memulai pemantauan si Kecil',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 24),

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

                        _buildLabel('Nomor Ponsel (WhatsApp)'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _phone,
                          validator: _validatePhone,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: Color(0xFF0F172A)),
                          decoration: _buildInputDecoration('081234567890', Icons.phone_android_outlined),
                        ),
                        const SizedBox(height: 16),

                        _buildLabel('Kata Sandi'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _password,
                          validator: _validatePassword,
                          obscureText: _obscure,
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: Color(0xFF0F172A)),
                          decoration: _buildInputDecoration(
                            'Min. 8 karakter',
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

                        _buildLabel('Peran / Hubungan'),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _showRoleSelectorSheet,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 56),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _role == 'father'
                                      ? Icons.family_restroom_rounded
                                      : Icons.pregnant_woman_rounded,
                                  color: const Color(0xFF10B981),
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    roleLabel,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF475569)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

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
                                    _recomputeCanSubmit();
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: GestureDetector(
                                  onTap: () => Navigator.pushNamed(context, Routes.consentReadOnly),
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

                        ValueListenableBuilder<bool>(
                          valueListenable: _canSubmit,
                          builder: (context, canSubmit, _) {
                            return ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 50),
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: canSubmit ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                                  foregroundColor: canSubmit ? Colors.white : const Color(0xFF64748B),
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  textStyle: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: canSubmit ? _onSubmit : null,
                                child: const Text('Daftar Sekarang', textAlign: TextAlign.center),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
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

class _RoleOptionCard extends StatelessWidget {
  final String value;
  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color badgeBg;
  final Color badgeFg;
  final VoidCallback onTap;

  const _RoleOptionCard({
    required this.value,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badgeBg,
    required this.badgeFg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: badgeFg, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      color: Color(0xFF64748B),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
              ),
          ],
        ),
      ),
    );
  }
}
