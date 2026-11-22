import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import '../core/age_calculator.dart';
import '../core/maternal_guide_data.dart';
import '../core/storage.dart';
import '../routes.dart';
import '../widgets/common.dart';
import '../widgets/in_app_viewer_page.dart';
import '../services/api_client.dart';
import '../core/partner_sync.dart';

class HomePatientPage extends StatefulWidget {
  const HomePatientPage({super.key});

  @override
  State<HomePatientPage> createState() => _HomePatientPageState();
}

class _HomePatientPageState extends State<HomePatientPage> with WidgetsBindingObserver {
  final _api = ApiClient();
  String _displayName = '';
  String _role = '';
  bool _isLoading = true;
  bool _isOfflineCached = false;
  String? _errorMessage;
  Map<String, dynamic>? _infantAnalytics;
  Map<String, dynamic>? _pendingPartnerRequest;
  List<Map<String, dynamic>> _maternalGuideSlots = kDefaultMaternalGuideSlots;

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
    WidgetsBinding.instance.addObserver(this);
    PartnerSync.notifier.addListener(_onPartnerSync);
    _bannerController = PageController(viewportFraction: 0.9);
    _initData();
    _startAutoScroll();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startAutoScroll();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopAutoScroll();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PartnerSync.notifier.removeListener(_onPartnerSync);
    _bannerController.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _onPartnerSync() {
    if (mounted && _role != 'guest') {
      _loadPartnerStatusFromApi();
    }
  }

  void _startAutoScroll() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (_bannerController.hasClients && _bannerItems.length > 1) {
        int nextIndex = _currentBannerIndex + 1;
        if (nextIndex >= _bannerItems.length) nextIndex = 0;
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
      showAppSnackBar(context, message: 'Tautan edukasi tidak valid.', isError: true);
      return;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      showAppSnackBar(context, message: 'Format URL tidak valid.', isError: true);
      return;
    }

