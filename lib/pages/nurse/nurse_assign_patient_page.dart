import 'package:flutter/material.dart';
import '../../services/api_client.dart';

class NurseAssignPatientPage extends StatefulWidget {
  const NurseAssignPatientPage({super.key});

  @override
  State<NurseAssignPatientPage> createState() => _NurseAssignPatientPageState();
}

class _NurseAssignPatientPageState extends State<NurseAssignPatientPage> {
  final _api = ApiClient();

  bool _loading = true;
  bool _initialLoaded = false;
  String? _error;

  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _patients = [];
  String? _assigningId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Helper Alert Dialog
  Future<void> _showResultDialog(String title, String message, bool isSuccess) async {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: isSuccess ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(color: isSuccess ? Colors.green : Colors.red),
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

  Future<void> _load({String query = ''}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _api.nurseGetAssignablePatients(
        q: query.isEmpty ? null : query,
      );

      final list = items
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

      if (!mounted) return;
      setState(() {
        _patients = list;
        _loading = false;
        _initialLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (e is ApiError && e.status == 0) {
          _error = 'Tidak ada koneksi internet.\nPeriksa jaringan Anda.';
        } else {
          _error = '$e';
        }
        _loading = false;
        _initialLoaded = true;
      });
    }
  }

  String _displayName(Map<String, dynamic> p) {
    final name = p['name'] as String?;
    if (name != null && name.trim().isNotEmpty && name != '-') {
      return name.trim();
    }

    final mName = p['motherName'] as String?;
    if (mName != null && mName.trim().isNotEmpty) return mName.trim();

    final profile = (p['profile'] as Map?)?.cast<String, dynamic>();
    final profName = profile?['motherName'] as String?;
    if (profName != null && profName.trim().isNotEmpty) return profName.trim();

    final email = p['email'] as String?;
    if (email != null && email.isNotEmpty) return email.split('@').first;

    return 'Tanpa Nama';
  }

  String _displayInfant(Map<String, dynamic> p) {
    String? baby = p['infantName'] as String?;

    if (baby == null || baby.isEmpty) {
      final profile = (p['profile'] as Map?)?.cast<String, dynamic>();
      final infant = (profile?['infant'] as Map?)?.cast<String, dynamic>();
      baby = infant?['name'] as String?;
    }

    if (baby != null && baby.isNotEmpty) return 'Bayi: $baby';
    return '';
  }

  String _displayPhone(Map<String, dynamic> p) {
    final phone = (p['phone'] as String?) ?? '';
    return phone;
  }

  Future<void> _openAssignConfirm(Map<String, dynamic> patient) async {
    final name = _displayName(patient);
    final phone = _displayPhone(patient);
    final id = (patient['id'] as String?) ?? '';

    if (id.isEmpty) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: MediaQuery.of(ctx).viewInsets,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                children: [
                  Text(
                    'Assign Pasien ke Perawat Ini? ',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'No. WhatsApp: $phone',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Pasien ini akan menjadi tanggung jawab Anda.\n'
                        'Pastikan data benar sebelum konfirmasi.',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _assigningId == id
                              ? null
                              : () async {
                            Navigator.pop(ctx);
                            await _assignPatient(id, name);
                          },
                          child: const Text('Assign'),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _assignPatient(String patientId, String name) async {
    setState(() => _assigningId = patientId);
    try {
      await _api.nurseAssignPatient(patientId);

      if (!mounted) return;
      setState(() {
        _patients.removeWhere((e) => e['id'] == patientId);
        _assigningId = null;
      });

      await _showResultDialog(
        "Berhasil",
        'Pasien "$name" berhasil ditambahkan ke daftar binaan Anda.',
        true,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _assigningId = null);

      String msg = '$e';

      if (e is ApiError && e.status == 0) {
        msg = "Tidak ada koneksi internet. Gagal assign pasien.";
      } else if (msg.contains('sudah memiliki perawat') || msg.contains('sudah terdaftar')) {
        msg = 'Gagal: Pasien tersebut sudah memiliki perawat.';
        _load(query: _searchCtrl.text);
      }

      await _showResultDialog("Gagal", msg, false);
    }
  }

  Widget _buildBody() {
    if (_loading && !_initialLoaded) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Gagal memuat data', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => _load(query: _searchCtrl.text), child: const Text('Coba Lagi'))
          ],
        ),
      );
    }

    if (_patients.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Tidak ada pasien baru yang perlu di-assign.\n'
                'Semua pasien aktif saat ini sudah memiliki perawat.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(query: _searchCtrl.text),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _patients.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final p = _patients[index];
          final name = _displayName(p);
          final baby = _displayInfant(p);
          final phone = _displayPhone(p);
          final id = (p['id'] as String?) ?? '';

          return ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => _openAssignConfirm(p),
            leading: const CircleAvatar(child: Icon(Icons.person_add)),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (baby.isNotEmpty) Text(baby),
                if (phone.isNotEmpty) Text(phone),
              ],
            ),
            trailing: _assigningId == id
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_circle_outline, size: 24, color: Colors.blue),
          );
        },
      ),
    );
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim();
    _load(query: q);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Pasien'),
        actions: [IconButton(onPressed: () => _load(query: _searchCtrl.text), icon: const Icon(Icons.refresh))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _onSearchChanged(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Cari nama / WhatsApp',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    _onSearchChanged();
                  },
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }
}