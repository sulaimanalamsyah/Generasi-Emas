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
  bool _isCheckingStatus = true;
  Map<String, dynamic>? _outgoingPending;

  @override
  void initState() {
    super.initState();
    _checkInitialStatus();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkInitialStatus({bool showSnackBarFeedback = false}) async {
    setState(() => _isCheckingStatus = true);
    try {
      final status = await _api.getPartnerStatus();
      if (!mounted) return;

      if (status['isLinked'] == true) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          Routes.homePatient,
          (route) => false,
        );
        return;
      }

      setState(() {
        _outgoingPending = status['outgoingPendingRequest'] as Map<String, dynamic>?;
      });

      if (showSnackBarFeedback && mounted) {
        if (_outgoingPending != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Status masih menunggu persetujuan Ibu.'),
              backgroundColor: Color(0xFFF59E0B),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permintaan telah selesai atau ditolak.'),
              backgroundColor: Color(0xFF0F172A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking partner status: $e');
    } finally {
      if (mounted) setState(() => _isCheckingStatus = false);
    }
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

  Future<void> _cancelRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Batalkan Permintaan?',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: const Text(
          'Apakah Anda yakin ingin membatalkan permintaan penautan akun ini?',
          style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tidak', style: TextStyle(fontFamily: 'Inter', color: Color(0xFF64748B))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Batalkan', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _api.cancelPartnerRequest();
        if (mounted) {
          setState(() {
            _outgoingPending = null;
          });
          _showDialogInfo('Dibatalkan', 'Permintaan penautan akun telah dibatalkan.');
        }
      } catch (e) {
        if (mounted) {
          _showDialogInfo('Gagal', 'Gagal membatalkan permintaan: $e', isError: true);
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();

    if (phone.isEmpty) {
      _showDialogInfo("Peringatan", "Nomor HP Ibu wajib diisi", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await _api.requestLinkPartner(phone);

      if (!mounted) return;

      final reqData = res['request'] as Map<String, dynamic>?;
      setState(() {
        _outgoingPending = {
          'motherName': reqData?['motherName'] ?? 'Ibu',
          'motherPhone': phone,
          'createdAt': reqData?['createdAt'] ?? DateTime.now().toIso8601String(),
        };
      });

      await _showDialogInfo(
        "Permintaan Terkirim",
        "Permintaan penautan akun berhasil dikirim ke Ibu (${reqData?['motherName'] ?? 'Ibu'}). Silakan minta Ibu menyetujui permintaan di aplikasinya.",
      );
    } catch (e) {
      if (!mounted) return;

      String msg = e.toString();

      if (e is ApiError && e.status == 0) {
        msg = "Gagal terhubung ke server. Periksa koneksi internet Anda.";
      } else {
        msg = msg.replaceAll("ApiError: ", "");
        msg = msg.replaceAll("Exception: ", "");

        if (msg.contains("CANNOT_LINK_SELF") || msg.toLowerCase().contains("sendiri")) {
          msg = "Anda tidak dapat menautkan akun dengan nomor handphone Anda sendiri.";
        } else if (msg.contains("ALREADY_LINKED") || msg.toLowerCase().contains("sudah terhubung")) {
          msg = "Akun Anda sudah terhubung dengan akun Ibu. Putuskan tautan terlebih dahulu.";
        } else if (msg.contains("PARTNER_ALREADY_EXISTS") || msg.toLowerCase().contains("sudah memiliki partner")) {
          msg = "Gagal Menautkan: Akun Ibu sudah memiliki partner terhubung.";
        } else if (msg.contains("REQUEST_ALREADY_PENDING") || msg.toLowerCase().contains("menunggu persetujuan")) {
          msg = "Permintaan penautan ke akun Ibu ini masih menunggu persetujuan.";
        } else if (msg.contains("404") || msg.toLowerCase().contains("not found") || msg.contains("MOTHER_NOT_FOUND")) {
          msg = "Nomor HP tidak ditemukan. Pastikan nomor tersebut sudah terdaftar sebagai akun Ibu.";
        } else if (msg.toLowerCase().contains("timeout")) {
          msg = "Waktu habis. Koneksi internet mungkin lambat.";
        }
      }

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

  Widget _buildPendingCard(Map<String, dynamic> pending) {
    final motherName = pending['motherName'] as String? ?? 'Ibu';
    final motherPhone = pending['motherPhone'] as String? ?? '-';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              color: Color(0xFFD97706),
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Menunggu Persetujuan Ibu',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Permintaan penautan akun telah dikirim ke:',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Text(
                  motherName,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  motherPhone,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Silakan minta Ibu untuk membuka aplikasi Generasi Emas dan menyetujui permintaan penautan akun ini.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isLoading ? null : () => _checkInitialStatus(showSnackBarFeedback: true),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text(
                'Perbarui Status',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isLoading ? null : _cancelRequest,
              icon: const Icon(Icons.close_rounded, size: 20),
              label: const Text(
                'Batalkan Permintaan',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
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
            height: 48,
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
    );
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
            child: _isCheckingStatus
                ? const CircularProgressIndicator(color: Color(0xFF10B981))
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                          if (_outgoingPending != null)
                            _buildPendingCard(_outgoingPending!)
                          else
                            _buildInputCard(),
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