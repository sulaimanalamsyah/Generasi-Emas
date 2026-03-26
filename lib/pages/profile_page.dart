import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../routes.dart';
import '../core/storage.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _api = ApiClient();

  bool _loading = true;
  String _name = '...';
  String _phone = '...';
  String _role = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final localName = await Prefs.getDisplayName();
      final localPhone = await Prefs.getPhone();
      String currentRole = (await Prefs.getRole()) ?? 'mother';

      final res = await _api.getMyProfile();

      if (!mounted) return;

      if (res != null) {
        // ... (Logika parsing profil SAMA seperti sebelumnya) ...
        // Tentukan Role
        if (res['isObserver'] == true) {
          currentRole = 'father';
        } else if (res['profile'] != null && res['profile']['user'] != null) {
          currentRole = res['profile']['user']['role'] ?? currentRole;
        }

        final accountObj = res['account'];

        setState(() {
          _role = currentRole;

          if (_role == 'father') {
            if (accountObj != null) {
              String accName = (accountObj['name'] as String?) ?? '';
              if (accName.isEmpty || accName == '-') {
                final email = (accountObj['email'] as String?) ?? '';
                accName = email.split('@').first;
                if (accName.isEmpty) accName = 'Ayah';
              }
              _name = accName;
              _phone = (accountObj['phone'] as String?) ?? '-';
            } else {
              _name = localName ?? 'Ayah';
              _phone = localPhone ?? '-';
            }
          } else {
            if (res['profile'] != null) {
              final p = res['profile'];
              final u = p['user'] ?? {};
              String rawName = (p['name'] as String?) ?? '';
              if (rawName.isEmpty) rawName = (p['motherName'] as String?) ?? '';
              _name = rawName.isNotEmpty ? rawName : (localName ?? '-');
              _phone = (u['phone'] as String?) ?? (localPhone ?? '-');
            } else {
              _name = localName ?? '-';
              _phone = localPhone ?? '-';
            }
          }
          _loading = false;
        });

        await Prefs.saveRole(currentRole);
      }
    } catch (e) {
      if (mounted) {
        // [HANDLING ERROR OFFLINE]
        if (e is ApiError && e.status == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Offline: Menampilkan data lokal."))
          );
          // Tetap load data lokal jika gagal request
          final localName = await Prefs.getDisplayName();
          final localPhone = await Prefs.getPhone();
          setState(() {
            _name = localName ?? '-';
            _phone = localPhone ?? '-';
            _loading = false;
          });
        } else {
          setState(() {
            _name = 'Error memuat';
            _loading = false;
          });
        }
      }
    }
  }

  Future<void> _doLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar Aplikasi?'),
        content: const Text('Anda harus login kembali untuk masuk.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Keluar')),
        ],
      ),
    );

    if (confirm == true) {
      await _api.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, Routes.login, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Pasien')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.teal.shade100,
                  child: Text(
                    _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Nomor WhatsApp: $_phone',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      if (_role == 'father')
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(4)
                          ),
                          child: const Text("Ayah (Observer)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            _MenuTile(
              icon: Icons.assignment_ind,
              title: 'Data Ibu',
              subtitle: 'Lihat & ubah data profil',
              onTap: () async {
                await Navigator.pushNamed(context, Routes.profileMotherDetail);
                _load();
              },
            ),

            _MenuTile(
              icon: Icons.child_care,
              title: 'Data Bayi',
              subtitle: 'Lihat & ubah data bayi',
              onTap: () => Navigator.pushNamed(context, Routes.profileInfantDetail),
            ),

            _MenuTile(
              icon: Icons.history,
              title: 'Lupa Password',
              subtitle: 'Reset password via WhatsApp OTP',
              onTap: () {
                Navigator.pushNamed(context, Routes.forgot);
              },
            ),

            _MenuTile(
              icon: Icons.logout_outlined,
              title: 'Keluar',
              onTap: _doLogout,
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, color: isDestructive ? Colors.red : Colors.grey.shade800),
        title: Text(
            title,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDestructive ? Colors.red : Colors.black87
            )
        ),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}