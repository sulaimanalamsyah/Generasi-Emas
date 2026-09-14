import 'dart:async';
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
      final res = await _api.nurseSyncScores().timeout(
        const Duration(seconds: 25),
        onTimeout: () {
          return {'timeout': true, 'message': 'Proses sinkronisasi berjalan di latar belakang.'};
        },
      );

      if (!mounted) return;

      if (res['timeout'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sinkronisasi sedang diproses di server Google Sheets..."),
            backgroundColor: Color(0xFF0EA5E9),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sinkronisasi data Google Sheets berhasil!"),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
      await _loadDetail();
    } catch (e) {
      if (!mounted) return;
      String msg = "$e";
      if (e is ApiError && e.status == 0) {
        msg = "Gagal koneksi. Pastikan internet lancar.";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal Sync: $msg"),
          backgroundColor: const Color(0xFFEF4444),
        ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Lepas Pasien?',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        content: const Text(
          'Pasien ini akan dihapus dari daftar binaan Anda.',
          style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lepas', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Gagal", style: TextStyle(fontFamily: 'Nunito', color: Color(0xFFEF4444))),
          content: Text(msg, style: const TextStyle(fontFamily: 'Inter')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("OK", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
            ),
          ],
        ),
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

  Widget _buildPatientHeaderCard() {
    final rootName = _safeStr(_detail?['name'], 'Ibu');
    final phone = _safeStr(_detail?['phone'], '');
    final prof = (_detail?['profile'] as Map?)?.cast<String, dynamic>() ?? {};
    final infant = (prof['infant'] as Map?)?.cast<String, dynamic>() ?? {};

    String babyName = _safeStr(_detail?['infantName'], '');
    if (babyName.isEmpty || babyName == '-') {
      babyName = _safeStr(prof['babyName'], '');
    }
    if (babyName.isEmpty || babyName == '-') {
      babyName = _safeStr(infant['name'], 'Bayi');
    }

    final mdx = _safeStr(infant['medicalDiagnosis'], '');
    final isDone = infant['dischargeDate'] != null && infant['dischargeDate'].toString().trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar Circle
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    babyName.isNotEmpty ? babyName[0].toUpperCase() : 'B',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Patient Header Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rootName,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.child_care_rounded, size: 13, color: Color(0xFF072846)),
                          const SizedBox(width: 4),
                          Text(
                            babyName,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF072846),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Treatment Status Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDone ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isDone ? 'Selesai' : 'Perawatan',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDone ? const Color(0xFF78350F) : const Color(0xFF064E3B),
                  ),
                ),
              ),
            ],
          ),
          if (phone.isNotEmpty || mdx.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: Color(0xFFF1F5F9), height: 1),
            ),
            Row(
              children: [
                if (phone.isNotEmpty) ...[
                  const Icon(Icons.phone_android_rounded, size: 14, color: Color(0xFF475569)),
                  const SizedBox(width: 4),
                  Text(
                    phone,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF475569)),
                  ),
                  const SizedBox(width: 14),
                ],
                if (mdx.isNotEmpty) ...[
                  const Icon(Icons.medical_information_rounded, size: 14, color: Color(0xFF0EA5E9)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      mdx,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF0EA5E9)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  /* ======================== BUILD ======================== */

  @override
  Widget build(BuildContext context) {
    if (_tabCtrl == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detail Pasien',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          if (!_loadingDetail && _errorDetail == null)
            IconButton(
              icon: const Icon(Icons.person_remove_rounded, color: Color(0xFFEF4444)),
              onPressed: _unassign,
              tooltip: "Lepas Pasien",
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!_loadingDetail && _errorDetail == null && _detail != null)
              _buildPatientHeaderCard(),

            // TabBar Container
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TabBar(
                controller: _tabCtrl,
                isScrollable: false,
                indicatorColor: const Color(0xFF10B981),
                labelColor: const Color(0xFF10B981),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 13),
                onTap: (i) {
                  if (_errorDetail != null || patientId.isEmpty) return;
                  if (i == 0) _loadLogbook();
                  if (i == 1) _loadJournal();
                },
                tabs: const [
                  Tab(text: 'Logbook'),
                  Tab(text: 'Jurnal'),
                  Tab(text: 'Evaluasi'),
                  Tab(text: 'Data Ibu'),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: _loadingDetail
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
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
            ),
          ],
        ),
      ),
    );
  }

  /* ======================== TABS ======================== */

  Widget _buildLogbookTab() {
    if (_logbooks == null && !_loadingLogbook && _errorDetail == null && patientId.isNotEmpty) {
      _loadLogbook();
    }

    if (_loadingLogbook) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
    }
    if (_errorLogbook != null) {
      return _ErrView(message: _errorLogbook!, onRetry: _loadLogbook);
    }
    final items = _logbooks ?? const <Map<String, dynamic>>[];

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.edit_note_rounded, size: 48, color: Color(0xFF94A3B8)),
              SizedBox(height: 12),
              Text(
                'Belum Ada Isian Logbook',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _logbooks = null;
        await _loadLogbook();
      },
      color: const Color(0xFF10B981),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final it = items[i];
          final date = _fmtDate(it['date']);
          final dur = it['durationMinutes'];
          final ok = _safeBool(it['coTargetMet']);
          final note = _safeStr(it['note'], '');

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(color: Color(0x0F0F172A), blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        date,
                        style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0F172A)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: ok ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ok ? 'Target Tercapai' : 'Target Belum',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: ok ? const Color(0xFF064E3B) : const Color(0xFF78350F),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Durasi: ${dur ?? '-'} menit',
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF475569)),
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      note,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF0F172A)),
                    ),
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
      return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
    }
    if (_errorJournal != null) {
      return _ErrView(message: _errorJournal!, onRetry: _loadJournal);
    }
    final items = _journals ?? const <Map<String, dynamic>>[];

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.menu_book_rounded, size: 48, color: Color(0xFF94A3B8)),
              SizedBox(height: 12),
              Text(
                'Belum Ada Jurnal Bayi',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _journals = null;
        await _loadJournal();
      },
      color: const Color(0xFF10B981),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final it = items[i];
          final date = _fmtDate(it['date']);
          final sum = _safeStr(it['summary'], '');

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(color: Color(0x0F0F172A), blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0F172A)),
                  ),
                  if (sum.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      sum,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF475569)),
                    ),
                  ],
                ],
              ),
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
        // Sync Header Box
        Container(
          margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(color: Color(0x0F0F172A), blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Sinkronisasi Data Evaluasi",
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Tarik nilai terbaru dari Google Sheets",
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSyncingScores ? null : _syncAndRefreshScores,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  icon: _isSyncingScores
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded, size: 18),
                  label: const Text('Sync', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: scores.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.assignment_outlined, size: 48, color: Color(0xFF94A3B8)),
                        SizedBox(height: 12),
                        Text(
                          "Belum Ada Data Nilai Evaluasi",
                          style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  itemCount: scores.length,
                  itemBuilder: (context, index) {
                    final item = scores[index];
                    final label = _safeStr(item['label'], 'Evaluasi');
                    final cat = _safeStr(item['category'], 'Umum');
                    final val = _safeInt(item['score']);
                    final date = _fmtDate(item['updatedAt'] ?? item['createdAt']);

                    Color bgPill = const Color(0xFFFEE2E2);
                    Color fgPill = const Color(0xFF991B1B);

                    if (val >= 80) {
                      bgPill = const Color(0xFFD1FAE5);
                      fgPill = const Color(0xFF064E3B);
                    } else if (val >= 60) {
                      bgPill = const Color(0xFFFEF3C7);
                      fgPill = const Color(0xFF78350F);
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x0F0F172A), blurRadius: 8, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Score Circle Pill
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: bgPill,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  "$val",
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: fgPill,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Score Label & Category
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    style: const TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "$cat • $date",
                                    style: const TextStyle(
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
      color: const Color(0xFF10B981),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          _ProfileSectionCard(
            title: 'Identitas Ibu',
            tiles: [
              _InfoTile('Nama Lengkap', rootName),
              _InfoTile('Email', email),
              _InfoTile('No. WhatsApp', phone),
              _InfoTile('Usia', age == 0 ? '-' : '$age tahun'),
              _InfoTile('Pendidikan', edu),
              _InfoTile('Pekerjaan', job),
              _InfoTile('Alamat', addr),
            ],
          ),
          const SizedBox(height: 12),
          _ProfileSectionCard(
            title: 'Riwayat Kehamilan',
            tiles: [
              _InfoTile('Paritas', parity == 0 ? '-' : '$parity'),
              _InfoTile('Jenis Persalinan', delivery),
              _InfoTile('Usia Kehamilan', gest == 0 ? '-' : '$gest minggu'),
            ],
          ),
          const SizedBox(height: 12),
          _ProfileSectionCard(
            title: 'Identitas Bayi',
            tiles: [
              _InfoTile('Jenis Kelamin', gender),
              _InfoTile('Berat Lahir', weight == 0 ? '-' : '$weight gram'),
              _InfoTile('Diagnosis Medis', mdx),
              _InfoTile('Tanggal Masuk', adm),
              _InfoTile('Mulai FINC', finc),
            ],
          ),
          const SizedBox(height: 12),
          _ProfileSectionCard(
            title: 'Perkembangan Berat Badan',
            tiles: [
              _InfoTile('BB Awal Intervensi', w0 == 0 ? '-' : '$w0 gram'),
              _InfoTile('BB Saat Pulang', w1 == 0 ? '-' : '$w1 gram'),
              _InfoTile('Tanggal Pulang', dc),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/* ======================== WIDGET KECIL ======================== */

class _ProfileSectionCard extends StatelessWidget {
  final String title;
  final List<Widget> tiles;
  const _ProfileSectionCard({required this.title, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0F0F172A), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: tiles),
          ),
        ],
      ),
    );
  }
}

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
              const Icon(Icons.wifi_off_rounded, size: 56, color: Color(0xFF94A3B8)),
              const SizedBox(height: 16),
              const Text(
                'Gagal Memuat Data',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFFEF4444)),
              ),
            ],
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              color: Color(0xFF64748B),
              fontSize: 13,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}