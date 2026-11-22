import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';
import '../routes.dart';
import '../core/storage.dart';
import '../widgets/common.dart';

class LogbookPage extends StatefulWidget {
  const LogbookPage({super.key});

  @override
  State<LogbookPage> createState() => _LogbookPageState();
}

class _LogbookPageState extends State<LogbookPage> {
  final _api = ApiClient();

  bool _loading = true;
  bool _isFather = false;
  DateTime? _fincStartLocal;

  final Map<int, Map<String, dynamic>> _entriesByDayIndex = {};

  // Status filter state
  String _selectedFilter = 'ALL'; // 'ALL', 'FILLED', 'UNFILLED'

  @override
  void initState() {
    super.initState();
    _checkRole();
    _loadAll();
  }

  Future<void> _checkRole() async {
    final role = await Prefs.getRole();
    if (mounted) {
      setState(() => _isFather = (role == 'father'));
    }
  }

  Future<void> _showDialogInfo(String title, String message, {bool isError = false, InfoDialogVariant? variant}) {
    return showAppInfoDialog(
      context,
      title: title,
      message: message,
      isError: isError,
      variant: variant,
    );
  }

  // Helper Date and Localization Formatters
  DateTime _localDateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _formatDateFull(DateTime d) =>
      DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(d.toLocal());

  DateTime? _parseAnyDate(dynamic v) => ApiClient.parseDate(v);

  List<DateTime> _daysFromStart() {
    if (_fincStartLocal == null) return [];
    final start = _localDateOnly(_fincStartLocal!);
    return List.generate(14, (i) => start.add(Duration(days: i)));
  }

  // Computed Statistics Getters (strictly bounded to the 14-day I-FINC program window)
  int get _completedCount =>
      _entriesByDayIndex.keys.where((k) => k >= 1 && k <= 14).length;

  int get _unfilledCount => (14 - _completedCount).clamp(0, 14);

  int get _totalDuration => _entriesByDayIndex.entries
      .where((e) => e.key >= 1 && e.key <= 14)
      .fold(0, (sum, e) => sum + ((e.value['durationMinutes'] as int?) ?? 0));

  int get _targetMetCount => _entriesByDayIndex.entries
      .where((e) => e.key >= 1 && e.key <= 14 && e.value['coTargetMet'] == true)
      .length;

  bool _isToday(DateTime dayDate) {
    final today = _localDateOnly(DateTime.now());
    final checkDate = _localDateOnly(dayDate);
    return today.isAtSameMomentAs(checkDate);
  }

  static const _kLogbookCacheKey = 'patient_logbook_v1';

  void _applyLogbookPayload(Map<String, dynamic> res) {
    _entriesByDayIndex.clear();
    final fincStartRaw = res['fincStart'];
    _fincStartLocal = ApiClient.parseDate(fincStartRaw);

    final List items = (res['items'] as List?) ?? [];

    for (final raw in items) {
      final m = (raw as Map).cast<String, dynamic>();
      final idx = m['dayIndex'];

      if (idx != null && idx is int) {
        if (idx >= 1 && idx <= 14) {
          _entriesByDayIndex[idx] = m;
        }
      } else {
        final dateLog = ApiClient.parseDate(m['date']);
        if (_fincStartLocal != null && dateLog != null) {
          final diff = _localDateOnly(dateLog)
                  .difference(_localDateOnly(_fincStartLocal!))
                  .inDays +
              1;
          if (diff >= 1 && diff <= 14) {
            _entriesByDayIndex[diff] = m;
          }
        }
      }
    }
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);

