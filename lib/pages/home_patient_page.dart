import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/storage.dart';
import '../routes.dart';
import '../widgets/common.dart';
import '../widgets/in_app_viewer_page.dart';
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

  // Banner Carousel State
  int _currentBannerIndex = 0;
  late PageController _bannerController;
  Timer? _bannerTimer;

  List<Map<String, String>> _bannerItems = [
    {
      'title': 'Kemenkes RI',
      'image': 'https://ucarecdn.com/b1b89674-e69e-4fe1-b399-02595aa5bf3c/-/quality/smart/-/format/auto/-/resize/960x/bgimage.png',
      'url': 'https://kemkes.go.id',
    },
    {
      'title': 'Cegah Stunting',
      'image': 'https://ucarecdn.com/b1b89674-e69e-4fe1-b399-02595aa5bf3c/-/quality/smart/-/format/auto/-/resize/960x/bgimage.png',
      'url': 'https://stunting.go.id',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initData();

    _bannerController = PageController(viewportFraction: 0.9);
    _startAutoScroll();
  }

  @override
  void dispose() {
    _bannerController.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _startAutoScroll() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_bannerController.hasClients && _bannerItems.isNotEmpty) {
        int nextIndex = _currentBannerIndex + 1;
        if (nextIndex >= _bannerItems.length) {
          nextIndex = 0;
        }
        _bannerController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _stopAutoScroll() {
    _bannerTimer?.cancel();
  }

  void _openBannerUrl(String rawUrl, {String? title}) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      _showSnackBar('Link berita/edukasi tidak valid.', isError: true);
      return;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https'))) {
      _showSnackBar('Format URL tidak valid.', isError: true);
      return;
    }

    final pageTitle = (title != null && title.trim().isNotEmpty) ? title.trim() : 'Berita Edukasi';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InAppViewerPage(
          title: pageTitle,
          url: trimmed,
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.wifi_off_outlined : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
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

    await Future.wait([
      _loadProfileFromApi(),
      _loadBannersFromApi(),
    ]);
  }

  Future<void> _loadBannersFromApi() async {
    try {
      final banners = await _api.getBanners();
      if (mounted && banners.isNotEmpty) {
        setState(() {
          _bannerItems = banners;
          _currentBannerIndex = 0;
        });
        _startAutoScroll();
      }
    } catch (e) {
      debugPrint('Gagal load banners: $e');
    }
  }

  Future<void> _loadProfileFromApi() async {
    try {
      final res = await _api.getMyProfile();

      if (!mounted) return;

      if (res != null && res['needLink'] == true) {
        Navigator.pushNamedAndRemoveUntil(
            context, Routes.fatherLink, (route) => false);
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
        await Prefs.setRole(detectedRole);
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (e is ApiError && e.status == 0) {
        const errorMsg = "Tidak ada koneksi internet.";
        setState(() => _errorMessage = errorMsg);
        _showSnackBar(errorMsg, isError: true);
      } else {
        debugPrint('Gagal load profil: $e');
      }
    }
  }

  String _titleCase(String s) {
    if (s.isEmpty) return '';
    final parts = s.trim().split(RegExp(r'\s+'));
    return parts
        .map((w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final greetName = _displayName.isEmpty ? 'Pasien' : _titleCase(_displayName);
    final bool isFather = _role == 'father';

    // Shortcut list mapping Material icons to assets/icons/ PNG assets
    final List<Widget> shortcuts = [
      _Shortcut(
        assetPath: 'assets/icons/pre-test.png',
        label: 'Pre Test',
        onTap: () => Navigator.pushNamed(context, Routes.pretest),
      ),
      _Shortcut(
        assetPath: 'assets/icons/post-test.png',
        label: 'Post Test',
        onTap: () => Navigator.pushNamed(context, Routes.posttest),
      ),
      _Shortcut(
        assetPath: 'assets/icons/quiz.png',
        label: 'Quiz',
        onTap: () => Navigator.pushNamed(context, Routes.quiz),
      ),
      // Brainstorm component updated to Video while preserving Routes.brainstorming
      _Shortcut(
        assetPath: 'assets/icons/video.png',
        label: 'Video',
        onTap: () => Navigator.pushNamed(context, Routes.brainstorming),
      ),
      _Shortcut(
        assetPath: 'assets/icons/modul.png',
        label: 'Modul',
        onTap: () => Navigator.pushNamed(context, Routes.modules),
      ),
      _Shortcut(
        assetPath: 'assets/icons/referensi.png',
        label: 'Referensi',
        onTap: () => Navigator.pushNamed(context, Routes.references),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: commonAppBar(
        'Beranda Pasien',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () => Navigator.pushNamed(context, Routes.notifications),
              icon: const Icon(Icons.notifications_outlined, color: Color(0xFF0F172A), size: 24),
              tooltip: 'Notifikasi',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(
                    color: Color(0xFF10B981),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Memuat beranda...',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Periksa koneksi internet Anda.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _initData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                            ),
                            icon: const Icon(Icons.refresh),
                            label: const Text(
                              "Coba Lagi",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  child: RefreshIndicator(
                    onRefresh: _initData,
                    color: const Color(0xFF10B981),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      children: [
                        // Hero Welcome Banner with "Panduan" CTA Placeholder
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Halo, $greetName!',
                                        style: const TextStyle(
                                          fontFamily: 'Nunito',
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    if (isFather)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE0F2FE),
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(color: const Color(0xFFBAE6FD)),
                                        ),
                                        child: const Text(
                                          'Observer (Ayah)',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF072846),
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.25),
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                                        ),
                                        child: const Text(
                                          'Ibu',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Hari ini: ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Pantau tumbuh kembang si kecil setiap hari.',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    height: 1.4,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Tombol CTA ke Halaman Panduan
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pushNamed(context, Routes.guide);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF047857),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 18),
                                    ),
                                    icon: const Icon(Icons.auto_stories_rounded, size: 18),
                                    label: const Text(
                                      'Lihat Panduan',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Section Title: Aksi Cepat
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: const [
                              Text(
                                'Aksi Cepat',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Shortcut Items Grid (2 rows x 3 columns)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: GridView.count(
                            crossAxisCount: 3,
                            childAspectRatio: 0.85,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: shortcuts,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // [PLACEHOLDER] Section: Ringkasan Si Kecil (Dasbor Analitik Anak Placeholder)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Ringkasan Si Kecil',
                                      style: TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => Navigator.pushNamed(context, Routes.profileInfantDetail),
                                      borderRadius: BorderRadius.circular(8),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        child: Text(
                                          'Detail >',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFD1FAE5),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.child_care_rounded,
                                        color: Color(0xFF064E3B),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            'Si Kecil',
                                            style: TextStyle(
                                              fontFamily: 'Nunito',
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Pemantauan Tumbuh Kembang Aktif',
                                            style: TextStyle(
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
                                        color: const Color(0xFFD1FAE5),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: const Color(0xFFA7F3D0)),
                                      ),
                                      child: const Text(
                                        'Sehat',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF064E3B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Interactive Banner Carousel with Soft Elevation Shadow (Klik Banner -> URL News)
                        if (_bannerItems.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: const Text(
                                  'Edukasi & Berita Hari Ini',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: MediaQuery.of(context).size.width * (9 / 21),
                                child: GestureDetector(
                                  onPanDown: (_) => _stopAutoScroll(),
                                  onPanCancel: _startAutoScroll,
                                  onPanEnd: (_) => _startAutoScroll(),
                                  child: PageView.builder(
                                    controller: _bannerController,
                                    onPageChanged: (index) {
                                      setState(() {
                                        _currentBannerIndex = index;
                                      });
                                    },
                                    itemCount: _bannerItems.length,
                                    itemBuilder: (context, index) {
                                      final item = _bannerItems[index];
                                      return AnimatedBuilder(
                                        animation: _bannerController,
                                        builder: (context, child) {
                                          double value = 1.0;
                                          if (_bannerController.position.haveDimensions) {
                                            value = _bannerController.page! - index;
                                            value = (1 - (value.abs() * 0.08)).clamp(0.0, 1.0);
                                          }
                                          return Transform.scale(
                                            scale: value,
                                            child: child,
                                          );
                                        },
                                        child: Material(
                                          color: Colors.transparent,
                                          borderRadius: BorderRadius.circular(16),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(16),
                                            onTap: () => _openBannerUrl(item['url']!, title: item['title']),
                                            child: Container(
                                              margin: const EdgeInsets.symmetric(horizontal: 6.0),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(16),
                                                image: DecorationImage(
                                                  image: NetworkImage(item['image']!),
                                                  fit: BoxFit.cover,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              // Carousel Indicator Dots
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  _bannerItems.length,
                                  (index) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                                    height: 8.0,
                                    width: _currentBannerIndex == index ? 24.0 : 8.0,
                                    decoration: BoxDecoration(
                                      color: _currentBannerIndex == index
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFCBD5E1),
                                      borderRadius: BorderRadius.circular(4.0),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 24),

                        // Observer Info Card
                        if (isFather)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFBAE6FD)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline, color: Color(0xFF0284C7), size: 24),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Sebagai Ayah, Anda dapat memantau hasil dan data yang diisi oleh Ibu (Pretest, Posttest, Jurnal, dll).',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF072846),
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

// Refactored Shortcut widget utilizing assets/icons PNG image assets
class _Shortcut extends StatelessWidget {
  final String assetPath;
  final String label;
  final VoidCallback onTap;

  const _Shortcut({
    required this.assetPath,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFA7F3D0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Image.asset(
                assetPath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.grid_view_rounded,
                  color: Color(0xFF10B981),
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}