import 'package:flutter/material.dart';
import '../core/storage.dart';
import '../widgets/common.dart';

class GuidePage extends StatefulWidget {
  final int initialRoleIndex;
  const GuidePage({super.key, this.initialRoleIndex = 0});

  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> {
  bool _loading = true;
  bool _isNurse = false;
  int _selectedRoleIndex = 0; // 0 = Ibu, 1 = Ayah (khusus pasien)

  @override
  void initState() {
    super.initState();
    _selectedRoleIndex = widget.initialRoleIndex;
    _initRole();
  }

  Future<void> _initRole() async {
    final role = await Prefs.getRole();
    if (mounted) {
      setState(() {
        if (role == 'nurse') {
          _isNurse = true;
        } else if (role == 'father') {
          _isNurse = false;
          _selectedRoleIndex = 1;
        } else {
          _isNurse = false;
          _selectedRoleIndex = 0;
        }
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBarTitle = _isNurse ? 'Panduan Perawat' : 'Panduan Penggunaan';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: evaluationAppBar(
        context: context,
        title: appBarTitle,
        showBackButton: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                children: [
                  // Hero Header Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isNurse
                            ? const [Color(0xFF0284C7), Color(0xFF0369A1)]
                            : const [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (_isNurse ? const Color(0xFF0284C7) : const Color(0xFF10B981))
                              .withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.auto_stories_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _isNurse ? 'Panduan Alur Perawat' : 'Panduan Alur Aplikasi',
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _isNurse
                              ? 'Panduan langkah terstruktur bagi perawat dalam mengelola pasien binaan, pemantauan klinis, dan sinkronisasi evaluasi.'
                              : 'Pelajari alur dan langkah-langkah penggunaan aplikasi Model I-FINC sesuai dengan peran Anda.',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            height: 1.4,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Role Segmented Switcher (HANYA MUNCUL UNTUK PASIEN: IBU / AYAH)
                  if (!_isNurse) ...[
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _RoleTab(
                              label: 'Panduan Ibu (Pasien)',
                              icon: Icons.pregnant_woman_rounded,
                              isSelected: _selectedRoleIndex == 0,
                              onTap: () => setState(() => _selectedRoleIndex = 0),
                            ),
                          ),
                          Expanded(
                            child: _RoleTab(
                              label: 'Panduan Ayah (Observer)',
                              icon: Icons.person_rounded,
                              isSelected: _selectedRoleIndex == 1,
                              onTap: () => setState(() => _selectedRoleIndex = 1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Role Overview Card
                  _RoleOverviewCard(
                    isNurse: _isNurse,
                    isMother: !_isNurse && _selectedRoleIndex == 0,
                  ),

                  const SizedBox(height: 24),

                  // Section Title
                  Row(
                    children: [
                      const Icon(
                        Icons.format_list_numbered_rounded,
                        color: Color(0xFF0F172A),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isNurse
                            ? 'Langkah Kerja Perawat (6 Langkah)'
                            : (_selectedRoleIndex == 0
                                ? 'Langkah Penggunaan Ibu (8 Langkah)'
                                : 'Langkah Penggunaan Ayah (5 Langkah)'),
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Ketuk pada setiap langkah untuk melihat penjelasan detail.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Step Accordion Cards
                  if (_isNurse)
                    ..._buildNurseSteps()
                  else if (_selectedRoleIndex == 0)
                    ..._buildMotherSteps()
                  else
                    ..._buildFatherSteps(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // --------------------------------------------------------------------------
  // ALUR PERAWAT (6 LANGKAH)
  // --------------------------------------------------------------------------
  List<Widget> _buildNurseSteps() {
    return const [
      _ExpandableGuideStepCard(
        stepNumber: 1,
        title: 'Login & Akses Dasbor Perawat',
        category: 'Autentikasi',
        categoryColor: Color(0xFFE0F2FE),
        categoryTextColor: Color(0xFF075985),
        description:
            '• Masuk ke aplikasi menggunakan akun terdaftar dengan peran "Perawat".\n'
            '• Pada Beranda Perawat, pantau ringkasan jumlah pasien binaan aktif yang sedang Anda dampingi.\n'
            '• Pastikan koneksi internet stabil saat mengakses data rekapitulasi pasien.',
      ),
      _ExpandableGuideStepCard(
        stepNumber: 2,
        title: 'Klaim / Assign Pasien Binaan',
        category: 'Manajemen Pasien',
        categoryColor: Color(0xFFD1FAE5),
        categoryTextColor: Color(0xFF064E3B),
        description:
            '• Buka menu "Assign Pasien" pada beranda perawat.\n'
            '• Telusuri daftar pasien baru (Ibu & Bayi) yang belum memiliki perawat pendamping.\n'
            '• Tekan tombol "Pilih / Assign" pada pasien yang menjadi tanggung jawab asuhan Anda untuk menambahkan mereka ke daftar binaan.',
      ),
      _ExpandableGuideStepCard(
        stepNumber: 3,
        title: 'Pemantauan Pasien Binaan & Data Klinis',
        category: 'Monitoring',
        categoryColor: Color(0xFFD1FAE5),
        categoryTextColor: Color(0xFF064E3B),
        description:
            '• Buka menu "Pasien Binaan" untuk melihat seluruh daftar ibu dan bayi dalam asuhan Anda.\n'
            '• Tekan salah satu pasien untuk masuk ke halaman "Detail Pasien".\n'
            '• Pantau parameter medis: Berat Badan Bayi, Tanggal Lahir, Diagnosis Medis, dan Lama Hari Rawat.\n'
            '• Periksa riwayat pengisian Logbook Harian (durasi KMC/Kanguru Care, menyusui) serta catatan Jurnal Bayi yang diinput oleh Ibu.',
      ),
      _ExpandableGuideStepCard(
        stepNumber: 4,
        title: 'Sinkronisasi Respons & Nilai Evaluasi (Global Sync)',
        category: 'Evaluasi',
        categoryColor: Color(0xFFFEF3C7),
        categoryTextColor: Color(0xFF92400E),
        description:
            '• Masuk ke menu "Pasien Binaan" dan tekan tombol "Sinkronisasi Form" di sudut kanan atas.\n'
            '• Sistem akan secara otomatis membaca spreadsheet Google Forms untuk mengambil nilai Pre-Test, Post-Test (1-5), dan Kuis Pasien.\n'
            '• Pantau kepatuhan pasien dalam menyelesaikan evaluasi sesuai jadwal berkala.',
      ),
      _ExpandableGuideStepCard(
        stepNumber: 5,
        title: 'Diskusi Kasus & Modul Brainstorming',
        category: 'Edukasi Klinis',
        categoryColor: Color(0xFFE0F2FE),
        categoryTextColor: Color(0xFF075985),
        description:
            '• Buka menu "Brainstorming" untuk mengakses studi kasus dan panduan asuhan keperawatan neonatal berbasis Model I-FINC.\n'
            '• Manfaatkan materi klinis ini sebagai bahan edukasi dan pendampingan saat berinteraksi dengan orang tua bayi.',
      ),
      _ExpandableGuideStepCard(
        stepNumber: 6,
        title: 'Evaluasi & Quiz Standar Asuhan Perawat',
        category: 'Kuis Perawat',
        categoryColor: Color(0xFFFEF3C7),
        categoryTextColor: Color(0xFF92400E),
        description:
            '• Buka menu "Quiz Perawat" untuk mengikuti evaluasi berkala mengenai kompetensi asuhan neonatal terintegrasi keluarga.\n'
            '• Hasil kuis membantu memantau pemahaman standar operasional pendampingan keluarga di ruang rawat.',
      ),
    ];
  }

  // --------------------------------------------------------------------------
  // ALUR IBU (8 LANGKAH)
  // --------------------------------------------------------------------------
  List<Widget> _buildMotherSteps() {
    return const [
      _ExpandableGuideStepCard(
        stepNumber: 1,
        title: 'Registrasi & Verifikasi Akun',
        category: 'Akun',
        categoryColor: Color(0xFFD1FAE5),
        categoryTextColor: Color(0xFF064E3B),
        description:
            '• Daftar akun baru dengan memilih peran "Ibu" menggunakan nomor WhatsApp dan email aktif.\n'
            '• Masukkan 6 digit kode OTP yang dikirimkan via WhatsApp untuk menyelesaikan aktivasi akun.',
      ),
      _ExpandableGuideStepCard(
        stepNumber: 2,
        title: 'Persetujuan Penelitian (Informed Consent)',
        category: 'Persetujuan',
        categoryColor: Color(0xFFE0F2FE),
        categoryTextColor: Color(0xFF075985),
        description:
            '• Baca penjelasan lengkap mengenai penelitian Model I-FINC (Indonesian Family Integrated Neonatal Care).\n'
            '• Berikan persetujuan digital untuk melanjutkan ke tahap intervensi dan pemantauan kesehatan bayi.',
      ),
      _ExpandableGuideStepCard(
        stepNumber: 3,
        title: 'Pengisian Evaluasi Pre-Test (Single Form)',
        category: 'Evaluasi',
        categoryColor: Color(0xFFFEF3C7),
        categoryTextColor: Color(0xFF92400E),
        description:
            '• Kerjakan 1 formulir kuesioner Pre-Test awal sebelum intervensi dimulai.\n'
            '• Setelah kuesioner selesai dikerjakan dan diverifikasi sistem, dasbor beranda dan jadwal Post-Test akan terbuka secara otomatis.',
      ),
      _ExpandableGuideStepCard(
        stepNumber: 4,
        title: 'Eksplorasi Modul Pembelajaran & Edukasi',
        category: 'Edukasi',
        categoryColor: Color(0xFFD1FAE5),
        categoryTextColor: Color(0xFF064E3B),
        description:
            '• Akses materi panduan perawatan bayi melalui Modul Pembelajaran (teks PDF dan video interaktif).\n'
            '• Pelajari materi Brainstorming dan Referensi Ilmiah seputar metode kanguru (KMC), pencegahan stunting, dan stimulasi dini bayi.',
      ),
      _ExpandableGuideStepCard(
        stepNumber: 5,
        title: 'Pencatatan Harian (Jurnal & Logbook)',
        category: 'Aktivitas Harian',
        categoryColor: Color(0xFFD1FAE5),
        categoryTextColor: Color(0xFF064E3B),
        description:
            '• Jurnal Bayi: Catat kondisi fisik, tanda vital, dan momen penting harian si kecil.\n'
            '• Logbook Perawatan: Catat durasi perawatan harian (KMC/Metode Kanguru, menyusui/feeding) dan pantau pemenuhan target harian.',
      ),
      _ExpandableGuideStepCard(
        stepNumber: 6,
        title: 'Mengerjakan Kuis Edukasi Pasien',
        category: 'Kuis',
        categoryColor: Color(0xFFFEF3C7),
        categoryTextColor: Color(0xFF92400E),
        description:
            '• Ikuti kuis edukasi untuk menguji pemahaman materi perawatan neonatal.\n'
            '• Nilai dari setiap kuis akan dihitung dan ditampilkan dalam ringkasan skor rata-rata pada halaman kuis.',
      ),
      _ExpandableGuideStepCard(
        stepNumber: 7,
        title: 'Bagikan Nomor HP ke Pasangan (Ayah)',
        category: 'Kolaborasi',
        categoryColor: Color(0xFFE0F2FE),
        categoryTextColor: Color(0xFF075985),
        description:
            '• Berikan nomor WhatsApp Anda yang terdaftar kepada suami/Ayah.\n'
            '• Ayah dapat memasukkan nomor tersebut di menu "Tautkan Akun Pasangan" agar akun Ayah terhubung dan dapat memantau data si kecil.',
      ),
      _ExpandableGuideStepCard(
        stepNumber: 8,
        title: 'Evaluasi Post-Test Terjadwal (1 s/d 5)',
        category: 'Evaluasi',
        categoryColor: Color(0xFFFEF3C7),
        categoryTextColor: Color(0xFF92400E),
        description:
            '• Kerjakan evaluasi Post-Test 1 hingga 5 yang terbuka secara berurutan setiap 3 hari setelah Pre-Test selesai.\n'
            '• Pantau peningkatan pemahaman dan skor evaluasi Anda secara berkala sepanjang program intervensi.',
      ),
    ];
  }

  // --------------------------------------------------------------------------
  // ALUR AYAH (5 LANGKAH)
  // --------------------------------------------------------------------------
  List<Widget> _buildFatherSteps() {
    return const [
      _ExpandableGuideStepCard(
        stepNumber: 1,
        title: 'Registrasi & Aktivasi Akun Ayah',
        category: 'Akun',
        categoryColor: Color(0xFFD1FAE5),
        categoryTextColor: Color(0xFF064E3B),
        description:
            '• Daftar akun baru dengan memilih peran "Ayah" menggunakan nomor WhatsApp dan email pribadi.\n'
            '• Masukkan 6 digit kode OTP WhatsApp untuk mengaktifkan akun pemantau Anda.',
      ),
      _ExpandableGuideStepCard(
        stepNumber: 2,
        title: 'Tautkan Akun ke Ibu (Partner Linking)',
        category: 'Kolaborasi',
        categoryColor: Color(0xFFE0F2FE),
        categoryTextColor: Color(0xFF075985),
        description:
            '• Buka menu "Tautkan Akun Pasangan" pada beranda atau profil.\n'
            '• Masukkan nomor WhatsApp Ibu yang telah terdaftar di aplikasi.\n'
            '• Setelah terhubung, data bayi dan jurnal harian Ibu akan otomatis tersinkronisasi ke akun Anda.',
      ),
      _ExpandableGuideStepCard(
        stepNumber: 3,
        title: 'Masuk Dasbor Pemantau (Observer Mode)',
        category: 'Dasbor',
        categoryColor: Color(0xFFE0F2FE),
        categoryTextColor: Color(0xFF075985),
        description:
            '• Akun Ayah dilengkapi dengan badge penanda "Observer (Ayah)".\n'
            '• Ayah dapat melihat ringkasan status bayi, modul edukasi, dan banner berita kesehatan terkini.',
      ),
      _ExpandableGuideStepCard(
        stepNumber: 4,
        title: 'Memantau Jurnal & Logbook Bayi',
        category: 'Pemantauan',
        categoryColor: Color(0xFFD1FAE5),
        categoryTextColor: Color(0xFF064E3B),
        description:
            '• Pantau catatan perkembangan bayi dan durasi perawatan harian yang diisi oleh Ibu secara real-time.\n'
            '• Berikan dukungan moral dan dampingi Ibu dalam mencapai target durasi perawatan harian si kecil.',
      ),
      _ExpandableGuideStepCard(
        stepNumber: 5,
        title: 'Partisipasi Kuis & Mempelajari Materi',
        category: 'Edukasi',
        categoryColor: Color(0xFFFEF3C7),
        categoryTextColor: Color(0xFF92400E),
        description:
            '• Pelajari seluruh modul pembelajaran perawatan bayi dan ikuti kuis edukasi interaktif.\n'
            '• Keterlibatan ayah yang aktif terbukti meningkatkan keberhasilan asuhan neonatal dan tumbuh kembang bayi.',
      ),
    ];
  }
}

// ----------------------------------------------------------------------------
// COMPONENT: Role Segmented Tab
// ----------------------------------------------------------------------------
class _RoleTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? const Color(0xFF064E3B) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: isSelected ? 'Nunito' : 'Inter',
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? const Color(0xFF064E3B) : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// COMPONENT: Role Overview Card
// ----------------------------------------------------------------------------
class _RoleOverviewCard extends StatelessWidget {
  final bool isNurse;
  final bool isMother;

  const _RoleOverviewCard({
    required this.isNurse,
    required this.isMother,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color iconColor;
    Color titleColor;
    Color descColor;
    IconData icon;
    String title;
    String desc;

    if (isNurse) {
      bg = const Color(0xFFF0F9FF);
      border = const Color(0xFFBAE6FD);
      iconColor = const Color(0xFF0284C7);
      titleColor = const Color(0xFF075985);
      descColor = const Color(0xFF0C4A6E);
      icon = Icons.medical_services_rounded;
      title = 'Peran Perawat (Clinical Care & Monitoring)';
      desc =
          'Perawat bertindak sebagai pembina klinis, memvalidasi klaim pasien, memantau logbook & jurnal bayi, serta menyinkronkan data evaluasi dari Google Forms.';
    } else if (isMother) {
      bg = const Color(0xFFECFDF5);
      border = const Color(0xFFA7F3D0);
      iconColor = const Color(0xFF047857);
      titleColor = const Color(0xFF064E3B);
      descColor = const Color(0xFF065F46);
      icon = Icons.verified_user_rounded;
      title = 'Peran Ibu (Primary User)';
      desc =
          'Ibu bertindak sebagai pelaku utama perawatan dan pengisian data medis bayi, logbook harian, serta formulir evaluasi pretest & posttest.';
    } else {
      bg = const Color(0xFFF0F9FF);
      border = const Color(0xFFBAE6FD);
      iconColor = const Color(0xFF0284C7);
      titleColor = const Color(0xFF075985);
      descColor = const Color(0xFF0C4A6E);
      icon = Icons.visibility_rounded;
      title = 'Peran Ayah (Observer)';
      desc =
          'Ayah bertindak sebagai pendamping dan pemantau perkembangan si kecil secara real-time setelah menghubungkan akun dengan nomor HP Ibu.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
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
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    height: 1.4,
                    color: descColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// COMPONENT: Expandable Guide Step Accordion Card (NO NESTED ROUTE BUTTONS)
// ----------------------------------------------------------------------------
class _ExpandableGuideStepCard extends StatefulWidget {
  final int stepNumber;
  final String title;
  final String category;
  final Color categoryColor;
  final Color categoryTextColor;
  final String description;

  const _ExpandableGuideStepCard({
    required this.stepNumber,
    required this.title,
    required this.category,
    required this.categoryColor,
    required this.categoryTextColor,
    required this.description,
  });

  @override
  State<_ExpandableGuideStepCard> createState() => _ExpandableGuideStepCardState();
}

class _ExpandableGuideStepCardState extends State<_ExpandableGuideStepCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isExpanded ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
          width: _isExpanded ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: _isExpanded ? 0.05 : 0.02),
            blurRadius: _isExpanded ? 10 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: false,
          onExpansionChanged: (expanded) {
            setState(() => _isExpanded = expanded);
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${widget.stepNumber}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          title: Text(
            widget.title,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.categoryColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  widget.category,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: widget.categoryTextColor,
                  ),
                ),
              ),
            ),
          ),
          trailing: AnimatedRotation(
            turns: _isExpanded ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF64748B),
              size: 24,
            ),
          ),
          children: [
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.description,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5,
                  height: 1.5,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