    final pageTitle = (title != null && title.trim().isNotEmpty) ? title.trim() : 'Berita Edukasi';
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InAppViewerPage(title: pageTitle, url: trimmed)),
    );
  }

  Future<void> _initData() async {
    setState(() {
      _errorMessage = null;
      _isOfflineCached = false;
    });

    final localName = await Prefs.getDisplayName();
    final localRole = (await Prefs.getRole()) ?? 'mother';

    if (mounted) {
      setState(() {
        _displayName = localName ?? (localRole == 'guest' ? 'Tamu' : '');
        _role = localRole;
      });
    }

    if (localRole == 'guest') {
      await _loadBannersFromApi();
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    await Future.wait([
      _loadProfileFromApi(),
      _loadBannersFromApi(),
      _loadInfantSummaryFromApi(),
      _loadPartnerStatusFromApi(),
      _loadMaternalGuide(),
    ]);
  }

  Future<void> _loadMaternalGuide() async {
    final slots = await fetchMaternalGuideWithFallback();
    if (mounted) {
      setState(() => _maternalGuideSlots = slots);
    }
  }

  Future<void> _loadPartnerStatusFromApi() async {
    try {
      final res = await _api.getPartnerStatus();
      if (!mounted) return;
      setState(() {
        _pendingPartnerRequest = (res['role'] == 'mother' && res['pendingRequest'] != null)
            ? res['pendingRequest'] as Map<String, dynamic>
            : null;
      });
    } catch (e) {
      debugPrint('Gagal load partner status on home: $e');
    }
  }

  Future<void> _loadInfantSummaryFromApi() async {
    try {
      final res = await _api.getInfantAnalytics('me');
      if (res.isNotEmpty) {
        await Prefs.setCachedJson('infant_analytics_me', res);
      }
      if (mounted) {
        setState(() => _infantAnalytics = res);
      }
    } catch (e) {
      if (e is ApiError && e.status == 0) {
        final cached = await Prefs.getCachedJson('infant_analytics_me');
        if (cached is Map && mounted) {
          setState(() {
            _infantAnalytics = Map<String, dynamic>.from(cached);
            _isOfflineCached = true;
          });
        }
      }
    }
  }

  Future<void> _loadBannersFromApi() async {
    try {
      final banners = await _api.getBanners();
      if (banners.isNotEmpty) {
        await Prefs.setCachedJson('home_banners', banners);
        if (mounted) {
          setState(() {
            _bannerItems = banners;
            _currentBannerIndex = 0;
          });
          _startAutoScroll();
        }
        return;
      }
    } catch (_) {}

    final cached = await Prefs.getCachedJson('home_banners');
    if (cached is List && cached.isNotEmpty && mounted) {
      final parsed = cached
          .whereType<Map>()
          .map((m) => m.map((k, v) => MapEntry(k.toString(), v.toString())))
          .toList();
      if (parsed.isNotEmpty) {
        setState(() => _bannerItems = parsed);
      }
    }
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
        await Prefs.setCachedJson('my_profile', res);
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
            await Prefs.setDisplayName(nameToShow);
            await Prefs.setPhone((accountObj['phone'] as String?) ?? '-');
          }
        } else if (profileObj != null) {
          String rawName = (profileObj['name'] as String?) ?? '';
          if (rawName.isEmpty) rawName = (profileObj['motherName'] as String?) ?? '';
          if (rawName.isNotEmpty) {
            nameToShow = _titleCase(rawName);
            await Prefs.setDisplayName(nameToShow);
          }
          final userObj = profileObj['user'] ?? {};
          if (userObj['phone'] != null) await Prefs.setPhone(userObj['phone']);
        }

        setState(() {
          _role = detectedRole;
          _displayName = nameToShow;
          _isLoading = false;
        });
        await Prefs.setRole(detectedRole);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      if (e is ApiError && e.status == 0) {
        final cached = await Prefs.getCachedJson('my_profile');
        if (cached is Map || _displayName.isNotEmpty) {
          setState(() {
            _isOfflineCached = true;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Tidak ada koneksi internet.';
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  String _titleCase(String s) {
    if (s.isEmpty) return '';
    return s
        .trim()
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  Widget _buildPendingPartnerBanner() {
    final req = _pendingPartnerRequest!;
    final reqName = req['requesterName'] as String? ?? 'Ayah';
    final reqPhone = req['requesterPhone'] as String? ?? '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: Color(0xFFFDE68A), shape: BoxShape.circle),
                child: const Icon(Icons.supervised_user_circle_rounded, color: Color(0xFFD97706), size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Permintaan Penautan Akun',
                      style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF92400E)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$reqName ($reqPhone) ingin menautkan akun untuk memantau tumbuh kembang bayi bersama.',
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF78350F), height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _showPartnerApprovalBottomSheet(req),
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: const Text('Tinjau Permintaan', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPartnerApprovalBottomSheet(Map<String, dynamic> request) {
    final requestId = request['id'] as String;
    final reqName = request['requesterName'] as String? ?? 'Ayah';
    final reqPhone = request['requesterPhone'] as String? ?? '-';
    final rawDate = request['createdAt'];
    final dt = rawDate != null ? DateTime.tryParse(rawDate.toString())?.toLocal() : null;
    final dateStr = dt != null ? '${DateFormat('d MMMM yyyy, HH:mm', 'id_ID').format(dt)} WIB' : '-';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        bool isResponding = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: sheetBottomPadding(ctx, horizontal: 20, top: 16, extra: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(999)),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(color: Color(0xFFD1FAE5), shape: BoxShape.circle),
                      child: const Icon(Icons.family_restroom_rounded, color: Color(0xFF10B981), size: 32),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Permintaan Penautan Pasangan',
                      style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Akun Ayah meminta izin untuk memantau data perkembangan bayi Anda.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nama Ayah: $reqName', style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Nomor Ponsel: $reqPhone', style: const TextStyle(fontFamily: 'Inter', fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('Waktu: $dateStr', style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (isResponding)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(color: Color(0xFF10B981)),
                      )
                    else
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 48),
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFEF4444),
                                    side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () async {
                                    setSheetState(() => isResponding = true);
                                    try {
                                      await _api.respondPartnerRequest(requestId: requestId, approve: false);
                                      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                                      if (mounted) {
                                        showAppSnackBar(context, message: 'Permintaan penautan ditolak.');
                                        _initData();
                                        PartnerSync.notify();
                                      }
                                    } catch (e) {
                                      setSheetState(() => isResponding = false);
                                      if (mounted) showAppSnackBar(context, message: 'Gagal menolak: $e', isError: true);
                                    }
                                  },
                                  child: const Text('Tolak', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 48),
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () async {
                                    setSheetState(() => isResponding = true);
                                    try {
                                      await _api.respondPartnerRequest(requestId: requestId, approve: true);
                                      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                                      if (mounted) {
                                        showAppSnackBar(context, message: 'Berhasil! Akun Ayah kini terhubung.');
                                        _initData();
                                        PartnerSync.notify();
                                      }
                                    } catch (e) {
                                      setSheetState(() => isResponding = false);
                                      if (mounted) showAppSnackBar(context, message: 'Gagal menyetujui: $e', isError: true);
                                    }
                                  },
                                  child: const Text('Setujui', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isGuest = _role == 'guest';
    final bool isFather = _role == 'father';
    final greetName = isGuest ? 'Tamu' : (_displayName.isEmpty ? 'Ibu/Ayah' : _titleCase(_displayName));
    final activeSlot = activeMaternalGuideSlot(_maternalGuideSlots);

    final List<Widget> row1Shortcuts = [
      _Shortcut(
        assetPath: 'assets/icons/pre-test.png',
        label: 'Pre-Test',
        locked: isGuest,
        onTap: () => isGuest ? showGuestGateDialog(context) : Navigator.pushNamed(context, Routes.pretest),
      ),
      _Shortcut(
        assetPath: 'assets/icons/post-test.png',
        label: 'Post-Test',
        locked: isGuest,
        onTap: () => isGuest ? showGuestGateDialog(context) : Navigator.pushNamed(context, Routes.posttest),
      ),
      _Shortcut(
        assetPath: 'assets/icons/quiz.png',
        label: 'Kuis',
        locked: isGuest,
        onTap: () => isGuest ? showGuestGateDialog(context) : Navigator.pushNamed(context, Routes.quiz),
      ),
    ];

    final List<Widget> row2Shortcuts = [
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
        showLogo: true,
        actions: [
          if (isGuest)
            IconButton(
              onPressed: () => exitGuestMode(context),
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 22),
              tooltip: 'Keluar Mode Tamu',
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () {
                if (isGuest) {
                  showGuestGateDialog(context);
                } else {
                  Navigator.pushNamed(context, Routes.notifications);
                }
              },
              icon: const Icon(Icons.notifications_outlined, color: Color(0xFF0F172A), size: 24),
              tooltip: 'Notifikasi',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF10B981)),
                  SizedBox(height: 16),
                  Text('Memuat beranda...', style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF64748B))),
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
                          decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                          child: const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text('Periksa koneksi internet Anda.', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF64748B))),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _initData,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(140, 48),
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba Lagi'),
                        ),
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
                        if (_isOfflineCached)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.cloud_off_rounded, size: 18, color: Color(0xFFD97706)),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Mode Offline — menampilkan data tersimpan terakhir',
                                      style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        if (_pendingPartnerRequest != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                            child: _buildPendingPartnerBanner(),
                          ),

                        // Hero Greeting Card
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
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    Text(
                                      'Halo, $greetName!',
                                      style: const TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isFather
                                            ? const Color(0xFFE0F2FE)
                                            : Colors.white.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                          color: isFather
                                              ? const Color(0xFFBAE6FD)
                                              : Colors.white.withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Text(
                                        isGuest ? 'Mode Tamu' : (isFather ? 'Ayah (Pemantau)' : 'Ibu'),
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isFather ? const Color(0xFF072846) : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Hari ini: ${DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.now())}',
                                  style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Kehadiran, sentuhan, dan kedekatan Ibu setiap hari sangat berarti untuk kesembuhan bayi',
                                  style: TextStyle(fontFamily: 'Inter', fontSize: 13.5, height: 1.45, color: Colors.white, fontWeight: FontWeight.w500),
                                ),
                                if (!isGuest) ...[
                                  const SizedBox(height: 16),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(minHeight: 48),
                                    child: ElevatedButton.icon(
                                      onPressed: () => Navigator.pushNamed(context, Routes.guide),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: const Color(0xFF047857),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                      ),
                                      icon: const Icon(Icons.auto_stories_rounded, size: 18),
                                      label: const Text(
                                        'Lihat Panduan',
                                        style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // Quick Active Maternal NICU Schedule Banner (Authenticated Users)
                        if (!isGuest && activeSlot != null) ...[
                          const SizedBox(height: 14),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: InkWell(
                              onTap: () => Navigator.pushNamed(context, Routes.guide),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFA7F3D0)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.schedule_rounded, color: Colors.white, size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Aktivitas NICU Saat Ini (${activeSlot['timeRange']} WIB)',
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF047857),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${activeSlot['title']}',
                                            style: const TextStyle(
                                              fontFamily: 'Nunito',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF059669)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),

                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Aksi Cepat',
                            style: TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Responsive 3-column shortcut rows without rigid aspect-ratio clipping
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: row1Shortcuts.map((w) => Expanded(child: w)).toList(),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: row2Shortcuts.map((w) => Expanded(child: w)).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: isGuest
                              ? _buildGuestWelcomeCard()
                              : _buildRingkasanSiKecilCard(),
                        ),
                        const SizedBox(height: 24),

                        if (_bannerItems.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20),
                                child: Text(
                                  'Edukasi & Berita Hari Ini',
                                  style: TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
                                    onPageChanged: (index) => setState(() => _currentBannerIndex = index),
                                    itemCount: _bannerItems.length,
                                    itemBuilder: (context, index) {
                                      final item = _bannerItems[index];
                                      return RepaintBoundary(
                                        child: AnimatedBuilder(
                                          animation: _bannerController,
                                          builder: (context, child) {
                                            double value = 1.0;
                                            if (_bannerController.position.haveDimensions) {
                                              value = (_bannerController.page ?? 0) - index;
                                              value = (1 - (value.abs() * 0.08)).clamp(0.0, 1.0);
                                            }
                                            return Transform.scale(scale: value, child: child);
                                          },
                                          child: Material(
                                            color: Colors.transparent,
                                            borderRadius: BorderRadius.circular(16),
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(16),
                                              onTap: () => _openBannerUrl(item['url'] ?? '', title: item['title']),
                                              child: Container(
                                                margin: const EdgeInsets.symmetric(horizontal: 6.0),
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(16),
                                                  color: const Color(0xFFE2E8F0),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                                                      blurRadius: 12,
                                                      offset: const Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                                clipBehavior: Clip.antiAlias,
                                                child: Image.network(
                                                  item['image'] ?? '',
                                                  fit: BoxFit.cover,
                                                  cacheWidth: 960,
                                                  errorBuilder: (_, __, ___) => const Center(
                                                    child: Icon(Icons.image_not_supported_outlined, color: Color(0xFF64748B)),
                                                  ),
                                                ),
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
                                      color: _currentBannerIndex == index ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                                      borderRadius: BorderRadius.circular(4.0),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                        if (isFather) ...[
                          const SizedBox(height: 24),
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
                                      'Sebagai Ayah (Pemantau), Anda dapat melihat hasil evaluasi, tumbuh kembang, logbook ibu, dan jurnal bayi.',
                                      style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF072846), height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildGuestWelcomeCard() {
    return InkWell(
      onTap: () => showGuestGateDialog(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBAE6FD)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: Color(0xFFE0F2FE), shape: BoxShape.circle),
              child: const Icon(Icons.child_care_rounded, color: Color(0xFF0284C7), size: 28),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mode Tamu ENICare',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Daftar atau masuk untuk memantau tumbuh kembang bayi, mengisi Logbook Ibu, Jurnal Bayi, dan mengikuti Evaluasi.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Color(0xFF475569), height: 1.4),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF0284C7)),
          ],
        ),
      ),
    );
  }

  Widget _buildRingkasanSiKecilCard() {
    final infant = (_infantAnalytics?['infant'] as Map?)?.cast<String, dynamic>() ?? {};
    final latestMeasurement = (_infantAnalytics?['latestMeasurement'] as Map?)?.cast<String, dynamic>() ?? {};
    final stuntingStatus = (_infantAnalytics?['stuntingStatus'] as Map?)?.cast<String, dynamic>() ?? {};
    final weightStatus = (_infantAnalytics?['weightStatus'] as Map?)?.cast<String, dynamic>() ?? {};

    final rawInfantName = (infant['name'] as String?)?.trim();
    final hasBabyData = rawInfantName != null && rawInfantName.isNotEmpty;
    final babyName = hasBabyData ? rawInfantName : 'Nama Bayi Belum Diisi';

    String ageStr = (_infantAnalytics?['currentAge']?['formatted'] as String?) ?? '';
    if (ageStr.isEmpty && infant['birthDate'] != null) {
      final parsedDob = ApiClient.parseDate(infant['birthDate']);
      if (parsedDob != null) ageStr = InfantAge.calculate(parsedDob).formatted;
    }
    if (ageStr.isEmpty) ageStr = (infant['age'] as String?) ?? '-';

    final gender = (infant['babyGender'] as String?) ?? (infant['gender'] as String?) ?? '-';
    final isMale = gender.toLowerCase().contains('laki') || gender.toLowerCase().contains('male');

    final stuntingLabel = (stuntingStatus['label'] as String?) ?? 'Belum Ada Data';
    final rawStuntingCat = (stuntingStatus['category'] as String?) ?? '';
    final weightLabel = (weightStatus['label'] as String?) ?? 'Belum Ada Data';
    final rawWeightCat = (weightStatus['category'] as String?) ?? '';

    final zLength = latestMeasurement['zScoreLength'];
    final zWeight = latestMeasurement['zScoreWeight'];
    final lastDate = latestMeasurement['date'] as String?;

    Color stuntingColor = const Color(0xFF10B981);
    Color stuntingBg = const Color(0xFFD1FAE5);
    IconData stuntingIcon = Icons.check_circle_rounded;
    if (rawStuntingCat == 'SEVERELY_STUNTED' || stuntingLabel.contains('Sangat')) {
      stuntingColor = const Color(0xFFDC2626);
      stuntingBg = const Color(0xFFFEE2E2);
      stuntingIcon = Icons.error_outline_rounded;
    } else if (rawStuntingCat == 'STUNTED' || stuntingLabel.contains('Indikasi Stunting')) {
      stuntingColor = const Color(0xFFD97706);
      stuntingBg = const Color(0xFFFEF3C7);
      stuntingIcon = Icons.warning_amber_rounded;
    } else if (rawStuntingCat == 'TALL' || stuntingLabel.contains('Tinggi')) {
      stuntingColor = const Color(0xFF0284C7);
      stuntingBg = const Color(0xFFE0F2FE);
      stuntingIcon = Icons.trending_up_rounded;
    }

    Color weightColor = const Color(0xFF10B981);
    Color weightBg = const Color(0xFFD1FAE5);
    if (rawWeightCat == 'SEVERELY_UNDERWEIGHT' || weightLabel.contains('Sangat Kurang')) {
      weightColor = const Color(0xFFDC2626);
      weightBg = const Color(0xFFFEE2E2);
    } else if (rawWeightCat == 'UNDERWEIGHT' || weightLabel.contains('Kurang')) {
      weightColor = const Color(0xFFD97706);
      weightBg = const Color(0xFFFEF3C7);
    } else if (rawWeightCat == 'OVERWEIGHT' || weightLabel.contains('Lebih')) {
      weightColor = const Color(0xFF0284C7);
      weightBg = const Color(0xFFE0F2FE);
    }

    return InkWell(
      onTap: () async {
        await Navigator.pushNamed(context, Routes.infantAnalytics);
        if (mounted) _loadInfantSummaryFromApi();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [BoxShadow(color: Color(0x080F172A), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Max-font safe responsive header
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: const [
                Text(
                  'Ringkasan Si Kecil',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                Text(
                  'Lihat Grafik & Analisis >',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isMale ? const Color(0xFFE0F2FE) : const Color(0xFFFCE7F3),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.child_care_rounded, color: isMale ? const Color(0xFF0284C7) : const Color(0xFFDB2777), size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        babyName,
                        style: const TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isMale ? const Color(0xFFE0F2FE) : const Color(0xFFFCE7F3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isMale ? 'Laki-laki' : (gender == '-' ? '-' : 'Perempuan'),
                              style: TextStyle(fontFamily: 'Inter', fontSize: 10.5, fontWeight: FontWeight.w700, color: isMale ? const Color(0xFF0369A1) : const Color(0xFFBE185D)),
                            ),
                          ),
                          Text(
                            ageStr,
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: stuntingBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: stuntingColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(stuntingIcon, size: 13, color: stuntingColor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          stuntingLabel,
                          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 11, color: stuntingColor),
                        ),
                      ),
                    ],
                  ),
                ),
                if (rawWeightCat.isNotEmpty && weightLabel != 'Belum Ada Data')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: weightBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: weightColor.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      weightLabel,
                      style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 11, color: weightColor),
                    ),
                  ),
                if (zWeight != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                    child: Text('Z-BB: $zWeight SD', style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                  ),
                if (zLength != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                    child: Text('Z-PB: $zLength SD', style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                  ),
              ],
            ),
            if (lastDate != null && (zLength != null || zWeight != null)) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Diukur: $lastDate',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 10.5, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  final String assetPath;
  final String label;
  final VoidCallback onTap;
  final bool locked;

  const _Shortcut({
    required this.assetPath,
    required this.label,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: locked ? const Color(0xFFF1F5F9) : const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: locked ? const Color(0xFFE2E8F0) : const Color(0xFFA7F3D0)),
                    ),
                    child: Image.asset(
                      assetPath,
                      cacheWidth: 160,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.grid_view_rounded, color: Color(0xFF10B981), size: 32),
                    ),
                  ),
                  if (locked)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Icon(Icons.lock_rounded, size: 12, color: Color(0xFF64748B)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
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
      ),
    );
  }
}
