import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../core/storage.dart';
import '../routes.dart';
import '../widgets/common.dart';
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

  // Helper Hitung Skor Rata-Rata per Kategori (CO_PARTNER / PSS_NICU)
  Map<String, dynamic> _getAverageScoreData(String type) {
    double totalScore = 0;
    int count = 0;

    for (final item in _items) {
      final data = (type == 'CO_PARTNER') ? item['coPartner'] : item['pssNicu'];

      if (data != null && data is Map) {
        final rawScore = data['score'];
        if (rawScore != null) {
          final parsed = double.tryParse(rawScore.toString());
          if (parsed != null) {
            totalScore += parsed;
            count++;
          }
        }
      }
    }

    if (count == 0) {
      return {'avg': '-', 'count': 0};
    }

    final avg = totalScore / count;
    final formattedAvg = (avg % 1 == 0) ? avg.toInt().toString() : avg.toStringAsFixed(1);
    return {'avg': formattedAvg, 'count': count};
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Link form ini belum diatur.",
            style: TextStyle(fontFamily: 'Inter'),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    if (isFather) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Info untuk Ayah',
            style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          content: const Text(
            'Pengisian dilakukan oleh Ibu. Ayah hanya sebagai pemantau.',
            style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF334155)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Oke',
                style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
              ),
            )
          ],
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

  Widget _summaryCard(String title, String type, Color scoreColor, Color bgContainer) {
    final avgData = _getAverageScoreData(type);
    final String avgScore = avgData['avg'] as String;
    final int count = avgData['count'] as int;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              avgScore,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: 26,
                color: scoreColor,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: bgContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                count > 0 ? '$count evaluasi selesai' : 'Belum ada data',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scoreColor,
                ),
              ),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
      leading: Icon(
        isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
        color: isDone ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
        size: 22,
      ),
      trailing: isDone
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Text(
                score != null ? 'Skor: $score' : 'Selesai',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF064E3B),
                ),
              ),
            )
          : SizedBox(
              height: 38,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text(
                  'Isi',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
      onTap: isDone ? null : onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = !loading && _items.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: evaluationAppBar(
        context: context,
        title: 'Post Test',
        onRefresh: _load,
      ),
      body: loading
          ? const LoadingOverlay(message: "Sinkronisasi Hasil Posttest...")
          : RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFF10B981),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (isFather)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 22),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Ayah hanya sebagai pemantau, Pengisian dilakukan oleh Ibu.',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF072846),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // [PREREQUISITE GUARD] Locked Pretest Uncompleted View
                  if (isEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFEF3C7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_clock_rounded,
                              size: 32,
                              color: Color(0xFFD97706),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            "Pretest Belum Selesai",
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF78350F),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Jadwal Post Test akan muncul setelah data Pre Test Anda diselesaikan dan terverifikasi oleh sistem. Silakan kerjakan Pretest terlebih dahulu.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              height: 1.5,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(context, Routes.pretest);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.assignment_turned_in_rounded, size: 20),
                              label: const Text(
                                "Kerjakan Pretest Sekarang",
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // [ACTIVE POSTTEST] Active Evaluation Cards & Summary Scores
                  if (!isEmpty) ...[
                    const Text(
                      'Ringkasan Rata-Rata Nilai',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _summaryCard(
                            'CO Partner',
                            'CO_PARTNER',
                            const Color(0xFF10B981),
                            const Color(0xFFD1FAE5),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _summaryCard(
                            'PSS:NICU',
                            'PSS_NICU',
                            const Color(0xFF0EA5E9),
                            const Color(0xFFE0F2FE),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    const Text(
                      'Daftar Evaluasi',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 14, top: 4),
                      child: Text(
                        'Kerjakan secara berurutan sesuai jadwal.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
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

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isLocked ? const Color(0xFFF1F5F9) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCompleted
                                ? const Color(0xFFA7F3D0)
                                : (isLocked ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1)),
                          ),
                          boxShadow: [
                            if (!isLocked)
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? const Color(0xFFECFDF5)
                                    : (isLocked ? const Color(0xFFF1F5F9) : Colors.white),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 13,
                                    backgroundColor: isLocked
                                        ? const Color(0xFF94A3B8)
                                        : (isCompleted ? const Color(0xFF10B981) : const Color(0xFF0EA5E9)),
                                    child: Text(
                                      '$n',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Evaluasi Ke-$n',
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isLocked ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (isLocked)
                                    const Icon(Icons.lock_rounded, size: 18, color: Color(0xFF94A3B8))
                                  else if (isCompleted)
                                    const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF10B981))
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
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            if (!isLocked) ...[
                              const Divider(height: 1, thickness: 0.5, color: Color(0xFFE2E8F0)),
                              _subItem('CO Partner', item['coPartner'], () => _handleOpenForm('Evaluasi $n: CO Partner', urlCo)),
                              const Divider(height: 1, indent: 16, endIndent: 16, thickness: 0.5, color: Color(0xFFE2E8F0)),
                              _subItem('PSS NICU', item['pssNicu'], () => _handleOpenForm('Evaluasi $n: PSS NICU', urlPss)),
                              const SizedBox(height: 8),
                            ]
                          ],
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}