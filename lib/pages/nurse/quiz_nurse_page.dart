import 'package:material_ui/material_ui.dart';
import '../../widgets/common.dart';
import '../../widgets/in_app_viewer_page.dart';
import '../../core/storage.dart';
import '../../services/api_client.dart';

class QuizNursePage extends StatefulWidget {
  const QuizNursePage({super.key});

  @override
  State<QuizNursePage> createState() => _QuizNursePageState();
}

class _QuizNursePageState extends State<QuizNursePage> {
  final _api = ApiClient();
  bool _loading = true;

  List<_QuizItem> _items = [
    const _QuizItem(
      title: 'Quiz FINC & FCC Dasar',
      desc: 'Pengetahuan dasar Family Involvement in Neonatal Care (FINC) & Family-Centered Care (FCC).',
      url: '',
      icon: Icons.menu_book_rounded,
      color: Color(0xFF10B981),
      bgColor: Color(0xFFD1FAE5),
    ),
    const _QuizItem(
      title: 'Komunikasi & Dukungan Psikososial',
      desc: 'Latihan komunikasi terapeutik dan dukungan psikososial untuk keluarga di ruang NICU.',
      url: '',
      icon: Icons.forum_outlined,
      color: Color(0xFF0284C7),
      bgColor: Color(0xFFE0F2FE),
    ),
    const _QuizItem(
      title: 'Kolaborasi Perawatan Neonatus',
      desc: 'Koordinasi dengan orang tua dalam tindakan non-invasif & edukasi laktasi terstruktur.',
      url: '',
      icon: Icons.handshake_outlined,
      color: Color(0xFF6366F1),
      bgColor: Color(0xFFEEF2FF),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  static const _canonicalKeys = {
    'GFORM_NURSE_QUIZ_FINC_LINK',
    'GFORM_NURSE_QUIZ_KOMUNIKASI_LINK',
    'GFORM_NURSE_QUIZ_KOLABORASI_LINK',
  };

  Future<void> _loadLinks() async {
    setState(() => _loading = true);
    var links = await Prefs.getFormLinks();
    var labels = await Prefs.getFormLabels();

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

    if (mounted) {
      setState(() {
        final url0 = links['GFORM_NURSE_QUIZ_FINC_LINK'] ?? '';
        final url1 = links['GFORM_NURSE_QUIZ_KOMUNIKASI_LINK'] ?? '';
        final url2 = links['GFORM_NURSE_QUIZ_KOLABORASI_LINK'] ?? '';

        String labelOr(String key, String fallback) {
          final lbl = (labels[key] ?? '').trim();
          return lbl.isNotEmpty ? lbl : fallback;
        }

        final nextItems = <_QuizItem>[
          _QuizItem(
            title: labelOr('GFORM_NURSE_QUIZ_FINC_LINK', 'Kuis FINC & FCC Dasar'),
            desc: 'Pengetahuan dasar Family Involvement in Neonatal Care (FINC) & Family-Centered Care (FCC).',
            url: url0.trim(),
            icon: Icons.menu_book_rounded,
            color: const Color(0xFF10B981),
            bgColor: const Color(0xFFD1FAE5),
          ),
          _QuizItem(
            title: labelOr('GFORM_NURSE_QUIZ_KOMUNIKASI_LINK', 'Komunikasi & Dukungan Psikososial'),
            desc: 'Latihan komunikasi terapeutik dan dukungan psikososial untuk keluarga di ruang NICU.',
            url: url1.trim(),
            icon: Icons.forum_outlined,
            color: const Color(0xFF0284C7),
            bgColor: const Color(0xFFE0F2FE),
          ),
          _QuizItem(
            title: labelOr('GFORM_NURSE_QUIZ_KOLABORASI_LINK', 'Kolaborasi Perawatan Neonatus'),
            desc: 'Koordinasi dengan orang tua dalam tindakan non-invasif & edukasi laktasi terstruktur.',
            url: url2.trim(),
            icon: Icons.handshake_outlined,
            color: const Color(0xFF6366F1),
            bgColor: const Color(0xFFEEF2FF),
          ),
        ];

        // Dynamically append any additional GFORM_NURSE_QUIZ_*_LINK configured by Admin
        final extraKeys = links.keys
            .where((k) =>
                k.startsWith('GFORM_NURSE_QUIZ_') &&
                k.endsWith('_LINK') &&
                !_canonicalKeys.contains(k) &&
                (links[k] ?? '').trim().isNotEmpty)
            .toList()
          ..sort();

        for (final k in extraKeys) {
          final pretty = k
              .replaceAll(RegExp(r'^GFORM_NURSE_QUIZ_|_LINK$'), '')
              .replaceAll('_', ' ');
          nextItems.add(_QuizItem(
            title: labelOr(k, 'Kuis Perawat: $pretty'),
            desc: 'Formulir evaluasi klinis tambahan untuk perawat NICU.',
            url: (links[k] ?? '').trim(),
            icon: Icons.quiz_outlined,
            color: const Color(0xFF0EA5E9),
            bgColor: const Color(0xFFE0F2FE),
          ));
        }

        _items = nextItems;
        _loading = false;
      });
    }
  }

  void _openForm(String title, String url) {
    if (url.isEmpty) {
      showAppSnackBar(
        context,
        message: "Tautan formulir evaluasi belum dikonfigurasi.",
        isError: true,
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InAppViewerPage(
          title: title,
          url: url,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: enicareAppBar(
        context,
        title: 'Kuis Perawat',
        showBackButton: Navigator.of(context).canPop(),
        actions: [
          IconButton(
            tooltip: 'Perbarui Formulir',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
            onPressed: _loadLinks,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : RefreshIndicator(
              onRefresh: _loadLinks,
              color: const Color(0xFF10B981),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // Info Header Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.psychology_rounded, color: Color(0xFF0284C7), size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Evaluasi Mandiri Klinis',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF072846),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Formulir kuis ditujukan untuk mengukur pemahaman asuhan neonatal integratif keluarga (Model I-FINC).',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: Color(0xFF0369A1),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Section Title
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      'DAFTAR TOPIK EVALUASI',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  // Quiz Items List
                  ..._items.map((item) => _buildQuizCard(item)),

                  const SizedBox(height: 32),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildQuizCard(_QuizItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        border: Border.fromBorderSide(BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
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
                    color: item.bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: item.color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.desc,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: Color(0xFF475569),
                          height: 1.4,
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

            Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  onPressed: () => _openForm(item.title, item.url),
                  icon: const Icon(Icons.assignment_outlined, size: 18),
                  label: const Text(
                    'Buka Kuis',
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
}

class _QuizItem {
  final String title;
  final String desc;
  final String url;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _QuizItem({
    required this.title,
    required this.desc,
    required this.url,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}