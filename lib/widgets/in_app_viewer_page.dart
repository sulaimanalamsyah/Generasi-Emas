import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:url_launcher/url_launcher.dart'; // [TAMBAHAN] Untuk buka WA

class InAppViewerPage extends StatefulWidget {
  final String title;
  final String url; // bisa http/https/pdf/mp4/drive/form/flip, dll.
  const InAppViewerPage({super.key, required this.title, required this.url});
  @override
  State<InAppViewerPage> createState() => _InAppViewerPageState();
}

class _InAppViewerPageState extends State<InAppViewerPage> {
  // Regex untuk deteksi file video langsung
  bool get _isVideo =>
      RegExp(r'\.(mp4|webm|m3u8)(\?.*)?$', caseSensitive: false).hasMatch(widget.url);

  // Regex untuk deteksi PDF
  bool get _isPdf =>
      RegExp(r'\.pdf(\?.*)?$', caseSensitive: false).hasMatch(widget.url);

  @override
  Widget build(BuildContext context) {
    final title = widget.title.isEmpty ? 'Viewer' : widget.title;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        // [OPSIONAL] Tombol back manual jika WebView punya history navigasi sendiri
        // actions: [IconButton(icon: Icon(Icons.refresh), onPressed: () {})],
      ),
      body: _isVideo
          ? _VideoPlayer(url: widget.url)
          : _PdfOrWeb(url: widget.url, isPdf: _isPdf),
    );
  }
}

class _PdfOrWeb extends StatefulWidget {
  final String url;
  final bool isPdf;
  const _PdfOrWeb({required this.url, required this.isPdf});

  @override
  State<_PdfOrWeb> createState() => _PdfOrWebState();
}

class _PdfOrWebState extends State<_PdfOrWeb> {
  late final WebViewController _c;
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    // 1. Tentukan URL. Jika PDF, bungkus dengan Google Docs Viewer
    final String loadUrl = widget.isPdf
        ? 'https://docs.google.com/gview?embedded=1&url=${Uri.encodeComponent(widget.url)}'
        : _prepareUrl(widget.url);

    // 2. Konfigurasi Controller
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
    // [PENTING] UserAgent: Terkadang Google Drive memblokir WebView default.
    // Kita "menyamar" sebagai browser Chrome mobile biasa.
      ..setUserAgent("Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Mobile Safari/537.36")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() {
            _loading = true;
            _errorMessage = null;
          }),
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (error) {
            setState(() {
              _loading = false;
              // Jangan tampilkan error jika itu hanya "net::ERR_UNKNOWN_URL_SCHEME" (biasanya intent WA)
              if (error.description.contains("ERR_UNKNOWN_URL_SCHEME")) return;
              _errorMessage = "Gagal memuat halaman: ${error.description}";
            });
          },
          // [SOLUSI UTAMA] Intersepsi Request Navigasi
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.parse(request.url);

            // Cek apakah skema-nya HTTP/HTTPS (Web biasa)
            if (uri.scheme == 'http' || uri.scheme == 'https') {
              // Khusus: Link WhatsApp Web (api.whatsapp.com / wa.me)
              // Kita paksa buka di aplikasi luar, karena WA Web sering error di WebView mobile
              if (request.url.contains('api.whatsapp.com') ||
                  request.url.contains('wa.me') ||
                  request.url.contains('chat.whatsapp.com')) {
                _launchExternal(request.url);
                return NavigationDecision.prevent; // Batalkan loading di WebView
              }

              // Selain itu, izinkan WebView memuatnya (Tetap In-App)
              return NavigationDecision.navigate;
            }

            // Jika skema bukan http/https (misal: whatsapp://, tel:, mailto:, intent://)
            // Buka di aplikasi eksternal
            _launchExternal(request.url);
            return NavigationDecision.prevent; // Batalkan loading di WebView
          },
        ),
      )
      ..loadRequest(Uri.parse(loadUrl));
  }

  // Helper: Memperbaiki URL YouTube/Drive agar ramah embed (Opsional)
  String _prepareUrl(String raw) {
    // Jika YouTube biasa (watch?v=), ubah jadi embed agar fullscreen rapi
    if (raw.contains('youtube.com/watch?v=')) {
      return raw.replaceAll('watch?v=', 'embed/');
    }
    if (raw.contains('youtu.be/')) {
      return raw.replaceAll('youtu.be/', 'youtube.com/embed/');
    }
    return raw;
  }

  // Helper: Buka URL Eksternal (WA, Telp, dll)
  Future<void> _launchExternal(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback jika tidak bisa handle scheme
        debugPrint("Tidak ada aplikasi yang bisa menangani: $urlString");
      }
    } catch (e) {
      debugPrint("Error launch external: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 10),
              Text(_errorMessage!, textAlign: TextAlign.center),
              TextButton(
                onPressed: () => _c.reload(),
                child: const Text("Coba Lagi"),
              )
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _c),
        if (_loading)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

// === BAGIAN VIDEO PLAYER (Tidak Berubah Signifikan) ===
class _VideoPlayer extends StatefulWidget {
  final String url;
  const _VideoPlayer({required this.url});

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> {
  VideoPlayerController? _v;
  ChewieController? _chewie;
  String? _err;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final v = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await v.initialize();
      if (!mounted) return;
      _v = v;
      _chewie = ChewieController(
        videoPlayerController: v,
        autoPlay: true, // Auto play agar user langsung nonton
        looping: false,
        aspectRatio: v.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(child: Text(errorMessage, style: const TextStyle(color: Colors.white)));
        },
      );
      setState(() {});
    } catch (e) {
      if(mounted) {
        setState(() => _err = 'Gagal memuat video.\n$e');
      }
    }
  }

  @override
  void dispose() {
    _v?.dispose();
    _chewie?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_err != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_err!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
        ),
      );
    }
    if (_v == null || !_v!.value.isInitialized || _chewie == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return SafeArea(
      child: Chewie(controller: _chewie!),
    );
  }
}