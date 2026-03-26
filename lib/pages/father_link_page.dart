import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../routes.dart';

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
        title: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: isError ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(color: isError ? Colors.red : Colors.green),
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
          "Akun Anda berhasil terhubung dengan akun Ibu!"
      );

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
          context,
          Routes.homePatient,
              (route) => false
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
        if (msg.contains("404") || msg.toLowerCase().contains("not found")) {
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
    Navigator.pushNamedAndRemoveUntil(context, Routes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hubungkan Akun'),
        actions: [
          IconButton(
            onPressed: _doLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
          )
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ilustrasi Icon
              const Icon(Icons.connect_without_contact, size: 80, color: Colors.teal),
              const SizedBox(height: 24),

              const Text(
                'Halo, Ayah!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              const Text(
                'Agar Anda dapat memantau perkembangan bayi, silakan hubungkan akun Anda dengan akun Ibu.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 32),

              // Form Input
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor HP Ibu',
                  hintText: 'Contoh: 08123456789',
                  prefixIcon: Icon(Icons.phone_android),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Tombol Submit
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  )
                      : const Text('HUBUNGKAN SEKARANG', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}