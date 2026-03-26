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
      appBar: AppBar(title: const Text('Kontak Peneliti')),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Handling Error Offline
          if (snap.hasError) {
            final err = snap.error;
            if (err is ApiError && err.status == 0) {
              return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.contact_support_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        "Offline: Tidak dapat memuat kontak.",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text("Periksa koneksi internet Anda.", style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _load, // Retry
                        icon: const Icon(Icons.refresh),
                        label: const Text("Coba Lagi"),
                      )
                    ],
                  )
              );
            }
            return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Gagal memuat kontak: $err')));
          }

          final items = (snap.data ?? []).where((e) => (e is Map && (e['visible'] != false))).toList();

          if (items.isEmpty) {
            return const Center(child: Text('Belum ada data kontak.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final m = (items[i] as Map).cast<String, dynamic>();
              final name = (m['name'] as String?) ?? '—';
              final role = (m['role'] as String?) ?? '—';
              final phone = (m['phone'] as String?);
              final info = (m['info'] as String?);
              final initials = name.trim().isEmpty ? '?' : name.trim().split(RegExp(r'\s+')).map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).dividerColor)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [CircleAvatar(radius: 22, child: Text(initials)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text(role, style: Theme.of(context).textTheme.bodySmall)]))]),
                      if (info != null && info.trim().isNotEmpty) ...[const SizedBox(height: 10), Text(info, style: Theme.of(context).textTheme.bodyMedium)],
                      const SizedBox(height: 12),
                      Row(children: [
                        FilledButton.icon(onPressed: () => _openWhatsApp(phone, name: name), icon: const Icon(Icons.chat_bubble_outline), label: const Text('WhatsApp')),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(onPressed: () => _call(phone), icon: const Icon(Icons.call_outlined), label: const Text('Telepon')),
                        const Spacer(),
                        IconButton(tooltip: 'Salin nomor', onPressed: () => _copy(phone), icon: const Icon(Icons.copy)),
                      ])
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