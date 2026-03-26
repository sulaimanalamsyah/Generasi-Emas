import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../routes.dart';
import '../services/api_client.dart';

String _formatDate(String? isoString) {
  if (isoString == null || isoString.isEmpty) return kConsentLastUpdated;
  try {
    final dt = DateTime.parse(isoString).toLocal();
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  } catch (_) {
    return kConsentLastUpdated;
  }
}

// Read Only
class ConsentReadOnlyPage extends StatefulWidget {
  const ConsentReadOnlyPage({super.key});
  @override State<ConsentReadOnlyPage> createState() => _ConsentReadOnlyPageState();
}
class _ConsentReadOnlyPageState extends State<ConsentReadOnlyPage> {
  String _text = ''; String _date = kConsentLastUpdated; bool _loading = true;
  @override void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final api = ApiClient();
    try {
      final data = await api.getConsentData();
      if (mounted) {
        setState(() {
          if (data['text'] != null && data['text'].toString().isNotEmpty) {
            _text = data['text']; _date = _formatDate(data['updatedAt']);
          } else {
            _text = _defaultConsentText;
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _text = _defaultConsentText;
          _loading = false;
        });

        if (e is ApiError && e.status == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Offline: Menampilkan teks standar."))
          );
        }
      }
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Informed Consent')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : Column(
        children: [
          _ConsentHeader(date: _date),
          Expanded(child: _ConsentText(text: _text)),
          Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Kembali')))),
        ],
      ),
    );
  }
}

// Register Flow Version
class ConsentRegisterPage extends StatefulWidget {
  const ConsentRegisterPage({super.key});

  @override
  State<ConsentRegisterPage> createState() => _ConsentRegisterPageState();
}

