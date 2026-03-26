import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../core/storage.dart';
import '../widgets/in_app_viewer_page.dart';
import '../widgets/loading_overlay.dart';


String _fmtDate(dynamic submittedAt) {
  if (submittedAt == null) return '-';
  try {
    final s = submittedAt.toString();
    final dt = DateTime.tryParse(s)?.toLocal();
    return (dt ?? DateTime.now()).toString().substring(0, 16);
  } catch (_) {
    return submittedAt.toString();
  }
}

class PosttestPage extends StatefulWidget {
  const PosttestPage({super.key});

  @override
  State<PosttestPage> createState() => _PosttestPageState();
}

class _PosttestPageState extends State<PosttestPage> {
  final _api = ApiClient();

  bool loading = true;
  bool isFather = false;
  List<Map<String, dynamic>> _items = [];

  // List Link Dinamis
  final List<String> _postCoLinks = [];
  final List<String> _postPssLinks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Helper Skor Terakhir (Max N)
  Map<String, dynamic>? _getLastScore(String type) {
    Map<String, dynamic>? lastData;
    int maxN = 0;

    for (final item in _items) {
      final n = item['n'] as int;
      final data = (type == 'CO_PARTNER') ? item['coPartner'] : item['pssNicu'];

      if (data != null && data is Map) {
        final hasScore = data['score'] != null;
        final hasDate = data['doneAt'] != null || data['submittedAt'] != null;

        if (hasScore || hasDate) {
          if (n > maxN) {
            maxN = n;
            lastData = Map<String, dynamic>.from(data);
          }
        }
      }
    }
    return lastData;
  }

