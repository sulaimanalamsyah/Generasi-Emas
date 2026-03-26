import 'package:flutter/material.dart';
import '../services/api_client.dart';

class ProfileMotherDetailPage extends StatefulWidget {
  const ProfileMotherDetailPage({super.key});
  @override
  State<ProfileMotherDetailPage> createState() => _ProfileMotherDetailPageState();
}

class _ProfileMotherDetailPageState extends State<ProfileMotherDetailPage> {
  final _api = ApiClient();
  bool _loading = true;
  bool _editing = false;
  bool _isObserver = false;

  // Text Controllers
  final _babyName = TextEditingController();
  final _motherName = TextEditingController();
  final _age = TextEditingController();
  final _parity = TextEditingController();
  final _gestWeeks = TextEditingController();
  final _birthWeight = TextEditingController();
  final _address = TextEditingController();

  String? _education;
  String? _job;
  String? _delivery;
  String? _gender;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _babyName.dispose();
    _motherName.dispose();
    _age.dispose();
    _parity.dispose();
    _gestWeeks.dispose();
    _birthWeight.dispose();
    _address.dispose();
    super.dispose();
  }

  // HELPER Alert Dialog
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

  Future<void> _load() async {
    try {
      final res = await _api.getMyProfile();
      if (!mounted) return;

      if (res == null) {
        setState(() => _loading = false);
        return;
      }

      final bool isObs = res['isObserver'] == true;

      final p = res['profile'] as Map<String, dynamic>?;
      if (p == null) {
        setState(() {
          _isObserver = isObs;
          _loading = false;
        });
        return;
      }

      final infant = (p['infant'] is Map) ? (p['infant'] as Map).cast<String, dynamic>() : null;

      setState(() {
        _isObserver = isObs;

        _motherName.text   = (p['motherName'] as String?) ?? '';
        _age.text          = (p['age']?.toString() ?? '');
        _parity.text       = (p['parity']?.toString() ?? '');
        _gestWeeks.text    = (p['gestationalWeeks']?.toString() ?? '');
        _birthWeight.text  = (p['birthWeight']?.toString() ?? '');
        _address.text      = (p['address'] as String?) ?? '';

        _education = p['education'] as String?;
        _job       = p['job'] as String?;
        _delivery  = p['delivery'] as String?;
        _gender    = p['babyGender'] as String?;

        _babyName.text = (infant?['name'] as String?) ?? '';

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      // HANDLING ERROR OFFLINE
      if (e is ApiError && e.status == 0) {
        _showDialogInfo("Offline", "Gagal memuat data ibu. Periksa koneksi internet.", isError: true);
      } else {

      }
    }
  }

  int? _toInt(TextEditingController c) {
    final s = c.text.trim();
    if (s.isEmpty) return null;
    final v = int.tryParse(s);
    return v;
  }

  Future<void> _save() async {
    if (_isObserver) return;

    // VALIDASI REQUIRED
    if (_motherName.text.trim().isEmpty) {
      _showDialogInfo("Data Belum Lengkap", "Nama Ibu wajib diisi.", isError: true);
      return;
    }

    final bodyProfile = <String, dynamic>{
      'motherName': _motherName.text.trim().isEmpty ? null : _motherName.text.trim(),
      'age': _toInt(_age),
      'education': _education,
      'job': _job,
      'parity': _toInt(_parity),
      'delivery': _delivery,
      'gestationalWeeks': _toInt(_gestWeeks),
      'babyGender': _gender,
      'birthWeight': _toInt(_birthWeight),
      'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
    };
    final bn = _babyName.text.trim();
    final bodyInfant = <String, dynamic>{};
    if (bn.isNotEmpty) bodyInfant['name'] = bn;

    setState(() => _loading = true);
    try {
      await Future.wait([
        _api.upsertMyProfile(bodyProfile),
        _api.upsertInfant(bodyInfant),
      ]);
      await _load();
      if (!mounted) return;
      setState(() {
        _editing = false;
        _loading = false;
      });

      _showDialogInfo("Berhasil", "Data Profil Ibu & Bayi berhasil disimpan.");

    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      // HANDLING ERROR OFFLINE
      if (e is ApiError && e.status == 0) {
        _showDialogInfo("Gagal Simpan", "Tidak ada internet. Data gagal disimpan.", isError: true);
      } else {
        _showDialogInfo("Gagal", "Gagal menyimpan data: $e", isError: true);
      }
    }
  }

  // Helper Widgets
  Widget _dd({required String label, required String? value, required List<String> items, required ValueChanged<String?> onChanged}) {
    final enabled = !_isObserver && _editing;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        enabled: enabled,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isDense: true,
          value: value,
          items: items.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))).toList(),
          onChanged: enabled ? onChanged : null,
          style: TextStyle(color: enabled ? Colors.black : Colors.black54),
        ),
      ),
    );
  }

  Widget _tf({required TextEditingController c, required String label, TextInputType? type}) {
    final enabled = !_isObserver && _editing;

    return TextField(
      controller: c,
      keyboardType: type,
      enabled: enabled,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // PopScope Logic
    return PopScope(
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() => _editing = false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Data Ibu & Bayi'),
          actions: [
            if (!_isObserver && !_editing)
              TextButton(
                onPressed: _loading ? null : () => setState(() => _editing = true),
                child: const Text('Ubah data'),
              ),
            if (_editing)
              TextButton(
                onPressed: _loading ? null : _save,
                child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isObserver)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(child: Text("Mode Pantau: Anda hanya dapat melihat data istri.", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),

              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Text("Informasi Bayi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
              ),
              _tf(c: _babyName, label: 'Nama Bayi'),
              const SizedBox(height: 12),
              _dd(label: 'Jenis Kelamin Bayi', value: _gender, items: const ['LAKI_LAKI', 'PEREMPUAN'], onChanged: (v) => setState(() => _gender = v)),
              const SizedBox(height: 12),
              _tf(c: _birthWeight, label: 'Berat Lahir (gram)', type: TextInputType.number),
              const SizedBox(height: 12),
              _tf(c: _gestWeeks, label: 'Usia Kehamilan (minggu)', type: TextInputType.number),

              const Divider(height: 40, thickness: 1),

              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Text("Informasi Ibu", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
              ),
              _tf(c: _motherName, label: 'Nama Ibu'),
              const SizedBox(height: 12),
              _tf(c: _age, label: 'Usia Ibu (tahun)', type: TextInputType.number),
              const SizedBox(height: 12),
              _dd(label: 'Pendidikan Terakhir', value: _education, items: const ['SD', 'SMP', 'SMA', 'PT'], onChanged: (v) => setState(() => _education = v)),
              const SizedBox(height: 12),
              _dd(label: 'Pekerjaan', value: _job, items: const ['IRT', 'KARYAWAN', 'PNS', 'WIRASWASTA'], onChanged: (v) => setState(() => _job = v)),
              const SizedBox(height: 12),
              _tf(c: _parity, label: 'Jumlah Anak Lahir (Paritas)', type: TextInputType.number),
              const SizedBox(height: 12),
              _dd(label: 'Jenis Persalinan', value: _delivery, items: const ['SPONTAN', 'SC', 'INDUKSI'], onChanged: (v) => setState(() => _delivery = v)),
              const SizedBox(height: 12),
              _tf(c: _address, label: 'Alamat Lengkap'),
              const SizedBox(height: 24),

              if (_editing)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : () => setState(() => _editing = false),
                    icon: const Icon(Icons.close),
                    label: const Text('Batal Ubah'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                  ),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}