class _ConsentRegisterPageState extends State<ConsentRegisterPage> {
  final _scroll = ScrollController();
  bool _atBottom = false;
  bool _submitting = false;
  bool _loadingContent = true;
  String _contentBody = '';
  String _contentDate = kConsentLastUpdated;
  Map<String, dynamic>? _payload;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadContent();
  }

  // Helper Alert Dialog
  Future<void> _showDialogInfo(String title, String message, {bool isError = false}) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: isError ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(color: isError ? Colors.red : Colors.green),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _loadContent() async {
    final api = ApiClient();
    try {
      final data = await api.getConsentData();
      if (mounted) {
        setState(() {
          if (data['text'] != null && data['text'].toString().isNotEmpty) {
            _contentBody = data['text'];
            _contentDate = _formatDate(data['updatedAt']);
          } else {
            _contentBody = _defaultConsentText;
          }
          _loadingContent = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _contentBody = _defaultConsentText;
          _loadingContent = false;
        });
        if (e is ApiError && e.status == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Offline: Menampilkan teks standar."))
          );
        }
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    Map<String, dynamic>? p;
    if (args is Map) {
      final m = args.cast<String, dynamic>();
      final inner = m['payload'];
      if (inner is Map) p = inner.cast<String, dynamic>();
    }
    _payload = p;
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final nowAtBottom = pos.pixels >= pos.maxScrollExtent && pos.maxScrollExtent > 0;
    if (nowAtBottom != _atBottom) {
      setState(() => _atBottom = nowAtBottom);
    }
  }

  Future<void> _agreeAndRegister() async {
    if (_payload == null) {
      _showDialogInfo("Error", "Data pendaftaran tidak ditemukan. Silakan ulangi.", isError: true);
      return;
    }
    if (!_atBottom) {
      _showDialogInfo("Baca Dahulu", "Silakan scroll sampai bawah untuk menyetujui.", isError: true);
      return;
    }

    final name = (_payload!['name'] as String? ?? '').trim();
    final email = (_payload!['email'] as String? ?? '').trim();
    final phone = (_payload!['phone'] as String? ?? '').replaceAll(RegExp(r'\D'), '');
    final password = (_payload!['password'] as String? ?? '');
    final role = (_payload!['role'] as String? ?? 'mother');

    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      _showDialogInfo("Data Tidak Lengkap", "Data (Nama/Email/WA/Password) belum lengkap", isError: true);
      return;
    }

    setState(() => _submitting = true);
    final api = ApiClient();
    try {
      await api.register(
          name: name,
          email: email,
          phone: phone,
          password: password,
          role: role
      );

      try {
        await api.sendOtpWhatsApp(phone);
      } catch (e) {
        if (!mounted) return;
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, Routes.activate, arguments: phone);
    } catch (e) {
      if (!mounted) return;

      // Handling Error Offline
      if (e is ApiError && e.status == 0) {
        _showDialogInfo("Gagal Daftar", "Tidak ada koneksi internet. Pendaftaran membutuhkan koneksi.", isError: true);
      } else if (e is ApiError) {
        final detail = e.detail;
        final code = (detail is Map && detail['code'] is String) ? detail['code'] as String : null;

        if (code == 'ACCOUNT_ALREADY_ACTIVE') {
          await _showDialogInfo("Info Akun", "Akun sudah aktif. Silakan langsung login.", isError: true);
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(context, Routes.login, (route) => false);
          return;
        }
        _showDialogInfo("Gagal Register", e.toString(), isError: true);
      } else {
        _showDialogInfo("Gagal Register", e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Informed Consent')),
      body: _loadingContent
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _ConsentHeader(date: _contentDate),
          Expanded(
            child: _ConsentText(
              controller: _scroll,
              text: _contentBody,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.pushNamedAndRemoveUntil(context, Routes.start, (r) => false),
                    child: const Text('Tidak Setuju'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: (!_submitting && _atBottom) ? _agreeAndRegister : null,
                    child: _submitting
                        ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Setuju'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Widget
class _ConsentHeader extends StatelessWidget {
  final String date;
  const _ConsentHeader({required this.date});
  @override Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Informed Consent', style: TextStyle(fontWeight: FontWeight.w600)), Text('Diperbarui: $date', style: const TextStyle(fontSize: 12, color: Colors.grey))]));
  }
}
class _ConsentText extends StatelessWidget {
  final ScrollController? controller; final String text;
  const _ConsentText({this.controller, required this.text});
  @override Widget build(BuildContext context) {
    final List<String> lines = text.split('\n');
    return ListView.builder(
      controller: controller, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), itemCount: lines.length,
      itemBuilder: (context, index) {
        final line = lines[index].trim();
        if (line.isEmpty) return const SizedBox(height: 12);
        final bool isHeader = line == line.toUpperCase() && line.length < 60 && line.length > 3;
        return Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(line, textAlign: isHeader ? TextAlign.center : TextAlign.justify, style: TextStyle(fontSize: isHeader ? 15 : 13.5, fontWeight: isHeader ? FontWeight.bold : FontWeight.normal, height: 1.6, color: Colors.black87)));
      },
    );
  }
}
const String _defaultConsentText = '''PENJELASAN PENELITIAN
PENELITIAN TAHAP UJI COBA MODEL I-FINC BERBASIS APLIKASI MOBILE

Assalamualaikum Wr. Wb., Saya Eni Rahmawati merupakan mahasiswa akan mengadakan penelitian. Pada bagian ini, saya bermaksud mengadakan penelitian tentang Usability Testing terhadap Aplikasi Model Indonesian Family Integrated Neonatal Care (I-FINC) bermasis aplikasi mobile menggunakan smartphone. Penelitian ini bertujuan untuk mengetahui kelayakan dan kegunaan dari Model I-FINC dengan aplikasi interaktif. Saya memohon kesediaan Bapak/Ibu untuk menjadi responden dalam penelitian ini. Bapak/Ibu diminta untuk download aplikasi dari handphone kemudian Bapak/Ibu menggunakan aplikasi tersebut sesuai kebutuhan Bapak/Ibu. Bapak/Ibu menggunakan aplikasi tersebut selama 2-4 minggu kemudian pada sesi Bapak/Ibu akan diminta mengisi kuesioner. Kuesioner ini terdiri dari dua bagian, yaitu bagian yang pertama berisi tentang data biografi, bagian kedua berisi tentang kelayakan dan kegunaan dari aplikasi yang dibuat seperti adanya permasalahan dan kemudahan dalam menggunakan aplikasi. Waktu pengisian kuesioner termasuk penggunaan aplikasi kurang lebih selama 30 menit. Partisipasi Bapak/Ibu dalam penelitian ini bersifat sukarela dan tidak ada unsur paksaan sehingga Bapak/Ibu berhak memutuskan bersedia atau menolak untuk menjadi responden. Peneliti akan memberikan hak kepada responden apabila ingin mengundurkan diri dari penelitian. Penelitian ini tidak akan menimbulkan dampak negatif yang merugikan pekerjaan maupun kehidupan pribadi responden. Peneliti akan menjaga kerahasiaan data yang diperoleh, identitas responden tidak akan dicantumkan oleh peneliti baik dalam pelaporan maupun publikasi. Data yang diperoleh akan disimpan dengan pengamanan dan akses terbatas hanya untuk peneliti. Jika dikemudian hari Bapak/Ibu ingin menghapus data yang telah dimasukkan karena satu dan lain hal, saya dengan senang hati akan membantu.

Jika Bapak/Ibu tertarik untuk menjadi bagian dari penelitian ini, maka dapat dilanjutkan dengan mengisi lembar demografi partisipan dan menandatangani formulir persetujuan (informed consent) yang terlampir dengan surat ini. Jika merasa masih ada hal yang belum jelas atau belum dimengerti dengan baik, maka bapak/Ibu dapat menanyakan atau minta penjelasan dengan saya : Eni Rahmawati di 08986611977. Atas perhatian dan kerjasamanya saya ucapkan terimakasih.


Purwokerto, November 2025

Peneliti, 
Eni Rahmawati
''';