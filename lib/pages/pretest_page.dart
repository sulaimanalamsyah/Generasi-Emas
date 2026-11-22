import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../services/api_client.dart';
import '../core/storage.dart';
import '../core/date_formatter.dart';
import '../routes.dart';
import '../widgets/common.dart';
import '../widgets/in_app_viewer_page.dart';
import '../widgets/loading_overlay.dart';

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
  Map<String, dynamic>? _legacyCoItem;
  Map<String, dynamic>? _legacyPssItem;
  bool pretestAck = false;

  String _pretestUrl = '';
  String _pretestPrefix = 'GFORM_PRETEST';

  @override
  void initState() {
    super.initState();
    _loadLinksAndData();
  }

  static const _kScoresCacheKey = 'patient_form_scores_v1';

  // Load Form Link (always refresh online, fallback to cache offline)
  Future<void> _loadLinksAndData() async {
    var links = await Prefs.getFormLinks();

    try {
      final apiConfig = await _api.getFormConfig();
      await Prefs.setFormLinks(apiConfig);
      links = apiConfig.map((k, v) => MapEntry(k, v.toString()));
    } catch (e) {
      debugPrint("⚠️ Pretest menggunakan cache tautan: $e");
    }

    String chosenUrl = '';
    String chosenPrefix = 'GFORM_PRETEST';
    if ((links['GFORM_PRETEST_LINK'] ?? '').trim().isNotEmpty) {
      chosenUrl = links['GFORM_PRETEST_LINK']!.trim();
      chosenPrefix = 'GFORM_PRETEST';
    } else if ((links['GFORM_CO_PARTNER_LINK'] ?? '').trim().isNotEmpty) {
      chosenUrl = links['GFORM_CO_PARTNER_LINK']!.trim();
      chosenPrefix = 'GFORM_CO_PARTNER';
    } else if ((links['GFORM_PRETEST_MOTHER_LINK'] ?? '').trim().isNotEmpty) {
      chosenUrl = links['GFORM_PRETEST_MOTHER_LINK']!.trim();
      chosenPrefix = 'GFORM_PRETEST_MOTHER';
    }

    if (mounted) {
      setState(() {
        _pretestUrl = chosenUrl;
        _pretestPrefix = chosenPrefix;
      });
    }
    await _bootstrap();
  }

  Future<void> _syncAndRefresh() async {
    try {
      await _api.syncMyFormScore(prefix: _pretestPrefix);
    } catch (_) {}
    await _loadLinksAndData();
  }

  void _applyScoreItems(List items, {required bool isFatherRole, required bool ack}) {
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

    num? numScore(Map<String, dynamic>? m) =>
        m == null ? null : num.tryParse('${m['score'] ?? ''}');

    final pre = pick('PRETEST');
    final co = pick('CO_PARTNER');
    final pss = pick('PSS_NICU');

    // Avoid surfacing a false `0` PRETEST row when legacy CO_PARTNER / PSS_NICU holds a non-zero score
    final preScore = numScore(pre);
    Map<String, dynamic>? primary = pre;
    if (primary == null || (preScore == 0 && ((numScore(co) ?? 0) > 0 || (numScore(pss) ?? 0) > 0))) {
      primary = ((numScore(co) ?? 0) > 0 ? co : null) ??
          ((numScore(pss) ?? 0) > 0 ? pss : null) ??
          pre ??
          co ??
          pss;
    }

    if (mounted) {
      setState(() {
        isFather = isFatherRole;
        pretestItem = primary;
        _legacyCoItem = co;
        _legacyPssItem = pss;
        pretestAck = ack;
        loading = false;
      });
    }
  }

  Future<void> _bootstrap() async {
    final role = await Prefs.getRole();
    final ack = await Prefs.getBool('pretest_ack') ?? false;
    final isFatherRole = (role == 'father');

    try {
      final dynamic response = await _api.getMyFormScores();
      final List items = (response is List)
          ? response
          : (response is Map ? (response['items'] as List? ?? []) : []);
      await Prefs.setCachedJson(_kScoresCacheKey, items);
      _applyScoreItems(items, isFatherRole: isFatherRole, ack: ack);
    } catch (e) {
      if (e is ApiError && e.status == 0) {
        final cached = await Prefs.getCachedJson(_kScoresCacheKey);
        if (cached is List) {
          _applyScoreItems(cached, isFatherRole: isFatherRole, ack: ack);
          return;
        }
      }
      if (mounted) {
        setState(() {
          isFather = isFatherRole;
          pretestAck = ack;
          loading = false;
        });
      }
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
      showAppSnackBar(context, message: "Tautan formulir belum tersedia.", isError: true);
      return;
    }

    if (isFather) {
      showAppInfoDialog(
        context,
        title: 'Info untuk Ayah',
        message: 'Pengisian dilakukan oleh Ibu. Ayah hanya sebagai pemantau.',
        variant: InfoDialogVariant.info,
        buttonLabel: 'Oke',
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InAppViewerPage(title: title, url: url),
      ),
    ).then((_) async {
      await _syncAndRefresh();
    });
  }

  Widget _card({
    required String title,
    required Map<String, dynamic>? item,
    required String url,
  }) {
    final score = item?['score'];
    final submittedAt = item?['submittedAt'] ?? item?['doneAt'];
    final isDone = (score != null) || (submittedAt != null);
    final hasLegacyCo = _legacyCoItem != null && _legacyCoItem != item && _legacyCoItem!['score'] != null;
    final hasLegacyPss = _legacyPssItem != null && _legacyPssItem != item && _legacyPssItem!['score'] != null;

    final badge = Container(
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
    );

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
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Column(
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
                      badge,
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.score_rounded, size: 18, color: Color(0xFF64748B)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      const Text(
                        'Skor Pre-Test:',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        AppDateFormatter.score(score),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasLegacyCo || hasLegacyPss) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (hasLegacyCo)
                    Text(
                      'CO Partner: ${AppDateFormatter.score(_legacyCoItem!['score'])}',
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF475569)),
                    ),
                  if (hasLegacyPss)
                    Text(
                      'PSS:NICU: ${AppDateFormatter.score(_legacyPssItem!['score'])}',
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF475569)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF64748B)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      const Text(
                        'Tanggal dikerjakan:',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        AppDateFormatter.dateTime(submittedAt),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _handleOpenForm(title, url),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text(
                    'Buka Formulir Pre-Test',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
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
        title: 'Pre-Test',
        onRefresh: _syncAndRefresh,
      ),
      body: SafeArea(
        top: false,
        child: loading
            ? const LoadingOverlay(message: "Memuat Status Pre-Test...")
            : RefreshIndicator(
              onRefresh: _syncAndRefresh,
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
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: ElevatedButton.icon(
                        onPressed: _markDoneAndGoHome,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_rounded, size: 20),
                        label: const Text(
                          'Kembali ke Beranda',
                          textAlign: TextAlign.center,
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
      ),
    );
  }
}