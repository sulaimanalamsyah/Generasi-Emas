import 'package:flutter/material.dart';
import '../../core/storage.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../routes.dart';
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
    Navigator.pushNamedAndRemoveUntil(context, Routes.login, (_) => false);
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    double? width,
    double? height,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
    Widget? trailing,
  }) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(radius: 22, child: Icon(icon)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              trailing ?? const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
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

    final screenWidth = MediaQuery.of(context).size.width;
    const padding = 16.0 * 2;
    const spacing = 12.0;
    final cardWidth = (screenWidth - padding - spacing) / 2;
    final cardHeight = cardWidth * 1.1;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Beranda Perawat'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            ListTile(
              leading: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text('Memuat...'),
            ),
          ],
        )
            : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- HEADER ---
            Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  child: Icon(Icons.local_hospital_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Halo, $_displayName',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.person_search_outlined, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Pasien Binaan: $_patientCount',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            _tile(
              icon: Icons.refresh,
              title: 'Reload Data',
              subtitle: 'Tarik data pasien terbaru',
              onTap: _refresh,
              trailing: const Icon(Icons.refresh),
            ),

            const SizedBox(height: 16),

            // --- MENU LAYOUT PYRAMID ---
            // Baris 1: Assign Pasien & Pasien Binaan
            Row(
              children: [
                // 1. Assign Pasien
                Expanded(
                  child: _buildMenuCard(
                    context: context,
                    height: cardHeight,
                    icon: Icons.person_add_alt_1_outlined,
                    title: 'Assign Pasien',
                    subtitle: 'Pilih pasien yang\nbelum punya perawat',
                    onTap: _openAssignPage,
                  ),
                ),
                const SizedBox(width: 12),

                // 2. Pasien Binaan
                Expanded(
                  child: _buildMenuCard(
                    context: context,
                    height: cardHeight,
                    icon: Icons.diversity_3_outlined,
                    title: 'Pasien Binaan',
                    subtitle: 'Lihat data bayi, logbook,\n& jurnal per pasien',
                    onTap: () => Navigator.pushNamed(context, Routes.nurseAgg),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Baris 2: Folder Perawat
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 3. Folder Perawat
                _buildMenuCard(
                  context: context,
                  width: cardWidth,
                  height: cardHeight,
                  icon: Icons.folder_special_outlined,
                  title: 'Folder Perawat',
                  subtitle: 'Brainstorming,\nPasien Binaan, \nQuiz',
                  onTap: () => Navigator.pushNamed(context, Routes.nurseFolder),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}