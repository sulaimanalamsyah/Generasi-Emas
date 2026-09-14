import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../routes.dart';
import '../widgets/common.dart';

class FatherLinkPage extends StatefulWidget {
  const FatherLinkPage({super.key});

  @override
  State<FatherLinkPage> createState() => _FatherLinkPageState();
}

class _FatherLinkPageState extends State<FatherLinkPage> {
  final _phoneCtrl = TextEditingController();
  final _api = ApiClient();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
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

  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();

    if (phone.isEmpty) {
      _showDialogInfo("Peringatan", "Nomor HP Ibu wajib diisi", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _api.linkPartner(phone);

      if (!mounted) return;

      await _showDialogInfo(
        "Berhasil",
        "Akun Anda berhasil terhubung dengan akun Ibu!",
      );

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        Routes.homePatient,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      // Logic Message Cleaning
      String msg = e.toString();

      // Handling Error Offline
      if (e is ApiError && e.status == 0) {
        msg = "Gagal terhubung ke server. Periksa koneksi internet Anda.";
      } else {
        msg = msg.replaceAll("ApiError: ", "");
        msg = msg.replaceAll("Exception: ", "");

        // Mapping error
        if (msg.contains("PARTNER_ALREADY_EXISTS") || msg.toLowerCase().contains("sudah memiliki partner")) {
          msg = "Gagal Menautkan: Akun Ibu sudah memiliki partner terhubung.";
        } else if (msg.contains("404") || msg.toLowerCase().contains("not found")) {
          msg = "Nomor HP tidak ditemukan. Pastikan nomor tersebut sudah terdaftar sebagai akun Ibu.";
        } else if (msg.toLowerCase().contains("timeout")) {
          msg = "Waktu habis. Koneksi internet mungkin lambat.";
        }
      }

      // Dialog Error
      _showDialogInfo("Gagal Menghubungkan", msg, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _doLogout() async {
    await _api.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, Routes.start, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacementNamed(context, Routes.start);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            'Hubungkan Akun',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: _doLogout,
              icon: const Icon(Icons.logout, color: Color(0xFFEF4444)),
              tooltip: 'Keluar',
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Centralized Logo Header
                    const Center(child: AppLogo(size: 90)),
                    const SizedBox(height: 20),

                    const Text(
                      'Halo, Ayah!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    const Text(
                      'Agar Anda dapat memantau perkembangan bayi, silakan hubungkan akun Anda dengan akun Ibu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Level 1 Elevation Card Form Container
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nomor HP Ibu',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(fontSize: 15, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: 'Contoh: 08123456789',
                              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
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
                            ),
                          ),
                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
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
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: _isLoading ? null : _submit,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Hubungkan Sekarang'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}