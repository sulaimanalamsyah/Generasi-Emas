import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../routes.dart';
import '../core/storage.dart';

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

  String _formatDate(BuildContext ctx, DateTime d) {
    return MaterialLocalizations.of(ctx).formatFullDate(d.toLocal());
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    var nextHasInfant = _hasInfant;
    List<Map<String, dynamic>> nextItems = _items;

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
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('bayi') && msg.contains('belum ada')) {
        nextHasInfant = false;
        nextItems = const [];
      } else {
        if (mounted) {
          if (e is ApiError && e.status == 0) {
            _showDialogInfo("Offline", "Tidak dapat memuat jurnal. Periksa koneksi internet.", isError: true);
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _hasInfant = nextHasInfant;
          _items = nextItems;
          _loading = false;
        });
      }
    }
  }

  Future<void> _openAddJournalSheet() async {
    if (_isObserver) return;

    final result = await showModalBottomSheet<_JournalFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _AddJournalSheet(),
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

      await _showDialogInfo("Berhasil", "Jurnal harian berhasil ditambahkan.");
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
          _showDialogInfo("Gagal", "Gagal menambah jurnal: $e", isError: true);
        }
      }
    }
  }

  // ====== VIEW / EDIT JURNAL ======

  Future<void> _openEditJournalSheet(Map<String, dynamic> item) async {
    final date = ApiClient.parseDate(item['date']) ?? DateTime.now();
    final summary = (item['summary'] ?? '').toString();

    final result = await showModalBottomSheet<_JournalFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _EditJournalSheet(
        initialDate: date,
        initialSummary: summary,
        readOnly: _isObserver,
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
    final dateLabel = _formatDate(context, date);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Hapus jurnal?'),
          content: Text(
            'Jurnal bayi tanggal $dateLabel akan dihapus. Tindakan ini tidak dapat dibatalkan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    ) ?? false;

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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Text('Belum ada jurnal bayi.'),
            SizedBox(height: 8),
            Text(
              'Tarik untuk refresh.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoInfantBanner() {
    if (_hasInfant) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        elevation: 0,
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Data bayi belum ada',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      _isObserver
                          ? 'Mohon tunggu Ibu membuat data bayi di Profil.'
                          : 'Untuk menambah jurnal, silakan buat data bayi di halaman Profil.',
                      style: const TextStyle(color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    if (!_isObserver)
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.pushNamed(context, Routes.profile);
                          if (!mounted) return;
                          await _load();
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Buat Data Bayi di Profil'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_items.isEmpty) return _buildEmptyState();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (context, i) {
        final it = _items[i];
        final d = ApiClient.parseDate(it['date']);

        final title = d != null
            ? _formatDate(context, d)
            : '(tanpa tanggal)';
        final summary = (it['summary'] ?? '').toString();

        return ListTile(
          leading: const Icon(Icons.event_note),
          title: Text(title),
          subtitle: summary.isEmpty ? const Text('—') : Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () => _openEditJournalSheet(it),
          trailing: _isObserver
              ? null
              : PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _openEditJournalSheet(it);
                  break;
                case 'delete':
                  _confirmDeleteJournal(it);
                  break;
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'edit', child: Text('Ubah')),
              PopupMenuItem(value: 'delete', child: Text('Hapus')),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = _hasInfant && !_loading && !_isObserver;

    return Scaffold(
      appBar: AppBar(title: const Text('Jurnal Bayi')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _load,
        child: Column(
          children: [
            if (_isObserver && _hasInfant)
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 16),
                  color: Colors.blue.shade50,
                  child: Row(
                    children: [
                      const Icon(Icons.visibility,
                          size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                          "Mode Pantau: Anda hanya dapat melihat jurnal.",
                          style: TextStyle(
                              color: Colors.blue.shade800, fontSize: 12)),
                    ],
                  )),
            _buildNoInfantBanner(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
      floatingActionButton: canAdd
          ? FloatingActionButton(
        onPressed: _openAddJournalSheet,
        child: const Icon(Icons.add),
      )
          : null,
    );
  }
}

class _JournalFormResult {
  final DateTime date;
  final String summary;
  _JournalFormResult(this.date, this.summary);
}

class _AddJournalSheet extends StatefulWidget {
  const _AddJournalSheet();
  @override
  State<_AddJournalSheet> createState() => _AddJournalSheetState();
}

class _AddJournalSheetState extends State<_AddJournalSheet> {
  DateTime _date = DateTime.now();
  final _summary = TextEditingController();

  @override
  void dispose() {
    _summary.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDate: _date,
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
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
              const Text('Tambah Jurnal',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Tanggal',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Text(MaterialLocalizations.of(context)
                          .formatFullDate(_date.toLocal())),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Pilih'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _summary,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Ringkasan',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                          _JournalFormResult(_date, _summary.text),
                        );
                      },
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
            ],
          ),
        ),
      ),
    );
  }
}

class _EditJournalSheet extends StatefulWidget {
  final DateTime initialDate;
  final String? initialSummary;
  final bool readOnly;

  const _EditJournalSheet({
    required this.initialDate,
    this.initialSummary,
    this.readOnly = false,
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
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isReadOnly = widget.readOnly;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isReadOnly ? 'Detail Jurnal' : 'Ubah Jurnal',
                style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tanggal',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                child: Text(MaterialLocalizations.of(context)
                    .formatFullDate(_date.toLocal())),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _summary,
                readOnly: isReadOnly,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Ringkasan',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (!isReadOnly)
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(
                            context,
                            _JournalFormResult(_date, _summary.text),
                          );
                        },
                        child: const Text('Simpan Perubahan'),
                      ),
                    ),
                  if (!isReadOnly) const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(isReadOnly ? 'Tutup' : 'Batal'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}