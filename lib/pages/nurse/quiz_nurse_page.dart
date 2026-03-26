import 'package:flutter/material.dart';
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

  List<_QuizItem> _items = [
    const _QuizItem(
      title: 'Quiz FINC & FCC Dasar',
      desc: 'Pengetahuan dasar Family Involvement in Neonatal Care (FINC) & Family-Centered Care (FCC).',
      url: '',
    ),
    const _QuizItem(
      title: 'Komunikasi & Dukungan Psikososial',
      desc: 'Latihan komunikasi terapeutik dan dukungan psikososial untuk keluarga NICU.',
      url: '',
    ),
    const _QuizItem(
      title: 'Kolaborasi Perawatan Neonatus',
      desc: 'Koordinasi dengan orang tua dalam tindakan non-invasif & edukasi laktasi.',
      url: '',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    var links = await Prefs.getFormLinks();

    if (links.isEmpty || !links.containsKey('GFORM_NURSE_QUIZ_FINC_LINK')) {
      debugPrint("⚠️ UI Nurse: Storage kosong, fetch API...");
      try {
        final apiConfig = await _api.getFormConfig();
        await Prefs.setFormLinks(apiConfig);

        links = apiConfig.map((k, v) => MapEntry(k, v.toString()));

        debugPrint("✅ UI Nurse: Config refreshed (${links.length} items)");
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        final url0 = links['GFORM_NURSE_QUIZ_FINC_LINK'] ?? '';
        final url1 = links['GFORM_NURSE_QUIZ_KOMUNIKASI_LINK'] ?? '';
        final url2 = links['GFORM_NURSE_QUIZ_KOLABORASI_LINK'] ?? '';

        _items = [
          _QuizItem(title: _items[0].title, desc: _items[0].desc, url: url0.trim()),
          _QuizItem(title: _items[1].title, desc: _items[1].desc, url: url1.trim()),
          _QuizItem(title: _items[2].title, desc: _items[2].desc, url: url2.trim()),
        ];
      });
    }
  }

  void _openForm(String title, String url) {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link form belum tersedia.")));
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
      appBar: AppBar(title: const Text('Quiz Perawat')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (context, i) {
          final item = _items[i];
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 20,
                    child: Icon(Icons.quiz_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            )),
                        const SizedBox(height: 6),
                        Text(
                          item.desc,
                          style: TextStyle(color: Theme.of(context).hintColor),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: () => _openForm(item.title, item.url),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Buka Form'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuizItem {
  final String title;
  final String desc;
  final String url;
  const _QuizItem({required this.title, required this.desc, required this.url});
}