import 'package:material_ui/material_ui.dart';
import '../routes.dart';
import '../services/fcm_service.dart';
import '../services/api_client.dart';
import '../core/storage.dart';
import '../core/constants.dart';
import '../widgets/common.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _api = ApiClient();
  bool _isEnabled = true;
  bool _isLoading = true;
  bool _isToggling = false;
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _schedules = [];
  int _unreadCount = 0;
  String? _errorMessage;

  static const _kNotifCacheKey = 'user_notifications_v1';

  static const List<Map<String, dynamic>> _fallbackSchedules = [
    {
      'id': 'morning',
      'label': 'Pengingat Pagi',
      'hourWib': 7,
      'minuteWib': 0,
      'title': 'Selamat Pagi Ayah & Bunda!',
      'body': 'Awali hari dengan mencatat asupan ASI dan perkembangan si kecil hari ini.',
      'route': '/logbook',
      'enabled': true,
    },
    {
      'id': 'evening',
      'label': 'Pengingat Malam',
      'hourWib': 19,
      'minuteWib': 0,
      'title': 'Waktunya Refleksi Harian',
      'body': 'Sudahkah mengisi jurnal dan melihat panduan stimulasi tumbuh kembang hari ini?',
      'route': '/babyJournal',
      'enabled': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  List<Map<String, dynamic>> _extractSchedules(dynamic raw) {
    if (raw is List && raw.isNotEmpty) {
      return raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    return _fallbackSchedules;
  }

  void _applyNotifPayload(Map<String, dynamic> notifData, bool resolvedEnabled, List<Map<String, dynamic>> schedules) {
    setState(() {
      _isEnabled = resolvedEnabled;
      _schedules = schedules;
      if (notifData['notifications'] is List) {
        _notifications = (notifData['notifications'] as List)
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
      _unreadCount = notifData['unreadCount'] as int? ?? 0;
      _isLoading = false;
    });
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final localEnabled = await Prefs.getNotificationEnabled();
    try {
      final notifData = await _api.getNotifications();
      final bool? serverEnabled = notifData['notificationsEnabled'] as bool?;
      final bool resolvedEnabled = serverEnabled ?? localEnabled;
      if (serverEnabled != null && serverEnabled != localEnabled) {
        await Prefs.setNotificationEnabled(serverEnabled);
      }

      List<Map<String, dynamic>> schedules = _extractSchedules(notifData['schedules']);
      if (notifData['schedules'] is! List || (notifData['schedules'] as List).isEmpty) {
        try {
          final fetchedSchedules = await _api.getNotificationSchedules();
          if (fetchedSchedules.isNotEmpty) schedules = fetchedSchedules;
        } catch (_) {}
      }

      await Prefs.setCachedJson(_kNotifCacheKey, {
        ...notifData,
        'schedules': schedules,
      });

      await FcmService().syncScheduledDailyReminders(schedules, enabled: resolvedEnabled);

      if (mounted) {
        _applyNotifPayload(notifData, resolvedEnabled, schedules);
      }
    } catch (e) {
      if (!mounted) return;
      if (e is ApiError && e.status == 0) {
        final cached = await Prefs.getCachedJson(_kNotifCacheKey);
        if (!mounted) return;
        if (cached is Map) {
          final cachedMap = Map<String, dynamic>.from(cached);
          final cachedEnabled = (cachedMap['notificationsEnabled'] as bool?) ?? localEnabled;
          final cachedSchedules = _extractSchedules(cachedMap['schedules']);
          _applyNotifPayload(cachedMap, cachedEnabled, cachedSchedules);
          showAppSnackBar(
            context,
            message: 'Menampilkan notifikasi terakhir tersimpan (mode luring).',
          );
          return;
        }
      }
      String msg = "Gagal memuat riwayat notifikasi: $e";
      if (e is ApiError && e.status == 0) {
        msg = "Tidak ada koneksi internet. Mode luring.";
      }
      setState(() {
        _schedules = _schedules.isEmpty ? _fallbackSchedules : _schedules;
        _isEnabled = localEnabled;
        _errorMessage = msg;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleNotification(bool value) async {
    setState(() => _isToggling = true);
    try {
      await _api.updateNotificationSettings(value);
      if (value) {
        try {
          await FcmService().enableNotifications();
        } catch (_) {}
      } else {
        try {
          await FcmService().disableNotifications();
        } catch (_) {}
      }

      await Prefs.setNotificationEnabled(value);
      final activeSchedules = _schedules.isNotEmpty ? _schedules : _fallbackSchedules;
      await FcmService().syncScheduledDailyReminders(activeSchedules, enabled: value);

      if (mounted) {
        setState(() {
          _isEnabled = value;
        });
        showAppSnackBar(
          context,
          message: value
              ? "Notifikasi pengingat harian diaktifkan"
              : "Notifikasi pengingat harian dinonaktifkan",
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = "Gagal mengubah pengaturan: $e";
        if (e is ApiError && e.status == 0) {
          msg = "Tidak ada koneksi internet. Gagal sinkronisasi pengaturan.";
        }
        showAppSnackBar(context, message: msg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  Future<void> _markSingleRead(int index) async {
    final item = _notifications[index];
    final notifId = item['id'] as int?;
    final isRead = item['isRead'] as bool? ?? false;
    final route = item['route'] as String?;
    final type = item['type']?.toString();

    if (notifId != null && !isRead) {
      setState(() {
        _notifications[index]['isRead'] = true;
        if (_unreadCount > 0) _unreadCount--;
      });
      _api.markNotificationAsRead(notifId);
    }

    if (type == 'reminder' ||
        route == Routes.babyJournal ||
        route == '/logbook' ||
        route == null ||
        route.isEmpty) {
      if (mounted) Navigator.pushNamed(context, Routes.babyJournal);
      return;
    }

    Navigator.pushNamed(context, route);
  }

  Future<void> _markAllRead() async {
    if (_unreadCount == 0) return;

    setState(() {
      for (var n in _notifications) {
        n['isRead'] = true;
      }
      _unreadCount = 0;
    });

    try {
      await _api.markAllNotificationsAsRead();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Semua notifikasi telah ditandai dibaca",
                style: TextStyle(fontFamily: 'Inter')),
            backgroundColor: kPrimary,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  String _formatTimestamp(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      final hourStr = dt.hour.toString().padLeft(2, '0');
      final minuteStr = dt.minute.toString().padLeft(2, '0');
      final timeStr = "$hourStr:$minuteStr WIB";

      if (diff.inDays == 0 && dt.day == now.day) {
        return "Hari ini, $timeStr";
      } else if (diff.inDays == 1 || (diff.inDays == 0 && dt.day == now.day - 1)) {
        return "Kemarin, $timeStr";
      } else if (diff.inDays < 7) {
        return "${diff.inDays} hari lalu, $timeStr";
      } else {
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
          'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
        ];
        return "${dt.day} ${months[dt.month - 1]} ${dt.year}, $timeStr";
      }
    } catch (_) {
      return dateStr;
    }
  }

  IconData _getCategoryIcon(String? type) {
    switch (type) {
      case 'evaluation':
      case 'posttest':
      case 'pretest':
        return Icons.assignment_outlined;
      case 'quiz':
        return Icons.quiz_outlined;
      case 'video':
      case 'brainstorm':
        return Icons.play_circle_outline_rounded;
      case 'reminder':
      default:
        return Icons.alarm_rounded;
    }
  }

  Color _getCategoryColor(String? type) {
    switch (type) {
      case 'evaluation':
      case 'posttest':
      case 'pretest':
        return const Color(0xFF0EA5E9); // Sky blue
      case 'quiz':
        return const Color(0xFF8B5CF6); // Purple
      case 'video':
      case 'brainstorm':
        return const Color(0xFFF59E0B); // Amber
      case 'reminder':
      default:
        return kPrimary; // Emerald #10B981
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: enicareAppBar(
        context,
        title: 'Notifikasi',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
            onPressed: _isLoading ? null : _loadAll,
            tooltip: 'Perbarui',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
        onRefresh: _loadAll,
        color: kPrimary,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // 1. MASTER PUSH CONTROL CARD
            _buildMasterSwitchCard(),

            const SizedBox(height: 16),

            // 2. DYNAMIC SCHEDULE BREAKDOWN CARD
            _buildScheduleCard(),

            const SizedBox(height: 24),

            // 3. INBOX HEADER & ACTIONS (Wrap prevents 14px max-font overflow)
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Riwayat Notifikasi",
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (_unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "$_unreadCount baru",
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF064E3B),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_unreadCount > 0)
                    TextButton.icon(
                      onPressed: _markAllRead,
                      icon: const Icon(Icons.done_all_rounded,
                          size: 16, color: kPrimary),
                      label: const Text(
                        "Tandai Semua Dibaca",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kPrimary,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        minimumSize: const Size(48, 44),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 4. NOTIFICATION INBOX LIST OR EMPTY/ERROR STATES
            if (_isLoading)
              _buildLoadingShimmer()
            else if (_errorMessage != null && _notifications.isEmpty)
              _buildErrorCard()
            else if (_notifications.isEmpty)
              _buildEmptyState()
            else
              ...List.generate(_notifications.length, (index) {
                return _buildNotificationCard(index);
              }),

            const SizedBox(height: 32),
          ],
        ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  String _formatScheduleTime(Map<String, dynamic> s) {
    final h = (int.tryParse('${s['hourWib'] ?? 7}') ?? 7).toString().padLeft(2, '0');
    final m = (int.tryParse('${s['minuteWib'] ?? 0}') ?? 0).toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _buildMasterSwitchCard() {
    final activeSlots = (_schedules.isNotEmpty ? _schedules : _fallbackSchedules)
        .where((s) => s['enabled'] != false)
        .toList();
    final timesSummary = activeSlots.isNotEmpty
        ? '${activeSlots.map(_formatScheduleTime).join(' & ')} WIB'
        : 'Aktif';
    final isLargeText = MediaQuery.textScalerOf(context).scale(15) > 19.5;

    final switchControl = Switch(
      value: _isEnabled,
      onChanged: _isToggling ? null : _toggleNotification,
      activeTrackColor: kPrimary,
      activeThumbColor: Colors.white,
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: const Color(0xFFCBD5E1),
    );

    final textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Pengingat Otomatis",
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _isEnabled
              ? "Pengingat harian aktif ($timesSummary)"
              : "Notifikasi pengingat dinonaktifkan",
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: _isEnabled ? const Color(0xFF047857) : const Color(0xFF64748B),
          ),
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isEnabled ? const Color(0xFFD1FAE5) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _isEnabled ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isEnabled
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_rounded,
                  color: _isEnabled ? kPrimary : const Color(0xFF94A3B8),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: isLargeText
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          textBlock,
                          const SizedBox(height: 8),
                          switchControl,
                        ],
                      )
                    : textBlock,
              ),
              if (!isLargeText) ...[
                const SizedBox(width: 8),
                switchControl,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleCard() {
    final activeSlots = (_schedules.isNotEmpty ? _schedules : _fallbackSchedules)
        .where((s) => s['enabled'] != false)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.schedule_rounded, size: 18, color: Color(0xFF047857)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Jadwal Pengingat Harian (I-FINC)",
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF064E3B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < activeSlots.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: Color(0x33064E3B), height: 1),
              ),
            _buildScheduleRow(
              time: '${_formatScheduleTime(activeSlots[i])} WIB',
              title: (activeSlots[i]['label'] ?? activeSlots[i]['title'] ?? 'Pengingat Harian').toString(),
              subtitle: (activeSlots[i]['body'] ?? 'Lengkapi catatan & aktivitas perawatan bayi hari ini.').toString(),
              icon: ((int.tryParse('${activeSlots[i]['hourWib'] ?? 7}') ?? 7) < 12)
                  ? Icons.wb_sunny_rounded
                  : Icons.nights_stay_rounded,
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: Color(0xFF047857)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Pengingat otomatis dijadwalkan setiap hari untuk Ibu dan Ayah.",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: Color(0xFF064E3B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleRow({
    required String time,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF047857),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                time,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF064E3B),
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: Color(0xFF047857),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard(int index) {
    final item = _notifications[index];
    final title = (item['title'] ?? 'Pengingat Harian').toString();
    final message = (item['message'] ?? '').toString();
    final isRead = item['isRead'] as bool? ?? false;
    final type = (item['type'] ?? 'reminder').toString();
    final firedAt = item['firedAt'] as String?;
    final route = item['route'] as String?;

    final categoryIcon = _getCategoryIcon(type);
    final categoryColor = _getCategoryColor(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead ? const Color(0xFFE2E8F0) : kPrimary.withValues(alpha: 0.5),
          width: isRead ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isRead
                ? const Color(0x040F172A)
                : kPrimary.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _markSingleRead(index),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(categoryIcon, color: categoryColor, size: 20),
                ),
                const SizedBox(width: 12),

                // Main Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 14,
                                fontWeight: isRead
                                    ? FontWeight.w600
                                    : FontWeight.w800,
                                color: isRead
                                    ? const Color(0xFF334155)
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 6),
                              decoration: const BoxDecoration(
                                color: kPrimary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          height: 1.35,
                          color: isRead
                              ? const Color(0xFF64748B)
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              _formatTimestamp(firedAt),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            if ((route != null && route.isNotEmpty) || item['type']?.toString() == 'reminder')
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "Buka",
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: kPrimary,
                                    ),
                                  ),
                                  SizedBox(width: 2),
                                  Icon(Icons.chevron_right_rounded,
                                      size: 14, color: kPrimary),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 36,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Belum Ada Riwayat Notifikasi",
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Pengingat harian sesuai jadwal aktif serta pengumuman penting akan tersimpan di sini.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 36, color: Color(0xFFEF4444)),
          const SizedBox(height: 10),
          Text(
            _errorMessage ?? "Gagal memuat notifikasi",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Color(0xFF991B1B),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text("Coba Lagi"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Column(
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}