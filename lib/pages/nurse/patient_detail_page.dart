import 'package:flutter/material.dart';
import '../../services/api_client.dart';

class PatientDetailPage extends StatefulWidget {
  const PatientDetailPage({super.key});

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage>
    with SingleTickerProviderStateMixin {
  final _api = ApiClient();

  late final String patientId;
  late final int initialTabIndex;
  bool _argsInited = false;

  TabController? _tabCtrl;

  bool _loadingDetail = true;
  bool _loadingLogbook = false;
  bool _loadingJournal = false;

  bool _isSyncingScores = false;

  String? _errorDetail;
  String? _errorLogbook;
  String? _errorJournal;

  Map<String, dynamic>? _detail;

  List<Map<String, dynamic>>? _logbooks;
  List<Map<String, dynamic>>? _journals;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsInited) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    String pid = '';
    int initIdx = 0;

    if (args is Map) {
      final m = args.cast<String, dynamic>();
      pid = (m['patientId'] as String?) ?? '';
      final tabStr = (m['tab'] as String?) ?? 'logbook';
      initIdx = switch (tabStr) {
        'logbook' => 0,
        'journal' => 1,
        'evaluasi' => 2,
        'scores' => 2,
        'profile' => 3,
        _ => 3,
      };
    } else if (args is String) {
      pid = args;
    }

    patientId = pid;
    initialTabIndex = initIdx;

    _tabCtrl = TabController(length: 4, vsync: this, initialIndex: initialTabIndex)
      ..addListener(() {
        if (_tabCtrl!.indexIsChanging) return;
        if (_tabCtrl!.index == 0) _loadLogbook();
        if (_tabCtrl!.index == 1) _loadJournal();
      });

