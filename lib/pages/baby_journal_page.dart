import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';
import '../routes.dart';
import '../core/storage.dart';
import '../widgets/common.dart';

class BabyJournalPage extends StatefulWidget {
  const BabyJournalPage({super.key});

  @override
  State<BabyJournalPage> createState() => _BabyJournalPageState();
}

class _BabyJournalPageState extends State<BabyJournalPage> {
  final _api = ApiClient();

  bool _loading = true;
  bool _hasInfant = true;
  bool _isObserver = false;
  List<Map<String, dynamic>> _items = const [];

  // --- Filter & Pagination State ---
  DateTime? _selectedCalendarDate;
  int? _filterMonth;
  int? _filterYear;
  int _currentPage = 1;
  static const int _kPageSize = 5;

  // Calendar Navigation State
  DateTime _focusedMonth = DateTime.now();

  // Computed Streak State
  int _currentStreak = 0;
  int _longestStreak = 0;
  bool _hasLoggedToday = false;

  @override
  void initState() {
    super.initState();
    _checkRole();
    _load();
  }

  Future<void> _checkRole() async {
    final role = await Prefs.getRole();
    if (mounted) {
      setState(() => _isObserver = (role == 'father'));
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

  String _formatDate(DateTime d) {
    return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(d.toLocal());
  }

  String _getRelativeDateLabel(DateTime d) {
    final now = DateTime.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final entryDate = DateTime(d.year, d.month, d.day);
    final diff = today.difference(entryDate).inDays;

    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';
    if (diff > 1 && diff <= 7) return '$diff hari lalu';
    return '';
  }

  int _computeStreak(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return 0;

    final now = DateTime.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);

    final dates = items
        .map((e) => ApiClient.parseDate(e['date']))
        .whereType<DateTime>()
        .map((d) {
          final loc = d.toLocal();
          return DateTime(loc.year, loc.month, loc.day);
        })
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (dates.isEmpty) return 0;

    final diffFromToday = today.difference(dates.first).inDays;
    if (diffFromToday > 1) return 0;

    int streak = 1;
    for (int i = 0; i < dates.length - 1; i++) {
      final gap = dates[i].difference(dates[i + 1]).inDays;
      if (gap == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  int _computeLongestStreak(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return 0;

    final dates = items
        .map((e) => ApiClient.parseDate(e['date']))
        .whereType<DateTime>()
        .map((d) {
          final loc = d.toLocal();
          return DateTime(loc.year, loc.month, loc.day);
        })
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (dates.isEmpty) return 0;

    int longest = 1;
    int current = 1;
    for (int i = 0; i < dates.length - 1; i++) {
      final gap = dates[i].difference(dates[i + 1]).inDays;
      if (gap == 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }
    return longest;
  }

  bool _computeHasLoggedToday(List<Map<String, dynamic>> items) {
    final now = DateTime.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    return items.any((e) {
      final d = ApiClient.parseDate(e['date']);
      if (d == null) return false;
      final loc = d.toLocal();
      return loc.year == today.year && loc.month == today.month && loc.day == today.day;
    });
  }

  Map<String, dynamic>? _getEntryForDate(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    for (final it in _items) {
      final d = ApiClient.parseDate(it['date']);
      if (d == null) continue;
      final loc = d.toLocal();
      if (loc.year == target.year && loc.month == target.month && loc.day == target.day) {
        return it;
      }
    }
    return null;
  }

  Map<String, dynamic>? _getTodayEntry() {
    return _getEntryForDate(DateTime.now().toLocal());
  }

  Set<String> get _markedDates {
    final set = <String>{};
    for (final it in _items) {
      final d = ApiClient.parseDate(it['date']);
      if (d != null) {
        final loc = d.toLocal();
        final y = loc.year.toString().padLeft(4, '0');
        final m = loc.month.toString().padLeft(2, '0');
        final day = loc.day.toString().padLeft(2, '0');
        set.add('$y-$m-$day');
      }
    }
    return set;
  }

  List<Map<String, dynamic>> get _filteredItems {
    return _items.where((it) {
      final d = ApiClient.parseDate(it['date']);
      if (d == null) return false;
      final loc = d.toLocal();

      if (_selectedCalendarDate != null) {
        return loc.year == _selectedCalendarDate!.year &&
            loc.month == _selectedCalendarDate!.month &&
            loc.day == _selectedCalendarDate!.day;
      }

      if (_filterMonth != null && loc.month != _filterMonth) return false;
      if (_filterYear != null && loc.year != _filterYear) return false;
      return true;
    }).toList();
  }

  int get _totalPages {
    final total = _filteredItems.length;
    if (total == 0) return 1;
    return (total / _kPageSize).ceil();
  }

  List<Map<String, dynamic>> get _displayedItems {
    final filtered = _filteredItems;
    final startIndex = (_currentPage - 1) * _kPageSize;
    if (startIndex >= filtered.length) return const [];
    return filtered.skip(startIndex).take(_kPageSize).toList();
  }

  static const _kJournalCacheKey = 'patient_baby_journal_v1';

  void _applyJournalState(bool nextHasInfant, List<Map<String, dynamic>> nextItems) {
    if (!mounted) return;
    setState(() {
      _hasInfant = nextHasInfant;
      _items = nextItems;
      _currentStreak = _computeStreak(_items);
      _longestStreak = _computeLongestStreak(_items);
      _hasLoggedToday = _computeHasLoggedToday(_items);
      _currentPage = 1;
      _loading = false;
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    var nextHasInfant = _hasInfant;
    List<Map<String, dynamic>> nextItems = _items;
    var appliedFromCache = false;

    try {
      final infant = await _api.getInfant();
      nextHasInfant = infant != null;

      if (nextHasInfant) {
        nextItems = (await _api.getBabyJournal())
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
      } else {
        nextItems = const [];
      }
      await Prefs.setCachedJson(_kJournalCacheKey, {
        'hasInfant': nextHasInfant,
        'items': nextItems,
      });
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('bayi') && msg.contains('belum ada')) {
        nextHasInfant = false;
        nextItems = const [];
      } else if (e is ApiError && e.status == 0) {
        final cached = await Prefs.getCachedJson(_kJournalCacheKey);
        if (cached is Map && cached['items'] is List) {
          nextHasInfant = cached['hasInfant'] != false;
          nextItems = (cached['items'] as List)
              .whereType<Map>()
              .map((m) => m.cast<String, dynamic>())
              .toList();
          appliedFromCache = true;
          if (mounted) {
            showAppSnackBar(
              context,
              message: 'Menampilkan data terakhir tersimpan (mode luring).',
            );
          }
        } else if (mounted) {
          _showDialogInfo(
            "Luring",
            "Tidak dapat memuat jurnal. Periksa koneksi internet.",
            variant: InfoDialogVariant.warning,
          );
        }
      }
    } finally {
      if (mounted) {
        if (appliedFromCache || nextItems.isNotEmpty || !nextHasInfant || _items.isEmpty) {
          _applyJournalState(nextHasInfant, nextItems);
        } else {
          setState(() => _loading = false);
        }
      }
    }
  }

  Future<void> _openAddJournalSheet({DateTime? initialDate}) async {
    if (_isObserver) return;

    final result = await showModalBottomSheet<_JournalFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddJournalSheet(
        initialDate: initialDate,
        existingItems: _items,
      ),
    );
    if (result == null) return;

    final text = result.summary.trim();
    if (text.isEmpty) {
      if (!mounted) return;
      _showDialogInfo("Peringatan", "Ringkasan jurnal wajib diisi.", isError: true);
      return;
    }

    try {
      await _api.createBabyJournal(
        date: result.date,
        summary: text,
      );
      if (!mounted) return;

      await _showDialogInfo("Berhasil", "Jurnal harian berhasil disimpan.");
      await _load();
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('bayi') && msg.contains('belum ada')) {
        if (!mounted) return;
        _showDialogInfo("Data Bayi Kosong", "Silakan lengkapi data bayi di halaman Profil terlebih dahulu.", isError: true);
        setState(() => _hasInfant = false);
      } else {
        if (!mounted) return;
        if (e is ApiError && e.status == 0) {
          _showDialogInfo("Gagal Simpan", "Tidak ada internet. Jurnal gagal disimpan.", isError: true);
        } else {
          _showDialogInfo("Gagal", "Gagal menyimpan jurnal: $e", isError: true);
        }
      }
    }
  }

  void _showAddOrEditChoiceSheet(Map<String, dynamic> todayEntry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final now = DateTime.now().toLocal();
        final formattedToday = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now);
        return Container(
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
                const Text(
                  'Jurnal Hari Ini Sudah Ada',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Anda sudah memiliki catatan untuk $formattedToday. Silakan pilih opsi:',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 18),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openEditJournalSheet(todayEntry, isTodayEdit: true);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.edit_note_rounded,
                            color: Color(0xFF10B981),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ubah Jurnal Hari Ini',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Perbarui catatan aktivitas si kecil untuk hari ini',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openAddJournalSheet();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.edit_calendar_rounded,
                            color: Color(0xFF475569),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Catat Jurnal untuk Tanggal Lain',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Pilih tanggal kemarin atau tanggal lain yang terlewat',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'Batal',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleJournalFabTap() {
    if (_isObserver) return;

    if (_selectedCalendarDate != null) {
      final entry = _getEntryForDate(_selectedCalendarDate!);
      if (entry != null) {
        _openEditJournalSheet(entry);
      } else {
        _openAddJournalSheet(initialDate: _selectedCalendarDate);
      }
      return;
    }

    final todayEntry = _getTodayEntry();
    if (todayEntry != null) {
      _showAddOrEditChoiceSheet(todayEntry);
    } else {
      _openAddJournalSheet(initialDate: DateTime.now());
    }
  }

  // ====== VIEW / EDIT JURNAL ======

  Future<void> _openEditJournalSheet(Map<String, dynamic> item, {bool? isTodayEdit}) async {
    final date = ApiClient.parseDate(item['date']) ?? DateTime.now();
    final summary = (item['summary'] ?? '').toString();

    final now = DateTime.now().toLocal();
    final loc = date.toLocal();
    final isToday = isTodayEdit ?? (loc.year == now.year && loc.month == now.month && loc.day == now.day);

    final result = await showModalBottomSheet<_JournalFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditJournalSheet(
        initialDate: date,
        initialSummary: summary,
        readOnly: _isObserver,
        isTodayEdit: isToday,
      ),
    );

    if (result == null) return;

    final text = result.summary.trim();
    if (text.isEmpty) {
      if (!mounted) return;
      _showDialogInfo("Peringatan", "Ringkasan tidak boleh kosong.", isError: true);
      return;
    }

    try {
      await _api.createBabyJournal(
        date: result.date,
        summary: text,
      );
      if (!mounted) return;

      await _showDialogInfo("Berhasil", "Jurnal berhasil diperbarui.");
      await _load();
    } catch (e) {
      if (!mounted) return;
      if (e is ApiError && e.status == 0) {
        _showDialogInfo("Gagal Simpan", "Tidak ada internet. Perubahan gagal disimpan.", isError: true);
      } else {
        _showDialogInfo("Gagal", "$e", isError: true);
      }
    }
  }

  // ====== HAPUS JURNAL ======

  Future<void> _confirmDeleteJournal(Map<String, dynamic> item) async {
    if (_isObserver) return;

    final date = ApiClient.parseDate(item['date']) ?? DateTime.now();
    final dateLabel = _formatDate(date);

    final ok = await showAppConfirmDialog(
      context,
      title: 'Hapus Jurnal?',
      message: 'Jurnal bayi tanggal $dateLabel akan dihapus. Tindakan ini tidak dapat dibatalkan.',
      confirmLabel: 'Hapus',
      isDestructive: true,
    );

    if (!ok) return;

    try {
      await _api.deleteBabyJournal(
        date: date,
      );
      if (!mounted) return;

      await _showDialogInfo("Dihapus", "Jurnal berhasil dihapus.");
      await _load();
    } catch (e) {
      if (!mounted) return;
      if (e is ApiError && e.status == 0) {
        _showDialogInfo("Gagal Hapus", "Tidak ada internet. Gagal menghapus jurnal.", isError: true);
      } else {
        _showDialogInfo("Gagal", "Gagal menghapus jurnal: $e", isError: true);
      }
    }
  }

  Widget _buildEmptyState() {
    final hasFilter = _selectedCalendarDate != null || _filterMonth != null || _filterYear != null;

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                hasFilter ? Icons.search_off_rounded : Icons.menu_book_rounded,
                size: 36,
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hasFilter ? 'Tidak Ada Jurnal Ditemukan' : 'Belum Ada Jurnal Bayi',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilter
                  ? 'Tidak ada catatan jurnal untuk filter tanggal/periode yang dipilih.'
                  : 'Tarik ke bawah untuk memperbarui daftar atau tekan tombol + untuk menambah jurnal baru.',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasFilter) ...[
              const SizedBox(height: 16),
              if (_selectedCalendarDate != null && !_isObserver) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _openAddJournalSheet(initialDate: _selectedCalendarDate),
                  icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                  label: Text(
                    'Catat Jurnal Tanggal Ini (${DateFormat('d MMM', 'id_ID').format(_selectedCalendarDate!)})',
                    style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedCalendarDate = null;
                    _filterMonth = null;
                    _filterYear = null;
                    _currentPage = 1;
                  });
                },
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF10B981)),
                label: const Text(
                  'Reset Filter',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildObserverBanner() {
    if (!_isObserver || !_hasInfant) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
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
              "Mode Pantau: Anda hanya dapat melihat jurnal.",
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
    );
  }

  Widget _buildNoInfantBanner() {
    if (_hasInfant) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Data bayi belum ada',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF451A03),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isObserver
                      ? 'Mohon tunggu Ibu membuat data bayi di Profil.'
                      : 'Untuk menambah jurnal, silakan buat data bayi di halaman Profil.',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFF78350F),
                    height: 1.4,
                  ),
                ),
                if (!_isObserver) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB45309),
                        side: const BorderSide(color: Color(0xFFF59E0B)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        await Navigator.pushNamed(context, Routes.profileMotherDetail);
                        if (!mounted) return;
                        await _load();
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text(
                        'Buat Data Bayi di Profil',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJournalCard(Map<String, dynamic> it) {
    final d = ApiClient.parseDate(it['date']);
    final title = d != null ? _formatDate(d) : '(tanpa tanggal)';
    final relativeLabel = d != null ? _getRelativeDateLabel(d) : '';
    final summary = (it['summary'] ?? '').toString();

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
          onTap: () => _openEditJournalSheet(it),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    color: Color(0xFF10B981),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (relativeLabel.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: relativeLabel == 'Hari ini'
                                    ? const Color(0xFFD1FAE5)
                                    : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                relativeLabel,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: relativeLabel == 'Hari ini'
                                      ? const Color(0xFF065F46)
                                      : const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        summary.isEmpty ? '—' : summary,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Color(0xFF475569),
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (!_isObserver)
                  IconButton(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                    tooltip: 'Opsi Jurnal',
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    onPressed: () {
                      showEnicareOptionSheet<String>(
                        context,
                        title: 'Opsi Jurnal',
                        subtitle: 'Kelola entri jurnal bayi ini',
                        options: const [
                          EnicarePickerOption<String>(
                            value: 'edit',
                            label: 'Ubah Jurnal',
                            subtitle: 'Perbarui isi atau tanggal catatan',
                            icon: Icons.edit_outlined,
                          ),
                          EnicarePickerOption<String>(
                            value: 'delete',
                            label: 'Hapus Jurnal',
                            subtitle: 'Hapus entri ini secara permanen',
                            icon: Icons.delete_outline_rounded,
                            isDestructive: true,
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'edit') {
                            _openEditJournalSheet(it);
                          } else if (value == 'delete') {
                            _confirmDeleteJournal(it);
                          }
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPager() {
    if (_totalPages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: const Icon(Icons.chevron_left_rounded, size: 28),
              color: _currentPage > 1 ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
              onPressed: _currentPage > 1
                  ? () => setState(() => _currentPage--)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              'Halaman $_currentPage dari $_totalPages',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: const Icon(Icons.chevron_right_rounded, size: 28),
              color: _currentPage < _totalPages ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
              onPressed: _currentPage < _totalPages
                  ? () => setState(() => _currentPage++)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = _hasInfant && !_loading && !_isObserver;
    final displayed = _displayedItems;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: enicareAppBar(
        context,
        title: 'Jurnal Bayi',
        showBackButton: Navigator.of(context).canPop(),
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
            : RefreshIndicator(
              color: const Color(0xFF10B981),
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildObserverBanner(),
                        _buildNoInfantBanner(),
                        if (_hasInfant) ...[
                          _StreakBanner(
                            currentStreak: _currentStreak,
                            longestStreak: _longestStreak,
                            hasLoggedToday: _hasLoggedToday,
                          ),
                          const SizedBox(height: 12),
                          _MonthCalendar(
                            focusedMonth: _focusedMonth,
                            markedDates: _markedDates,
                            selectedDate: _selectedCalendarDate,
                            onDateTap: (d) {
                              setState(() {
                                if (_selectedCalendarDate != null &&
                                    _selectedCalendarDate!.year == d.year &&
                                    _selectedCalendarDate!.month == d.month &&
                                    _selectedCalendarDate!.day == d.day) {
                                  _selectedCalendarDate = null;
                                } else {
                                  _selectedCalendarDate = d;
                                  _filterMonth = null;
                                  _filterYear = null;
                                }
                                _currentPage = 1;
                              });
                            },
                            onMonthChange: (dir) {
                              setState(() {
                                _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + dir, 1);
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          _FilterBar(
                            filterMonth: _filterMonth,
                            filterYear: _filterYear,
                            onMonthChanged: (m) {
                              setState(() {
                                _filterMonth = m;
                                _selectedCalendarDate = null;
                                _currentPage = 1;
                              });
                            },
                            onYearChanged: (y) {
                              setState(() {
                                _filterYear = y;
                                _selectedCalendarDate = null;
                                _currentPage = 1;
                              });
                            },
                            onReset: () {
                              setState(() {
                                _filterMonth = null;
                                _filterYear = null;
                                _selectedCalendarDate = null;
                                _currentPage = 1;
                              });
                            },
                          ),
                          if (_selectedCalendarDate != null)
                            Container(
                              margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD1FAE5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF10B981)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.event_available_rounded, size: 18, color: Color(0xFF047857)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Menampilkan tanggal: ${DateFormat('d MMMM yyyy', 'id_ID').format(_selectedCalendarDate!)}',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF065F46),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(() {
                                      _selectedCalendarDate = null;
                                      _currentPage = 1;
                                    }),
                                    child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF047857)),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                  if (_filteredItems.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    )
                  else ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      sliver: SliverList.builder(
                        itemCount: displayed.length,
                        itemBuilder: (context, idx) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: RepaintBoundary(
                              child: _buildJournalCard(displayed[idx]),
                            ),
                          );
                        },
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _buildPager(),
                    ),
                  ],
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 88),
                  ),
                ],
              ),
            ),
      ),
      floatingActionButton: canAdd
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 3,
              onPressed: _handleJournalFabTap,
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
    );
  }
}

