import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../services/api_client.dart';
import '../core/storage.dart';
import '../core/date_formatter.dart';
import '../widgets/common.dart';
import '../widgets/in_app_viewer_page.dart';
import '../widgets/loading_overlay.dart';

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

  static const _kScoresCacheKey = 'patient_form_scores_v1';

  Future<void> _loadData() async {
    setState(() => _loading = true);

    Map<String, String> links = await Prefs.getFormLinks();
    Map<String, String> labels = await Prefs.getFormLabels();

    try {
      final results = await Future.wait([
        _api.getFormConfig(),
        _api.getFormConfigMeta(),
      ]);
      final apiConfig = results[0];
      if (apiConfig.isNotEmpty) {
        await Prefs.setFormLinks(apiConfig);
        links = apiConfig.map((k, v) => MapEntry(k, v.toString()));
      }
      final meta = results[1];
      final metaLinks = meta['links'];
      if (metaLinks is Map && metaLinks.isNotEmpty && apiConfig.isEmpty) {
        final typedLinks = metaLinks.map((k, v) => MapEntry(k.toString(), v));
        await Prefs.setFormLinks(typedLinks);
        links = typedLinks.map((k, v) => MapEntry(k, v.toString()));
      }
      final metaLabels = meta['labels'];
      if (metaLabels is Map && metaLabels.isNotEmpty) {
        final typedLabels = metaLabels.map((k, v) => MapEntry(k.toString(), v));
        await Prefs.setFormLabels(typedLabels);
        labels = typedLabels.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (_) {}

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

    // Assign custom Admin label if provided, else sequential "Kuis Edukasi X"
    for (int i = 0; i < collectedQuizzes.length; i++) {
      final k = collectedQuizzes[i]['key'] ?? '';
      final customLabel = (labels[k] ?? '').trim();
      collectedQuizzes[i] = {
        ...collectedQuizzes[i],
        'title': customLabel.isNotEmpty ? customLabel : 'Kuis Edukasi ${i + 1}',
      };
    }

    final role = await Prefs.getRole();
    final isFatherRole = (role == 'father');

    void applyItems(List allItems) {
      final quizzes = allItems.where((it) {
        if (it is! Map) return false;
        final t = (it['kind'] ?? it['type'])?.toString().toUpperCase() ?? '';
        return t == 'QUIZ' || t.startsWith('QUIZ_');
      }).map((e) => Map<String, dynamic>.from(e)).toList();

      double? avgScore;
      final int totalCount = quizzes.length;
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

      final String? singleScore = avgScore != null ? AppDateFormatter.score(avgScore) : null;
      for (int i = 0; i < collectedQuizzes.length; i++) {
        final key = collectedQuizzes[i]['key'] ?? '';
        final keyIndexMatch = RegExp(r'QUIZ_(\d+)').firstMatch(key);
        final quizType = keyIndexMatch != null ? 'QUIZ_${keyIndexMatch.group(1)}' : 'QUIZ_${i + 1}';
        final matchedScore = quizzes.where((q) {
          final t = (q['kind'] ?? q['type'])?.toString().toUpperCase() ?? '';
          return t == quizType;
        }).firstOrNull;

        final perQuizScore = matchedScore != null && matchedScore['score'] != null
            ? AppDateFormatter.score(matchedScore['score'])
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
          _isFather = isFatherRole;
          _averageScore = avgScore;
          _totalAttempts = totalCount;
          _latestSubmittedAt = latestDate;
          _quizItems = collectedQuizzes;
          _loading = false;
        });
      }
    }

    try {
      final dynamic res = await _api.getMyFormScores();
      final List allItems = (res is List)
          ? res
          : (res is Map ? (res['items'] as List? ?? []) : []);
      await Prefs.setCachedJson(_kScoresCacheKey, allItems);
      applyItems(allItems);
    } catch (e) {
      if (e is ApiError && e.status == 0) {
        final cached = await Prefs.getCachedJson(_kScoresCacheKey);
        if (cached is List) {
          applyItems(cached);
          return;
        }
      }
      if (mounted) {
        setState(() {
          _isFather = isFatherRole;
          _quizItems = collectedQuizzes;
          _loading = false;
        });
      }
    }
  }

  void _handleOpenForm(String title, String? url, {String? key}) {
    final safeUrl = url?.trim() ?? '';
    if (safeUrl.isEmpty) {
      showAppSnackBar(context, message: "Tautan kuis belum tersedia.", isError: true);
      return;
    }

    if (_isFather) {
      showAppInfoDialog(
        context,
        title: 'Info untuk Ayah',
        message: 'Pengisian dilakukan oleh Ibu. Ayah hanya sebagai pemantau.',
        variant: InfoDialogVariant.info,
        buttonLabel: 'Oke',
      );
      return;
    }

    final prefix = (key ?? '').replaceAll(RegExp(r'_LINK$'), '');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InAppViewerPage(title: title, url: safeUrl),
      ),
    ).then((_) async {
      try {
        await _api.syncMyFormScore(prefix: prefix.isNotEmpty ? prefix : null);
      } catch (_) {}
      await _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final String displayAvgScore =
        _averageScore != null ? AppDateFormatter.score(_averageScore!) : '-';
    final isLargeText = MediaQuery.textScalerOf(context).scale(14) > 18;

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
              top: false,
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
                      'Kerjakan kuis pada tautan di bawah. Hasil skor dan riwayat pengerjaan akan otomatis diperbarui setelah lembar respons diproses.',
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
                          SizedBox(
                            width: double.infinity,
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.end,
                              spacing: 16,
                              runSpacing: 12,
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
                                  crossAxisAlignment: isLargeText ? CrossAxisAlignment.start : CrossAxisAlignment.end,
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
                                      'Terakhir: ${AppDateFormatter.dateTime(_latestSubmittedAt)}',
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
                      final itemKey = item['key'];
                      final itemTitle = item['title'] ?? 'Kuis Edukasi';
                      final itemUrl = item['url'] ?? '';
                      final itemScore = item['score']; // null = belum dikerjakan
                      final openBtn = ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _handleOpenForm(itemTitle, itemUrl, key: itemKey),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: const Text(
                            'Buka',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );

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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
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
                                if (!isLargeText) ...[
                                  const SizedBox(width: 8),
                                  openBtn,
                                ],
                              ],
                            ),
                            if (isLargeText) ...[
                              const SizedBox(height: 12),
                              openBtn,
                            ],
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