import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';
import '../core/weight_formatter.dart';

class ProfileInfantDetailPage extends StatefulWidget {
  const ProfileInfantDetailPage({super.key});

  @override
  State<ProfileInfantDetailPage> createState() => _ProfileInfantDetailPageState();
}

class _ProfileInfantDetailPageState extends State<ProfileInfantDetailPage> {
  final _api = ApiClient();
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  bool _isObserver = false;

  final _nameCtrl = TextEditingController();
  final _medicalDiagnosisCtrl = TextEditingController();
  final _weightInterventionCtrl = TextEditingController();
  final _weightDischargeCtrl = TextEditingController();

  DateTime? _birthDateLocal;
  DateTime? _admissionLocal;
  DateTime? _fincStartLocal;
  DateTime? _dischargeLocal;

  // Snapshot variables for in-place revert upon "Batal"
  String _origName = '';
  String _origDiagnosis = '';
  DateTime? _origBirthDate;
  DateTime? _origAdmission;
  DateTime? _origFincStart;
  DateTime? _origDischarge;
  String _origWeightIntervention = '';
  String _origWeightDischarge = '';

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
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  color: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "OK",
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                color: Color(0xFF10B981),
              ),
            ),
          )
        ],
      ),
    );
  }

  int? _parseIntOrNull(String text) {
    if (text.trim().isEmpty) return null;
    return int.tryParse(text.trim());
  }

  String _formatDateFull(DateTime d) =>
      DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(d.toLocal());

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profileRes = await _api.getMyProfile();
      final bool isObs = (profileRes != null && profileRes['isObserver'] == true);

      final m = await _api.getInfant();
      if (!mounted) return;

      final name = (m?['name'] as String?) ?? '';
      final diagnosis = (m?['medicalDiagnosis'] as String?) ?? '';

      final birthDate = ApiClient.parseDate(m?['birthDate']);
      final admission = ApiClient.parseDate(m?['admissionDate']);
      final finc = ApiClient.parseDate(m?['fincStart']);
      final discharge = ApiClient.parseDate(m?['dischargeDate']);

      final wInterv = m?['weightAtIntervention'];
      final wDisch = m?['weightAtDischarge'];

      final wIntervStr = (wInterv is int) ? wInterv.toString() : '';
      final wDischStr = (wDisch is int) ? wDisch.toString() : '';

      setState(() {
        _isObserver = isObs;
        _nameCtrl.text = name;
        _medicalDiagnosisCtrl.text = diagnosis;
        _birthDateLocal = birthDate;
        _admissionLocal = admission;
        _fincStartLocal = finc;
        _dischargeLocal = discharge;
        _weightInterventionCtrl.text = wIntervStr;
        _weightDischargeCtrl.text = wDischStr;

        // Snapshot original fetched state
        _origName = name;
        _origDiagnosis = diagnosis;
        _origBirthDate = birthDate;
        _origAdmission = admission;
        _origFincStart = finc;
        _origDischarge = discharge;
        _origWeightIntervention = wIntervStr;
        _origWeightDischarge = wDischStr;

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

  void _cancelEdit() {
    setState(() {
      _nameCtrl.text = _origName;
      _medicalDiagnosisCtrl.text = _origDiagnosis;
      _birthDateLocal = _origBirthDate;
      _admissionLocal = _origAdmission;
      _fincStartLocal = _origFincStart;
      _dischargeLocal = _origDischarge;
      _weightInterventionCtrl.text = _origWeightIntervention;
      _weightDischargeCtrl.text = _origWeightDischarge;
      _editing = false;
    });
  }

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime?> onChanged,
    required String helpText,
  }) async {
    if (_isObserver || !_editing) return;
    final now = DateTime.now();
    final initial = current ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      helpText: helpText,
      cancelText: 'Batal',
      confirmText: 'Pilih',
      locale: const Locale('id', 'ID'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF10B981),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      onChanged(DateTime(picked.year, picked.month, picked.day));
    }
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
      body['birthDate'] = ApiClient.formatDateTimeIso(_birthDateLocal);
      final diag = _medicalDiagnosisCtrl.text.trim();
      body['medicalDiagnosis'] = diag.isNotEmpty ? diag : null;
      body['admissionDate'] = ApiClient.formatDateTimeIso(_admissionLocal);
      body['fincStart'] = ApiClient.formatDateTimeIso(_fincStartLocal);
      body['dischargeDate'] = ApiClient.formatDateTimeIso(_dischargeLocal);
      body['weightAtIntervention'] = _parseIntOrNull(_weightInterventionCtrl.text);
      body['weightAtDischarge'] = _parseIntOrNull(_weightDischargeCtrl.text);

      await _api.upsertInfant(body);
      await _load();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
      });

      await _showDialogInfo("Berhasil", "Data Bayi berhasil disimpan.");
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (e is ApiError && e.status == 0) {
        _showDialogInfo("Gagal Simpan", "Tidak ada internet. Data gagal disimpan.", isError: true);
      } else {
        _showDialogInfo("Gagal", "Gagal menyimpan data: $e", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_editing && !_saving,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _cancelEdit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Data Bayi (Program FINC)',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
          actions: [
            if (!_isObserver && !_editing)
              TextButton.icon(
                onPressed: _loading ? null : () => setState(() => _editing = true),
                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF10B981)),
                label: const Text(
                  'Ubah Data',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            if (_editing)
              TextButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 18),
                label: const Text(
                  'Simpan',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
          ],
        ),
        body: _loading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircularProgressIndicator(color: Color(0xFF10B981)),
                    SizedBox(height: 16),
                    Text(
                      'Memuat data bayi...',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                color: const Color(0xFF10B981),
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isObserver)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBAE6FD)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.visibility_outlined, color: Color(0xFF0EA5E9), size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Mode Pantau: Read-Only (Hanya dapat melihat data).",
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: Color(0xFF072846),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // FINC Start Reminder Banner
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B), size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Tanggal Mulai FINC diperlukan untuk mengaktifkan jadwal Logbook 14 hari.',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: Color(0xFF78350F),
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Section 1: Identitas & Diagnosis Klinis
                      _buildSectionCard(
                        title: 'Identitas & Diagnosis',
                        icon: Icons.child_friendly_rounded,
                        children: [
                          if (_editing) ...[
                            _buildTextField(
                              c: _nameCtrl,
                              label: 'Nama Bayi',
                              hint: 'Masukkan nama bayi',
                            ),
                            const SizedBox(height: 12),
                            _buildDateRow(
                              label: 'Tanggal Lahir Bayi (DOB)',
                              value: _birthDateLocal,
                              onPick: () => _pickDate(
                                current: _birthDateLocal,
                                onChanged: (d) => setState(() => _birthDateLocal = d),
                                helpText: 'Pilih Tanggal Lahir Bayi',
                              ),
                              onClear: () => setState(() => _birthDateLocal = null),
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              c: _medicalDiagnosisCtrl,
                              label: 'Diagnosis Medis',
                              hint: 'Diagnosis medis bayi (misal: BBLR, Asfiksia, dll)',
                              maxLines: 2,
                            ),
                          ] else ...[
                            _buildViewRow('Nama Bayi', _nameCtrl.text),
                            _buildViewRow(
                              'Tanggal Lahir (DOB)',
                              _birthDateLocal != null ? _formatDateFull(_birthDateLocal!) : '-',
                            ),
                            _buildViewRow('Diagnosis Medis', _medicalDiagnosisCtrl.text, isLast: true),
                          ],
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Section 2: Jadwal Perawatan Klinis
                      _buildSectionCard(
                        title: 'Jadwal Perawatan Klinis',
                        icon: Icons.calendar_month_rounded,
                        children: [
                          if (_editing) ...[
                            _buildDateRow(
                              label: 'Tanggal Masuk (Admission)',
                              value: _admissionLocal,
                              onPick: () => _pickDate(
                                current: _admissionLocal,
                                onChanged: (d) => setState(() => _admissionLocal = d),
                                helpText: 'Pilih Tanggal Masuk',
                              ),
                              onClear: () => setState(() => _admissionLocal = null),
                            ),
                            const SizedBox(height: 12),
                            _buildDateRow(
                              label: 'Tanggal Mulai FINC *',
                              value: _fincStartLocal,
                              isRequired: true,
                              onPick: () => _pickDate(
                                current: _fincStartLocal,
                                onChanged: (d) => setState(() => _fincStartLocal = d),
                                helpText: 'Pilih Tanggal Mulai FINC',
                              ),
                              onClear: () => setState(() => _fincStartLocal = null),
                            ),
                            const SizedBox(height: 12),
                            _buildDateRow(
                              label: 'Tanggal Pulang (Discharge)',
                              value: _dischargeLocal,
                              onPick: () => _pickDate(
                                current: _dischargeLocal,
                                onChanged: (d) => setState(() => _dischargeLocal = d),
                                helpText: 'Pilih Tanggal Pulang',
                              ),
                              onClear: () => setState(() => _dischargeLocal = null),
                            ),
                          ] else ...[
                            _buildViewRow(
                              'Tanggal Masuk',
                              _admissionLocal != null ? _formatDateFull(_admissionLocal!) : '-',
                            ),
                            _buildViewRow(
                              'Mulai FINC',
                              _fincStartLocal != null ? _formatDateFull(_fincStartLocal!) : '-',
                            ),
                            _buildViewRow(
                              'Tanggal Pulang',
                              _dischargeLocal != null ? _formatDateFull(_dischargeLocal!) : '-',
                              isLast: true,
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Section 3: Metrik Pertumbuhan & Berat Badan
                      _buildSectionCard(
                        title: 'Metrik Berat Badan',
                        icon: Icons.monitor_weight_outlined,
                        children: [
                          if (_editing) ...[
                            _buildTextField(
                              c: _weightInterventionCtrl,
                              label: 'Berat Saat Intervensi (gram)',
                              hint: 'Contoh: 1800',
                              type: TextInputType.number,
                              suffixText: 'gram',
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              c: _weightDischargeCtrl,
                              label: 'Berat Saat Pulang (gram)',
                              hint: 'Contoh: 2200',
                              type: TextInputType.number,
                              suffixText: 'gram',
                            ),
                          ] else ...[
                            _buildViewRow(
                              'Berat Intervensi',
                              _weightInterventionCtrl.text.isNotEmpty ? WeightFormatter.formatGrams(int.tryParse(_weightInterventionCtrl.text)) : '-',
                            ),
                            _buildViewRow(
                              'Berat Pulang',
                              _weightDischargeCtrl.text.isNotEmpty ? WeightFormatter.formatGrams(int.tryParse(_weightDischargeCtrl.text)) : '-',
                              isLast: true,
                            ),
                          ],
                        ],
                      ),

                      if (_editing) ...[
                        const SizedBox(height: 24),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                onPressed: _saving ? null : _save,
                                child: _saving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Text(
                                        'Simpan Perubahan',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 15),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF475569),
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _saving ? null : _cancelEdit,
                                child: const Text(
                                  'Batal',
                                  maxLines: 1,
                                  style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 15),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        border: Border.fromBorderSide(BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Color(0x04000000),
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: const Color(0xFF10B981)),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildViewRow(String label, String value, {bool isLast = false}) {
    final displayVal = value.trim().isEmpty ? '-' : value.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              displayVal,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController c,
    required String label,
    TextInputType? type,
    String? hint,
    String? suffixText,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return TextField(
      controller: c,
      keyboardType: type,
      maxLines: maxLines,
      enabled: enabled,
      style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffixText,
        suffixStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
        labelStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF475569)),
        hintStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF1F5F9)),
        ),
      ),
    );
  }

  Widget _buildDateRow({
    required String label,
    required DateTime? value,
    required VoidCallback onPick,
    required VoidCallback onClear,
    bool isRequired = false,
  }) {
    final disabled = _isObserver || !_editing;
    final dateStr = value != null ? _formatDateFull(value) : 'Belum dipilih';

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          color: isRequired ? const Color(0xFFB45309) : const Color(0xFF475569),
          fontWeight: isRequired ? FontWeight.w600 : FontWeight.w400,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isRequired && value == null ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              dateStr,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: value != null ? FontWeight.w600 : FontWeight.w400,
                color: value != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
              ),
            ),
          ),
          if (!disabled)
            SizedBox(
              height: 38,
              child: TextButton.icon(
                onPressed: onPick,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  foregroundColor: const Color(0xFF10B981),
                ),
                icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                label: const Text('Pilih', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
          if (value != null && !disabled)
            SizedBox(
              width: 32,
              height: 38,
              child: IconButton(
                onPressed: onClear,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
              ),
            ),
        ],
      ),
    );
  }
}