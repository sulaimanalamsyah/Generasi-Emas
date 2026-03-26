import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/storage.dart';
import '../routes.dart';
import '../widgets/common.dart';
import '../services/api_client.dart';

class HomePatientPage extends StatefulWidget {
  const HomePatientPage({super.key});
  @override
  State<HomePatientPage> createState() => _HomePatientPageState();
}

class _HomePatientPageState extends State<HomePatientPage> {
  final _api = ApiClient();
  String _displayName = '';
  String _role = '';
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _errorMessage = null);

    final localName = await Prefs.getDisplayName();
    final localRole = await Prefs.getRole();

    if (mounted) {
      setState(() {
        _displayName = localName ?? '';
        _role = localRole ?? 'mother';
      });
    }

    await _loadProfileFromApi();
  }

  Future<void> _loadProfileFromApi() async {
    try {
      final res = await _api.getMyProfile();

      if (!mounted) return;

      if (res != null && res['needLink'] == true) {
        Navigator.pushNamedAndRemoveUntil(context, Routes.fatherLink, (route) => false);
        return;
      }

      if (res != null) {
        final accountObj = res['account'];
        final profileObj = res['profile'];
        final bool isObs = res['isObserver'] == true;
        final String detectedRole = isObs ? 'father' : 'mother';
        String nameToShow = _displayName;

        if (isObs) {
          if (accountObj != null) {
            String accName = (accountObj['name'] as String?) ?? '';
            if (accName.isEmpty || accName == '-') {
              final email = (accountObj['email'] as String?) ?? '';
              accName = email.split('@').first;
              if (accName.isEmpty) accName = 'Ayah';
            }
            nameToShow = _titleCase(accName);
            String accPhone = (accountObj['phone'] as String?) ?? '-';
            await Prefs.setDisplayName(nameToShow);
            await Prefs.setPhone(accPhone);
          }
        } else {
          if (profileObj != null) {
            String rawName = (profileObj['name'] as String?) ?? '';
            if (rawName.isEmpty) rawName = (profileObj['motherName'] as String?) ?? '';
            if (rawName.isNotEmpty) {
              nameToShow = _titleCase(rawName);
              await Prefs.setDisplayName(nameToShow);
            }
            final userObj = profileObj['user'] ?? {};
            if (userObj['phone'] != null) await Prefs.setPhone(userObj['phone']);
          }
        }

        setState(() {
          _role = detectedRole;
          _displayName = nameToShow;
          _isLoading = false;
        });
        await Prefs.saveRole(detectedRole);
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (e is ApiError && e.status == 0) {
        setState(() => _errorMessage = "Tidak ada koneksi internet.");
      } else {
        debugPrint('Gagal load profil: $e');
      }
    }
  }

  String _titleCase(String s) {
    if (s.isEmpty) return '';
    final parts = s.trim().split(RegExp(r'\s+'));
    return parts.map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final greetName = _displayName.isEmpty ? 'Pasien' : _titleCase(_displayName);
    final bool isFather = _role == 'father';

    final List<Widget> items = [];
    Widget buildAssessmentShortcut(IconData icon, String label, String route) {
      return _Shortcut(
        icon: icon, label: label, onTap: () => Navigator.pushNamed(context, route),
      );
    }
    items.addAll([
      buildAssessmentShortcut(Icons.assignment, 'Pre Test', Routes.pretest),
      buildAssessmentShortcut(Icons.assignment_turned_in, 'Post Test', Routes.posttest),
      buildAssessmentShortcut(Icons.quiz, 'Quiz', Routes.quiz),
    ]);
    items.addAll([
      _Shortcut(icon: Icons.lightbulb, label: 'Brainstorm', onTap: ()=>Navigator.pushNamed(context, Routes.brainstorming)),
      _Shortcut(icon: Icons.menu_book, label: 'Modul', onTap: ()=>Navigator.pushNamed(context, Routes.modules)),
      _Shortcut(icon: Icons.link, label: 'Referensi', onTap: ()=>Navigator.pushNamed(context, Routes.references)),
    ]);

    return Scaffold(
      appBar: commonAppBar('Beranda Pasien', actions: [
        IconButton(onPressed: ()=>Navigator.pushNamed(context, Routes.notifications), icon: const Icon(Icons.notifications))
      ]),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initData, // Retry
              icon: const Icon(Icons.refresh),
              label: const Text("Coba Lagi"),
            )
          ],
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Halo, $greetName', style: Theme.of(context).textTheme.headlineSmall),

            const SizedBox(height: 4),
            Text(
              'Hari ini: ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 12),

            if (isFather)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: const Text('Observer (Ayah)'),
                  backgroundColor: Colors.teal.shade100,
                  labelStyle: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                  visualDensity: VisualDensity.compact,
                ),
              ),

            GridView.count(
              crossAxisCount: 3, childAspectRatio: .9, shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: items,
            ),

            const SizedBox(height: 24),
            if (isFather)
              Padding(
                padding: const EdgeInsets.only(top: 0),
                child: Card(
                  color: Colors.blue.shade50, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 12),
                        Expanded(child: Text('Sebagai Ayah, Anda dapat memantau hasil dan data yang diisi oleh Ibu (Pretest, Posttest, Jurnal, dll).', style: TextStyle(fontSize: 13, color: Colors.blueAccent))),
                      ],
                    ),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _Shortcut({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Column(children: [const SizedBox(height: 8), CircleAvatar(radius: 28, child: Icon(icon, size: 28)), const SizedBox(height: 6), Text(label, textAlign: TextAlign.center)]),
  );
}