  Future<void> _load() async {
    setState(() => loading = true);

    var links = await Prefs.getFormLinks();

    if (links.isEmpty || !links.containsKey('GFORM_POSTTEST_CO_1_LINK')) {
      try {
        final apiConfig = await _api.getFormConfig();
        await Prefs.setFormLinks(apiConfig);

        links = apiConfig.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {}
    }

    _postCoLinks.clear();
    _postPssLinks.clear();

    for (int i = 1; i <= 5; i++) {
      final urlCo = links['GFORM_POSTTEST_CO_${i}_LINK'] ?? '';
      final urlPss = links['GFORM_POSTTEST_PSS_${i}_LINK'] ?? '';
      _postCoLinks.add(urlCo.trim());
      _postPssLinks.add(urlPss.trim());
    }

    try {
      final role = await Prefs.getRole();
      final dynamic res = await _api.getPosttests();

      if (mounted) {
        setState(() {
          isFather = (role == 'father');
          if (res != null && res is Map && res['items'] != null) {
            _items = List<Map<String, dynamic>>.from(res['items']);
          } else {
            _items = [];
          }
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _handleOpenForm(String title, String url) {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link form ini belum diatur.")));
      return;
    }

    if (isFather) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Info untuk Ayah'),
          content: const Text('Pengisian dilakukan oleh Ibu. Ayah hanya sebagai pemantau.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Oke'))],
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InAppViewerPage(title: title, url: url),
      ),
    ).then((_) => _load());
  }

  Widget _summaryCard(String title, String type, Color color) {
    final lastData = _getLastScore(type);
    final score = lastData?['score'];
    final date = lastData?['doneAt'] ?? lastData?['submittedAt'];

    return Card(
      color: color,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade800)),
            const SizedBox(height: 8),
            Text(
                '${score ?? '-'}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)
            ),
            const SizedBox(height: 4),
            Text(
                date != null ? _fmtDate(date).split(' ')[0] : 'Belum ada',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700)
            ),
          ],
        ),
      ),
    );
  }

  Widget _subItem(String label, Map<String, dynamic>? data, VoidCallback onTap) {
    final isDone = data != null && (data['score'] != null || data['doneAt'] != null);
    final score = data?['score'];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      leading: Icon(
        isDone ? Icons.check_circle : Icons.radio_button_unchecked,
        color: isDone ? Colors.teal : Colors.grey,
        size: 20,
      ),
      trailing: isDone
          ? Text(
          score != null ? 'Skor: $score' : 'Selesai',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)
      )
          : SizedBox(
        height: 32,
        child: FilledButton.tonal(
          onPressed: onTap,
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16)),
          child: const Text('Isi', style: TextStyle(fontSize: 12)),
        ),
      ),
      onTap: isDone ? null : onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = !loading && _items.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Post Test')),
      body: loading
          ? const LoadingOverlay(message: "Sinkronisasi Hasil Posttest...")
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (isFather)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(children: [
                  Icon(Icons.info, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(
                        'Ayah hanya sebagai pemantau, Pengisian dilakukan oleh Ibu.',
                        style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                      )
                  ),
                ]),
              ),

            if (isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.pending_actions, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        "Jadwal Post Test akan muncul setelah data Pre Test Anda terverifikasi oleh sistem. Silakan cek kembali nanti.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),

            if (!isEmpty) ...[
              const Text(
                'Ringkasan Nilai Terakhir',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(child: _summaryCard('CO Partner', 'CO_PARTNER', Colors.teal.shade50)),
                  const SizedBox(width: 12),
                  Expanded(child: _summaryCard('PSS:NICU', 'PSS_NICU', Colors.orange.shade50)),
                ],
              ),

              const SizedBox(height: 24),
              const Text(
                'Daftar Evaluasi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 12, top: 4),
                child: Text(
                  'Kerjakan secara berurutan sesuai jadwal.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),

              ..._items.map((item) {
                final n = item['n'] as int;
                final dueAtStr = item['dueAt']?.toString() ?? DateTime.now().toIso8601String();
                final dueAt = DateTime.parse(dueAtStr).toLocal();
                final now = DateTime.now();

                final isLockedTime = now.isBefore(dueAt);
                bool isLockedSeq = false;
                if (n > 1) {
                  try {
                    final prevItem = _items.firstWhere((e) => e['n'] == n - 1);
                    final prevCo = prevItem['coPartner'];
                    final prevPss = prevItem['pssNicu'];
                    if (prevCo == null || prevPss == null) {
                      isLockedSeq = true;
                    }
                  } catch (_) {}
                }

                final isLocked = isLockedTime || isLockedSeq;

                final isCompleted = item['coPartner'] != null && item['pssNicu'] != null;

                final urlCo = (n - 1 < _postCoLinks.length) ? _postCoLinks[n - 1] : '';
                final urlPss = (n - 1 < _postPssLinks.length) ? _postPssLinks[n - 1] : '';

                return Card(
                  clipBehavior: Clip.antiAlias,
                  color: isLocked ? Colors.grey.shade100 : Colors.white,
                  elevation: isLocked ? 0 : 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isCompleted
                          ? BorderSide(color: Colors.teal.withValues(alpha: 0.5), width: 1)
                          : BorderSide.none
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: isCompleted ? Colors.teal.shade50 : (isLocked ? Colors.grey.shade200 : Colors.white),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: isLocked ? Colors.grey : (isCompleted ? Colors.teal : Colors.blue),
                              child: Text('$n', style: const TextStyle(fontSize: 12, color: Colors.white)),
                            ),
                            const SizedBox(width: 12),
                            Text(
                                'Evaluasi Ke-$n',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isLocked ? Colors.grey : Colors.black87
                                )
                            ),
                            const Spacer(),
                            if (isLocked)
                              const Icon(Icons.lock, size: 16, color: Colors.grey)
                            else if (isCompleted)
                              const Icon(Icons.check_circle, size: 20, color: Colors.teal)
                          ],
                        ),
                      ),
                      if (isLocked)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            isLockedTime
                                ? 'Tersedia mulai: ${_fmtDate(dueAt)}'
                                : 'Selesaikan evaluasi sebelumnya terlebih dahulu.',
                            style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                          ),
                        ),
                      if (!isLocked) ...[
                        const Divider(height: 1, thickness: 0.5),
                        _subItem('CO Partner', item['coPartner'], () => _handleOpenForm('Evaluasi $n: CO Partner', urlCo)),
                        const Divider(height: 1, indent: 16, endIndent: 16, thickness: 0.5),
                        _subItem('PSS NICU', item['pssNicu'], () => _handleOpenForm('Evaluasi $n: PSS NICU', urlPss)),
                        const SizedBox(height: 8),
                      ]
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}