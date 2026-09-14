import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../routes.dart';

class NurseAggPage extends StatefulWidget {
  const NurseAggPage({super.key});

  @override
  State<NurseAggPage> createState() => _NurseAggPageState();
}

class _NurseAggPageState extends State<NurseAggPage> with WidgetsBindingObserver {
  final _api = ApiClient();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _patients = [];

  String? _unassigningId;
  String _filterStatus = 'all'; // 'all', 'active', 'completed'
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  // Helper Alert Dialog with styled design
  Future<void> _showInfoDialog(String title, String message, {bool isError = false}) {
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
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                color: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
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
            child: const Text("OK", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.nurseGetPatients();
      if (!mounted) return;
      setState(() {
        _patients = items.map((e) => (e as Map).cast<String, dynamic>()).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (e is ApiError && e.status == 0) {
          _error = 'Tidak ada koneksi internet.\nPeriksa jaringan Anda.';
        } else {
          _error = '$e';
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _asString(dynamic v) => v?.toString().trim() ?? '';

  String _patientIdOf(Map<String, dynamic> p) {
    return _asString(p['id'] ?? p['patientId'] ?? p['userId']);
  }

  String _motherNameOf(Map<String, dynamic> p) {
    final name = p['name'] as String?;
    if (name != null && name.isNotEmpty && name != '-') return name;
    final profile = (p['profile'] as Map?)?.cast<String, dynamic>();
    final byProfile = (profile?['motherName'] as String?)?.trim();
    if (byProfile != null && byProfile.isNotEmpty) return byProfile;
    final email = p['email'] as String?;
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'Ibu';
  }

  String _babyNameOf(Map<String, dynamic> p) {
    final iName = p['infantName'] as String?;
    if (iName != null && iName.isNotEmpty) return iName;

    final profile = (p['profile'] as Map?)?.cast<String, dynamic>();
    final byProfile = (profile?['babyName'] as String?)?.trim();
    if (byProfile != null && byProfile.isNotEmpty) return byProfile;

    final infant = (p['infant'] as Map?)?.cast<String, dynamic>();
    final byInfant = (infant?['name'] as String?)?.trim();
    if (byInfant != null && byInfant.isNotEmpty) return byInfant;

    if (profile != null && profile['infant'] is Map) {
      final nestedInfant = profile['infant'] as Map;
      if (nestedInfant['name'] != null) return nestedInfant['name'];
    }
    return 'Bayi';
  }

  int _logbookCountOf(Map<String, dynamic> p) {
    if (p['logbookCount'] is int) return p['logbookCount'];
    return 0;
  }

  int _journalCountOf(Map<String, dynamic> p) {
    if (p['journalCount'] is int) return p['journalCount'];
    return 0;
  }

  bool _isCompleted(Map<String, dynamic> p) {
    Map<String, dynamic>? infantData;
    if (p['infant'] != null && p['infant'] is Map) {
      infantData = (p['infant'] as Map).cast<String, dynamic>();
    } else if (p['profile'] is Map) {
      final prof = (p['profile'] as Map).cast<String, dynamic>();
      if (prof['infant'] is Map) {
        infantData = (prof['infant'] as Map).cast<String, dynamic>();
      }
    }

    if (infantData == null) return false;
    final discharge = infantData['dischargeDate'];
    return discharge != null && discharge.toString().trim().isNotEmpty;
  }

  // Filtered patients getter
  List<Map<String, dynamic>> get _filteredPatients {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _patients.where((p) {
      final baby = _babyNameOf(p).toLowerCase();
      final mother = _motherNameOf(p).toLowerCase();
      final matchesQuery = query.isEmpty || baby.contains(query) || mother.contains(query);

      final isDone = _isCompleted(p);
      if (_filterStatus == 'active') return matchesQuery && !isDone;
      if (_filterStatus == 'completed') return matchesQuery && isDone;
      return matchesQuery;
    }).toList();
  }

  void _openDetail(String pid, String tab) {
    if (pid.isEmpty) {
      _showInfoDialog("Error", "ID pasien tidak tersedia", isError: true);
      return;
    }
    Navigator.pushNamed(
      context,
      Routes.nursePatientDetail,
      arguments: {'patientId': pid, 'tab': tab},
    ).then((_) {
      _load();
    });
  }

  Future<void> _confirmUnassign(Map<String, dynamic> p) async {
    final pid = _patientIdOf(p);
    final name = _motherNameOf(p);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Lepas Pasien?',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        content: Text(
          'Pasien "$name" akan dilepas dari daftar tanggung jawab Anda. Data logbook dan jurnal tetap tersimpan.',
          style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lepas', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (ok == true) {
      setState(() => _unassigningId = pid);
      try {
        await _api.nurseUnassignPatient(pid);
        if (!mounted) return;

        setState(() {
          _patients.removeWhere((e) => _patientIdOf(e) == pid);
          _unassigningId = null;
        });

        _showInfoDialog("Berhasil", "Pasien berhasil dilepas dari daftar binaan.");
      } catch (e) {
        if (!mounted) return;
        setState(() => _unassigningId = null);

        if (e is ApiError && e.status == 0) {
          _showInfoDialog("Gagal Lepas", "Tidak ada koneksi internet. Gagal melepas pasien.", isError: true);
        } else {
          _showInfoDialog("Gagal", "Gagal melepas pasien: $e", isError: true);
        }
      }
    }
  }

  Widget _buildMetricsHeader() {
    final total = _patients.length;
    final active = _patients.where((p) => !_isCompleted(p)).length;
    final completed = _patients.where((p) => _isCompleted(p)).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.analytics_rounded, size: 20, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text(
                'Ringkasan Pasien Binaan',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricChip(
                  label: 'Total Pasien',
                  value: '$total',
                  bgColor: const Color(0xFFD1FAE5),
                  textColor: const Color(0xFF064E3B),
                  icon: Icons.people_alt_rounded,
                  iconColor: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricChip(
                  label: 'Perawatan',
                  value: '$active',
                  bgColor: const Color(0xFFE0F2FE),
                  textColor: const Color(0xFF072846),
                  icon: Icons.local_hospital_rounded,
                  iconColor: const Color(0xFF0EA5E9),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricChip(
                  label: 'Selesai',
                  value: '$completed',
                  bgColor: const Color(0xFFFEF3C7),
                  textColor: const Color(0xFF78350F),
                  icon: Icons.check_circle_rounded,
                  iconColor: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterAndSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Search TextField
          TextField(
            controller: _searchCtrl,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Cari nama bayi / ibu...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          const SizedBox(height: 12),

          // Status Filter Segment Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterSegmentChip(
                  label: 'Semua',
                  count: _patients.length,
                  isSelected: _filterStatus == 'all',
                  onTap: () => setState(() => _filterStatus = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterSegmentChip(
                  label: 'Dalam Perawatan',
                  count: _patients.where((p) => !_isCompleted(p)).length,
                  isSelected: _filterStatus == 'active',
                  onTap: () => setState(() => _filterStatus = 'active'),
                ),
                const SizedBox(width: 8),
                _FilterSegmentChip(
                  label: 'Selesai / Pulang',
                  count: _patients.where((p) => _isCompleted(p)).length,
                  isSelected: _filterStatus == 'completed',
                  onTap: () => setState(() => _filterStatus = 'completed'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
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
              const Icon(Icons.wifi_off_rounded, size: 56, color: Color(0xFF94A3B8)),
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
                  color: Color(0xFFEF4444),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _load,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(
                  'Coba Lagi',
                  style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
                ),
              )
            ],
          ),
        ),
      );
    }

    final list = _filteredPatients;

    if (list.isEmpty) {
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
                  Icons.people_outline_rounded,
                  size: 36,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _searchCtrl.text.isNotEmpty || _filterStatus != 'all'
                    ? 'Pasien Tidak Ditemukan'
                    : 'Belum Ada Pasien Binaan',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _searchCtrl.text.isNotEmpty || _filterStatus != 'all'
                    ? 'Coba sesuaikan kata kunci pencarian atau filter status pasien Anda.'
                    : 'Pasien yang Anda assign akan muncul di daftar ini.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Color(0xFF475569),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final p = list[i];
        final pid = _patientIdOf(p);
        final mName = _motherNameOf(p);
        final bName = _babyNameOf(p);
        final lc = _logbookCountOf(p);
        final jc = _journalCountOf(p);
        final isDone = _isCompleted(p);
        final isUnassigning = _unassigningId == pid;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F0F172A),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient Info Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar Badge
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          bName.isNotEmpty ? bName[0].toUpperCase() : 'B',
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Names Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bName,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF475569)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Ibu: $mName',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: Color(0xFF475569),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Unassign Action Button / Loading
                    isUnassigning
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Color(0xFFEF4444), strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.link_off_rounded, color: Color(0xFFEF4444), size: 22),
                            onPressed: () => _confirmUnassign(p),
                            tooltip: 'Lepas Pasien',
                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          ),
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: Color(0xFFF1F5F9), height: 1),
                ),

                // Status & Counts Row
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(text: 'Logbook: $lc', icon: Icons.edit_note_rounded),
                    _Pill(text: 'Jurnal: $jc', icon: Icons.menu_book_rounded),
                    _Pill(
                      text: isDone ? 'Selesai' : 'Perawatan',
                      color: isDone ? const Color(0xFFFEF3C7) : const Color(0xFFE0F2FE),
                      textColor: isDone ? const Color(0xFF78350F) : const Color(0xFF072846),
                      icon: isDone ? Icons.check_circle_outline_rounded : Icons.local_hospital_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 4-Tile Action Grid
                Row(
                  children: [
                    Expanded(
                      child: _GridActionButton(
                        icon: Icons.edit_note_rounded,
                        label: 'Logbook',
                        onTap: () => _openDetail(pid, 'logbook'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _GridActionButton(
                        icon: Icons.menu_book_rounded,
                        label: 'Jurnal',
                        onTap: () => _openDetail(pid, 'journal'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _GridActionButton(
                        icon: Icons.assignment_turned_in_rounded,
                        label: 'Evaluasi',
                        onTap: () => _openDetail(pid, 'evaluasi'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _GridActionButton(
                        icon: Icons.person_rounded,
                        label: 'Detail',
                        onTap: () => _openDetail(pid, 'profile'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pasien Binaan',
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
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: const Color(0xFF10B981),
          child: Column(
            children: [
              if (!_loading && _error == null && _patients.isNotEmpty) ...[
                _buildMetricsHeader(),
                _buildFilterAndSearchBar(),
                const SizedBox(height: 8),
              ],
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget Metric Summary Chip
class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color bgColor;
  final Color textColor;
  final IconData icon;
  final Color iconColor;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.bgColor,
    required this.textColor,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// Widget Filter Segment Chip
class _FilterSegmentChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterSegmentChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10B981) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF064E3B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget Pill Chip
class _Pill extends StatelessWidget {
  final String text;
  final Color? color;
  final Color? textColor;
  final IconData? icon;

  const _Pill({required this.text, this.color, this.textColor, this.icon});

  @override
  Widget build(BuildContext context) {
    final bg = color ?? const Color(0xFFF1F5F9);
    final fg = textColor ?? const Color(0xFF475569);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(fontFamily: 'Inter', color: fg, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// Widget Tombol Grid (48dp height minimum touch target)
class _GridActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GridActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: const Color(0xFF10B981)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}