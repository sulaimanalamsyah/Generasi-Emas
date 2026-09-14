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

  static const String _defaultPolicy = '''KEBIJAKAN PRIVASI

Aplikasi ini berkomitmen melindungi data pribadi Anda.
Kami mengumpulkan data nama, kesehatan, dan kontak untuk keperluan pemantauan stunting dan penelitian.
Data tidak akan disebarluaskan tanpa izin.

(Silakan hubungkan internet untuk melihat kebijakan lengkap)''';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return "$y-$m-$d";
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Kebijakan Privasi',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF10B981),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Container(
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
                        children: [
                          _PolicyHeader(date: _date),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          Expanded(
                            child: RefreshIndicator(
                              color: const Color(0xFF10B981),
                              onRefresh: _loadData,
                              child: _PolicyText(text: _text),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

// Custom Header Widget
class _PolicyHeader extends StatelessWidget {
  final String date;
  const _PolicyHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Text(
              'Kebijakan Privasi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Diperbarui: $date',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Scrollable Text Widget with Paragraph Formatting
class _PolicyText extends StatelessWidget {
  final String text;
  const _PolicyText({required this.text});

  @override
  Widget build(BuildContext context) {
    final List<String> lines = text.split('\n');
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final line = lines[index].trim();
        if (line.isEmpty) return const SizedBox(height: 12);
        
        final bool isHeader = (line == line.toUpperCase() && line.length < 60 && line.length > 3) ||
            RegExp(r'^\d+\.\s+[A-Z]').hasMatch(line);

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            line,
            textAlign: isHeader ? TextAlign.left : TextAlign.justify,
            style: TextStyle(
              fontSize: isHeader ? 16 : 15,
              fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
              height: 1.6,
              color: isHeader ? const Color(0xFF0F172A) : const Color(0xFF334155),
            ),
          ),
        );
      },
    );
  }
}