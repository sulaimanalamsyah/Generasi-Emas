import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../../services/api_client.dart';
import '../../routes.dart';
import '../../core/age_calculator.dart';
import '../../core/date_formatter.dart';
import '../../core/storage.dart';
import '../../core/weight_formatter.dart';
import '../../widgets/common.dart';

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

  DateTime? _fincStartLocal;
  final Map<int, Map<String, dynamic>> _entriesByDayIndex = {};
  final List<Map<String, dynamic>> _orphanEntries = [];
  String _selectedLogbookFilter = 'ALL'; // 'ALL', 'FILLED', 'UNFILLED'

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
        if (_tabCtrl!.index == 0) _loadLogbook(force: true);
        if (_tabCtrl!.index == 1) _loadJournal(force: true);
      });

    _argsInited = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadDetail();
    });
  }

  @override
  void dispose() {
    _tabCtrl?.dispose();
    super.dispose();
  }

  /* ======================== LOADERS ======================== */

  String get _detailCacheKey => 'nurse_patient_detail_v1_$patientId';

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
      await Prefs.setCachedJson(_detailCacheKey, _detail!);
    } catch (e) {
      var loadedFallback = false;
      if (e is! ApiError || e.status != 0) {
        try {
          final list = await _api.nurseGetPatients();
          final found = list
              .whereType<Map>()
              .map((m) => m.cast<String, dynamic>())
              .firstWhere(
                (m) => ((m['id'] ?? m['userId'] ?? '').toString() == patientId),
            orElse: () => <String, dynamic>{},
          );
          if (found.isNotEmpty) {
            _detail = found;
            loadedFallback = true;
          }
        } catch (_) {}
      }
      if (!loadedFallback) {
        final cached = await Prefs.getCachedJson(_detailCacheKey);
        if (cached is Map) {
          _detail = Map<String, dynamic>.from(cached);
          if (mounted) {
            showAppSnackBar(
              context,
              message: 'Menampilkan detail pasien tersimpan (mode luring).',
            );
          }
        } else if (e is ApiError && e.status == 0) {
          _errorDetail = 'Tidak ada koneksi internet.';
        } else {
          _errorDetail = '$e';
        }
      }
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
      if (mounted && _tabCtrl != null) {
        if (_tabCtrl!.index == 0) _loadLogbook(force: true);
        if (_tabCtrl!.index == 1) _loadJournal(force: true);
      }
    }
  }

  Future<void> _loadLogbook({bool force = false}) async {
    if (_loadingLogbook || (!force && _logbooks != null)) return;
    if (patientId.isEmpty) return;
    setState(() {
      _loadingLogbook = true;
      _errorLogbook = null;
    });
    try {
      final res = await _api.nurseGetPatientLogbook(patientId);
      final rawItems = (res['items'] as List?) ?? [];
      final items = rawItems.map((e) => (e as Map).cast<String, dynamic>()).toList();
      _logbooks = items;

      final fincRaw = res['fincStart'] ??
          _detail?['profile']?['infant']?['fincStart'] ??
          _detail?['fincStart'];
      _fincStartLocal = ApiClient.parseDate(fincRaw);

      _entriesByDayIndex.clear();
      _orphanEntries.clear();

      for (final m in items) {
        final idx = m['dayIndex'];
        if (idx is int && idx >= 1 && idx <= 14) {
          _entriesByDayIndex[idx] = m;
        } else if (_fincStartLocal != null) {
          final dateLog = ApiClient.parseDate(m['date']);
          if (dateLog != null) {
            final diff = DateTime(dateLog.year, dateLog.month, dateLog.day)
                    .difference(DateTime(_fincStartLocal!.year, _fincStartLocal!.month, _fincStartLocal!.day))
                    .inDays +
                1;
            if (diff >= 1 && diff <= 14) {
              _entriesByDayIndex[diff] = m;
            } else {
              _orphanEntries.add(m);
            }
          } else {
            _orphanEntries.add(m);
          }
        } else {
          _orphanEntries.add(m);
        }
      }
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

  Future<void> _loadJournal({bool force = false}) async {
    if (_loadingJournal || (!force && _journals != null)) return;
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
      final res = await _api.nurseSyncScores(patientId: patientId).timeout(
        const Duration(seconds: 35),
        onTimeout: () {
          return {'timeout': true, 'message': 'Proses sinkronisasi berjalan di latar belakang.'};
        },
      );

      if (!mounted) return;

      if (res['timeout'] == true) {
        showAppSnackBar(
          context,
          message: "Sinkronisasi sedang diproses di server Google Sheets...",
        );
      } else {
        showAppSnackBar(
          context,
          message: "Sinkronisasi data Google Sheets berhasil!",
        );
      }
      await _loadDetail();
    } catch (e) {
      if (!mounted) return;
      String msg = "$e";
      if (e is ApiError && e.status == 0) {
        msg = "Gagal koneksi. Pastikan internet lancar.";
      }
      showAppSnackBar(context, message: "Gagal Sync: $msg", isError: true);
    } finally {
      if (mounted) setState(() => _isSyncingScores = false);
    }
  }

  Future<void> _unassign() async {
    if (patientId.isEmpty) return;
    final ok = await showAppConfirmDialog(
      context,
      title: 'Lepas Pasien?',
      message: 'Pasien ini akan dihapus dari daftar binaan Anda.',
      confirmLabel: 'Lepas',
      isDestructive: true,
    );

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

      showAppInfoDialog(context, title: "Gagal", message: msg, isError: true);
    }
  }

  /* ======================== HELPERS ======================== */

  static const _indoMonths = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  String _fmtGender(dynamic g) {
    if (g == null) return '-';
    final s = g.toString().trim().toUpperCase();
    if (s == 'LAKI_LAKI' || s == 'L' || s == 'LAKI-LAKI') return 'Laki-laki';
    if (s == 'PEREMPUAN' || s == 'P') return 'Perempuan';
    return s.isEmpty ? '-' : s;
  }

  String _fmtDateIndo(dynamic iso) {
    if (iso == null) return '-';
    try {
      final dt = iso is DateTime ? iso : DateTime.tryParse(iso.toString())?.toLocal();
      if (dt == null) return '-';
      final day = dt.day;
      final month = _indoMonths[dt.month - 1];
      final year = dt.year;
      return '$day $month $year';
    } catch (_) {
      return '-';
    }
  }

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

  static const _indoDays = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

  String _fmtDateFull(DateTime dt) {
    final dName = _indoDays[(dt.weekday - 1).clamp(0, 6)];
    final mName = _indoMonths[(dt.month - 1).clamp(0, 11)];
    return '$dName, ${dt.day} $mName ${dt.year}';
  }

  String _fmtDateShort(DateTime dt) {
    final mName = _indoMonths[(dt.month - 1).clamp(0, 11)];
    final shortMonth = mName.length > 3 ? mName.substring(0, 3) : mName;
    return '${dt.day} $shortMonth';
  }

  String? _parseAttendance(dynamic rawNote) {
    if (rawNote == null) return null;
    final m = RegExp(r'^\[ATTENDANCE:(YES|NO)\]', caseSensitive: false).firstMatch(rawNote.toString());
    if (m != null) {
      return m.group(1)?.toUpperCase() == 'YES' ? 'Hadir' : 'Tidak Hadir';
    }
    return null;
  }

  String _cleanNote(dynamic rawNote) {
    if (rawNote == null) return '';
    return rawNote.toString().replaceAll(RegExp(r'^\[ATTENDANCE:(YES|NO)\]\s*', caseSensitive: false), '').trim();
  }

  Widget _buildMetricTile(IconData icon, String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
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

    final rawGender = (prof['babyGender'] ??
            prof['gender'] ??
            infant['babyGender'] ??
            infant['gender'] ??
            _detail?['babyGender'] ??
            _detail?['gender'] ??
            '')
        .toString()
        .trim()
        .toUpperCase();
    final isFemale = rawGender == 'PEREMPUAN' || rawGender == 'P';

    final avatarBg = isFemale ? const Color(0xFFFCE7F3) : const Color(0xFFE0F2FE);
    final avatarFg = isFemale ? const Color(0xFFDB2777) : const Color(0xFF0284C7);
    final pillBg = isFemale ? const Color(0xFFFCE7F3) : const Color(0xFFE0F2FE);
    final pillFg = isFemale ? const Color(0xFFBE185D) : const Color(0xFF0369A1);

    String babyAgeStr = '';
    if (infant['birthDate'] != null) {
      try {
        final bDate = infant['birthDate'] is DateTime
            ? infant['birthDate'] as DateTime
            : DateTime.tryParse(infant['birthDate'].toString())?.toLocal();
        if (bDate != null) {
          babyAgeStr = InfantAge.calculate(bDate).formatted;
        }
      } catch (_) {}
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
                  color: avatarBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    babyName.isNotEmpty ? babyName[0].toUpperCase() : 'B',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: avatarFg,
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
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: pillBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.child_care_rounded, size: 13, color: pillFg),
                              const SizedBox(width: 4),
                              Text(
                                babyName,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: pillFg,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (babyAgeStr.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF065F46)),
                                const SizedBox(width: 4),
                                Text(
                                  babyAgeStr,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF065F46),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
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
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final targetId = infant['id']?.toString() ?? patientId;
                  Navigator.pushNamed(context, Routes.infantAnalytics, arguments: {'infantId': targetId});
                },
                icon: const Icon(Icons.insights_rounded, size: 18, color: Color(0xFF10B981)),
                label: const Text(
                  'Buka Dasbor Analitik & Grafik WHO',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF10B981)),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  side: const BorderSide(color: Color(0xFFA7F3D0)),
                  backgroundColor: const Color(0xFFF0FDF4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
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
      appBar: enicareAppBar(
        context,
        title: 'Detail Pasien',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
            tooltip: 'Perbarui Data',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: (_loadingDetail || _loadingLogbook || _loadingJournal)
                ? null
                : () async {
                    await Future.wait([
                      _loadDetail(),
                      _loadLogbook(force: true),
                      _loadJournal(force: true),
                    ]);
                  },
          ),
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
        top: false,
        child: _loadingDetail
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
            : (_errorDetail != null
                ? _ErrView(
                    message: _errorDetail!,
                    onRetry: _loadDetail,
                  )
                : Builder(
                    builder: (innerCtx) {
                      final scaledFont = MediaQuery.textScalerOf(innerCtx).scale(13);
                      final tabHeight = (scaledFont * 2.4 + 36).clamp(62.0, 112.0);
                      return NestedScrollView(
                        headerSliverBuilder: (context, innerBoxIsScrolled) => [
                          if (_detail != null)
                            SliverToBoxAdapter(child: _buildPatientHeaderCard()),
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _TabBarHeaderDelegate(
                              height: tabHeight,
                              child: Container(
                                margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: TabBar(
                                  controller: _tabCtrl,
                                  isScrollable: true,
                                  tabAlignment: TabAlignment.start,
                                  indicatorColor: const Color(0xFF10B981),
                                  labelColor: const Color(0xFF10B981),
                                  unselectedLabelColor: const Color(0xFF64748B),
                                  labelStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13),
                                  unselectedLabelStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 13),
                                  onTap: (i) {
                                    if (_errorDetail != null || patientId.isEmpty) return;
                                    if (i == 0) _loadLogbook(force: true);
                                    if (i == 1) _loadJournal(force: true);
                                  },
                                  tabs: const [
                                    Tab(text: 'Logbook'),
                                    Tab(text: 'Jurnal'),
                                    Tab(text: 'Evaluasi'),
                                    Tab(text: 'Data Ibu'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        body: TabBarView(
                          controller: _tabCtrl,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildLogbookTab(),
                            _buildJournalTab(),
                            _buildScoreTab(),
                            _buildProfileTab(),
                          ],
                        ),
                      );
                    },
                  )),
      ),
    );
  }

  /* ======================== TABS ======================== */

  Widget _buildLogbookTab() {
    if (_loadingLogbook) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
    }
    if (_errorLogbook != null) {
      return _ErrView(message: _errorLogbook!, onRetry: _loadLogbook);
    }

    final items = _logbooks ?? const <Map<String, dynamic>>[];

    if (_fincStartLocal == null) {
      return RefreshIndicator(
        onRefresh: () => _loadLogbook(force: true),
        color: const Color(0xFF10B981),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jadwal FINC Belum Dimulai',
                          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF78350F)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Ibu belum mengatur tanggal mulai program I-FINC pada profil bayi.',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF92400E)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.35,
                child: const Center(
                  child: Text(
                    'Belum Ada Isian Logbook',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                ),
              )
            else
              ...items.map((it) {
                final dt = ApiClient.parseDate(it['date']);
                final dateStr = dt != null ? _fmtDateFull(dt) : _fmtDate(it['date']);
                final dur = it['durationMinutes'];
                final ok = _safeBool(it['coTargetMet']);
                final rawNote = it['note']?.toString();
                final att = _parseAttendance(rawNote);
                final note = _cleanNote(rawNote);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              dateStr,
                              style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: ok ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              ok ? 'Target: ✓' : 'Target: ×',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: ok ? const Color(0xFF064E3B) : const Color(0xFF991B1B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (dur != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$dur menit',
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                              ),
                            ),
                          if (att != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: att == 'Hadir' ? const Color(0xFFE0F2FE) : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                att,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: att == 'Hadir' ? const Color(0xFF0369A1) : const Color(0xFF991B1B),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          note,
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      );
    }

    // When _fincStartLocal != null: 14-Day I-FINC Matrix and Progress
    final start = DateTime(_fincStartLocal!.year, _fincStartLocal!.month, _fincStartLocal!.day);
    final programDays = List.generate(14, (i) => start.add(Duration(days: i)));
    final completedCount = _entriesByDayIndex.keys.where((k) => k >= 1 && k <= 14).length;
    final unfilledCount = (14 - completedCount).clamp(0, 14);
    final totalDuration = _entriesByDayIndex.entries
        .where((e) => e.key >= 1 && e.key <= 14)
        .fold(0, (sum, e) => sum + ((e.value['durationMinutes'] as int?) ?? 0));
    final targetMetCount = _entriesByDayIndex.entries
        .where((e) => e.key >= 1 && e.key <= 14 && e.value['coTargetMet'] == true)
        .length;
    final percentage = (completedCount / 14 * 100).round();
    final dateRangeStr = '${_fmtDateShort(programDays.first)} – ${_fmtDateShort(programDays.last)} ${programDays.last.year}';

    // Filter day indices (1..14)
    final filteredDayIndices = <int>[];
    for (int i = 1; i <= 14; i++) {
      final isFilled = _entriesByDayIndex.containsKey(i);
      if (_selectedLogbookFilter == 'FILLED' && !isFilled) continue;
      if (_selectedLogbookFilter == 'UNFILLED' && isFilled) continue;
      filteredDayIndices.add(i);
    }

    return RefreshIndicator(
      onRefresh: () => _loadLogbook(force: true),
      color: const Color(0xFF10B981),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // 1. Progres Program I-FINC Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(color: Color(0x080F172A), blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_graph_rounded, color: Color(0xFF10B981), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Progres Program I-FINC',
                            style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateRangeStr,
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$percentage%',
                        style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF065F46)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: completedCount / 14,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 14),
                Builder(
                  builder: (mCtx) {
                    final isLargeText = MediaQuery.textScalerOf(mCtx).scale(14) > 18;
                    if (isLargeText) {
                      return Column(
                        children: [
                          _buildMetricTile(Icons.calendar_today_rounded, '$completedCount / 14', 'Hari Terisi', const Color(0xFF10B981)),
                          const Divider(height: 16, color: Color(0xFFE2E8F0)),
                          _buildMetricTile(Icons.schedule_rounded, '$totalDuration mnt', 'Total Durasi', const Color(0xFF0EA5E9)),
                          const Divider(height: 16, color: Color(0xFFE2E8F0)),
                          _buildMetricTile(Icons.check_circle_outline_rounded, '$targetMetCount Hari', 'Target CO', const Color(0xFFF59E0B)),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: _buildMetricTile(Icons.calendar_today_rounded, '$completedCount / 14', 'Hari Terisi', const Color(0xFF10B981))),
                        Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                        Expanded(child: _buildMetricTile(Icons.schedule_rounded, '$totalDuration mnt', 'Total Durasi', const Color(0xFF0EA5E9))),
                        Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                        Expanded(child: _buildMetricTile(Icons.check_circle_outline_rounded, '$targetMetCount Hari', 'Target CO', const Color(0xFFF59E0B))),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Matriks 14 Hari Perawatan Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Matriks 14 Hari Perawatan',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 10),
                Builder(
                  builder: (gridCtx) {
                    final fontFactor = MediaQuery.textScalerOf(gridCtx).scale(11) / 11.0;
                    final crossAxisCount = fontFactor > 1.55 ? 5 : 7;
                    return GridView.builder(
                      primary: false,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                        childAspectRatio: fontFactor > 1.55 ? 1.0 : 1.15,
                      ),
                      itemCount: 14,
                      itemBuilder: (_, idx) {
                        final dIdx = idx + 1;
                        final isFilled = _entriesByDayIndex.containsKey(dIdx);
                        return Container(
                          decoration: BoxDecoration(
                            color: isFilled ? const Color(0xFF10B981) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'H$dIdx',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isFilled ? Colors.white : const Color(0xFF991B1B),
                                ),
                              ),
                              Icon(
                                isFilled ? Icons.check_rounded : Icons.close_rounded,
                                size: 11,
                                color: isFilled ? Colors.white : const Color(0xFF991B1B),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 3. Status Filter Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Semua (14)', 'ALL'),
                const SizedBox(width: 8),
                _buildFilterChip('Sudah Diisi ($completedCount)', 'FILLED'),
                const SizedBox(width: 8),
                _buildFilterChip('Belum Diisi ($unfilledCount)', 'UNFILLED'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 4. Timeline Cards
          if (filteredDayIndices.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Text(
                  'Tidak ada hari yang sesuai filter.',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                ),
              ),
            )
          else
            ...filteredDayIndices.map((dayIndex) {
              final dayDate = programDays[dayIndex - 1];
              final dateStr = _fmtDateFull(dayDate);
              final entry = _entriesByDayIndex[dayIndex];
              final isFilled = entry != null;

              final dur = entry?['durationMinutes'];
              final ok = _safeBool(entry?['coTargetMet']);
              final rawNote = entry?['note']?.toString();
              final att = _parseAttendance(rawNote);
              final note = _cleanNote(rawNote);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isFilled ? const Color(0xFFE2E8F0) : const Color(0xFFFECDD3),
                    width: isFilled ? 1 : 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x060F172A), blurRadius: 6, offset: Offset(0, 2)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: isFilled ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                          width: 4,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Hari ke-$dayIndex',
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isFilled ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isFilled ? 'Sudah diisi' : 'Belum diisi',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isFilled ? const Color(0xFF064E3B) : const Color(0xFF991B1B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        if (isFilled) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (dur != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$dur menit',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: ok ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  ok ? 'Target: ✓' : 'Target: ×',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: ok ? const Color(0xFF064E3B) : const Color(0xFF991B1B),
                                  ),
                                ),
                              ),
                              if (att != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: att == 'Hadir' ? const Color(0xFFE0F2FE) : const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    att,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: att == 'Hadir' ? const Color(0xFF0369A1) : const Color(0xFF991B1B),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (note.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFF1F5F9)),
                              ),
                              child: Text(
                                note,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ] else ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Pasien belum mengisi logbook untuk hari ini.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),

          // 5. Orphan Entries (Out of 14-day Window)
          if (_orphanEntries.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_toggle_off_rounded, size: 18, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Catatan di Luar Jadwal I-FINC (${_orphanEntries.length})',
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Entri berikut dicatat sebelum/setelah rentang 14 hari program (misal sebelum tanggal mulai FINC diubah):',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  ..._orphanEntries.map((it) {
                    final dt = ApiClient.parseDate(it['date']);
                    final dateStr = dt != null ? _fmtDateFull(dt) : _fmtDate(it['date']);
                    final dur = it['durationMinutes'];
                    final ok = _safeBool(it['coTargetMet']);
                    final rawNote = it['note']?.toString();
                    final att = _parseAttendance(rawNote);
                    final note = _cleanNote(rawNote);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  dateStr,
                                  style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ok ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  ok ? 'Target: ✓' : 'Target: ×',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: ok ? const Color(0xFF064E3B) : const Color(0xFF991B1B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (dur != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$dur mnt',
                                    style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                  ),
                                ),
                              if (att != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: att == 'Hadir' ? const Color(0xFFE0F2FE) : const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    att,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: att == 'Hadir' ? const Color(0xFF0369A1) : const Color(0xFF991B1B),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (note.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              note,
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF334155)),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedLogbookFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedLogbookFilter = value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF10B981) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJournalTab() {
    if (_loadingJournal) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
    }
    if (_errorJournal != null) {
      return _ErrView(message: _errorJournal!, onRetry: _loadJournal);
    }
    final items = _journals ?? const <Map<String, dynamic>>[];

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadJournal(force: true),
        color: const Color(0xFF10B981),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.45,
              child: Center(
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
                      SizedBox(height: 6),
                      Text(
                        'Tarik ke bawah untuk memuat ulang',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadJournal(force: true),
      color: const Color(0xFF10B981),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemCount: items.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Total: ${items.length} Catatan Jurnal',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final it = items[i - 1];
          final dt = ApiClient.parseDate(it['date']);
          final dateStr = dt != null ? _fmtDateFull(dt) : _fmtDate(it['date']);
          final sum = _safeStr(it['summary'], '');

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(color: Color(0x060F172A), blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.menu_book_rounded, size: 16, color: Color(0xFF0EA5E9)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          dateStr,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (sum.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      sum,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: Color(0xFF334155),
                        height: 1.4,
                      ),
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
    final isLargeText = MediaQuery.textScalerOf(context).scale(14) > 18;

    final syncTextColumn = Column(
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
    );

    final syncButton = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: ElevatedButton.icon(
        onPressed: _isSyncingScores ? null : _syncAndRefreshScores,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
    );

    final syncCard = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0F0F172A), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: isLargeText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                syncTextColumn,
                const SizedBox(height: 12),
                syncButton,
              ],
            )
          : Row(
              children: [
                Expanded(child: syncTextColumn),
                const SizedBox(width: 12),
                syncButton,
              ],
            ),
    );

    return RefreshIndicator(
      color: const Color(0xFF10B981),
      onRefresh: () async => _loadDetail(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: scores.isEmpty ? 2 : scores.length + 1,
        itemBuilder: (context, rawIdx) {
          if (rawIdx == 0) return syncCard;
          if (scores.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined, size: 48, color: Color(0xFF94A3B8)),
                  SizedBox(height: 12),
                  Text(
                    "Belum Ada Data Nilai Evaluasi",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
            );
          }
          final item = scores[rawIdx - 1];
                    final label = _safeStr(item['label'], 'Evaluasi');
                    final cat = _safeStr(item['category'], 'Umum');
                    final rawScore = item['score'];
                    final scoreNum = num.tryParse('${rawScore ?? ''}');
                    final scoreStr = rawScore != null ? AppDateFormatter.score(rawScore) : '-';
                    final date = _fmtDate(item['updatedAt'] ?? item['createdAt']);

                    Color bgPill = const Color(0xFFFEE2E2);
                    Color fgPill = const Color(0xFF991B1B);

                    if ((scoreNum ?? 0) >= 80) {
                      bgPill = const Color(0xFFD1FAE5);
                      fgPill = const Color(0xFF064E3B);
                    } else if ((scoreNum ?? 0) >= 60) {
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
                              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: bgPill,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  scoreStr,
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
    );
  }

  Widget _buildProfileTab() {
    final rootName = _safeStr(_detail?['name']);
    final phone = _safeStr(_detail?['phone']);

    final prof = (_detail?['profile'] as Map?)?.cast<String, dynamic>() ?? {};
    final infant = (prof['infant'] as Map?)?.cast<String, dynamic>() ?? {};

    final age = _safeInt(prof['age']);
    final edu = _safeStr(prof['education']);
    final job = _safeStr(prof['job']);
    final parity = _safeInt(prof['parity']);
    final delivery = _safeStr(prof['delivery']);
    final gest = _safeInt(prof['gestationalWeeks']);
    final gender = _fmtGender(prof['babyGender']);
    final weight = _safeInt(infant['birthWeight'] ?? prof['birthWeight']);
    final addr = _safeStr(prof['address']);

    final mdx = _safeStr(infant['medicalDiagnosis']);
    final adm = _fmtDate(infant['admissionDate']);
    final finc = _fmtDate(infant['fincStart']);
    final dc = _fmtDate(infant['dischargeDate']);
    final w0 = _safeInt(infant['weightAtIntervention']);
    final w1 = _safeInt(infant['weightAtDischarge']);

    String babyName = _safeStr(_detail?['infantName'], '');
    if (babyName.isEmpty || babyName == '-') {
      babyName = _safeStr(prof['babyName'], '');
    }
    if (babyName.isEmpty || babyName == '-') {
      babyName = _safeStr(infant['name'], '-');
    }

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
              _InfoTile('No. WhatsApp', phone),
              _InfoTile('Usia', age == 0 ? '-' : '$age tahun'),
              _InfoTile('Pendidikan', edu.isEmpty || edu == '-' ? '-' : (edu == 'PT' ? 'Perguruan Tinggi' : edu)),
              _InfoTile('Pekerjaan', job.isEmpty || job == '-' ? '-' : (job == 'LAINNYA' ? 'Lainnya' : job)),
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
              _InfoTile('Nama Bayi', babyName.isNotEmpty && babyName != '-' ? babyName : '-'),
              _InfoTile('Tanggal Lahir Bayi', _fmtDateIndo(infant['birthDate'])),
              _InfoTile('Jenis Kelamin', gender),
              _InfoTile('Berat Lahir', WeightFormatter.formatGrams(weight)),
              _InfoTile('Diagnosis Medis', mdx),
              _InfoTile('Tanggal Masuk', adm),
              _InfoTile('Mulai FINC', finc),
            ],
          ),
          const SizedBox(height: 12),
          _ProfileSectionCard(
            title: 'Perkembangan Berat Badan',
            tiles: [
              _InfoTile('Berat Saat Lahir', WeightFormatter.formatGrams(weight)),
              _InfoTile('BB Awal Intervensi', WeightFormatter.formatGrams(w0)),
              _InfoTile('BB Saat Pulang', WeightFormatter.formatGrams(w1)),
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
    final v = value.trim();
    final displayValue = (v.isEmpty || v == 'null' || v == 'Belum diisi') ? '-' : v;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFF64748B),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              displayValue,
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

class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  const _TabBarHeaderDelegate({
    required this.height,
    required this.child,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFFF8FAFC),
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}