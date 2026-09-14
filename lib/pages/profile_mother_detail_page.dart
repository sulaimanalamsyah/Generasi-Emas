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

  // HELPER Alert Dialog with styled design
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

        _motherName.text = (p['motherName'] as String?) ?? '';
        _age.text = (p['age']?.toString() ?? '');
        _parity.text = (p['parity']?.toString() ?? '');
        _gestWeeks.text = (p['gestationalWeeks']?.toString() ?? '');
        _birthWeight.text = (p['birthWeight']?.toString() ?? '');
        _address.text = (p['address'] as String?) ?? '';

        _education = p['education'] as String?;
        _job = p['job'] as String?;
        _delivery = p['delivery'] as String?;
        _gender = p['babyGender'] as String?;

        _babyName.text = (infant?['name'] as String?) ?? '';

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      if (e is ApiError && e.status == 0) {
        _showDialogInfo("Offline", "Gagal memuat data ibu. Periksa koneksi internet.", isError: true);
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
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Data Ibu & Bayi',
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
        body: _loading
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
                              onChanged: (v) => setState(() => _education = v),
                            ),
                            const SizedBox(height: 12),
                            _buildDropdown(
                              label: 'Pekerjaan',
                              value: _job,
                              items: const ['IRT', 'KARYAWAN', 'PNS', 'WIRASWASTA'],
                              onChanged: (v) => setState(() => _job = v),
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(c: _address, label: 'Alamat Lengkap', maxLines: 2, hint: 'Alamat tempat tinggal ibu'),
                          ] else ...[
                            _buildViewRow('Nama Lengkap', _motherName.text),
                            _buildViewRow('Usia Ibu', _age.text.isNotEmpty ? '${_age.text} tahun' : '-'),
                            _buildViewRow('Pendidikan Terakhir', _education ?? '-'),
                            _buildViewRow('Pekerjaan', _job ?? '-'),
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
                            _buildViewRow('Berat Lahir', _birthWeight.text.isNotEmpty ? '${_birthWeight.text} gram' : '-'),
                            _buildViewRow('Usia Kehamilan', _gestWeeks.text.isNotEmpty ? '${_gestWeeks.text} minggu' : '-', isLast: true),
                          ],
                        ],
                      ),

                      if (_editing) ...[
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: _loading ? null : _save,
                                  child: const Text(
                                    'Simpan Perubahan',
                                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 15),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
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
                                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 15),
                                  ),
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
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF475569)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isDense: true,
          value: value,
          icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF475569)),
          style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF0F172A)),
          items: items.map((e) {
            final display = itemLabels != null && itemLabels.containsKey(e) ? itemLabels[e]! : e;
            return DropdownMenuItem<String>(
              value: e,
              child: Text(display),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}