    try {
      final Map<String, dynamic> res = await _api.getLogbook();
      _applyLogbookPayload(res);
      await Prefs.setCachedJson(_kLogbookCacheKey, res);
    } catch (e) {
      if (!mounted) return;

      if (e is ApiError && e.status == 0) {
        final cached = await Prefs.getCachedJson(_kLogbookCacheKey);
        if (!mounted) return;
        if (cached is Map) {
          _applyLogbookPayload(Map<String, dynamic>.from(cached));
          showAppSnackBar(
            context,
            message: 'Menampilkan data terakhir tersimpan (mode luring).',
          );
        } else {
          _showDialogInfo(
            "Luring",
            "Gagal memuat logbook. Periksa koneksi internet Anda.",
            variant: InfoDialogVariant.warning,
          );
        }
      } else {
        final errStr = e.toString();
        if (errStr.contains('500') || errStr.contains('Internal Server Error')) {
          _showDialogInfo("Gagal Memuat", "Terjadi kendala pada server saat memuat logbook. Silakan coba lagi nanti.", isError: true);
        } else {
          _showDialogInfo("Gagal Memuat", "$e", isError: true);
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(int dayIndex, DateTime dayDate) {
    if (_entriesByDayIndex.containsKey(dayIndex)) {
      return const Color(0xFF10B981); // Emerald Green (Completed)
    }
    if (_isToday(dayDate)) {
      return const Color(0xFFF59E0B); // Amber / Yellow (Today - needs action)
    }
    final today = _localDateOnly(DateTime.now());
    final checkDate = _localDateOnly(dayDate);
    if (checkDate.isAfter(today)) {
      return const Color(0xFF94A3B8); // Slate Grey (Future)
    }
    return const Color(0xFFEF4444); // Red (Missed past day)
  }

  String _statusText(int dayIndex, DateTime dayDate) {
    if (_entriesByDayIndex.containsKey(dayIndex)) return 'Sudah diisi';
    if (_isToday(dayDate)) return 'Hari Ini';
    final today = _localDateOnly(DateTime.now());
    final checkDate = _localDateOnly(dayDate);
    if (checkDate.isAfter(today)) return 'Belum waktunya';
    return 'Belum diisi';
  }

  void _onTapDay(int dayIndex, DateTime dayDate) {
    if (_entriesByDayIndex.containsKey(dayIndex)) {
      _showDetailSheet(_entriesByDayIndex[dayIndex]!);
      return;
    }

    if (_isFather) {
      _showDialogInfo("Info Logbook", "Logbook hari ini belum diisi oleh Ibu.\n\nAnda hanya dapat melihat logbook yang sudah diisi.");
      return;
    }

    final today = _localDateOnly(DateTime.now());
    final checkDate = _localDateOnly(dayDate);

    if (!checkDate.isAfter(today)) {
      _showCreateSheet(initialDay: checkDate);
    } else {
      _showDialogInfo("Belum Waktunya", "Anda tidak dapat mengisi logbook untuk tanggal masa depan.", isError: true);
    }
  }

  void _showDetailSheet(Map<String, dynamic> entry) {
    final date = ApiClient.parseDate(entry['date']);
    final duration = entry['durationMinutes'];
    final coTarget = (entry['coTargetMet'] == true);
    final note = (entry['note'] ?? '').toString();

    bool? attended;
    String noteClean = note;
    final m = RegExp(r'^\[ATTENDANCE:(YES|NO)\]\s*').firstMatch(note);
    if (m != null) {
      attended = m.group(1) == 'YES';
      noteClean = note.substring(m.group(0)!.length);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: sheetBottomPadding(ctx, top: 12, extra: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Detail Logbook',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  if (!_isFather)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.edit_outlined, color: Color(0xFF0EA5E9), size: 20),
                            tooltip: 'Ubah',
                            onPressed: () {
                              Navigator.pop(ctx);
                              if (date != null) {
                                _showCreateSheet(
                                  initialDay: date,
                                  existingData: {
                                    'duration': duration,
                                    'coTarget': coTarget,
                                    'attended': attended ?? true,
                                    'note': noteClean
                                  },
                                );
                              }
                            },
                          ),
                        ),
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                            tooltip: 'Hapus',
                            onPressed: () {
                              Navigator.pop(ctx);
                              if (date != null) _confirmDelete(date);
                            },
                          ),
                        ),
                      ],
                    )
                ],
              ),
              const SizedBox(height: 16),
              _row('Tanggal', date == null ? '-' : _formatDateFull(date)),
              const SizedBox(height: 10),
              _row('Durasi', duration == null ? '-' : '$duration menit'),
              const SizedBox(height: 10),
              _row('Target (CO Partner)', coTarget ? 'Tercapai' : 'Tidak tercapai'),
              const SizedBox(height: 10),
              _row('Absensi', attended == null ? '-' : (attended ? 'Hadir' : 'Tidak hadir')),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 8),
              const Text(
                'Catatan',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  noteClean.isEmpty ? '-' : noteClean,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Tutup',
                      style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Logic Delete
  Future<void> _confirmDelete(DateTime date) async {
    final dateStr = _formatDateFull(date);
    final ok = await showAppConfirmDialog(
      context,
      title: "Hapus Logbook?",
      message: "Anda yakin ingin menghapus logbook tanggal $dateStr?",
      confirmLabel: "Hapus",
      isDestructive: true,
    );

    if (ok) {
      try {
        await _api.deleteLogbook(date);
        if (!mounted) return;
        await _showDialogInfo("Dihapus", "Logbook tanggal $dateStr berhasil dihapus.");
        await _loadAll();
      } catch (e) {
        if (!mounted) return;
        if (e is ApiError && e.status == 0) {
          _showDialogInfo("Gagal Hapus", "Tidak ada internet. Gagal menghapus data.", isError: true);
        } else {
          final errStr = e.toString();
          if (errStr.contains('500') || errStr.contains('Internal Server Error')) {
            _showDialogInfo("Gagal", "Terjadi kendala pada server saat menghapus logbook. Silakan coba lagi nanti.", isError: true);
          } else {
            _showDialogInfo("Gagal", "Gagal menghapus: $e", isError: true);
          }
        }
      }
    }
  }

  static Widget _row(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Color(0xFF475569),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  void _showCreateSheet({required DateTime initialDay, Map<String, dynamic>? existingData}) {
    final days = _daysFromStart();
    final start = days.isNotEmpty ? days.first : DateTime.now();
    final lastFromStart = days.isNotEmpty ? days.last : DateTime.now();
    final today = _localDateOnly(DateTime.now());
    final end = today.isBefore(lastFromStart) ? today : lastFromStart;

    final occupiedDates = _entriesByDayIndex.values.map((e) {
      final d = _parseAnyDate(e['date']);
      return d != null ? _localDateOnly(d).toString() : '';
    }).toSet();

    if (existingData != null) {
      occupiedDates.remove(_localDateOnly(initialDay).toString());
    }

    showModalBottomSheet<_CreateResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateLogbookSheet(
        initialDay: initialDay,
        startDate: start,
        endDate: end,
        occupiedKeys: occupiedDates,
        initialData: existingData,
      ),
    ).then((res) async {
      if (res == null) return;
      try {
        final note = _packAttendance(res.attended, res.note);

        await _api.createLogbook(
          date: _localDateOnly(res.date),
          durationMinutes: res.durationMinutes,
          coTargetMet: res.coTargetMet,
          note: note,
        );
        if (!mounted) return;

        await _showDialogInfo("Berhasil", "Logbook harian berhasil disimpan.");

        await _loadAll();
      } catch (e) {
        if (!mounted) return;
        if (e is ApiError && e.status == 0) {
          _showDialogInfo("Gagal Simpan", "Tidak ada internet. Logbook gagal disimpan.", isError: true);
        } else {
          final errStr = e.toString();
          if (errStr.contains('Unique constraint') ||
              errStr.contains('P2002') ||
              errStr.contains('500') ||
              errStr.contains('Internal Server Error')) {
            _showDialogInfo(
              "Gagal",
              "Terjadi kendala pada server saat menyimpan logbook. Silakan coba sesaat lagi.",
              isError: true,
            );
          } else {
            _showDialogInfo("Gagal", "Gagal menyimpan logbook: $e", isError: true);
          }
        }
      }
    });
  }

  String _packAttendance(bool attended, String? note) {
    final clean = (note ?? '').trim();
    return '[ATTENDANCE:${attended ? 'YES' : 'NO'}] $clean';
  }

  List<MapEntry<int, DateTime>> _getFilteredDays(List<DateTime> allDays) {
    final result = <MapEntry<int, DateTime>>[];
    for (int i = 0; i < allDays.length; i++) {
      final dayIndex = i + 1;
      final dayDate = allDays[i];
      final isFilled = _entriesByDayIndex.containsKey(dayIndex);

      if (_selectedFilter == 'FILLED' && !isFilled) continue;
      if (_selectedFilter == 'UNFILLED' && isFilled) continue;

      result.add(MapEntry(dayIndex, dayDate));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: enicareAppBar(
        context,
        title: 'Logbook Ibu',
        showBackButton: Navigator.of(context).canPop(),
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
            : _fincStartLocal == null
                ? _buildNoStart()
                : RefreshIndicator(
                  color: const Color(0xFF10B981),
                  onRefresh: _loadAll,
                  child: Builder(
                    builder: (ctx) {
                      final days = _daysFromStart();

                      if (days.isEmpty) {
                        return const Center(
                          child: Text(
                            'Data tanggal error',
                            style: TextStyle(fontFamily: 'Inter', color: Color(0xFF64748B)),
                          ),
                        );
                      }

                      final filteredDayEntries = _getFilteredDays(days);
                      final unfilledCount = _unfilledCount;

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                        children: [
                          if (_isFather)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFBAE6FD)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF0EA5E9)),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "Mode Pantau: Anda hanya dapat melihat logbook yang sudah diisi oleh Ibu.",
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        color: Color(0xFF072846),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // 1. Program 14-Day Progress Card
                          _LogbookProgressCard(
                            completedCount: _completedCount,
                            totalDuration: _totalDuration,
                            targetMetCount: _targetMetCount,
                            startDate: days.isNotEmpty ? days.first : null,
                            endDate: days.isNotEmpty ? days.last : null,
                          ),

                          const SizedBox(height: 10),

                          // Shortcut Chip -> Jadwal Aktivitas NICU
                          Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: () => Navigator.pushNamed(context, Routes.guide),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 48),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFBAE6FD)),
                                  color: const Color(0xFFF0F9FF),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.schedule_rounded, size: 20, color: Color(0xFF0EA5E9)),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Jadwal Aktivitas NICU',
                                        style: TextStyle(
                                          fontFamily: 'Nunito',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0369A1),
                                        ),
                                      ),
                                    ),
                                    Icon(Icons.chevron_right_rounded, size: 22, color: Color(0xFF0284C7)),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // 2. 14-Day Visual Matrix Grid
                          _DayMatrixGrid(
                            days: days,
                            entries: _entriesByDayIndex,
                            onSelectDay: (dayIdx, dayDt) => _onTapDay(dayIdx, dayDt),
                          ),

                          const SizedBox(height: 10),

                          // 3. Status Filter Bar
                          _StatusFilterBar(
                            selectedFilter: _selectedFilter,
                            totalCount: 14,
                            filledCount: _completedCount,
                            unfilledCount: unfilledCount,
                            onFilterChanged: (filter) => setState(() => _selectedFilter = filter),
                          ),

                          const SizedBox(height: 12),

                          // 4. Filtered Day Cards Timeline
                          if (filteredDayEntries.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              margin: const EdgeInsets.symmetric(vertical: 20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.fact_check_outlined, size: 40, color: Color(0xFF94A3B8)),
                                  const SizedBox(height: 10),
                                  Text(
                                    _selectedFilter == 'FILLED'
                                        ? 'Belum ada hari yang diisi.'
                                        : 'Semua hari telah diisi dengan lengkap!',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...filteredDayEntries.map((entryPair) {
                              final dayIndex = entryPair.key;
                              final d = entryPair.value;

                              final color = _statusColor(dayIndex, d);
                              final status = _statusText(dayIndex, d);
                              final entry = _entriesByDayIndex[dayIndex];

                              String? noteSnippet;
                              if (entry != null && entry['note'] != null) {
                                final rawNote = entry['note'].toString();
                                final noteClean = rawNote.replaceAll(RegExp(r'^\[ATTENDANCE:(YES|NO)\]\s*'), '');
                                if (noteClean.trim().isNotEmpty) {
                                  noteSnippet = noteClean.trim();
                                }
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: RepaintBoundary(
                                  child: _DayCard(
                                    dayIndex: dayIndex,
                                    dateText: _formatDateFull(d),
                                    statusText: status,
                                    color: color,
                                    onTap: () => _onTapDay(dayIndex, d),
                                    trailing: entry != null ? _summaryChips(entry) : null,
                                    noteSnippet: noteSnippet,
                                  ),
                                ),
                              );
                            }),
                        ],
                      );
                    },
                  ),
                ),
      ),
    );
  }

  Widget _buildNoStart() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_today_outlined,
                size: 40,
                color: Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Tanggal mulai FINC belum diatur",
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF451A03),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isFather
                  ? "Mohon tunggu Ibu mengatur tanggal mulai FINC di data bayi."
                  : "Silakan atur tanggal mulai di profil bayi.",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Color(0xFF78350F),
                height: 1.4,
              ),
            ),
            if (!_isFather) ...[
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await Navigator.pushNamed(
                      context,
                      Routes.profileInfantDetail,
                    );
                    _loadAll();
                  },
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  label: const Text(
                    "Atur Sekarang",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryChips(Map<String, dynamic> entry) {
    final dur = entry['durationMinutes'];
    final co = (entry['coTargetMet'] == true);
    final note = (entry['note'] ?? '').toString();

    String? attended;
    final m = RegExp(r'^\[ATTENDANCE:(YES|NO)\]\s*').firstMatch(note);
    if (m != null) attended = m.group(1) == 'YES' ? 'Hadir' : 'Tidak hadir';

    final chips = <Widget>[];
    if (dur != null) {
      chips.add(_buildBadgeChip('$dur menit', const Color(0xFFF1F5F9), const Color(0xFF0F172A)));
    }
    chips.add(
      _buildBadgeChip(
        co ? 'Target: ✓' : 'Target: ×',
        co ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
        co ? const Color(0xFF064E3B) : const Color(0xFF7F1D1D),
      ),
    );
    if (attended != null) {
      chips.add(
        _buildBadgeChip(
          attended,
          attended == 'Hadir' ? const Color(0xFFE0F2FE) : const Color(0xFFFEE2E2),
          attended == 'Hadir' ? const Color(0xFF072846) : const Color(0xFF7F1D1D),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  static Widget _buildBadgeChip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

// ==========================================
// SUB-WIDGETS: PROGRESS, MATRIX, FILTER, CARDS
// ==========================================

class _LogbookProgressCard extends StatelessWidget {
  final int completedCount;
  final int totalDuration;
  final int targetMetCount;
  final DateTime? startDate;
  final DateTime? endDate;

  const _LogbookProgressCard({
    required this.completedCount,
    required this.totalDuration,
    required this.targetMetCount,
    this.startDate,
    this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (completedCount / 14 * 100).round();
    final dateRangeStr = (startDate != null && endDate != null)
        ? '${DateFormat('d MMM', 'id_ID').format(startDate!)} – ${DateFormat('d MMM yyyy', 'id_ID').format(endDate!)}'
        : 'Program 14 Hari';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_graph_rounded,
                  color: Color(0xFF10B981),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Progres Program I-FINC',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateRangeStr,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
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
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF065F46),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: completedCount / 14,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statItem(
                  'Hari Terisi',
                  '$completedCount / 14',
                  Icons.calendar_month_outlined,
                  const Color(0xFF10B981),
                ),
              ),
              Container(width: 1, height: 32, color: const Color(0xFFF1F5F9)),
              Expanded(
                child: _statItem(
                  'Total Durasi',
                  '$totalDuration mnt',
                  Icons.timer_outlined,
                  const Color(0xFF0EA5E9),
                ),
              ),
              Container(width: 1, height: 32, color: const Color(0xFFF1F5F9)),
              Expanded(
                child: _statItem(
                  'Target CO',
                  '$targetMetCount Hari',
                  Icons.task_alt_rounded,
                  const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
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
                    fontSize: 14,
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
      ),
    );
  }
}

class _DayMatrixGrid extends StatelessWidget {
  final List<DateTime> days;
  final Map<int, Map<String, dynamic>> entries;
  final void Function(int dayIndex, DateTime date) onSelectDay;

  const _DayMatrixGrid({
    required this.days,
    required this.entries,
    required this.onSelectDay,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final fontFactor = MediaQuery.textScalerOf(context).scale(12) / 12.0;

    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              const Text(
                'Matriks 14 Hari Perawatan',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                'Ketuk hari untuk lihat/isi',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 14,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: fontFactor > 1.55 ? 5 : 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: fontFactor > 1.25 ? 0.85 : 1.0,
            ),
            itemBuilder: (context, idx) {
              final dayIndex = idx + 1;
              final dayDate = idx < days.length ? days[idx] : null;
              if (dayDate == null) return const SizedBox.shrink();

              final isFilled = entries.containsKey(dayIndex);
              final cellDate = DateTime(dayDate.year, dayDate.month, dayDate.day);
              final isToday = cellDate.isAtSameMomentAs(today);
              final isFuture = cellDate.isAfter(today);

              Color bgColor;
              Color textColor;
              Border? border;

              if (isFilled) {
                bgColor = const Color(0xFF10B981); // Green (Completed)
                textColor = Colors.white;
              } else if (isToday) {
                bgColor = const Color(0xFFFEF3C7); // Amber (Today)
                textColor = const Color(0xFF92400E);
                border = Border.all(color: const Color(0xFFF59E0B), width: 1.5);
              } else if (isFuture) {
                bgColor = const Color(0xFFF1F5F9); // Grey (Future)
                textColor = const Color(0xFF94A3B8);
              } else {
                bgColor = const Color(0xFFFEE2E2); // Red (Missed)
                textColor = const Color(0xFFEF4444);
              }

              return InkWell(
                onTap: () => onSelectDay(dayIndex, dayDate),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: border,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'H$dayIndex',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      if (isFilled)
                        const Icon(Icons.check_rounded, size: 10, color: Colors.white)
                      else if (isToday)
                        const Text('•', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 10, height: 0.8))
                      else
                        const SizedBox(height: 4),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  final String selectedFilter;
  final int totalCount;
  final int filledCount;
  final int unfilledCount;
  final ValueChanged<String> onFilterChanged;

  const _StatusFilterBar({
    required this.selectedFilter,
    required this.totalCount,
    required this.filledCount,
    required this.unfilledCount,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('Semua ($totalCount)', 'ALL'),
          const SizedBox(width: 8),
          _chip('Sudah Diisi ($filledCount)', 'FILLED'),
          const SizedBox(width: 8),
          _chip('Belum Diisi ($unfilledCount)', 'UNFILLED'),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final isSelected = selectedFilter == value;
    return InkWell(
      onTap: () => onFilterChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? const Color(0xFF065F46) : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final int dayIndex;
  final String dateText;
  final String statusText;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? noteSnippet;

  const _DayCard({
    required this.dayIndex,
    required this.dateText,
    required this.statusText,
    required this.color,
    required this.onTap,
    this.trailing,
    this.noteSnippet,
  });

  @override
  Widget build(BuildContext context) {
    final statusBg = _statusBgColor(color);
    final statusFg = _statusFgColor(color);

    return Container(
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 6, color: color),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Text(
                                'Hari ke-$dayIndex',
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: statusFg,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            dateText,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: Color(0xFF475569),
                            ),
                          ),
                          if (trailing != null) ...[
                            const SizedBox(height: 10),
                            trailing!,
                          ],
                          if (noteSnippet != null && noteSnippet!.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                noteSnippet!.trim(),
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 48,
                    child: Center(
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF94A3B8),
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Color _statusBgColor(Color c) {
    if (c == const Color(0xFFEF4444)) return const Color(0xFFFEE2E2);
    if (c == const Color(0xFF10B981)) return const Color(0xFFD1FAE5);
    if (c == const Color(0xFFF59E0B)) return const Color(0xFFFEF3C7);
    return const Color(0xFFF1F5F9);
  }

  static Color _statusFgColor(Color c) {
    if (c == const Color(0xFFEF4444)) return const Color(0xFF7F1D1D);
    if (c == const Color(0xFF10B981)) return const Color(0xFF064E3B);
    if (c == const Color(0xFFF59E0B)) return const Color(0xFF92400E);
    return const Color(0xFF475569);
  }
}

class _CreateResult {
  final DateTime date;
  final int? durationMinutes;
  final bool coTargetMet;
  final bool attended;
  final String? note;
  _CreateResult({
    required this.date,
    required this.durationMinutes,
    required this.coTargetMet,
    required this.attended,
    required this.note,
  });
}

class _CreateLogbookSheet extends StatefulWidget {
  final DateTime initialDay;
  final DateTime startDate;
  final DateTime endDate;
  final Set<String> occupiedKeys;
  final Map<String, dynamic>? initialData;

  const _CreateLogbookSheet({
    required this.initialDay,
    required this.startDate,
    required this.endDate,
    required this.occupiedKeys,
    this.initialData,
  });

  @override
  State<_CreateLogbookSheet> createState() => _CreateLogbookSheetState();
}

class _CreateLogbookSheetState extends State<_CreateLogbookSheet> {
  final _durationCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _co = false;
  bool _att = true;

  late DateTime _selected;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _selected = DateTime(
      widget.initialDay.year,
      widget.initialDay.month,
      widget.initialDay.day,
    );

    if (widget.initialData != null) {
      _isEditing = true;
      final d = widget.initialData!;
      if (d['duration'] != null) _durationCtrl.text = d['duration'].toString();
      if (d['note'] != null) _noteCtrl.text = d['note'];
      _co = d['coTarget'] == true;
      _att = d['attended'] == true;
    }
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _keyOfLocal(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showEnicareDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: widget.startDate,
      lastDate: widget.endDate,
      helpText: 'Pilih tanggal dalam 14 hari program',
    );
    if (picked == null) return;
    if (!mounted) return;

    final key = _keyOfLocal(picked);

    if (widget.occupiedKeys.contains(key)) {
      if (!mounted) return;
      showAppInfoDialog(
        context,
        title: "Peringatan",
        message: 'Tanggal tersebut sudah memiliki entri logbook.',
        variant: InfoDialogVariant.warning,
      );
      return;
    }

    if (!mounted) return;
    setState(() => _selected = DateTime(picked.year, picked.month, picked.day));
  }

  void _submit() {
    final durText = _durationCtrl.text.trim();
    int? dur;
    if (durText.isNotEmpty) {
      final parsed = int.tryParse(durText);
      if (parsed == null || parsed < 0) {
        showAppInfoDialog(
          context,
          title: "Input Salah",
          message: 'Durasi harus berupa angka (menit).',
          variant: InfoDialogVariant.warning,
        );
        return;
      }
      dur = parsed;
    }
    Navigator.pop(
      context,
      _CreateResult(
        date: _selected,
        durationMinutes: dur,
        coTargetMet: _co,
        attended: _att,
        note: _noteCtrl.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateField = InputDecorator(
      decoration: InputDecoration(
        labelText: 'Tanggal',
        labelStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF475569)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),
      child: Text(
        DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_selected),
        style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF0F172A)),
      ),
    );
    final pickDateButton = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF10B981),
          side: const BorderSide(color: Color(0xFF10B981)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _pickDate,
        icon: const Icon(Icons.edit_calendar_outlined, size: 18),
        label: const Text(
          'Ubah Tanggal',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
    final isLargeText = MediaQuery.textScalerOf(context).scale(14) > 18;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: sheetBottomPadding(context, top: 12, extra: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              _isEditing ? 'Ubah Logbook' : 'Isi Logbook',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            if (isLargeText) ...[
              dateField,
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: pickDateButton),
            ] else
              Row(
                children: [
                  Expanded(child: dateField),
                  const SizedBox(width: 10),
                  pickDateButton,
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _durationCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Durasi Kunjungan (menit)',
                  labelStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF475569)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: const Color(0xFF10B981),
                title: const Text(
                  'Target tindakan (CO Partner) tercapai',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF0F172A)),
                ),
                value: _co,
                onChanged: (v) => setState(() => _co = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: const Color(0xFF10B981),
                title: const Text(
                  'Absensi (Hadir)',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF0F172A)),
                ),
                value: _att,
                onChanged: (v) => setState(() => _att = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                minLines: 2,
                maxLines: 4,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Catatan (opsional)',
                  labelStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF475569)),
                  alignLabelWithHint: true,
                  hintText: 'Tuliskan catatan evaluasi kunjungan...',
                  hintStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _submit,
                        child: const Text('Simpan', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
  }
}