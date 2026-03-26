import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../core/storage.dart';
import '../routes.dart';
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

class PretestPage extends StatefulWidget {
  const PretestPage({super.key});

  @override
  State<PretestPage> createState() => _PretestPageState();
}

class _PretestPageState extends State<PretestPage> {
  final _api = ApiClient();

  bool loading = true;
  bool isFather = false;
  Map<String, dynamic>? coPartner;
  Map<String, dynamic>? pssNicu;
  bool pretestAck = false;

  String _urlPreCO = '';
  String _urlPrePss = '';

  @override
  void initState() {
    super.initState();
    _loadLinksAndData();
  }

  // Fungsi Load Link
  Future<void> _loadLinksAndData() async {
    var links = await Prefs.getFormLinks();

    if (links.isEmpty || !links.containsKey('GFORM_CO_PARTNER_LINK')) {
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
        _urlPreCO = (links['GFORM_CO_PARTNER_LINK'] ?? '').trim();
        _urlPrePss = (links['GFORM_PSS_NICU_LINK'] ?? '').trim();
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
            final t = (it['type'] ?? it['kind'] as String?)?.toUpperCase();
            if (t == k) {
              return Map<String, dynamic>.from(it);
            }
          }
        }
        return null;
      }

      if (mounted) {
        setState(() {
          isFather = (role == 'father');
          coPartner = pick('CO_PARTNER');
          pssNicu   = pick('PSS_NICU');
          pretestAck = ack;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  bool get _isCoDone => (coPartner?['score'] != null) || (coPartner?['submittedAt'] != null) || (coPartner?['doneAt'] != null);
  bool get _isPssDone => (pssNicu?['score'] != null) || (pssNicu?['submittedAt'] != null) || (pssNicu?['doneAt'] != null);
  bool get _bothDone => _isCoDone && _isPssDone;

  Future<void> _markDoneAndGoHome() async {
    await Prefs.setBool('pretest_ack', true);
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, Routes.homePatient, (_) => false);
  }

  void _handleOpenForm(String title, String url) {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link form belum tersedia.")));
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDone ? Colors.green.shade600 : Colors.orange.shade700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isDone ? 'Selesai' : 'Belum',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text('Skor terakhir: ${score ?? '-'}'),
            const SizedBox(height: 4),
            Text('Tanggal dikerjakan: ${_fmtDate(submittedAt)}'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _handleOpenForm(title, url),
              child: const Text('Buka Form'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showButtonContinue = _bothDone && !pretestAck;
    final showValidatedMsg = _bothDone && pretestAck;

    return Scaffold(
      appBar: AppBar(title: const Text('Pre Test')),
      body: loading
          ? const LoadingOverlay(message: "Memuat Status Pretest...")
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
                Expanded(
                    child: Text(
                      'Ayah hanya sebagai pemantau, Pengisian dilakukan oleh Ibu.',
                      style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                    )
                ),
              ]),
            ),

          const Text(
            'Silakan kerjakan kedua form berikut. Halaman ini bisa dilewati hanya setelah kedua form selesai dikerjakan.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),

          // [UBAH] Gunakan variabel _urlPreCO dan _urlPrePss
          _card(title: 'Kuesioner CO Partner (Pre)', item: coPartner, url: _urlPreCO),
          const SizedBox(height: 12),
          _card(title: 'Kuesioner PSS:NICU (Pre)', item: pssNicu, url: _urlPrePss),

          const SizedBox(height: 24),

          if (showButtonContinue)
            FilledButton.icon(
              onPressed: _markDoneAndGoHome,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Silakan kembali ke beranda.'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),

          if (showValidatedMsg)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified, color: Colors.green),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Pre test telah divalidasi. Anda dapat kembali ke beranda.',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              onPressed: _bootstrap,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Data'),
            ),
          )
        ],
      ),
    );
  }
}