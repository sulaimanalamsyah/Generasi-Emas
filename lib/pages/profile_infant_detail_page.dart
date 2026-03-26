import 'package:flutter/material.dart';
import '../services/api_client.dart';

class ProfileInfantDetailPage extends StatefulWidget {
  const ProfileInfantDetailPage({super.key});
  @override
  State<ProfileInfantDetailPage> createState() => _ProfileInfantDetailPageState();
}

class _ProfileInfantDetailPageState extends State<ProfileInfantDetailPage> {
  final _api = ApiClient();
  bool _loading = true;
  bool _saving = false;
  bool _isObserver = false;

  final _nameCtrl = TextEditingController();
  final _medicalDiagnosisCtrl = TextEditingController();
  final _weightInterventionCtrl = TextEditingController();
  final _weightDischargeCtrl = TextEditingController();

  DateTime? _admissionLocal;
  DateTime? _fincStartLocal;
  DateTime? _dischargeLocal;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _medicalDiagnosisCtrl.dispose();
    _weightInterventionCtrl.dispose();
    _weightDischargeCtrl.dispose();
    super.dispose();
  }

  Future<void> _showDialogInfo(String title, String message, {bool isError = false}) {
    return showDialog(context: context, builder: (ctx) => AlertDialog(title: Row(children: [Icon(isError ? Icons.error : Icons.check_circle, color: isError ? Colors.red : Colors.green), const SizedBox(width: 8), Text(title, style: TextStyle(color: isError ? Colors.red : Colors.green))]), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))]));
  }

  int? _parseIntOrNull(String text) {
    if(text.trim().isEmpty) return null;
    return int.tryParse(text.trim());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profileRes = await _api.getMyProfile();
      final bool isObs = (profileRes != null && profileRes['isObserver'] == true);

      final m = await _api.getInfant();
      if (!mounted) return;

      final name = (m?['name'] as String?) ?? '';
      final diagnosis = (m?['medicalDiagnosis'] as String?) ?? '';

      final admission = ApiClient.parseDate(m?['admissionDate']);
      final finc = ApiClient.parseDate(m?['fincStart']);
      final discharge = ApiClient.parseDate(m?['dischargeDate']);

      final wInterv = m?['weightAtIntervention'];
      final wDisch = m?['weightAtDischarge'];

      setState(() {
        _isObserver = isObs;
        _nameCtrl.text = name;
        _medicalDiagnosisCtrl.text = diagnosis;
        _admissionLocal = admission;
        _fincStartLocal = finc;
        _dischargeLocal = discharge;
        _weightInterventionCtrl.text = (wInterv is int) ? wInterv.toString() : '';
        _weightDischargeCtrl.text = (wDisch is int) ? wDisch.toString() : '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (e is ApiError && e.status == 0) {
        _showDialogInfo("Offline", "Gagal memuat data bayi. Periksa koneksi internet.", isError: true);
      }
    }
  }

  Future<void> _pickDate({required DateTime? current, required ValueChanged<DateTime?> onChanged, required String helpText}) async {
    if (_isObserver) return;
    final initial = current ?? DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2015), lastDate: DateTime(2100), helpText: helpText);
    if (picked != null && mounted) onChanged(DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _save() async {
    if (_isObserver) return;

    if (_fincStartLocal == null) {
      _showDialogInfo("Data Belum Lengkap", "Tanggal Mulai FINC wajib dipilih agar logbook aktif.", isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{};
      final name = _nameCtrl.text.trim();
      body['name'] = name.isNotEmpty ? name : null;
      final diag = _medicalDiagnosisCtrl.text.trim();
      body['medicalDiagnosis'] = diag.isNotEmpty ? diag : null;
      body['admissionDate'] = ApiClient.formatDateTimeIso(_admissionLocal);
      body['fincStart'] = ApiClient.formatDateTimeIso(_fincStartLocal);
      body['dischargeDate'] = ApiClient.formatDateTimeIso(_dischargeLocal);
      body['weightAtIntervention'] = _parseIntOrNull(_weightInterventionCtrl.text);
      body['weightAtDischarge'] = _parseIntOrNull(_weightDischargeCtrl.text);

      await _api.upsertInfant(body);
      if(!mounted) return;
      setState(() => _saving = false);

      await _showDialogInfo("Berhasil", "Data Bayi berhasil disimpan.");

      if (!mounted) return;
      Navigator.pop(context, true);

    } catch (e) {
      if(!mounted) return;
      setState(() => _saving = false);
      if (e is ApiError && e.status == 0) {
        _showDialogInfo("Gagal Simpan", "Tidak ada internet. Data gagal disimpan.", isError: true);
      } else {
        _showDialogInfo("Gagal", "Gagal menyimpan data: $e", isError: true);
      }
    }
  }

  Widget _buildDateRow({required String label, required DateTime? value, required VoidCallback onPick, required VoidCallback onClear}) {
    final disabled = _isObserver;
    return InputDecorator(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value == null ? 'Belum dipilih' : MaterialLocalizations.of(context).formatFullDate(value),
              style: TextStyle(color: value == null ? Theme.of(context).hintColor : null),
            ),
          ),
          if (!disabled) TextButton.icon(onPressed: onPick, icon: const Icon(Icons.edit_calendar_outlined), label: const Text('Pilih')),
          if (value != null && !disabled) IconButton(onPressed: onClear, icon: const Icon(Icons.clear)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Bayi'),
        actions: [
          if (!_isObserver)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Simpan'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isObserver)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(child: Text("Mode Pantau: Read-Only", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
              ]),
            ),

          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Tanggal Mulai FINC diperlukan untuk mengaktifkan Logbook 14 hari.', style: TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _nameCtrl,
            enabled: !_isObserver,
            decoration: const InputDecoration(labelText: 'Nama Bayi', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _medicalDiagnosisCtrl,
            enabled: !_isObserver,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Diagnosis Medis', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),

          _buildDateRow(label: 'Tanggal Masuk (admission)', value: _admissionLocal, onPick: () => _pickDate(current: _admissionLocal, onChanged: (d) => setState(() => _admissionLocal = d), helpText: '...'), onClear: () => setState(() => _admissionLocal = null)),
          const SizedBox(height: 12),
          _buildDateRow(label: 'Tanggal Mulai FINC *', value: _fincStartLocal, onPick: () => _pickDate(current: _fincStartLocal, onChanged: (d) => setState(() => _fincStartLocal = d), helpText: '...'), onClear: () => setState(() => _fincStartLocal = null)),
          const SizedBox(height: 12),
          _buildDateRow(label: 'Tanggal Pulang (discharge)', value: _dischargeLocal, onPick: () => _pickDate(current: _dischargeLocal, onChanged: (d) => setState(() => _dischargeLocal = d), helpText: '...'), onClear: () => setState(() => _dischargeLocal = null)),
          const SizedBox(height: 12),

          TextField(
            controller: _weightInterventionCtrl,
            enabled: !_isObserver,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Berat Saat Intervensi (gram)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _weightDischargeCtrl,
            enabled: !_isObserver,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Berat Saat Pulang (gram)', border: OutlineInputBorder()),
          ),

          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: Text(_isObserver ? 'Kembali' : 'Batal'),
          ),
        ],
      ),
    );
  }
}