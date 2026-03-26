import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_client.dart';

class ModulesPage extends StatefulWidget {
  const ModulesPage({super.key});
  @override
  State<ModulesPage> createState() => _ModulesPageState();
}

class _ModulesPageState extends State<ModulesPage> {
  final _api = ApiClient();

  Future<List<dynamic>> _loadModules() async {
    return await _api.getContent('MODULE', 'MOTHER');
  }

  // Helper Url Launcher
  Future<void> _launchUrl(String urlString) async {
    if (urlString.isEmpty) return;
    final uri = Uri.parse(urlString);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka tautan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modul Pembelajaran')),
      body: FutureBuilder<List<dynamic>>(
        future: _loadModules(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final err = snapshot.error;
            if (err is ApiError && err.status == 0) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.signal_wifi_off, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text("Anda sedang offline.", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text("Periksa koneksi internet Anda.", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => setState((){}),
                      icon: const Icon(Icons.refresh),
                      label: const Text("Coba Lagi"),
                    )
                  ],
                ),
              );
            }
            return Center(child: Text('Gagal memuat modul: $err'));
          }

          final modules = snapshot.data ?? [];
          if (modules.isEmpty) {
            return const Center(child: Text('Belum ada modul.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.menu_book, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Modul pembelajaran terstruktur sebagai panduan praktis perawatan bayi Anda.',
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),

              ...modules.map((m) {
                final title = m['title'] ?? 'Modul';
                final items = (m['items'] as List?) ?? [];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${items.length} materi'),
                    children: items.map<Widget>((it) {
                      final iTitle = it['title'] ?? '';
                      final iUrl = it['url'] ?? '';
                      final iKind = (it['kind'] ?? 'LINK').toString();

                      IconData icon;
                      if (iKind == 'VIDEO') {
                        icon = Icons.play_circle_fill;
                      } else if (iKind == 'PDF') {
                        icon = Icons.picture_as_pdf;
                      } else {
                        icon = Icons.link;
                      }

                      return ListTile(
                        leading: Icon(icon, color: Colors.blue),
                        title: Text(iTitle),
                        trailing: const Icon(Icons.open_in_new, size: 20, color: Colors.grey),
                        onTap: () {
                          _launchUrl(iUrl);
                        },
                      );
                    }).toList(),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}