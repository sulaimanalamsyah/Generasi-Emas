import 'package:material_ui/material_ui.dart';
import '../../core/storage.dart';
import '../../services/api_client.dart';
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
  bool _loading = true;
  int _patientCount = 0;
  String _rawName = 'Perawat';
  String? _salutation;
  String _displayName = 'Perawat';
  bool _roleOk = true;

  static const _kNursePatientsCacheKey = 'nurse_patients_list_v1';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _showDialogInfo(String title, String message, {bool isError = false, InfoDialogVariant? variant}) {
    return showAppInfoDialog(
      context,
      title: title,
      message: message,
      isError: isError,
      variant: variant,
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
    final sal = await Prefs.getSalutation();
    _rawName = (name ?? 'Perawat').trim().isEmpty ? 'Perawat' : name!.trim();
    _salutation = sal;
    _displayName = formatNurseDisplayName(_rawName, _salutation);

    try {
      final items = await _api.nurseGetPatients();
      await Prefs.setCachedJson(_kNursePatientsCacheKey, items);
      if (!mounted) return;
      setState(() {
        _patientCount = items.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is ApiError && e.status == 0) {
        final cached = await Prefs.getCachedJson(_kNursePatientsCacheKey);
        if (!mounted) return;
        if (cached is List) {
          setState(() {
            _patientCount = cached.length;
            _loading = false;
          });
          showAppSnackBar(
            context,
            message: 'Menampilkan data terakhir tersimpan (mode luring).',
          );
          return;
        }
        setState(() => _loading = false);
        _showDialogInfo(
          "Luring",
          "Tidak ada koneksi internet. Data pasien mungkin belum termuat.",
          variant: InfoDialogVariant.warning,
        );
      } else {
        setState(() => _loading = false);
        _showDialogInfo("Gagal Memuat", "Gagal memuat data pasien: $e", isError: true);
      }
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final items = await _api.nurseGetPatients();
      await Prefs.setCachedJson(_kNursePatientsCacheKey, items);
      if (!mounted) return;
      setState(() {
        _patientCount = items.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      if (e is ApiError && e.status == 0) {
        _showDialogInfo(
          "Luring",
          "Tidak ada koneksi internet. Gagal memperbarui data.",
          variant: InfoDialogVariant.warning,
        );
      } else {
        _showDialogInfo("Gagal", "Gagal memuat data: $e", isError: true);
      }
    }
  }

  Future<void> _logout() async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Keluar?',
      message: 'Anda akan keluar dari sesi perawat. Lanjutkan?',
      confirmLabel: 'Keluar',
      isDestructive: true,
    );

    if (!ok) return;

    await _api.logout();

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
    final isLargeText = MediaQuery.textScalerOf(context).scale(14) > 18;

    final cardAssign = _NurseMenuCard(
      icon: Icons.person_add_alt_1_outlined,
      title: 'Assign Pasien',
      subtitle: 'Pilih pasien yang belum memiliki perawat',
      onTap: _openAssignPage,
    );
    final cardPatients = _NurseMenuCard(
      icon: Icons.diversity_3_outlined,
      title: 'Pasien Binaan',
      subtitle: 'Lihat data bayi, logbook, & jurnal per pasien',
      onTap: () => Navigator.pushNamed(context, Routes.nurseAgg),
    );
    final cardBrainstorm = _NurseMenuCard(
      icon: Icons.forum_outlined,
      title: 'Brainstorming',
      subtitle: 'Diskusi & catatan kasus perawat',
      onTap: () => Navigator.pushNamed(context, Routes.nurseBrainstorm),
    );
    final cardQuiz = _NurseMenuCard(
      icon: Icons.quiz_outlined,
      title: 'Kuis Perawat',
      subtitle: 'Evaluasi & pemahaman perawat',
      onTap: () => Navigator.pushNamed(context, Routes.nurseQuiz),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: enicareAppBar(
        context,
        title: 'ENI Care',
        showLogo: true,
        showBackButton: false,
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
        top: false,
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
                    // --- GREETING & PATIENT BANNER WITH SALUTATION & GUIDE CHIP ---
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
                          Text(
                            'Halo, $_displayName',
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF064E3B),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.people_alt_outlined, size: 18, color: Color(0xFF064E3B)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Pasien Binaan: $_patientCount Pasien',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF064E3B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
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
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
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
                          const Row(
                            children: [
                              Icon(Icons.arrow_downward_rounded, size: 14, color: Color(0xFF047857)),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Tarik layar ke bawah untuk memperbarui data',
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

                    // --- FLEXIBLE SHORTCUT CARDS (Zero 4px Overflow) ---
                    if (isLargeText) ...[
                      cardAssign,
                      const SizedBox(height: 12),
                      cardPatients,
                      const SizedBox(height: 12),
                      cardBrainstorm,
                      const SizedBox(height: 12),
                      cardQuiz,
                    ] else ...[
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: cardAssign),
                            const SizedBox(width: 14),
                            Expanded(child: cardPatients),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: cardBrainstorm),
                            const SizedBox(width: 14),
                            Expanded(child: cardQuiz),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    const AppVersionFooter(),
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 132),
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
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}