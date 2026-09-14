import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/youtube_helper.dart';

/// Arguments model for navigating to VideoDetailPage
class VideoDetailArguments {
  final String title;
  final String url;
  final String? description;
  final String? moduleTitle;
  final List<Map<String, dynamic>> relatedVideos;

  const VideoDetailArguments({
    required this.title,
    required this.url,
    this.description,
    this.moduleTitle,
    this.relatedVideos = const [],
  });
}

class VideoDetailPage extends StatefulWidget {
  final VideoDetailArguments args;

  const VideoDetailPage({
    super.key,
    required this.args,
  });

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  late String _currentTitle;
  late String _currentUrl;
  late String? _currentDescription;
  late String? _currentModuleTitle;
  late List<Map<String, dynamic>> _relatedVideos;

  @override
  void initState() {
    super.initState();
    _currentTitle = widget.args.title;
    _currentUrl = widget.args.url;
    _currentDescription = widget.args.description;
    _currentModuleTitle = widget.args.moduleTitle;
    _relatedVideos = widget.args.relatedVideos;

    _initPlayer();
  }

  @override
  void dispose() {
    _controller.loadRequest(Uri.parse('about:blank'));
    super.dispose();
  }

  void _initPlayer() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final ytId = YouTubeHelper.extractVideoId(_currentUrl);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
        "Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onWebResourceError: (error) {
            if (mounted) {
              // Ignore non-critical scheme errors (e.g. intent schemes)
              if (error.description.contains("ERR_UNKNOWN_URL_SCHEME")) return;
              setState(() {
                _isLoading = false;
                _errorMessage = "Gagal memutar video secara langsung: ${error.description}";
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.parse(request.url);
            // Allow embedded player navigation
            if (request.url.contains("youtube.com") ||
                request.url.contains("youtube-nocookie.com") ||
                request.url.contains("youtu.be") ||
                request.url.contains("google.com") ||
                request.url.contains("googlevideo.com") ||
                request.url.startsWith("about:") ||
                request.url.startsWith("data:")) {
              return NavigationDecision.navigate;
            }
            if (uri.scheme == 'http' || uri.scheme == 'https') {
              return NavigationDecision.navigate;
            }
            launchUrl(uri, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          },
        ),
      );

    if (ytId != null && ytId.isNotEmpty) {
      final html = YouTubeHelper.buildPlayerHtml(ytId);
      _controller.loadHtmlString(html, baseUrl: 'https://www.youtube-nocookie.com');
    } else {
      final playableUrl = YouTubeHelper.getPlayableUrl(_currentUrl);
      if (playableUrl.isNotEmpty) {
        _controller.loadRequest(Uri.parse(playableUrl));
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = "URL video tidak valid atau kosong.";
        });
      }
    }
  }

  void _switchVideo(Map<String, dynamic> video) {
    setState(() {
      _currentTitle = video['title'] ?? 'Video Edukasi';
      _currentUrl = video['url'] ?? '';
      _currentDescription = video['description'] as String?;
    });
    _initPlayer();
  }

  Future<void> _launchExternalYouTube() async {
    if (_currentUrl.isEmpty) return;
    final uri = Uri.parse(_currentUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuka aplikasi YouTube')),
        );
      }
    }
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _currentUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tautan video berhasil disalin!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter out current video from related list
    final filteredRelated = _relatedVideos
        .where((v) => (v['url'] ?? '') != _currentUrl)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          tooltip: 'Kembali',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detail Video Edukasi',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 18,
            fontFamily: 'Nunito',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Color(0xFF0F172A)),
            tooltip: 'Salin Tautan',
            onPressed: _copyLink,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, color: Color(0xFF0F172A)),
            tooltip: 'Buka di YouTube',
            onPressed: _launchExternalYouTube,
          ),
        ],
      ),
      body: ListView(
        children: [
          // 1. In-App Video Player Card
          Container(
            color: Colors.black,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  RepaintBoundary(
                    child: WebViewWidget(controller: _controller),
                  ),
                  if (_isLoading)
                    Container(
                      color: Colors.black.withAlpha(180),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Menyiapkan pemutar video...',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_errorMessage != null)
                    Container(
                      color: Colors.black.withAlpha(220),
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.orange, size: 40),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _launchExternalYouTube,
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Buka di YouTube'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
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

          // 2. Video Title & Module Tag
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Module Badge
                if (_currentModuleTitle != null && _currentModuleTitle!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _currentModuleTitle!,
                      style: const TextStyle(
                        color: Color(0xFF047857),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),

                // Video Title
                Text(
                  _currentTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    fontFamily: 'Nunito',
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 16),

                // Quick Action Bar
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _launchExternalYouTube,
                        icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.red, size: 20),
                        label: const Text(
                          'Aplikasi YouTube',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _copyLink,
                        icon: const Icon(Icons.link_rounded, color: Color(0xFF10B981), size: 20),
                        label: const Text(
                          'Salin Tautan',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 3. Educational Description / Notes Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.description_outlined, color: Color(0xFF10B981), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Deskripsi & Panduan Edukasi',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              fontFamily: 'Nunito',
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      Text(
                        (_currentDescription != null && _currentDescription!.trim().isNotEmpty)
                            ? _currentDescription!
                            : 'Pelajari video ini dengan seksama untuk mendukung tumbuh kembang dan perawatan optimal bagi buah hati Anda.',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF334155),
                          height: 1.6,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. Related Videos Section (if any)
                if (filteredRelated.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Video Lainnya di Modul Ini',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      fontFamily: 'Nunito',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...filteredRelated.map((video) {
                    final vTitle = video['title'] ?? 'Video Edukasi';
                    final vUrl = video['url'] ?? '';
                    final thumbUrl = YouTubeHelper.getThumbnailUrl(vUrl);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: 72,
                            height: 48,
                            color: const Color(0xFFE2E8F0),
                            child: thumbUrl.isNotEmpty
                                ? Image.network(
                                    thumbUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.play_circle_outline, color: Color(0xFF10B981)),
                                    ),
                                  )
                                : const Center(
                                    child: Icon(Icons.play_circle_outline, color: Color(0xFF10B981)),
                                  ),
                          ),
                        ),
                        title: Text(
                          vTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                        onTap: () => _switchVideo(video),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
