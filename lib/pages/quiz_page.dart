import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../core/storage.dart';
import '../widgets/common.dart';
import '../widgets/in_app_viewer_page.dart';
import '../widgets/loading_overlay.dart';

String _fmtDate(dynamic submittedAt) {
  if (submittedAt == null) return '-';
  try {
    final s = submittedAt.toString();
    final dt = DateTime.tryParse(s)?.toLocal();
    if (dt == null) return s;
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
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

  bool _loading = true;
  bool _isFather = false;

  double? _averageScore;
  int _totalAttempts = 0;
  dynamic _latestSubmittedAt;

  // Each entry: { 'key', 'title', 'url', 'score' (nullable String) }
  List<Map<String, String?>> _quizItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    Map<String, String> links = await Prefs.getFormLinks();

    if (links.isEmpty || !links.keys.any((k) => k.startsWith('GFORM_QUIZ'))) {
      try {
        final apiConfig = await _api.getFormConfig();
        await Prefs.setFormLinks(apiConfig);
        links = apiConfig.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {}
    }

    // Collect only LINK keys, stripping _LINK suffix for clean title derivation.
    // Keys like GFORM_QUIZ_1_LINK, GFORM_QUIZ_2_LINK, GFORM_QUIZ_LINK are supported.
    final List<Map<String, String?>> collectedQuizzes = [];
    links.forEach((key, url) {
      if (key.startsWith('GFORM_QUIZ') && key.endsWith('_LINK') && url.trim().isNotEmpty) {
        collectedQuizzes.add({'key': key, 'url': url.trim(), 'title': null, 'score': null});
      }
    });

    // Fallback: bare GFORM_QUIZ_LINK or GFORM_QUIZ (legacy single-quiz)
    if (collectedQuizzes.isEmpty) {
      final fallbackUrl = links['GFORM_QUIZ_LINK'] ?? links['GFORM_QUIZ'] ?? '';
      if (fallbackUrl.trim().isNotEmpty) {
        collectedQuizzes.add({
          'key': 'GFORM_QUIZ_LINK',
          'url': fallbackUrl.trim(),
          'title': null,
          'score': null,
        });
      } else {
        // No links configured at all — show empty placeholder
        collectedQuizzes.add({
          'key': 'GFORM_QUIZ_LINK',
          'url': '',
          'title': null,
          'score': null,
        });
      }
    }

    // Sort alphabetically by key so numbering is deterministic
    collectedQuizzes.sort((a, b) => (a['key'] ?? '').compareTo(b['key'] ?? ''));

    // Assign sequential "Kuis Edukasi X" titles
    for (int i = 0; i < collectedQuizzes.length; i++) {
      collectedQuizzes[i] = {
        ...collectedQuizzes[i],
        'title': 'Kuis Edukasi ${i + 1}',
      };
    }

    try {
      final role = await Prefs.getRole();
      final dynamic res = await _api.getMyFormScores();

      final List allItems = (res is List)
          ? res
          : (res is Map ? (res['items'] as List? ?? []) : []);

      // Primary field is 'kind' (what the backend actually returns).
      // Accept 'QUIZ' or any 'QUIZ_X' type for future multi-quiz scores.
      final quizzes = allItems.where((it) {
        if (it is! Map) return false;
        final t = (it['kind'] ?? it['type'])?.toString().toUpperCase() ?? '';
        return t == 'QUIZ' || t.startsWith('QUIZ_');
      }).map((e) => Map<String, dynamic>.from(e)).toList();

      double? avgScore;
      int totalCount = quizzes.length;
      dynamic latestDate;

      if (quizzes.isNotEmpty) {
        quizzes.sort((a, b) {
          final dateA = a['doneAt'] ?? a['submittedAt'];
          final dateB = b['doneAt'] ?? b['submittedAt'];
          final da = DateTime.tryParse(dateA?.toString() ?? '') ?? DateTime(2000);
          final db = DateTime.tryParse(dateB?.toString() ?? '') ?? DateTime(2000);
          return db.compareTo(da);
        });

        latestDate = quizzes.first['doneAt'] ?? quizzes.first['submittedAt'];

        double sum = 0;
        int validScores = 0;
        for (final q in quizzes) {
          final sVal = q['score'];
          if (sVal != null) {
            final parsedScore = double.tryParse(sVal.toString());
            if (parsedScore != null) {
              sum += parsedScore;
              validScores++;
            }
          }
        }
        if (validScores > 0) {
          avgScore = sum / validScores;
        }
      }

      // Bind per-quiz scores: for now single QUIZ score shown on all cards.
      // When multi-quiz (QUIZ_1, QUIZ_2) scores exist, matched by index.
      final String? singleScore = avgScore?.toStringAsFixed(1);
      for (int i = 0; i < collectedQuizzes.length; i++) {
        // Try to find a score for QUIZ_${i+1} type (multi-quiz future support)
        final quizType = 'QUIZ_${i + 1}';
        final matchedScore = quizzes.where((q) {
          final t = (q['kind'] ?? q['type'])?.toString().toUpperCase() ?? '';
          return t == quizType;
        }).firstOrNull;

        final perQuizScore = matchedScore != null
            ? double.tryParse(matchedScore['score']?.toString() ?? '')?.toStringAsFixed(1)
            : (quizzes.length == 1 || (i == 0 && collectedQuizzes.length == 1))
                ? singleScore
                : (quizzes.isNotEmpty && collectedQuizzes.length == 1 ? singleScore : null);

        collectedQuizzes[i] = {
          ...collectedQuizzes[i],
          'score': perQuizScore,
        };
      }

      if (mounted) {
        setState(() {
          _isFather = (role == 'father');
          _averageScore = avgScore;
          _totalAttempts = totalCount;
          _latestSubmittedAt = latestDate;
          _quizItems = collectedQuizzes;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _quizItems = collectedQuizzes;
          _loading = false;
        });
      }
    }
  }

  void _handleOpenForm(String title, String? url) {
    final safeUrl = url?.trim() ?? '';
    if (safeUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Link kuis belum tersedia."),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_isFather) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF0284C7)),
              SizedBox(width: 8),
              Text(
                'Info untuk Ayah',
                style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Pengisian dilakukan oleh Ibu. Ayah hanya sebagai pemantau.',
            style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Oke',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981))),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InAppViewerPage(title: title, url: safeUrl),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final String displayAvgScore =
        _averageScore != null ? _averageScore!.toStringAsFixed(1) : '-';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: evaluationAppBar(
        context: context,
        title: 'Kuis Pasien',
        onRefresh: _loadData,
      ),
      body: _loading
          ? const LoadingOverlay(message: "Mengambil Nilai Kuis...")
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadData,
                color: const Color(0xFF10B981),
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  children: [
                    // Father / Observer Notice Banner
                    if (_isFather)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Color(0xFF0284C7), size: 24),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Ayah hanya sebagai pemantau. Pengisian kuis dilakukan oleh Ibu.',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF072846),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const Text(
                      'Kerjakan kuis pada tautan di bawah. Hasil skor dan riwayat pengerjaan akan otomatis ter-update setelah lembar respons diproses.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        height: 1.4,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Average Score Summary Card ──────────────────────────
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.analytics_rounded,
                                  color: Color(0xFF047857),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ringkasan Nilai Rata-rata',
                                      style: TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Akumulasi dari seluruh kuis yang dikerjakan',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Skor Rata-rata',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    displayAvgScore,
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: _averageScore != null
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Total Selesai',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$_totalAttempts Kuis',
                                    style: const TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Terakhir: ${_fmtDate(_latestSubmittedAt)}',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'Daftar Kuis Edukasi',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Dynamic Quiz Cards ──────────────────────────────────
                    ..._quizItems.map((item) {
                      final itemTitle = item['title'] ?? 'Kuis Edukasi';
                      final itemUrl = item['url'] ?? '';
                      final itemScore = item['score']; // null = belum dikerjakan

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.quiz_rounded,
                                color: Color(0xFF10B981),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    itemTitle,
                                    style: const TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Per-quiz score chip
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: itemScore != null
                                          ? const Color(0xFFD1FAE5)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      itemScore != null
                                          ? 'Skor: $itemScore'
                                          : 'Belum Dikerjakan',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: itemScore != null
                                            ? const Color(0xFF047857)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _handleOpenForm(itemTitle, itemUrl),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                ),
                                icon: const Icon(Icons.open_in_new_rounded,
                                    size: 16),
                                label: const Text(
                                  'Buka',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
    );
  }
}