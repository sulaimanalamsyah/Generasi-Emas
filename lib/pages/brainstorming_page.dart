import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_client.dart';

class BrainstormingPage extends StatefulWidget {
  const BrainstormingPage({super.key});
  @override
  State<BrainstormingPage> createState() => _BrainstormingPageState();
}

class _BrainstormingPageState extends State<BrainstormingPage> {
  final _api = ApiClient();

  Future<List<dynamic>> _load() async {
    return await _api.getContent('BRAINSTORM', 'MOTHER');
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
      appBar: AppBar(title: const Text('Brainstorming')),
      body: FutureBuilder<List<dynamic>>(
        future: _load(),
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
            return Center(child: Text('Gagal memuat materi: $err'));
          }

          final groups = snapshot.data ?? [];

          if (groups.isEmpty) {
            return const Center(child: Text('Belum ada materi brainstorming.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade100),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Materi pengantar dan wawasan awal untuk orang tua mengenai perawatan bayi.',
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),

              ...groups.map((g) {
                final title = g['title'] ?? '';
                final desc = g['description'] as String?;
                final items = (g['items'] as List?) ?? [];

                List<String> bullets = [];
                if (desc != null && desc.isNotEmpty) {
                  bullets = desc.split('\n').where((s) => s.trim().isNotEmpty).toList();
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.black12)
                  ),
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.lightbulb_outline, color: Colors.orange, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(
                                  title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                              )
                          ),
                        ]),

                        if (bullets.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ...bullets.map((b) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Expanded(child: Text(b.trim())),
                                ]
                            ),
                          )),
                        ],

                        if (items.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          ...items.map((it) => OutlinedButton.icon(
                            onPressed: () {
                              _launchUrl(it['url'] ?? '');
                            },
                            icon: Icon(it['kind']=='VIDEO' ? Icons.play_circle_outline : Icons.open_in_new, size: 18),
                            label: Text(it['title'] ?? 'Lihat'),
                            style: OutlinedButton.styleFrom(
                                alignment: Alignment.centerLeft,
                                minimumSize: const Size(double.infinity, 40)
                            ),
                          )),
                        ]
                      ],
                    ),
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