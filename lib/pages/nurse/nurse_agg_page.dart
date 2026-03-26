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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  // Helper Alert Dialog
  Future<void> _showInfoDialog(String title, String message, {bool isError = false}) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(isError ? Icons.error : Icons.check_circle, color: isError ? Colors.red : Colors.green),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: isError ? Colors.red : Colors.green)),
          ],
        ),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
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

  void _openDetail(String pid, String tab) {
    if (pid.isEmpty) {
      _showInfoDialog("Error", "ID pasien tidak tersedia", isError: true);
      return;
    }
    Navigator.pushNamed(
        context,
        Routes.nursePatientDetail,
        arguments: {'patientId': pid, 'tab': tab}
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
        title: const Text('Lepas Pasien?'),
        content: Text('Pasien "$name" akan dilepas dari daftar tanggung jawab Anda. Data logbook dan jurnal tetap tersimpan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Lepas')
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pasien Binaan')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Coba Lagi'))
            ],
          ),
        )
            : _patients.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.person_off_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Belum ada pasien binaan.'),
            ],
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _patients.length,
          itemBuilder: (ctx, i) {
            final p = _patients[i];
            final pid = _patientIdOf(p);
            final mName = _motherNameOf(p);
            final bName = _babyNameOf(p);
            final lc = _logbookCountOf(p);
            final jc = _journalCountOf(p);
            final isDone = _isCompleted(p);
            final isUnassigning = _unassigningId == pid;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                          child: Text(
                            bName.isNotEmpty ? bName[0].toUpperCase() : 'B',
                            style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ibu: $mName',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (isUnassigning)
                          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        else
                          IconButton(
                            icon: const Icon(Icons.link_off, color: Colors.red),
                            onPressed: () => _confirmUnassign(p),
                            tooltip: 'Lepas Pasien',
                            visualDensity: VisualDensity.compact,
                          )
                      ],
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Pill(text: 'Logbook: $lc', icon: Icons.edit_note),
                        _Pill(text: 'Jurnal: $jc', icon: Icons.menu_book),
                        _Pill(
                            text: isDone ? 'Selesai' : 'Perawatan',
                            color: isDone ? Colors.green.shade100 : Colors.blue.shade100,
                            textColor: isDone ? Colors.green.shade900 : Colors.blue.shade900,
                            icon: isDone ? Icons.check_circle_outline : Icons.local_hospital_outlined
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _GridActionButton(
                                  icon: Icons.edit_note,
                                  label: 'Logbook',
                                  color: Colors.teal.shade50,
                                  iconColor: Colors.teal.shade800,
                                  onTap: () => _openDetail(pid, 'logbook')
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _GridActionButton(
                                  icon: Icons.menu_book,
                                  label: 'Jurnal',
                                  color: Colors.teal.shade50,
                                  iconColor: Colors.teal.shade800,
                                  onTap: () => _openDetail(pid, 'journal')
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Expanded(
                              child: _GridActionButton(
                                  icon: Icons.assignment_turned_in,
                                  label: 'Evaluasi',
                                  color: Colors.teal.shade50,
                                  iconColor: Colors.teal.shade800,
                                  onTap: () => _openDetail(pid, 'evaluasi')
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _GridActionButton(
                                  icon: Icons.person,
                                  label: 'Detail',
                                  color: Colors.teal.shade50,
                                  iconColor: Colors.teal.shade800,
                                  onTap: () => _openDetail(pid, 'profile')
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Widget Chip Statistik
class _Pill extends StatelessWidget {
  final String text;
  final Color? color;
  final Color? textColor;
  final IconData? icon;

  const _Pill({required this.text, this.color, this.textColor, this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = color ?? scheme.surfaceContainerHighest;
    final fg = textColor ?? scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// Widget Tombol Grid
class _GridActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _GridActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: iconColor),
              const SizedBox(height: 6),
              Text(
                  label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: iconColor
                  )
              ),
            ],
          ),
        ),
      ),
    );
  }
}