// ==========================================
// PRIVATE SUB-WIDGETS & MODAL SHEETS
// ==========================================

class _StreakBanner extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;
  final bool hasLoggedToday;

  const _StreakBanner({
    required this.currentStreak,
    required this.longestStreak,
    required this.hasLoggedToday,
  });

  @override
  Widget build(BuildContext context) {
    if (currentStreak == 0) {
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.emoji_events_outlined,
                color: Color(0xFF10B981),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bangun Kebiasaan Mencatat Harian',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF064E3B),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Catat perkembangan bayi setiap hari untuk membangun kebiasaan rutin.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Color(0xFF047857),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFDE68A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                '🔥',
                style: TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '$currentStreak Hari Berturut-turut',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF451A03),
                      ),
                    ),
                    if (hasLoggedToday)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Hari Ini ✓',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  longestStreak > 1
                      ? 'Rekor terbaik: $longestStreak hari  •  Pertahankan terus!'
                      : (hasLoggedToday
                          ? 'Hebat! Anda sudah mengisi jurnal hari ini.'
                          : 'Jangan lupa isi jurnal hari ini untuk menjaga kebiasaan baik.'),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Color(0xFF78350F),
                    height: 1.3,
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

class _MonthCalendar extends StatelessWidget {
  final DateTime focusedMonth;
  final Set<String> markedDates;
  final DateTime? selectedDate;
  final void Function(DateTime) onDateTap;
  final void Function(int) onMonthChange;

