import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';
import '../core/storage.dart';
import '../core/weight_formatter.dart';
import '../widgets/common.dart';

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

  DateTime? _babyBirthDate;
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

  static const _kProfileCacheKey = 'patient_profile_detail_v1';

  Future<void> _showDialogInfo(String title, String message, {bool isError = false, InfoDialogVariant? variant}) {
    return showAppInfoDialog(
      context,
      title: title,
      message: message,
      isError: isError,
      variant: variant,
    );
  }

  void _applyProfileRes(Map<String, dynamic> res) {
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

      _motherName.text = (p['motherName'] as String?) ?? '';
      _age.text = (p['age']?.toString() ?? '');
      _parity.text = (p['parity']?.toString() ?? '');
      _gestWeeks.text = (p['gestationalWeeks']?.toString() ?? '');
      _birthWeight.text = ((infant?['birthWeight'] ?? p['birthWeight'])?.toString() ?? '');
      _address.text = (p['address'] as String?) ?? '';

      final rawEdu = p['education'] as String?;
      _education = (rawEdu == 'Perguruan Tinggi') ? 'PT' : rawEdu;

      final rawJob = p['job'] as String?;
      _job = (rawJob == 'Lainnya') ? 'LAINNYA' : rawJob;

      _delivery = p['delivery'] as String?;
      _gender = p['babyGender'] as String?;

      _babyName.text = (infant?['name'] as String?) ?? '';
      _babyBirthDate = ApiClient.parseDate(infant?['birthDate']);

      _loading = false;
    });
  }

  Future<void> _load() async {
    try {
      final res = await _api.getMyProfile();
      if (!mounted) return;

      if (res == null) {
        setState(() => _loading = false);
        return;
      }
      await Prefs.setCachedJson(_kProfileCacheKey, res);
      _applyProfileRes(res);
    } catch (e) {
      if (!mounted) return;

      if (e is ApiError && e.status == 0) {
        final cached = await Prefs.getCachedJson(_kProfileCacheKey);
        if (!mounted) return;
        if (cached is Map) {
          _applyProfileRes(Map<String, dynamic>.from(cached));
          showAppSnackBar(
            context,
            message: 'Menampilkan data terakhir tersimpan (mode luring).',
          );
          return;
        }
        setState(() => _loading = false);
        _showDialogInfo(
          "Luring",
          "Gagal memuat data ibu. Periksa koneksi internet.",
          variant: InfoDialogVariant.warning,
        );
      } else {
        setState(() => _loading = false);
      }
    }
  }

  int? _toInt(TextEditingController c) {
    final s = c.text.trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  Future<void> _save() async {
    if (_isObserver) return;

    if (_motherName.text.trim().isEmpty) {
      _showDialogInfo("Data Belum Lengkap", "Nama Ibu wajib diisi.", isError: true);
      return;
    }

    final rawBirthWeight = _birthWeight.text.trim();
    final birthWeight = _toInt(_birthWeight);
    if (rawBirthWeight.isNotEmpty && (birthWeight == null || birthWeight < 300 || birthWeight > 6000)) {
      _showDialogInfo(
        "Input Tidak Valid",
        "Berat Saat Lahir harus antara 300 hingga 6000 gram.",
        variant: InfoDialogVariant.warning,
      );
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
      'birthWeight': birthWeight,
      'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
      'birthDate': ApiClient.formatDateTimeIso(_babyBirthDate),
    };
    final bn = _babyName.text.trim();
    final bodyInfant = <String, dynamic>{
      'birthDate': ApiClient.formatDateTimeIso(_babyBirthDate),
    };
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

      await _showDialogInfo("Berhasil", "Data Profil Ibu & Bayi berhasil disimpan.");
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

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
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() => _editing = false);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: enicareAppBar(
          context,
          title: 'Data Ibu',
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
                onPressed: _loading ? null : _save,
                icon: const Icon(Icons.check_rounded, size: 18, color: Color(0xFF10B981)),
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
        body: SafeArea(
          top: false,
          child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
            : RefreshIndicator(
                color: const Color(0xFF10B981),
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                                  "Mode Pantau: Anda hanya dapat melihat data istri (Read-Only).",
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

                      // Section 1: Identitas Ibu
                      _buildSectionCard(
                        title: 'Identitas Ibu',
                        icon: Icons.person_outline_rounded,
                        children: [
                          if (_editing) ...[
                            _buildTextField(c: _motherName, label: 'Nama Ibu *', hint: 'Masukkan nama lengkap ibu'),
                            const SizedBox(height: 12),
                            _buildTextField(c: _age, label: 'Usia Ibu (tahun)', type: TextInputType.number, hint: 'Contoh: 28'),
                            const SizedBox(height: 12),
                            _buildDropdown(
                              label: 'Pendidikan Terakhir',
                              value: _education,
                              items: const ['SD', 'SMP', 'SMA', 'PT'],
                              itemLabels: const {
                                'SD': 'SD',
                                'SMP': 'SMP',
                                'SMA': 'SMA',
                                'PT': 'Perguruan Tinggi',
                              },
                              onChanged: (v) => setState(() => _education = v),
                            ),
                            const SizedBox(height: 12),
                            _buildDropdown(
                              label: 'Pekerjaan',
                              value: _job,
                              items: const ['IRT', 'KARYAWAN', 'PNS', 'WIRASWASTA', 'LAINNYA'],
                              itemLabels: const {
                                'IRT': 'IRT',
                                'KARYAWAN': 'Karyawan',
                                'PNS': 'PNS',
                                'WIRASWASTA': 'Wiraswasta',
                                'LAINNYA': 'Lainnya',
                              },
                              onChanged: (v) => setState(() => _job = v),
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(c: _address, label: 'Alamat Lengkap', maxLines: 2, hint: 'Alamat tempat tinggal ibu'),
                          ] else ...[
                            _buildViewRow('Nama Lengkap', _motherName.text),
                            _buildViewRow('Usia Ibu', _age.text.isNotEmpty ? '${_age.text} tahun' : '-'),
                            _buildViewRow(
                              'Pendidikan Terakhir',
                              _education == 'PT' ? 'Perguruan Tinggi' : (_education ?? '-'),
                            ),
                            _buildViewRow(
                              'Pekerjaan',
                              _job == 'LAINNYA' ? 'Lainnya' : (_job ?? '-'),
                            ),
                            _buildViewRow('Alamat Lengkap', _address.text, isLast: true),
                          ],
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Section 2: Riwayat Obstetri & Persalinan
                      _buildSectionCard(
                        title: 'Riwayat Obstetri & Persalinan',
                        icon: Icons.pregnant_woman_rounded,
                        children: [
                          if (_editing) ...[
                            _buildTextField(
                              c: _parity,
                              label: 'Jumlah Anak Lahir (Paritas)',
                              type: TextInputType.number,
                              hint: 'Contoh: 1',
                            ),
                            const SizedBox(height: 12),
                            _buildDropdown(
                              label: 'Jenis Persalinan',
                              value: _delivery,
                              items: const ['SPONTAN', 'SC', 'INDUKSI'],
                              onChanged: (v) => setState(() => _delivery = v),
                            ),
                          ] else ...[
                            _buildViewRow('Paritas (Jumlah Anak)', _parity.text.isNotEmpty ? '${_parity.text} anak' : '-'),
                            _buildViewRow('Jenis Persalinan', _delivery ?? '-', isLast: true),
                          ],
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Section 3: Informasi Bayi Terkait
                      _buildSectionCard(
                        title: 'Informasi Bayi Terkait',
                        icon: Icons.child_care_rounded,
                        children: [
                          if (_editing) ...[
                            _buildTextField(c: _babyName, label: 'Nama Bayi', hint: 'Masukkan nama bayi'),
                            const SizedBox(height: 12),
                            _buildDropdown(
                              label: 'Jenis Kelamin Bayi',
                              value: _gender,
                              items: const ['LAKI_LAKI', 'PEREMPUAN'],
                              itemLabels: const {'LAKI_LAKI': 'Laki-laki', 'PEREMPUAN': 'Perempuan'},
                              onChanged: (v) => setState(() => _gender = v),
                            ),
                            const SizedBox(height: 12),
                            _buildDateRow(
                              label: 'Tanggal Lahir Bayi (DOB)',
                              value: _babyBirthDate,
                              onPick: () => _pickDate(
                                current: _babyBirthDate,
                                onChanged: (d) => setState(() => _babyBirthDate = d),
                                helpText: 'Pilih Tanggal Lahir Bayi',
                              ),
                              onClear: () => setState(() => _babyBirthDate = null),
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              c: _birthWeight,
                              label: 'Berat Lahir (gram)',
                              type: TextInputType.number,
                              hint: 'Contoh: 2500',
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              c: _gestWeeks,
                              label: 'Usia Kehamilan saat Lahir (minggu)',
                              type: TextInputType.number,
                              hint: 'Contoh: 36',
                            ),
                          ] else ...[
                            _buildViewRow('Nama Bayi', _babyName.text),
                            _buildViewRow(
                              'Jenis Kelamin',
                              _gender == 'LAKI_LAKI'
                                  ? 'Laki-laki'
                                  : (_gender == 'PEREMPUAN' ? 'Perempuan' : (_gender ?? '-')),
                            ),
                            _buildViewRow(
                              'Tanggal Lahir',
                              _babyBirthDate != null
                                  ? DateFormat('d MMMM yyyy', 'id_ID').format(_babyBirthDate!)
                                  : '-',
                            ),
                            _buildViewRow('Berat Lahir', _birthWeight.text.isNotEmpty ? WeightFormatter.formatGrams(int.tryParse(_birthWeight.text)) : '-'),
                            _buildViewRow('Usia Kehamilan', _gestWeeks.text.isNotEmpty ? '${_gestWeeks.text} minggu' : '-', isLast: true),
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
                                onPressed: _loading ? null : _save,
                                child: const Text(
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
                                onPressed: () => setState(() => _editing = false),
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
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
          Expanded(
            flex: 4,
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
            flex: 5,
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
    int maxLines = 1,
  }) {
    return TextField(
      controller: c,
      keyboardType: type,
      maxLines: maxLines,
      style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
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
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    Map<String, String>? itemLabels,
    required ValueChanged<String?> onChanged,
  }) {
    final currentDisplay =
        (value != null && itemLabels != null && itemLabels.containsKey(value))
            ? itemLabels[value]!
            : (value != null && value.isNotEmpty ? value : 'Pilih $label');
    return EnicarePickerField(
      label: label,
      displayText: currentDisplay,
      isActive: value != null && value.isNotEmpty,
      onTap: () => showEnicareOptionSheet<String>(
        context,
        title: label,
        selectedValue: value,
        options: items.map((e) {
          final display =
              itemLabels != null && itemLabels.containsKey(e) ? itemLabels[e]! : e;
          return EnicarePickerOption<String>(value: e, label: display);
        }).toList(),
        onSelected: onChanged,
      ),
    );
  }

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime?> onChanged,
    required String helpText,
  }) async {
    if (_isObserver || !_editing) return;
    final now = DateTime.now();
    final initial = current ?? now;
    final picked = await showEnicareDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      helpText: helpText,
    );
    if (picked != null && mounted) {
      onChanged(DateTime(picked.year, picked.month, picked.day));
    }
  }

  Widget _buildDateRow({
    required String label,
    required DateTime? value,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final disabled = _isObserver || !_editing;
    final dateStr = value != null ? DateFormat('d MMMM yyyy', 'id_ID').format(value) : 'Belum dipilih';

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          color: Color(0xFF475569),
          fontWeight: FontWeight.w400,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Text(
            dateStr,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: value != null ? FontWeight.w600 : FontWeight.w400,
              color: value != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
            ),
          ),
          if (!disabled)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
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
                if (value != null)
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      onPressed: onClear,
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}