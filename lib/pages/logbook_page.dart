import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../routes.dart';
import '../core/storage.dart';

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
          )
        ],
      ),
    );
  }

  // Helper Date
  DateTime _localDateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _fmtFull(BuildContext ctx, DateTime d) =>
      MaterialLocalizations.of(ctx).formatFullDate(d.toLocal());

  DateTime? _parseAnyDate(dynamic v) => ApiClient.parseDate(v);

  List<DateTime> _daysFromStart() {
    if (_fincStartLocal == null) return [];
    final start = _localDateOnly(_fincStartLocal!);
    return List.generate(14, (i) => start.add(Duration(days: i)));
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    _entriesByDayIndex.clear();

    try {
      final Map<String, dynamic> res = await _api.getLogbook();

      // Helper ApiClient
      final fincStartRaw = res['fincStart'];
      _fincStartLocal = ApiClient.parseDate(fincStartRaw);

      final List items = res['items'] ?? [];

      for (final raw in items) {
        final m = (raw as Map).cast<String, dynamic>();
        final idx = m['dayIndex'];

        if (idx != null && idx is int) {
          _entriesByDayIndex[idx] = m;
        } else {
          // Helper ApiClient
          final dateLog = ApiClient.parseDate(m['date']);
          if (_fincStartLocal != null && dateLog != null) {
            final diff = _localDateOnly(dateLog)
                .difference(_localDateOnly(_fincStartLocal!))
                .inDays +
                1;
            _entriesByDayIndex[diff] = m;
          }
        }
      }
    } catch (e) {
      if (!mounted) return;

      // Handling Error Offline
      if (e is ApiError && e.status == 0) {
        _showDialogInfo("Offline", "Gagal memuat logbook. Periksa koneksi internet Anda.", isError: true);
      } else {
        _showDialogInfo("Gagal Memuat", "$e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(int dayIndex, DateTime dayDate) {
    if (_entriesByDayIndex.containsKey(dayIndex)) {
      return Colors.green;
    }
    final today = _localDateOnly(DateTime.now());
    final checkDate = _localDateOnly(dayDate);
    if (checkDate.isAfter(today)) {
      return Colors.grey;
    }
    return Colors.red;
  }

  String _statusText(int dayIndex, DateTime dayDate) {
    if (_entriesByDayIndex.containsKey(dayIndex)) return 'Sudah diisi';
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
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Detail Logbook',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),

                if (!_isFather)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        tooltip: 'Edit',
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
                                }
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Hapus',
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (date != null) _confirmDelete(date);
                        },
                      ),
                    ],
                  )
              ],
            ),
            const SizedBox(height: 16),
            _row('Tanggal', date == null ? '-' : _fmtFull(ctx, date)),
            const SizedBox(height: 8),
            _row('Durasi', duration == null ? '-' : '$duration menit'),
            const SizedBox(height: 8),
            _row('Target (CO Partner)',
                coTarget ? 'Tercapai' : 'Tidak tercapai'),
            const SizedBox(height: 8),
            _row('Absensi',
                attended == null ? '-' : (attended ? 'Hadir' : 'Tidak hadir')),
            const SizedBox(height: 8),
            const Divider(),
            const Text('Catatan',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(noteClean.isEmpty ? '-' : noteClean),
            const SizedBox(height: 20),

            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tutup')),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Logic Delete
  Future<void> _confirmDelete(DateTime date) async {
    final dateStr = _fmtFull(context, date);
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Hapus Logbook?"),
          content: Text("Anda yakin ingin menghapus logbook tanggal $dateStr?"),
          actions: [
            TextButton(onPressed: ()=>Navigator.pop(ctx, false), child: const Text("Batal")),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: ()=>Navigator.pop(ctx, true),
                child: const Text("Hapus")
            ),
          ],
        )
    ) ?? false;

    if (ok) {
      try {
        await _api.deleteLogbook(date);
        if (!mounted) return;
        await _showDialogInfo("Dihapus", "Logbook tanggal $dateStr berhasil dihapus.");
        await _loadAll();
      } catch (e) {
        if (!mounted) return;
        // Handling Error Offline
        if (e is ApiError && e.status == 0) {
          _showDialogInfo("Gagal Hapus", "Tidak ada internet. Gagal menghapus data.", isError: true);
        } else {
          _showDialogInfo("Gagal", "Gagal menghapus: $e", isError: true);
        }
      }
    }
  }

  static Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
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
        // Handlling Error Offline
        if (e is ApiError && e.status == 0) {
          _showDialogInfo("Gagal Simpan", "Tidak ada internet. Logbook gagal disimpan.", isError: true);
        } else {
          _showDialogInfo("Gagal", "Gagal menyimpan logbook: $e", isError: true);
        }
      }
    });
  }

  String _packAttendance(bool attended, String? note) {
    final clean = (note ?? '').trim();
    return '[ATTENDANCE:${attended ? 'YES' : 'NO'}] $clean';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logbook Bayi')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _fincStartLocal == null
          ? _buildNoStart()
          : RefreshIndicator(
        onRefresh: _loadAll,
        child: Builder(
          builder: (ctx) {
            final days = _daysFromStart();

            if (days.isEmpty) {
              return const Center(child: Text('Data tanggal error'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: days.length,
              itemBuilder: (_, i) {
                final d = days[i];
                final dayIndex = i + 1;

                final color = _statusColor(dayIndex, d);
                final status = _statusText(dayIndex, d);
                final entry = _entriesByDayIndex[dayIndex];

                return _DayCard(
                  labelLeft: 'Hari $dayIndex',
                  dateText: _fmtFull(ctx, d),
                  statusText: status,
                  color: color,
                  onTap: () => _onTapDay(dayIndex, d),
                  trailing:
                  entry != null ? _summaryChips(entry) : null,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildNoStart() {
    return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text("Tanggal mulai FINC belum diatur",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                  _isFather
                      ? "Mohon tunggu Ibu mengatur tanggal mulai FINC di data bayi."
                      : "Silakan atur tanggal mulai di profil bayi.",
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              if (!_isFather)
                FilledButton(
                    onPressed: () async {
                      await Navigator.pushNamed(
                          context, Routes.profileInfantDetail);
                      _loadAll();
                    },
                    child: const Text("Atur Sekarang"))
            ],
          ),
        ));
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
      chips.add(Chip(
          label: Text('$dur menit'), visualDensity: VisualDensity.compact));
    }
    chips.add(Chip(
        label: Text(co ? 'Target: ✓' : 'Target: ×'),
        visualDensity: VisualDensity.compact));
    if (attended != null) {
      chips.add(Chip(
          label: Text(attended), visualDensity: VisualDensity.compact));
    }

    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: -8, children: chips);
  }
}

class _DayCard extends StatelessWidget {
  final String labelLeft;
  final String dateText;
  final String statusText;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;

  const _DayCard({
    required this.labelLeft,
    required this.dateText,
    required this.statusText,
    required this.color,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(labelLeft,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(dateText,
                          style: const TextStyle(color: Colors.black87)),
                      const SizedBox(height: 6),
                      Text(statusText,
                          style: TextStyle(color: _statusColorText(color))),
                      if (trailing != null) ...[
                        const SizedBox(height: 8),
                        trailing!,
                      ],
                    ],
                  ),
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  static Color _statusColorText(Color c) {
    if (c == Colors.red) return Colors.red.shade700;
    if (c == Colors.green) return Colors.green.shade700;
    return Colors.grey.shade700;
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
    final picked = await showDatePicker(
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
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(children: [Icon(Icons.error, color: Colors.orange), SizedBox(width: 8), Text("Peringatan", style: TextStyle(color: Colors.orange))]),
            content: const Text('Tanggal tersebut sudah memiliki entri logbook.'),
            actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("OK"))],
          )
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
        showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(children: [Icon(Icons.error, color: Colors.orange), SizedBox(width: 8), Text("Input Salah", style: TextStyle(color: Colors.orange))]),
              content: const Text('Durasi harus berupa angka (menit).'),
              actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("OK"))],
            )
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
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isEditing ? 'Ubah Logbook' : 'Isi Logbook',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      MaterialLocalizations.of(context)
                          .formatFullDate(_selected),
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: const Text('Ubah Tanggal'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _durationCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Durasi Kunjungan (menit)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Target tindakan (CO Partner) tercapai'),
                value: _co,
                onChanged: (v) => setState(() => _co = v),
              ),
              SwitchListTile(
                title: const Text('Absensi (Hadir)'),
                value: _att,
                onChanged: (v) => setState(() => _att = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      child: const Text('Simpan'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}