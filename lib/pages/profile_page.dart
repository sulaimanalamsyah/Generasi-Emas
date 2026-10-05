import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';
import '../routes.dart';
import '../core/storage.dart';
import '../core/partner_sync.dart';

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
  Map<String, dynamic>? _partnerStatus;

  @override
  void initState() {
    super.initState();
    PartnerSync.notifier.addListener(_onPartnerSync);
    _load();
  }

  @override
  void dispose() {
    PartnerSync.notifier.removeListener(_onPartnerSync);
    super.dispose();
  }

  void _onPartnerSync() {
    if (mounted) {
      _loadPartnerStatusOnly();
    }
  }

  Future<void> _loadPartnerStatusOnly() async {
    try {
      final partnerRes = await _api.getPartnerStatus();
      if (mounted) {
        setState(() {
          _partnerStatus = partnerRes;
        });
      }
    } catch (e) {
      debugPrint('Gagal load partner status in profile page: $e');
    }
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

      try {
        final partnerRes = await _api.getPartnerStatus();
        if (mounted) {
          setState(() {
            _partnerStatus = partnerRes;
          });
        }
      } catch (e) {
        debugPrint('Gagal load partner status in profile page: $e');
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

                    _buildPartnerMenuTile(),

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

  Widget _buildPartnerMenuTile() {
    final status = _partnerStatus;
    final bool isLinked = status != null && status['isLinked'] == true;
    final partner = status != null ? status['linkedPartner'] as Map<String, dynamic>? : null;
    final pendingReq = status != null ? status['pendingRequest'] as Map<String, dynamic>? : null;
    final outgoingReq = status != null ? status['outgoingPendingRequest'] as Map<String, dynamic>? : null;

    final Color dotColor;
    final String statusText;

    if (isLinked && partner != null) {
      dotColor = const Color(0xFF10B981);
      statusText = 'Terhubung: ${partner['name'] ?? 'Pasangan'}';
    } else if (pendingReq != null) {
      dotColor = const Color(0xFFF59E0B);
      statusText = 'Permintaan dari ${pendingReq['requesterName'] ?? 'Ayah'}';
    } else if (outgoingReq != null) {
      dotColor = const Color(0xFFF59E0B);
      statusText = 'Menunggu persetujuan Ibu';
    } else {
      dotColor = const Color(0xFF94A3B8);
      statusText = 'Belum terhubung';
    }

    return _MenuTile(
      icon: Icons.family_restroom_rounded,
      title: 'Data Pasangan',
      subtitleWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              statusText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
      onTap: _showPartnerDetailBottomSheet,
    );
  }

  Future<void> _showPartnerDetailBottomSheet() async {
    // Pastikan data partner status selalu termutakhir sebelum membuka sheet
    await _loadPartnerStatusOnly();
    if (!mounted) return;

    final status = _partnerStatus;
    final bool isLinked = status != null && status['isLinked'] == true;
    final partner = status != null ? status['linkedPartner'] as Map<String, dynamic>? : null;
    final pendingReq = status != null ? status['pendingRequest'] as Map<String, dynamic>? : null;
    final outgoingReq = status != null ? status['outgoingPendingRequest'] as Map<String, dynamic>? : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: isLinked
                          ? const Color(0xFFD1FAE5)
                          : (pendingReq != null || outgoingReq != null
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFF1F5F9)),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.family_restroom_rounded,
                      color: isLinked
                          ? const Color(0xFF10B981)
                          : (pendingReq != null || outgoingReq != null
                              ? const Color(0xFFD97706)
                              : const Color(0xFF64748B)),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Data Pasangan',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isLinked
                              ? 'Status akun keluarga terhubung'
                              : (pendingReq != null || outgoingReq != null
                                  ? 'Permintaan penautan dalam proses'
                                  : 'Tautkan akun untuk pantau bersama'),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLinked
                          ? const Color(0xFFD1FAE5)
                          : (pendingReq != null || outgoingReq != null
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isLinked
                            ? const Color(0xFFA7F3D0)
                            : (pendingReq != null || outgoingReq != null
                                ? const Color(0xFFFDE68A)
                                : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Text(
                      isLinked
                          ? 'Terhubung'
                          : (pendingReq != null || outgoingReq != null ? 'Menunggu' : 'Belum Terhubung'),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isLinked
                            ? const Color(0xFF064E3B)
                            : (pendingReq != null || outgoingReq != null
                                ? const Color(0xFFB45309)
                                : const Color(0xFF475569)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 18),
              _buildPartnerContent(
                sheetCtx: sheetCtx,
                isLinked: isLinked,
                partner: partner,
                pendingReq: pendingReq,
                outgoingReq: outgoingReq,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPartnerContent({
    required BuildContext sheetCtx,
    required bool isLinked,
    required Map<String, dynamic>? partner,
    required Map<String, dynamic>? pendingReq,
    required Map<String, dynamic>? outgoingReq,
  }) {
    if (isLinked && partner != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPartnerInfoRow(
            icon: Icons.person_outline_rounded,
            label: 'Nama Pasangan',
            value: partner['name'] as String? ?? '-',
          ),
          const SizedBox(height: 12),
          _buildPartnerInfoRow(
            icon: Icons.phone_android_rounded,
            label: 'Nomor WhatsApp',
            value: partner['phone'] as String? ?? '-',
          ),
          const SizedBox(height: 12),
          _buildPartnerInfoRow(
            icon: Icons.shield_outlined,
            label: 'Peran Akses',
            value: _role == 'father' ? 'Akun Utama (Ibu)' : 'Pemantau Bayi (Ayah)',
            badge: _role == 'father' ? 'Primary' : 'Read-Only',
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Akun pasangan memiliki izin pemantauan metrik bayi & logbook harian (Mode Pantau / Read-Only).',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _confirmUnlinkPartner(sheetCtx),
              icon: const Icon(Icons.link_off_rounded, size: 20),
              label: const Text(
                'Putuskan Tautan',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (pendingReq != null) {
      final reqName = pendingReq['requesterName'] as String? ?? 'Ayah';
      final reqPhone = pendingReq['requesterPhone'] as String? ?? '-';
      final requestId = pendingReq['id'] as String;
      final rawDate = pendingReq['createdAt'];
      DateTime? dt;
      if (rawDate != null) {
        dt = DateTime.tryParse(rawDate.toString())?.toLocal();
      }
      final dateStr = dt != null ? '${DateFormat('d MMMM yyyy, HH:mm', 'id_ID').format(dt)} WIB' : '-';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.mark_email_unread_outlined, size: 18, color: Color(0xFFB45309)),
                    SizedBox(width: 8),
                    Text(
                      'Permintaan Akses Masuk dari Ayah',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildPartnerInfoRow(icon: Icons.person_outline_rounded, label: 'Nama Ayah', value: reqName),
                const SizedBox(height: 8),
                _buildPartnerInfoRow(icon: Icons.phone_android_rounded, label: 'Nomor WhatsApp', value: reqPhone),
                const SizedBox(height: 8),
                _buildPartnerInfoRow(icon: Icons.schedule_rounded, label: 'Waktu Pengajuan', value: dateStr),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Color(0xFF0EA5E9), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dengan menyetujui, Ayah dapat melihat data profil bayi, grafik KMS, dan logbook harian dalam mode pantau (Read-Only).',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF072846), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      try {
                        await _api.respondPartnerRequest(requestId: requestId, approve: false);
                        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                        await _load();
                        PartnerSync.notify();
                        _showDialogInfo('Ditolak', 'Permintaan penautan akun ditolak.');
                      } catch (e) {
                        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                        await _load();
                        PartnerSync.notify();
                        if (e is ApiError && (e.status == 404 || e.message.contains('sudah diproses') || e.message.contains('tidak ditemukan'))) {
                          _showDialogInfo('Informasi', 'Permintaan penautan ini sudah diproses sebelumnya.');
                        } else {
                          _showDialogInfo('Gagal', 'Gagal menolak: $e', isError: true);
                        }
                      }
                    },
                    child: const Text('Tolak', style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w700)),
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
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      try {
                        await _api.respondPartnerRequest(requestId: requestId, approve: true);
                        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                        await _load();
                        PartnerSync.notify();
                        _showDialogInfo('Berhasil', 'Permintaan penautan disetujui. Akun Ayah kini terhubung!');
                      } catch (e) {
                        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                        await _load();
                        PartnerSync.notify();
                        if (e is ApiError && (e.status == 404 || e.message.contains('sudah diproses') || e.message.contains('tidak ditemukan'))) {
                          _showDialogInfo('Informasi', 'Permintaan penautan ini sudah disetujui sebelumnya.');
                        } else {
                          _showDialogInfo('Gagal', 'Gagal menyetujui: $e', isError: true);
                        }
                      }
                    },
                    child: const Text('Setujui', style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    } else if (outgoingReq != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.schedule_rounded, size: 18, color: Color(0xFFB45309)),
                    SizedBox(width: 8),
                    Text(
                      'Menunggu Persetujuan Ibu',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Permintaan penautan telah dikirim ke nomor WhatsApp Ibu (${outgoingReq['targetPhone'] ?? '-'}). Minta Ibu menyetujui melalui aplikasi miliknya.',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFF78350F),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _cancelOutgoingRequest(sheetCtx),
              icon: const Icon(Icons.close_rounded, size: 20),
              label: const Text(
                'Batalkan Permintaan',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      if (_role == 'father') {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hubungkan akun dengan Ibu untuk dapat memantau data perkembangan bayi, grafik pertumbuhan KMS, dan jadwal edukasi harian.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  await Navigator.pushNamed(context, Routes.fatherLink);
                  _load();
                },
                icon: const Icon(Icons.add_link_rounded, size: 20),
                label: const Text(
                  'Hubungkan Akun Ibu',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        );
      } else {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.info_outline_rounded, size: 20, color: Color(0xFF64748B)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Belum ada akun Ayah yang terhubung. Ayah dapat mengajukan penautan dari aplikasi miliknya menggunakan nomor WhatsApp Anda untuk ikut memantau tumbuh kembang si kecil.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _buildPartnerInfoRow({
    required IconData icon,
    required String label,
    required String value,
    String? badge,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 10),
        SizedBox(
          width: 115,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        const Text(
          ': ',
          style: TextStyle(
            fontFamily: 'Inter',
            color: Color(0xFF64748B),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmUnlinkPartner(BuildContext? sheetCtx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Putuskan Tautan?',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          _role == 'father'
              ? 'Apakah Anda yakin ingin memutuskan tautan akun dengan Ibu? Sesi akun Ayah akan otomatis diakhiri dan keluar dari aplikasi.'
              : 'Apakah Anda yakin ingin memutuskan tautan akun pasangan? Akses pemantauan data bayi untuk akun Ayah akan dihentikan.',
          style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF334155), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(fontFamily: 'Inter', color: Color(0xFF64748B))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Putuskan', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (sheetCtx != null && sheetCtx.mounted) {
        Navigator.pop(sheetCtx);
      }
      setState(() => _loading = true);
      try {
        await _api.unlinkPartner();

        // JIKA AYAH: PAKSA LOGOUT SEGERA
        if (_role == 'father') {
          await _api.logout();
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(context, Routes.start, (route) => false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tautan berhasil diputuskan. Sesi akun Ayah telah diakhiri.'),
              backgroundColor: Color(0xFF0F172A),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        // JIKA IBU: Refresh profil lokal & tampilkan dialog konfirmasi
        await _load();
        PartnerSync.notify();
        _showDialogInfo('Berhasil', 'Tautan akun pasangan berhasil diputuskan.');
      } catch (e) {
        setState(() => _loading = false);
        _showDialogInfo('Gagal', 'Gagal memutuskan tautan: $e', isError: true);
      }
    }
  }

  Future<void> _cancelOutgoingRequest(BuildContext? sheetCtx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Batalkan Permintaan?',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: const Text(
          'Apakah Anda yakin ingin membatalkan permintaan penautan akun ke Ibu?',
          style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Kembali', style: TextStyle(fontFamily: 'Inter', color: Color(0xFF64748B))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Batalkan', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (sheetCtx != null && sheetCtx.mounted) {
        Navigator.pop(sheetCtx);
      }
      setState(() => _loading = true);
      try {
        await _api.cancelPartnerRequest();
        await _load();
        PartnerSync.notify();
        _showDialogInfo('Dibatalkan', 'Permintaan penautan akun berhasil dibatalkan.');
      } catch (e) {
        setState(() => _loading = false);
        _showDialogInfo('Gagal', 'Gagal membatalkan permintaan: $e', isError: true);
      }
    }
  }

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
  final Widget? subtitleWidget;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDestructive ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
                        ),
                      ),
                      if (subtitleWidget != null) ...[
                        const SizedBox(height: 3),
                        subtitleWidget!,
                      ] else if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                const SizedBox(width: 4),
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