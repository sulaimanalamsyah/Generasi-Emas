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

        await Prefs.setRole(currentRole);
      }
    } catch (e) {
      if (mounted) {
        if (e is ApiError && e.status == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Offline: Menampilkan data lokal.")),
          );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Keluar Aplikasi?',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        content: const Text(
          'Anda harus login kembali untuk masuk.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Batal',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'Keluar',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _api.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, Routes.start, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Profil Pasien',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(color: Color(0xFF10B981)),
                  SizedBox(height: 16),
                  Text(
                    'Memuat profil...',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: const Color(0xFF10B981),
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
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
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: Color(0xFFD1FAE5),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF064E3B),
                              ),
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
                                    fontFamily: 'Nunito',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Nomor WhatsApp: $_phone',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (_role == 'father')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0F2FE),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: const Color(0xFFBAE6FD)),
                                    ),
                                    child: const Text(
                                      "Ayah (Observer)",
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF072846),
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD1FAE5),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: const Color(0xFFA7F3D0)),
                                    ),
                                    child: const Text(
                                      "Ibu",
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF064E3B),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section 1: Data Klinis & Keluarga
                    _sectionHeader('DATA KLINIS & KELUARGA'),
                    const SizedBox(height: 8),

                    _MenuTile(
                      icon: Icons.assignment_ind_outlined,
                      title: 'Data Ibu & Bayi',
                      subtitle: 'Lihat & perbarui data profil serta kehamilan',
                      onTap: () async {
                        await Navigator.pushNamed(context, Routes.profileMotherDetail);
                        _load();
                      },
                    ),

                    _MenuTile(
                      icon: Icons.child_care_rounded,
                      title: 'Data Bayi (Program FINC)',
                      subtitle: 'Tanggal mulai FINC & metrik klinis bayi',
                      onTap: () async {
                        await Navigator.pushNamed(context, Routes.profileInfantDetail);
                        _load();
                      },
                    ),

                    const SizedBox(height: 16),

                    // Section 2: Pengaturan & Bantuan
                    _sectionHeader('PENGATURAN & BANTUAN'),
                    const SizedBox(height: 8),

                    _MenuTile(
                      icon: Icons.lock_reset_rounded,
                      title: 'Ubah / Reset Password',
                      subtitle: 'Reset kata sandi via OTP WhatsApp',
                      onTap: () {
                        Navigator.pushNamed(context, Routes.forgot);
                      },
                    ),

                    _MenuTile(
                      icon: Icons.support_agent_rounded,
                      title: 'Kontak Tim Peneliti',
                      subtitle: 'Bantuan teknis & konsultasi tim riset',
                      onTap: () {
                        Navigator.pushNamed(context, Routes.contactResearchers);
                      },
                    ),

                    const SizedBox(height: 16),

                    // Section 3: Akun
                    _sectionHeader('AKUN'),
                    const SizedBox(height: 8),

                    _MenuTile(
                      icon: Icons.logout_outlined,
                      title: 'Keluar',
                      subtitle: 'Keluar dari sesi akun aktif',
                      onTap: _doLogout,
                      isDestructive: true,
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 0.5,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        border: Border.fromBorderSide(BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDestructive ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: 22,
                    color: isDestructive ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDestructive ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}