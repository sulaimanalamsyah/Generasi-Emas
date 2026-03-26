import 'package:flutter/material.dart';
import '../services/fcm_service.dart';
import '../services/api_client.dart';
import '../core/storage.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _isEnabled = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final enabled = await Prefs.getNotificationEnabled();
    if (mounted) {
      setState(() {
        _isEnabled = enabled;
      });
    }
  }

  Future<void> _toggleNotification(bool value) async {
    setState(() => _isLoading = true);
    try {
      if (value) {
        await FcmService().enableNotifications();
      } else {
        await FcmService().disableNotifications();
      }

      await Prefs.setNotificationEnabled(value);

      if (mounted) {
        setState(() {
          _isEnabled = value;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {});

        String msg = "Gagal mengubah pengaturan: $e";

        // HANDLING ERROR OFFLINE
        if (e is ApiError && e.status == 0) {
          msg = "Tidak ada koneksi internet. Gagal sinkronisasi pengaturan.";
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      {'time': '07:00', 'text': 'Ingat perawatan harian sesuai CO Partner'},
      {'time': '13:00', 'text': 'Kunjungan siang hari'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: Column(
        children: [
          Material(
            color: Colors.white,
            elevation: 1,
            child: SwitchListTile(
              secondary: Icon(
                _isEnabled ? Icons.notifications_active : Icons.notifications_off,
                color: _isEnabled ? Colors.teal : Colors.grey,
              ),
              title: const Text("Aktifkan Notifikasi"),
              subtitle: Text(
                _isEnabled ? "Anda akan menerima pengingat harian" : "Notifikasi dimatikan",
                style: const TextStyle(fontSize: 12),
              ),
              value: _isEnabled,
              onChanged: _isLoading ? null : _toggleNotification,
              activeTrackColor: Colors.teal,
              activeThumbColor: Colors.white,
            ),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  "Jadwal Pengingat",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600]
                  )
              ),
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: Opacity(
              opacity: _isEnabled ? 1.0 : 0.5,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemBuilder: (_, i) => Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(8)
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.access_time, color: Colors.teal),
                    title: Text(
                      items[i]['time']!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(items[i]['text']!),
                  ),
                ),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: items.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}