    _argsInited = true;
    _loadDetail();
  }

  @override
  void dispose() {
    _tabCtrl?.dispose();
    super.dispose();
  }

  /* ======================== LOADERS ======================== */

  Future<void> _loadDetail() async {
    if (patientId.isEmpty) {
      setState(() {
        _loadingDetail = false;
        _errorDetail = 'ID pasien tidak tersedia';
      });
      return;
    }
    setState(() {
      _loadingDetail = true;
      _errorDetail = null;
    });

    try {
      final d = await _api.nurseGetPatientDetail(patientId);
      _detail = Map<String, dynamic>.from(d);
    } catch (_) {
      try {
        final list = await _api.nurseGetPatients();
        final found = list
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .firstWhere(
              (m) => ((m['id'] ?? m['userId'] ?? '').toString() == patientId),
          orElse: () => <String, dynamic>{},
        );
        _detail = found;
      } catch (e) {
        if (e is ApiError && e.status == 0) {
          _errorDetail = 'Tidak ada koneksi internet.';
        } else {
          _errorDetail = '$e';
        }
      }
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
      if (mounted && _tabCtrl != null) {
        if (_tabCtrl!.index == 0) _loadLogbook();
        if (_tabCtrl!.index == 1) _loadJournal();
      }
    }
  }

  Future<void> _loadLogbook() async {
    if (_loadingLogbook || _logbooks != null) return;
    if (patientId.isEmpty) return;
    setState(() {
      _loadingLogbook = true;
      _errorLogbook = null;
    });
    try {
      final items = await _api.nurseGetPatientLogbook(patientId);
      _logbooks = items.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (e) {
      if (e is ApiError && e.status == 0) {
        _errorLogbook = 'Tidak ada koneksi internet.';
      } else {
        _errorLogbook = '$e';
      }
    } finally {
      if (mounted) setState(() => _loadingLogbook = false);
    }
  }

  Future<void> _loadJournal() async {
    if (_loadingJournal || _journals != null) return;
    if (patientId.isEmpty) return;
    setState(() {
      _loadingJournal = true;
      _errorJournal = null;
    });
    try {
      final items = await _api.nurseGetPatientJournal(patientId);
      _journals = items.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (e) {
      if (e is ApiError && e.status == 0) {
        _errorJournal = 'Tidak ada koneksi internet.';
      } else {
        _errorJournal = '$e';
      }
    } finally {
      if (mounted) setState(() => _loadingJournal = false);
    }
  }

  Future<void> _syncAndRefreshScores() async {
    if (_isSyncingScores) return;

    setState(() => _isSyncingScores = true);

    try {
      await _api.nurseSyncScores();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sinkronisasi data Google Sheets berhasil!")),
      );
      await _loadDetail();

    } catch (e) {
      if (!mounted) return;
      String msg = "$e";
      if (e is ApiError && e.status == 0) {
        msg = "Gagal koneksi. Pastikan internet lancar.";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal Sync: $msg"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSyncingScores = false);
    }
  }

  Future<void> _unassign() async {
    if (patientId.isEmpty) return;
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Lepas Pasien?'),
          content: const Text('Pasien ini akan dihapus dari daftar binaan Anda.'),
          actions: [
            TextButton(onPressed: ()=>Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: ()=>Navigator.pop(ctx, true),
                child: const Text('Lepas')
            ),
          ],
        )
    ) ?? false;

    if (!ok) return;

    try {
      await _api.nurseUnassignPatient(patientId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      String msg = "$e";
      if (e is ApiError && e.status == 0) {
        msg = "Tidak ada koneksi internet. Gagal melepas pasien.";
      }

      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Gagal"),
            content: Text(msg),
            actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("OK"))],
          )
      );
    }
  }

  /* ======================== HELPERS ======================== */

  String _fmtDate(dynamic iso) {
    if (iso == null) return '-';
    try {
      final dt = iso is DateTime ? iso : DateTime.tryParse(iso.toString())?.toLocal();
      if (dt == null) return '-';
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    } catch (_) {
      return iso.toString();
    }
  }

  String _safeStr(dynamic v, [String fallback = '-']) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  int _safeInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  bool _safeBool(dynamic v, [bool def = false]) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return ['true', '1', 'ya'].contains(v.toLowerCase());
    return def;
  }

  Widget _sectionTitle(String s) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(
      s,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
  );

  /* ======================== BUILD ======================== */

  @override
  Widget build(BuildContext context) {
    if (_tabCtrl == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Pasien'),
        actions: [
          if (!_loadingDetail && _errorDetail == null)
            IconButton(
              icon: const Icon(Icons.person_remove, color: Colors.red),
              onPressed: _unassign,
              tooltip: "Lepas Pasien",
            )
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: false,

          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorSize: TabBarIndicatorSize.tab,

          onTap: (i) {
            if (_errorDetail != null || patientId.isEmpty) return;
            if (i == 0) _loadLogbook();
            if (i == 1) _loadJournal();
          },
          tabs: const [
            Tab(child: Text('Logbook', overflow: TextOverflow.ellipsis)),
            Tab(child: Text('Jurnal', overflow: TextOverflow.ellipsis)),
            Tab(child: Text('Evaluasi', overflow: TextOverflow.ellipsis)),
            Tab(child: Text('Data Ibu', overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: _loadingDetail
          ? const Center(child: CircularProgressIndicator())
          : (_errorDetail != null
          ? _ErrView(
        message: _errorDetail!,
        onRetry: _loadDetail,
      )
          : TabBarView(
        controller: _tabCtrl,
        children: [
          _buildLogbookTab(),
          _buildJournalTab(),
          _buildScoreTab(),
          _buildProfileTab(),
        ],
      )),
    );
  }

  /* ======================== TABS ======================== */

  Widget _buildLogbookTab() {
    if (_logbooks == null && !_loadingLogbook && _errorDetail == null && patientId.isNotEmpty) {
      _loadLogbook();
    }

    if (_loadingLogbook) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorLogbook != null) {
      return _ErrView(message: _errorLogbook!, onRetry: _loadLogbook);
    }
    final items = _logbooks ?? const <Map<String, dynamic>>[];

    if (items.isEmpty) {
      return const Center(child: Text('Belum ada isian logbook.'));
    }

    return RefreshIndicator(
      onRefresh: () async {
        _logbooks = null;
        await _loadLogbook();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final it = items[i];
          final date = _fmtDate(it['date']);
          final dur = it['durationMinutes'];
          final ok = _safeBool(it['coTargetMet']);
          final note = _safeStr(it['note'], '');

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(date, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _MiniPill('Durasi: ${dur ?? '-'} mnt'),
                      _MiniPill(ok ? 'Target tercapai' : 'Target belum'),
                    ],
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(note),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildJournalTab() {
    if (_journals == null && !_loadingJournal && _errorDetail == null && patientId.isNotEmpty) {
      _loadJournal();
    }

    if (_loadingJournal) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorJournal != null) {
      return _ErrView(message: _errorJournal!, onRetry: _loadJournal);
    }
    final items = _journals ?? const <Map<String, dynamic>>[];

    if (items.isEmpty) {
      return const Center(child: Text('Belum ada jurnal bayi.'));
    }

    return RefreshIndicator(
      onRefresh: () async {
        _journals = null;
        await _loadJournal();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final it = items[i];
          final date = _fmtDate(it['date']);
          final sum = _safeStr(it['summary'], '');

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            child: ListTile(
              title: Text(
                date,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              subtitle: sum.isEmpty ? null : Text(sum),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScoreTab() {
    final scoresRaw = (_detail?['evaluationScores'] as List?) ?? [];

    final scores = scoresRaw.map((e) => (e as Map).cast<String, dynamic>()).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Sinkronisasi Data", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("Tarik nilai terbaru dari Google Sheets", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              if (_isSyncingScores)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else
                FilledButton.icon(
                  onPressed: _syncAndRefreshScores,
                  icon: const Icon(Icons.sync),
                  label: const Text("Sync"),
                )
            ],
          ),
        ),

        Expanded(
          child: scores.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.assignment_outlined, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text("Belum ada data nilai evaluasi."),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: scores.length,
            itemBuilder: (context, index) {
              final item = scores[index];
              final label = _safeStr(item['label'], 'Evaluasi');
              final cat = _safeStr(item['category'], 'Umum');
              final val = _safeInt(item['score']);
              final date = _fmtDate(item['updatedAt'] ?? item['createdAt']);

              Color badgeColor = Colors.red;
              if (val >= 80) {
                badgeColor = Colors.green;
              } else if (val >= 60) {
                badgeColor = Colors.orange;
              }

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: badgeColor,
                    child: Text(
                      "$val",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("$cat • $date"),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTab() {
    final rootName = _safeStr(_detail?['name']);
    final email = _safeStr(_detail?['email']);
    final phone = _safeStr(_detail?['phone']);

    final prof = (_detail?['profile'] as Map?)?.cast<String, dynamic>() ?? {};
    final infant = (prof['infant'] as Map?)?.cast<String, dynamic>() ?? {};

    final age = _safeInt(prof['age']);
    final edu = _safeStr(prof['education']);
    final job = _safeStr(prof['job']);
    final parity = _safeInt(prof['parity']);
    final delivery = _safeStr(prof['delivery']);
    final gest = _safeInt(prof['gestationalWeeks']);
    final gender = _safeStr(prof['babyGender']);
    final weight = _safeInt(prof['birthWeight']);
    final addr = _safeStr(prof['address']);

    final mdx = _safeStr(infant['medicalDiagnosis']);
    final adm = _fmtDate(infant['admissionDate']);
    final finc = _fmtDate(infant['fincStart']);
    final dc = _fmtDate(infant['dischargeDate']);
    final w0 = _safeInt(infant['weightAtIntervention']);
    final w1 = _safeInt(infant['weightAtDischarge']);

    return RefreshIndicator(
      onRefresh: _loadDetail,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _sectionTitle('Identitas Ibu'),
          _InfoTile('Nama Lengkap', rootName),
          _InfoTile('Email', email),
          _InfoTile('No. WhatsApp', phone),
          _InfoTile('Usia (tahun)', age == 0 ? '-' : '$age'),
          _InfoTile('Pendidikan', edu),
          _InfoTile('Pekerjaan', job),
          _InfoTile('Alamat', addr),

          _sectionTitle('Riwayat Kehamilan'),
          _InfoTile('Paritas', parity == 0 ? '-' : '$parity'),
          _InfoTile('Jenis persalinan', delivery),
          _InfoTile('Usia kehamilan (minggu)', gest == 0 ? '-' : '$gest'),

          _sectionTitle('Identitas Bayi'),
          _InfoTile('Jenis kelamin', gender),
          _InfoTile('Berat lahir (gram)', weight == 0 ? '-' : '$weight'),
          _InfoTile('Diagnosis medis', mdx),
          _InfoTile('Tanggal masuk', adm),
          _InfoTile('Mulai FINC', finc),

          _sectionTitle('Perkembangan Berat Badan'),
          _InfoTile('BB Awal Intervensi', w0 == 0 ? '-' : '$w0 gram'),
          _InfoTile('BB Saat Pulang', w1 == 0 ? '-' : '$w1 gram'),
          _InfoTile('Tanggal Pulang', dc),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/* ======================== WIDGET KECIL ======================== */

class _ErrView extends StatelessWidget {
  final String message;
  final Future<void> Function()? onRetry;
  const _ErrView({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 16),
                ),
              ]
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ),
        ]
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).hintColor,
          fontSize: 13,
        ),
      ),
      subtitle: Text(value, style: const TextStyle(fontSize: 15)),
      dense: true,
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String text;
  const _MiniPill(this.text);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
    );
  }
}