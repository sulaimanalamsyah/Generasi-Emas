import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // [UBAH] Import ini
import '../services/api_client.dart';

class ReferencesPage extends StatefulWidget {
  const ReferencesPage({super.key});

  @override
  State<ReferencesPage> createState() => _ReferencesPageState();
}

class _ReferencesPageState extends State<ReferencesPage> {
  final _api = ApiClient();

  Future<List<dynamic>> _load() async {
    return await _api.getContent('REFERENCE', 'MOTHER');
  }

  // [BARU] Helper method
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
      appBar: AppBar(title: const Text('Referensi')),
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
            return Center(child: Text('Terjadi kesalahan: $err'));
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return const Center(child: Text('Belum ada referensi.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.link, color: Colors.green),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Kumpulan sumber bacaan, artikel, dan tautan penting terkait kesehatan ibu dan bayi.',
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),

              ...items.map((item) {
                final title = item['title'] ?? 'Referensi';
                final url = item['url'] ?? '';

                return _ReferenceCard(
                  icon: Icons.menu_book_rounded,
                  title: title,
                  url: url,
                  // [BARU] Pass fungsi launch ke card
                  onTap: () => _launchUrl(url),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _ReferenceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String url;
  final VoidCallback onTap; // [BARU] Callback

  const _ReferenceCard({
    required this.icon,
    required this.title,
    required this.url,
    required this.onTap, // [BARU]
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.blue.shade50,
                  child: Icon(icon, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),

            if (url.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: Text(
                  url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],

            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onTap, // [UBAH] Gunakan callback onTap
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Buka Tautan'),
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ),
          ],
        ),
      ),
    );
  }
}