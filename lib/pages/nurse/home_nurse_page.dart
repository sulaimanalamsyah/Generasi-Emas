import 'package:flutter/material.dart';
import '../../core/storage.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../routes.dart';
import '../../widgets/common.dart';
import 'nurse_assign_patient_page.dart';

class HomeNursePage extends StatefulWidget {
  const HomeNursePage({super.key});

  @override
  State<HomeNursePage> createState() => _HomeNursePageState();
}

class _HomeNursePageState extends State<HomeNursePage> {
  final _api = ApiClient();
  final _auth = AuthService();
  bool _loading = true;
  int _patientCount = 0;
  String _displayName = 'Perawat';
  bool _roleOk = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  // --- Helpers ---
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
          ),
        ],
      ),
    );
  }

  Future<void> _bootstrap() async {
    final role = await Prefs.getRole();
    if (role != 'nurse') {
      _roleOk = false;
      if (!mounted) return;

      await _showDialogInfo("Akses Ditolak", "Halaman ini khusus untuk akun Perawat.", isError: true);

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, Routes.login, (_) => false);
      return;
    }

    final name = await Prefs.getDisplayName();
    _displayName = _makeDoctorName(name ?? 'Perawat');

    try {
      final items = await _api.nurseGetPatients();
      if (!mounted) return;
      setState(() {
        _patientCount = items.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      if (e is ApiError && e.status == 0) {
        _showDialogInfo("Offline", "Tidak ada koneksi internet. Data pasien mungkin belum termuat.", isError: true);
      } else {
        _showDialogInfo("Gagal Memuat", "Gagal memuat data pasien: $e", isError: true);
      }
    }
  }

  String _makeDoctorName(String raw) {
    final n = raw.trim();
    if (n.toLowerCase().startsWith('dr.')) return 'Dr. ${n.substring(3).trim()}';
    if (n.toLowerCase().startsWith('dr ')) return 'Dr. ${n.substring(3).trim()}';
    return 'Dr. $n';
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final items = await _api.nurseGetPatients();
      if (!mounted) return;
      setState(() {
        _patientCount = items.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      if (e is ApiError && e.status == 0) {
        _showDialogInfo("Offline", "Tidak ada koneksi internet. Gagal memperbarui data.", isError: true);
      } else {
        _showDialogInfo("Gagal", "Gagal memuat data: $e", isError: true);
      }
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keluar?'),
        content: const Text('Anda akan keluar dari sesi perawat. Lanjutkan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    ) ?? false;

    if (!ok) return;

    await _auth.logout();

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, Routes.start, (_) => false);
  }

  Future<void> _openAssignPage() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const NurseAssignPatientPage(),
      ),
    );

    if (changed == true) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_roleOk) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: const [
            AppLogo(size: 32),
            SizedBox(width: 10),
            Text(
              'ENI Care',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Keluar',
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Color(0xFFEF4444), size: 24),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: const Color(0xFF10B981),
          child: _loading
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: const [
                    SizedBox(height: 100),
                    Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    // --- GREETING & PATIENT BANNER WITH EMBEDDED GUIDE CHIP ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5), // primary-container from DESIGN.md
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0F0F172A),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Greeting & Patient Count Column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Halo, $_displayName',
                                      style: const TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF064E3B), // on-primary-container
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.people_alt_outlined, size: 18, color: Color(0xFF064E3B)),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            'Pasien Binaan: $_patientCount Pasien',
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF064E3B),
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
                              const SizedBox(width: 12),

                              // Embedded Quick-Action Guide Chip (Min 48x48 dp touch target)
                              Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: () => Navigator.pushNamed(context, Routes.guide),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    constraints: const BoxConstraints(minHeight: 48),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.auto_stories_rounded, size: 18, color: Color(0xFF047857)),
                                        SizedBox(width: 6),
                                        Text(
                                          'Panduan',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF047857),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(color: Color(0x33064E3B), height: 1),
                          const SizedBox(height: 10),
                          // Pull-To-Refresh UX Hint
                          const Row(
                            children: [
                              Icon(Icons.arrow_downward_rounded, size: 14, color: Color(0xFF047857)),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Tarik ke bawah layar untuk memperbarui data',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // --- SECTION TITLE ---
                    const Text(
                      'Menu Utama Perawat',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // --- 4 SHORTCUT CARDS GRID ---
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.1,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _NurseMenuCard(
                          icon: Icons.person_add_alt_1_outlined,
                          title: 'Assign Pasien',
                          subtitle: 'Pilih pasien yang belum punya perawat',
                          onTap: _openAssignPage,
                        ),
                        _NurseMenuCard(
                          icon: Icons.diversity_3_outlined,
                          title: 'Pasien Binaan',
                          subtitle: 'Lihat data bayi, logbook, & jurnal per pasien',
                          onTap: () => Navigator.pushNamed(context, Routes.nurseAgg),
                        ),
                        _NurseMenuCard(
                          icon: Icons.forum_outlined,
                          title: 'Brainstorming',
                          subtitle: 'Diskusi & catatan kasus perawat',
                          onTap: () => Navigator.pushNamed(context, Routes.nurseBrainstorm),
                        ),
                        _NurseMenuCard(
                          icon: Icons.quiz_outlined,
                          title: 'Quiz Perawat',
                          subtitle: 'Evaluasi & pemahaman perawat',
                          onTap: () => Navigator.pushNamed(context, Routes.nurseQuiz),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
        ),
      ),
    );
  }
}

class _NurseMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NurseMenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 26, color: const Color(0xFF10B981)),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF475569),
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}