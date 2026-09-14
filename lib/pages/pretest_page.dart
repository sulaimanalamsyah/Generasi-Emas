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

class PretestPage extends StatefulWidget {
  const PretestPage({super.key});

  @override
  State<PretestPage> createState() => _PretestPageState();
}

class _PretestPageState extends State<PretestPage> {
  final _api = ApiClient();

  bool loading = true;
  bool isFather = false;
  Map<String, dynamic>? pretestItem;
  bool pretestAck = false;

  String _pretestUrl = '';

  @override
  void initState() {
    super.initState();
    _loadLinksAndData();
  }

  // Load Form Link (GFORM_PRETEST_LINK with fallback)
  Future<void> _loadLinksAndData() async {
    var links = await Prefs.getFormLinks();

    if (links.isEmpty ||
        (!links.containsKey('GFORM_PRETEST_LINK') &&
         !links.containsKey('GFORM_CO_PARTNER_LINK') &&
         !links.containsKey('GFORM_PRETEST_MOTHER_LINK'))) {
      debugPrint("⚠️ UI Pretest: Fetch API...");
      try {
        final apiConfig = await _api.getFormConfig();
        await Prefs.setFormLinks(apiConfig);
        links = apiConfig.map((k, v) => MapEntry(k, v.toString()));
      } catch (e) {
        debugPrint("❌ Gagal fetch config: $e");
      }
    }

    if (mounted) {
      setState(() {
        _pretestUrl = (links['GFORM_PRETEST_LINK'] ??
                       links['GFORM_CO_PARTNER_LINK'] ??
                       links['GFORM_PRETEST_MOTHER_LINK'] ??
                       '').trim();
      });
    }
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final role = await Prefs.getRole();
      final ack = await Prefs.getBool('pretest_ack') ?? false;

      final dynamic response = await _api.getMyFormScores();

      final List items = (response is List)
          ? response
          : (response is Map ? (response['items'] as List? ?? []) : []);

      Map<String, dynamic>? pick(String k) {
        for (final it in items) {
          if (it is Map) {
            final t = (it['kind'] ?? it['type'] as String?)?.toUpperCase();
            if (t == k) {
              return Map<String, dynamic>.from(it);
            }
          }
        }
        return null;
      }

      // Match PRETEST first, with fallback to legacy CO_PARTNER or PSS_NICU
      final foundItem = pick('PRETEST') ?? pick('CO_PARTNER') ?? pick('PSS_NICU');

      if (mounted) {
        setState(() {
          isFather = (role == 'father');
          pretestItem = foundItem;
          pretestAck = ack;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  bool get _isPretestDone =>
      (pretestItem?['score'] != null) ||
      (pretestItem?['submittedAt'] != null) ||
      (pretestItem?['doneAt'] != null);

  Future<void> _markDoneAndGoHome() async {
    await Prefs.setBool('pretest_ack', true);
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, Routes.homePatient, (_) => false);
  }

  void _handleOpenForm(String title, String url) {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Link form belum tersedia.",
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
    ).then((_) => _bootstrap());
  }

  Widget _card({
    required String title,
    required Map<String, dynamic>? item,
    required String url,
  }) {
    final score = item?['score'];
    final submittedAt = item?['submittedAt'] ?? item?['doneAt'];
    final isDone = (score != null) || (submittedAt != null);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    Icons.assignment_outlined,
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
                        title,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Kuesioner evaluasi awal sebelum intervensi',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDone ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isDone ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDone ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                        size: 14,
                        color: isDone ? const Color(0xFF064E3B) : const Color(0xFF78350F),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isDone ? 'Selesai' : 'Belum',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: isDone ? const Color(0xFF064E3B) : const Color(0xFF78350F),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.score_rounded, size: 18, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                const Text(
                  'Skor Pre-Test: ',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  '${score ?? '-'}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                const Text(
                  'Tanggal dikerjakan: ',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  _fmtDate(submittedAt),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _handleOpenForm(title, url),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text(
                  'Buka Form Pre-Test',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showButtonContinue = _isPretestDone && !pretestAck;
    final showValidatedMsg = _isPretestDone && pretestAck;
    final int completedCount = _isPretestDone ? 1 : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: evaluationAppBar(
        context: context,
        title: 'Pre Test',
        onRefresh: _bootstrap,
      ),
      body: loading
          ? const LoadingOverlay(message: "Memuat Status Pretest...")
          : RefreshIndicator(
              onRefresh: _bootstrap,
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

                  // Card Container Instruksi & Visual Progress Tracker
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Progress Evaluasi: $completedCount/1 Selesai',
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF072846),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: completedCount / 1.0,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFBAE6FD),
                            color: const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Silakan kerjakan form kuesioner Pre-Test di bawah ini. Selesaikan form ini untuk membuka jadwal evaluasi Post-Test.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Color(0xFF072846),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Single Form Status Card
                  _card(
                    title: 'Kuesioner Pre-Test',
                    item: pretestItem,
                    url: _pretestUrl,
                  ),

                  const SizedBox(height: 24),

                  if (showButtonContinue)
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _markDoneAndGoHome,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_rounded, size: 20),
                        label: const Text(
                          'Silakan kembali ke beranda.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  if (showValidatedMsg)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.verified_rounded, color: Color(0xFF064E3B), size: 22),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Pre test telah divalidasi. Anda dapat kembali ke beranda.',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF064E3B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}