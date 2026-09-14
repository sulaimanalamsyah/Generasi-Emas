import 'dart:async';
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
  Timer? _debounce;
  List<Map<String, dynamic>> _patients = [];
  String? _assigningId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // Helper Alert Dialog with styled design
  Future<void> _showResultDialog(String title, String message, bool isSuccess) async {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.error_outline,
              color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF0F172A)),
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
        q: query.trim().isEmpty ? null : query.trim(),
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

  String _displayInfantRaw(Map<String, dynamic> p) {
    String? baby = p['infantName'] as String?;

    if (baby == null || baby.isEmpty) {
      final profile = (p['profile'] as Map?)?.cast<String, dynamic>();
      final infant = (profile?['infant'] as Map?)?.cast<String, dynamic>();
      baby = infant?['name'] as String?;
    }

    return (baby != null && baby.trim().isNotEmpty) ? baby.trim() : '';
  }

  String _displayPhone(Map<String, dynamic> p) {
    final phone = (p['phone'] as String?) ?? '';
    return phone;
  }

  Future<void> _openAssignConfirm(Map<String, dynamic> patient) async {
    final name = _displayName(patient);
    final baby = _displayInfantRaw(patient);
    final phone = _displayPhone(patient);
    final id = (patient['id'] as String?) ?? '';

    if (id.isEmpty) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: MediaQuery.of(ctx).viewInsets,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Bottom Sheet Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Konfirmasi Assign Pasien',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Structured Patient & Infant Summary Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Mother Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD1FAE5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.person_rounded, size: 20, color: Color(0xFF10B981)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    phone.isNotEmpty ? 'No. WhatsApp: $phone' : 'No. WhatsApp: Tidak tersedia',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                        ),

                        // Infant Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.child_care_rounded, size: 20, color: Color(0xFF0284C7)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Nama Bayi',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  if (baby.isNotEmpty)
                                    Text(
                                      baby,
                                      style: const TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF072846),
                                      ),
                                    )
                                  else
                                    const Text(
                                      'Data bayi belum diisi',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  const Text(
                    'Pasien ini akan menjadi tanggung jawab binaan Anda.\nPastikan data benar sebelum konfirmasi.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),

                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF475569),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text(
                              'Batal',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _assigningId == id
                                ? null
                                : () async {
                                    Navigator.pop(ctx);
                                    await _assignPatient(id, name);
                                  },
                            child: const Text(
                              'Assign Pasien',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
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
    if (_loading && !_initialLoaded) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF10B981)),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_off_rounded, size: 32, color: Color(0xFFEF4444)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Gagal Memuat Data',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () => _load(query: _searchCtrl.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Coba Lagi',
                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
                  ),
                ),
              )
            ],
          ),
        ),
      );
    }

    if (_patients.isEmpty) {
      final isSearching = _searchCtrl.text.trim().isNotEmpty;

      if (isSearching) {
        // Redesigned Empty Search Result State
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.search_off_rounded,
                    size: 36,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Pasien Tidak Ditemukan',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tidak ada data ibu, nomor WhatsApp, atau nama bayi yang cocok dengan kata kunci "${_searchCtrl.text.trim()}".',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _debounce?.cancel();
                      _searchCtrl.clear();
                      _load();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: const Text(
                      'Reset Pencarian',
                      style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // No Assignable Patients at all
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
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
                child: const Icon(
                  Icons.assignment_turned_in_rounded,
                  size: 36,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Semua Pasien Ter-assign',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Saat ini tidak ada pasien baru yang perlu di-assign.\nSemua pasien aktif sudah memiliki perawat binaan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Color(0xFF475569),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => _load(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Segarkan Data',
                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(query: _searchCtrl.text),
      color: const Color(0xFF10B981),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemCount: _patients.length,
        itemBuilder: (context, index) {
          final p = _patients[index];
          final name = _displayName(p);
          final baby = _displayInfantRaw(p);
          final phone = _displayPhone(p);
          final id = (p['id'] as String?) ?? '';
          final bool isAssigningThis = _assigningId == id;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
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
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openAssignConfirm(p),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Avatar Badge
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_add_rounded,
                        color: Color(0xFF10B981),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Patient Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (baby.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.child_care_rounded,
                                    size: 14,
                                    color: Color(0xFF0284C7),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      'Bayi: $baby',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF072846),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (phone.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.phone_android_rounded, size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  phone,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Action Button / Loading Indicator
                    isAssigningThis
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2.5),
                          )
                        : Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'Assign',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _onSearchInputChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _load(query: query.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final showRefreshBar = _loading && _initialLoaded;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Assign Pasien',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Perbarui Data',
            onPressed: () => _load(query: _searchCtrl.text),
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Container
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onChanged: _onSearchInputChanged,
                onSubmitted: (q) {
                  _debounce?.cancel();
                  _load(query: q.trim());
                },
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Cari nama ibu, nomor WhatsApp, atau bayi...',
                  hintStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8), size: 20),
                          onPressed: () {
                            _debounce?.cancel();
                            _searchCtrl.clear();
                            _load();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            ),

            // Non-blocking visual refresh indicator
            if (showRefreshBar)
              const LinearProgressIndicator(
                minHeight: 3,
                color: Color(0xFF10B981),
                backgroundColor: Color(0xFFD1FAE5),
              ),

            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }
}