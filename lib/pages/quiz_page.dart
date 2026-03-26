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

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final _api = ApiClient();

  bool loading = true;
  bool isFather = false;
  Map<String, dynamic>? latestQuiz;

  List<String> _quizLinks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);

    var links = await Prefs.getFormLinks();

    if (links.isEmpty || !links.containsKey('GFORM_QUIZ_LINK')) {
      try {
        final apiConfig = await _api.getFormConfig();
        await Prefs.setFormLinks(apiConfig);

        // [FIX UTAMA] Update variabel lokal
        links = apiConfig.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {}
    }

    _quizLinks = [];
    final url = links['GFORM_QUIZ_LINK'];

    if (url != null && url.isNotEmpty) {
      _quizLinks.add(url.trim());
    } else {
      _quizLinks.add('');
    }

    try {
      final role = await Prefs.getRole();

      final dynamic res = await _api.getMyFormScores();

      final List allItems = (res is List)
          ? res
          : (res is Map ? (res['items'] as List? ?? []) : []);

      final quizzes = allItems.where((it) {
        if (it is! Map) return false;
        final t = (it['type'] ?? it['kind'])?.toString().toUpperCase();
        return t == 'QUIZ';
      }).map((e) => Map<String, dynamic>.from(e)).toList();

      Map<String, dynamic>? foundLatest;
      if (quizzes.isNotEmpty) {
        quizzes.sort((a, b) {
          final dateA = a['doneAt'] ?? a['submittedAt'];
          final dateB = b['doneAt'] ?? b['submittedAt'];

          final da = DateTime.tryParse(dateA?.toString() ?? '') ?? DateTime(2000);
          final db = DateTime.tryParse(dateB?.toString() ?? '') ?? DateTime(2000);
          return db.compareTo(da);
        });
        foundLatest = quizzes.first;
      }

      if (mounted) {
        setState(() {
          isFather = (role == 'father');
          latestQuiz = foundLatest;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _handleOpenForm(String title, String url) {
    // [UBAH] Validasi
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link kuis belum tersedia.")));
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

  @override
  Widget build(BuildContext context) {
    final score = latestQuiz?['score'];
    final submittedAt = latestQuiz?['doneAt'] ?? latestQuiz?['submittedAt'];

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: loading
          ? const LoadingOverlay(message: "Mengambil Nilai Kuis...")
          : ListView(
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
                Expanded(child: Text('Ayah hanya sebagai pemantau, Pengisian dilakukan oleh Ibu.', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
              ]),
            ),

          const Text(
            'Kerjakan kuis pada tautan di bawah. Hasil (skor & tanggal) akan otomatis muncul setelah lembar respons diproses.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),

          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.quiz_outlined, size: 32, color: Colors.deepOrange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ringkasan Nilai Quiz Terakhir',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text('Skor: ${score ?? '-'}'),
                        const SizedBox(height: 2),
                        Text('Tanggal: ${_fmtDate(submittedAt)}'),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  )
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Daftar Kuis',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                  // [UBAH] Generate dari list dinamis
                  ...List.generate(_quizLinks.length, (i) {
                    final idx = i + 1;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Quiz #$idx'),
                      trailing: const Icon(Icons.open_in_new, color: Colors.blue),
                      onTap: () => _handleOpenForm('Quiz #$idx', _quizLinks[i]),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}