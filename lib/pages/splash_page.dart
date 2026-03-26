import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/storage.dart';
import '../routes.dart';
import '../services/api_client.dart';
import '../widgets/common.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  bool _isVersionOlder(String current, String latest) {
    if (current.isEmpty || latest.isEmpty) return false;

    final cParts = current.split('+')[0].split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final lParts = latest.split('+')[0].split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final len = cParts.length > lParts.length ? cParts.length : lParts.length;

    for (int i = cParts.length; i < len; i++) {
      cParts.add(0);
    }
    for (int i = lParts.length; i < len; i++) {
      lParts.add(0);
    }

    for (int i = 0; i < len; i++) {
      if (cParts[i] < lParts[i]) return true;
      if (cParts[i] > lParts[i]) return false;
    }
    return false;
  }

  Future<void> _initApp() async {
    final api = ApiClient();

    // ------------------------------------------------------------
    // 1. APP VERSION CHECK
    // ------------------------------------------------------------
    try {
      final pkgInfo = await PackageInfo.fromPlatform();
      final currentVersion = pkgInfo.version;
      final versionConfig = await api.getAppVersionConfig();

      if (versionConfig.isNotEmpty) {
        final latestVersion = (versionConfig['latestVersion'] as String?) ?? currentVersion;
        final forceUpdate = (versionConfig['forceUpdate'] as bool?) ?? false;
        final storeUrl = (versionConfig['storeUrl'] as String?) ?? '';

        if (_isVersionOlder(currentVersion, latestVersion)) {
          if (!mounted) return;

          debugPrint("🚀 Update Available: $currentVersion -> $latestVersion (Force: $forceUpdate)");

          // Tampilkan Dialog
          await showDialog(
            context: context,
            barrierDismissible: !forceUpdate,
            builder: (ctx) => PopScope(
              canPop: !forceUpdate,
              child: AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.system_update, color: Colors.teal),
                    SizedBox(width: 8),
                    Text("Update Tersedia"),
                  ],
                ),
                content: Text(
                  forceUpdate
                      ? "Versi aplikasi Anda ($currentVersion) sudah usang. Mohon update ke versi terbaru ($latestVersion) agar aplikasi berjalan optimal."
                      : "Versi baru ($latestVersion) tersedia. Apakah Anda ingin update sekarang?",
                ),
                actions: [
                  if (!forceUpdate)
                    TextButton(
                      // Gunakan ctx (Dialog Context) untuk menutup dialog
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Nanti Saja"),
                    ),
                  FilledButton(
                    onPressed: () async {
                      if (storeUrl.isNotEmpty) {
                        final uri = Uri.parse(storeUrl);

                        try {
                          final success = await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );

                          if (!success) {
                            throw 'Could not launch $uri';
                          }
                        } catch (e) {
                          debugPrint("🔴 Gagal membuka link: $e");

                          // [FIX] Gunakan ctx (context dialog) dan cek ctx.mounted
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text("Gagal membuka link: $e")),
                          );
                        }
                      } else {
                        // [FIX] Gunakan ctx dan cek ctx.mounted
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text("Link update belum tersedia.")),
                          );
                        }
                      }

                      // [FIX UTAMA] Perbaikan Async Gap
                      if (!forceUpdate) {
                        // Pastikan DIALOG context (ctx) masih valid sebelum pop
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text("Update Sekarang"),
                  ),
                ],
              ),
            ),
          );

          if (forceUpdate) return;
        }
      }
    } catch (e) {
      debugPrint("⚠️ Gagal cek versi: $e");
    }

    // ------------------------------------------------------------
    // 2. Fetch Config Link Form
    // ------------------------------------------------------------
    try {
      final links = await api.getFormConfig();
      if (links.isNotEmpty) {
        debugPrint("🔍 DEBUG LINK CONFIG DITERIMA: ${links.length} items");
        await Prefs.setFormLinks(links);
      }
    } catch (e) {
      debugPrint("⚠️ Offline/Gagal load config: $e");
    }

    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    // 3. Cek Status Login
    final token = await Prefs.getToken();
    final role = await Prefs.getRole();

    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      if (role == 'nurse') {
        Navigator.pushReplacementNamed(context, Routes.nurseHome);
      } else {
        Navigator.pushReplacementNamed(context, Routes.homePatient);
      }
    } else {
      final last = await Prefs.getLastStartSeenMs();
      final now = DateTime.now().millisecondsSinceEpoch;
      const gateMs = 96 * 60 * 60 * 1000; // 96 jam

      final showStart = (last == null) || (now - last > gateMs);

      if (showStart) {
        await Prefs.setLastStartSeenNow();
      }

      if (!mounted) return;

      Navigator.pushReplacementNamed(
          context,
          showStart ? Routes.start : Routes.login
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppLogo(size: 120),
          SizedBox(height: 16),
          CircularProgressIndicator(),
          SizedBox(height: 8),
          Text("Menyiapkan aplikasi...", style: TextStyle(fontSize: 12, color: Colors.grey))
        ],
      )),
    );
  }
}