  const _MonthCalendar({
    required this.focusedMonth,
    required this.markedDates,
    required this.selectedDate,
    required this.onDateTap,
    required this.onMonthChange,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);

    final monthTitle = DateFormat('MMMM yyyy', 'id_ID').format(focusedMonth);
    final firstDayOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final lastDayOfMonth = DateTime(focusedMonth.year, focusedMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;

    final startOffset = firstDayOfMonth.weekday - 1; // Monday=1 -> 0, Sunday=7 -> 6
    final totalCells = ((startOffset + daysInMonth + 6) ~/ 7) * 7;

    const dayHeaders = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
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
        children: [
          // Month Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF10B981), size: 28),
                onPressed: () => onMonthChange(-1),
                tooltip: 'Bulan Sebelumnya',
              ),
              Text(
                monthTitle,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF10B981), size: 28),
                onPressed: () => onMonthChange(1),
                tooltip: 'Bulan Berikutnya',
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Day Names
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: dayHeaders.map((dh) {
              return Expanded(
                child: Center(
                  child: Text(
                    dh,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          // Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, idx) {
              if (idx < startOffset || idx >= startOffset + daysInMonth) {
                return const SizedBox.shrink();
              }

              final dayNum = idx - startOffset + 1;
              final cellDate = DateTime(focusedMonth.year, focusedMonth.month, dayNum);
              final isToday = cellDate.year == today.year &&
                  cellDate.month == today.month &&
                  cellDate.day == today.day;
              final isSelected = selectedDate != null &&
                  cellDate.year == selectedDate!.year &&
                  cellDate.month == selectedDate!.month &&
                  cellDate.day == selectedDate!.day;

              final yStr = cellDate.year.toString().padLeft(4, '0');
              final mStr = cellDate.month.toString().padLeft(2, '0');
              final dStr = cellDate.day.toString().padLeft(2, '0');
              final hasEntry = markedDates.contains('$yStr-$mStr-$dStr');

              Color textColor = const Color(0xFF0F172A);
              if (isSelected) {
                textColor = Colors.white;
              } else if (isToday) {
                textColor = const Color(0xFF10B981);
              }

              return InkWell(
                onTap: () => onDateTap(cellDate),
                borderRadius: BorderRadius.circular(10),
                child: Center(
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF10B981)
                          : (isToday ? const Color(0xFFD1FAE5) : Colors.transparent),
                      shape: BoxShape.circle,
                      border: isToday && !isSelected
                          ? Border.all(color: const Color(0xFF10B981), width: 1.5)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNum',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: (isSelected || isToday || hasEntry)
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                        if (hasEntry)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : const Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          )
                        else
                          const SizedBox(height: 5),
                      ],
                    ),
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

class _FilterBar extends StatelessWidget {
  final int? filterMonth;
  final int? filterYear;
  final void Function(int?) onMonthChanged;
  final void Function(int?) onYearChanged;
  final VoidCallback onReset;

  const _FilterBar({
    required this.filterMonth,
    required this.filterYear,
    required this.onMonthChanged,
    required this.onYearChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = [null, currentYear, currentYear - 1, currentYear - 2];
    final months = [null, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
    final isFiltered = filterMonth != null || filterYear != null;

    final monthNames = [
      'Semua Bulan',
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];

    final isLargeText = MediaQuery.textScalerOf(context).scale(12) > 15.5;

    Widget buildMonthDropdown() => EnicarePickerField(
          displayText: filterMonth == null ? 'Semua Bulan' : monthNames[filterMonth!],
          isActive: filterMonth != null,
          leadingIcon: Icons.calendar_view_month_rounded,
          onTap: () => showEnicareOptionSheet<int?>(
            context,
            title: 'Filter Bulan',
            selectedValue: filterMonth,
            options: months
                .map((m) => EnicarePickerOption<int?>(
                      value: m,
                      label: m == null ? 'Semua Bulan' : monthNames[m],
                    ))
                .toList(),
            onSelected: onMonthChanged,
          ),
        );

    Widget buildYearDropdown() => EnicarePickerField(
          displayText: filterYear == null ? 'Semua Tahun' : '$filterYear',
          isActive: filterYear != null,
          leadingIcon: Icons.event_note_rounded,
          onTap: () => showEnicareOptionSheet<int?>(
            context,
            title: 'Filter Tahun',
            selectedValue: filterYear,
            options: years
                .map((y) => EnicarePickerOption<int?>(
                      value: y,
                      label: y == null ? 'Semua Tahun' : '$y',
                    ))
                .toList(),
            onSelected: onYearChanged,
          ),
        );

    Widget buildResetBtn() => Tooltip(
          message: 'Reset Filter',
          child: SizedBox(
            width: 44,
            height: 44,
            child: Material(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onReset,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFFCA5A5),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.restart_alt_rounded,
                      size: 18,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: isLargeText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buildMonthDropdown(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: buildYearDropdown()),
                    if (isFiltered) ...[
                      const SizedBox(width: 8),
                      buildResetBtn(),
                    ],
                  ],
                ),
              ],
            )
          : Row(
              children: [
                const SizedBox(
                  width: 28,
                  height: 44,
                  child: Center(
                    child: Icon(Icons.filter_list_rounded, size: 20, color: Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(child: buildMonthDropdown()),
                const SizedBox(width: 8),
                Expanded(child: buildYearDropdown()),
                if (isFiltered) ...[
                  const SizedBox(width: 8),
                  buildResetBtn(),
                ],
              ],
            ),
    );
  }
}

class _JournalFormResult {
  final DateTime date;
  final String summary;
  _JournalFormResult(this.date, this.summary);
}

class _AddJournalSheet extends StatefulWidget {
  final DateTime? initialDate;
  final List<Map<String, dynamic>>? existingItems;

  const _AddJournalSheet({
    this.initialDate,
    this.existingItems,
  });

  @override
  State<_AddJournalSheet> createState() => _AddJournalSheetState();
}

class _AddJournalSheetState extends State<_AddJournalSheet> {
  late DateTime _date;
  Map<String, dynamic>? _existingEntry;
  final _summary = TextEditingController();

  Map<String, dynamic>? _getExistingFor(DateTime date) {
    if (widget.existingItems == null) return null;
    final target = DateTime(date.year, date.month, date.day);
    for (final it in widget.existingItems!) {
      final d = ApiClient.parseDate(it['date']);
      if (d == null) continue;
      final loc = d.toLocal();
      if (loc.year == target.year && loc.month == target.month && loc.day == target.day) {
        return it;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();
    _existingEntry = _getExistingFor(_date);
    if (_existingEntry != null) {
      _summary.text = (_existingEntry!['summary'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    _summary.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showEnicareDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDate: _date,
    );
    if (picked != null) {
      final newDate = DateTime(picked.year, picked.month, picked.day);
      final existing = _getExistingFor(newDate);
      setState(() {
        _date = newDate;
        _existingEntry = existing;
        if (_summary.text.trim().isEmpty && existing != null) {
          _summary.text = (existing['summary'] ?? '').toString();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLargeText = MediaQuery.textScalerOf(context).scale(14) > 18;
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
        DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_date.toLocal()),
        style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF0F172A)),
      ),
    );
    final pickButton = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF10B981),
          side: const BorderSide(color: Color(0xFF10B981)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _pickDate,
        icon: const Icon(Icons.calendar_today_rounded, size: 18),
        label: const Text('Pilih', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
      ),
    );

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
              _existingEntry != null ? 'Ubah Jurnal' : 'Tambah Jurnal',
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
              SizedBox(width: double.infinity, child: pickButton),
            ] else
              Row(
                children: [
                  Expanded(child: dateField),
                  const SizedBox(width: 10),
                  pickButton,
                ],
              ),
              if (_existingEntry != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFB45309)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Jurnal pada tanggal ini sudah ada. Menyimpan akan memperbarui catatan tersebut.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _summary,
                maxLines: 4,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Ringkasan',
                  labelStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF475569)),
                  alignLabelWithHint: true,
                  hintText: 'Tuliskan catatan harian perkembangan bayi...',
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
                        onPressed: () {
                          Navigator.pop(
                            context,
                            _JournalFormResult(_date, _summary.text),
                          );
                        },
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

class _EditJournalSheet extends StatefulWidget {
  final DateTime initialDate;
  final String? initialSummary;
  final bool readOnly;
  final bool isTodayEdit;

  const _EditJournalSheet({
    required this.initialDate,
    this.initialSummary,
    this.readOnly = false,
    this.isTodayEdit = false,
  });

  @override
  State<_EditJournalSheet> createState() => _EditJournalSheetState();
}

class _EditJournalSheetState extends State<_EditJournalSheet> {
  late DateTime _date;
  late TextEditingController _summary;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    _summary = TextEditingController(text: widget.initialSummary ?? '');
  }

  @override
  void dispose() {
    _summary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReadOnly = widget.readOnly;

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
              if (widget.isTodayEdit) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981), width: 1.2),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.edit_calendar_rounded, size: 20, color: Color(0xFF047857)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mengubah Jurnal Hari Ini',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Color(0xFF064E3B),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Catatan perkembangan hari ini sudah tersimpan. Mengedit akan memperbarui catatan ini.',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Color(0xFF047857),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Text(
                isReadOnly
                    ? 'Detail Jurnal'
                    : (widget.isTodayEdit ? 'Ubah Jurnal Hari Ini' : 'Ubah Jurnal'),
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              InputDecorator(
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
                  DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_date.toLocal()),
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF0F172A)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _summary,
                readOnly: isReadOnly,
                maxLines: 4,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Ringkasan',
                  labelStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF475569)),
                  alignLabelWithHint: true,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isReadOnly) ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(
                              context,
                              _JournalFormResult(_date, _summary.text),
                            );
                          },
                          child: const Text(
                            'Simpan Perubahan',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          isReadOnly ? 'Tutup' : 'Batal',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 15),
                        ),
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