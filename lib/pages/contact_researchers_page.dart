import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_client.dart';
import '../widgets/in_app_viewer_page.dart';

class ContactResearchersPage extends StatefulWidget {
  const ContactResearchersPage({super.key});

  @override
  State<ContactResearchersPage> createState() => _ContactResearchersPageState();
}

class _ContactResearchersPageState extends State<ContactResearchersPage> {
  final _api = ApiClient();
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = _api.getContacts();
    });
  }

  // Helper Alert Dialog with styled design
  Future<void> _showDialogInfo(String title, String message, {bool isError = false}) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                color: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF0F172A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _normalizeForWa(String? raw) {
    if (raw == null) return '';
    var p = raw.replaceAll(RegExp(r'\D'), '');
    if (p.isEmpty) return '';
    if (p.startsWith('0')) p = '62${p.substring(1)}';
    if (p.startsWith('8')) p = '62$p';
    return p;
  }

  String _normalizeForTel(String? raw) {
    final wa = _normalizeForWa(raw);
    if (wa.isEmpty) return '';
    return wa.startsWith('+') ? wa : '+$wa';
  }

  Future<void> _openWhatsApp(String? phone, {String? name}) async {
    final p = _normalizeForWa(phone);
    if (p.isEmpty) {
      _showDialogInfo("Error", "Nomor tidak tersedia", isError: true);
      return;
    }
    final msg = Uri.encodeComponent('Halo${name != null ? " $name" : ""}, saya ingin berkonsultasi.');
    final uri = Uri.parse('https://wa.me/$p?text=$msg');

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => InAppViewerPage(title: 'WhatsApp: $p', url: uri.toString())));
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => InAppViewerPage(title: 'WhatsApp: $p', url: uri.toString())));
    }
  }

  Future<void> _call(String? phone) async {
    final p = _normalizeForTel(phone);
    if (p.isEmpty) {
      _showDialogInfo("Error", "Nomor tidak tersedia", isError: true);
      return;
    }
    final uri = Uri(scheme: 'tel', path: p);

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _showDialogInfo("Gagal", "Tidak bisa melakukan panggilan. Periksa aplikasi telepon Anda.", isError: true);
    } catch (_) {
      _showDialogInfo("Gagal", "Tidak bisa melakukan panggilan.", isError: true);
    }
  }

  void _copy(String? phone) {
    final p = _normalizeForTel(phone);
    if (p.isEmpty) {
      _showDialogInfo("Error", "Nomor tidak tersedia", isError: true);
      return;
    }
    Clipboard.setData(ClipboardData(text: p));
    _showDialogInfo("Berhasil", "Nomor disalin ke clipboard.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Kontak Peneliti',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(color: Color(0xFF10B981)),
                  SizedBox(height: 16),
                  Text(
                    'Memuat data kontak...',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            );
          }

          // Handling Error Offline
          if (snap.hasError) {
            final err = snap.error;
            if (err is ApiError && err.status == 0) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Offline: Tidak dapat memuat kontak.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Periksa koneksi internet Anda.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _load, // Retry
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                          ),
                          icon: const Icon(Icons.refresh),
                          label: const Text("Coba Lagi", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                        ),
                      )
                    ],
                  ),
                ),
              );
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Gagal memuat kontak: $err',
                  style: const TextStyle(fontFamily: 'Inter', color: Color(0xFFEF4444)),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final items = (snap.data ?? []).where((e) => (e is Map && (e['visible'] != false))).toList();

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.people_outline_rounded, size: 48, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Belum ada data kontak.',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: items.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline, color: Color(0xFF0284C7), size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Hubungi tim peneliti untuk konsultasi atau pertanyaan seputar program ENI Care.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            height: 1.4,
                            color: Color(0xFF072846),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final m = (items[i - 1] as Map).cast<String, dynamic>();
              final name = (m['name'] as String?) ?? '—';
              final role = (m['role'] as String?) ?? '—';
              final phone = (m['phone'] as String?);
              final info = (m['info'] as String?);
              final initials = name.trim().isEmpty ? '?' : name.trim().split(RegExp(r'\s+')).map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: Color(0xFFD1FAE5),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials,
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF064E3B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(
                                    role,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (info != null && info.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 12),
                        Text(
                          info,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            height: 1.4,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: FilledButton.icon(
                                onPressed: () => _openWhatsApp(phone, name: name),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                                icon: const Icon(Icons.chat_bubble_outline, size: 20),
                                label: const Text(
                                  'WhatsApp',
                                  style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: () => _call(phone),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0EA5E9),
                                  side: const BorderSide(color: Color(0xFF0EA5E9)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                                icon: const Icon(Icons.call_outlined, size: 20),
                                label: const Text(
                                  'Telepon',
                                  style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => _copy(phone),
                              child: Tooltip(
                                message: 'Salin nomor',
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.copy_rounded,
                                    size: 20,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
