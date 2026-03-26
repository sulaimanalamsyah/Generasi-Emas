import 'package:flutter/material.dart';
import '../services/api_client.dart';

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  String _text = '';
  String _date = '-';
  bool _loading = true;

  static const String _defaultPolicy = '''
KEBIJAKAN PRIVASI

Aplikasi ini berkomitmen melindungi data pribadi Anda.
Kami mengumpulkan data nama, kesehatan, dan kontak untuk keperluan pemantauan stunting dan penelitian.
Data tidak akan disebarluaskan tanpa izin.

(Silakan hubungkan internet untuk melihat kebijakan lengkap)
''';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      // Format YYYY-MM-DD
      return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
    } catch (_) {
      return '-';
    }
  }

  Future<void> _loadData() async {
    final api = ApiClient();
    try {
      final data = await api.getPrivacyPolicy();
      if (mounted) {
        setState(() {
          if (data['text'] != null && data['text'].toString().isNotEmpty) {
            _text = data['text'];
            _date = _formatDate(data['updatedAt']);
          } else {
            _text = _defaultPolicy;
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _text = _defaultPolicy;
          _loading = false;
        });

        if (e is ApiError && e.status == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Offline: Menampilkan teks standar.")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kebijakan Privasi')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Header Tanggal
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.w600)),
                Text('Update: $_date', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const Divider(height: 1),

          // Isi Konten
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(
                _text,
                textAlign: TextAlign.justify,
                style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
              ),
            ),
          ),

          // Tombol Tutup
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}