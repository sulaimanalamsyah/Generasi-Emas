import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../core/youtube_helper.dart';
import '../routes.dart';
import 'module_detail_page.dart';

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
  Timer? _loadingTimeout;
  bool _isCustomWidgetShown = false;

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

    _initController();
    _loadVideo();
  }

  @override
  void dispose() {
    _loadingTimeout?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller.loadRequest(Uri.parse('about:blank'));
    super.dispose();
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
        "Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _loadingTimeout?.cancel();
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onWebResourceError: (error) {
            if (mounted) {
              if (error.description.contains("ERR_UNKNOWN_URL_SCHEME")) return;
              _loadingTimeout?.cancel();
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

    _setupCustomWidgetCallbacks();
  }

  void _setupCustomWidgetCallbacks() {
    if (_controller.platform is AndroidWebViewController) {
      final androidController = _controller.platform as AndroidWebViewController;
      androidController.setCustomWidgetCallbacks(
        onShowCustomWidget: (Widget widget, OnHideCustomWidgetCallback callback) {
          if (!mounted) return;
          _isCustomWidgetShown = true;
          // Hide status bar & navigation bar to ensure buttons are never covered
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext routeContext) {
                return PopScope(
                  canPop: true,
                  onPopInvokedWithResult: (bool didPop, dynamic result) {
                    if (didPop) {
                      _isCustomWidgetShown = false;
                      callback();
                      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                    }
                  },
                  child: Scaffold(
                    backgroundColor: Colors.black,
                    body: SizedBox.expand(
                      child: widget,
                    ),
                  ),
                );
              },
              fullscreenDialog: true,
            ),
          ).then((_) {
            if (_isCustomWidgetShown) {
              _isCustomWidgetShown = false;
              callback();
            }
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          });
        },
        onHideCustomWidget: () {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          if (_isCustomWidgetShown && mounted) {
            _isCustomWidgetShown = false;
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          }
        },
      );
    }
  }

  void _loadVideo() {
    _loadingTimeout?.cancel();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Safety timeout to prevent infinite loading spinner in case of silent iframe delay
    _loadingTimeout = Timer(const Duration(seconds: 8), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });

    final ytId = YouTubeHelper.extractVideoId(_currentUrl);
    if (ytId != null && ytId.isNotEmpty) {
      final html = YouTubeHelper.buildPlayerHtml(ytId);
      _controller.loadHtmlString(html, baseUrl: 'https://www.youtube-nocookie.com');
    } else {
      final playableUrl = YouTubeHelper.getPlayableUrl(_currentUrl);
      if (playableUrl.isNotEmpty) {
        _controller.loadRequest(Uri.parse(playableUrl));
      } else {
        _loadingTimeout?.cancel();
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
    _loadVideo();
  }

  String _detectFormat(Map<String, dynamic> item) {
    final kind = (item['kind'] as String?)?.toUpperCase();
    if (kind != null && kind.isNotEmpty) {
      if (kind.contains('PDF')) return 'PDF';
      if (kind.contains('LINK')) return 'LINK';
      if (kind.contains('VIDEO')) return 'VIDEO';
    }
    final url = (item['url'] as String? ?? '').toLowerCase();
    if (YouTubeHelper.extractVideoId(url) != null ||
        url.contains('youtu.be') ||
        url.contains('youtube.com')) {
      return 'VIDEO';
    }
    if (url.endsWith('.pdf') ||
        url.contains('/pdf') ||
        url.contains('drive.google.com')) {
      return 'PDF';
    }
    return 'VIDEO';
  }

  void _handleSiblingTap(Map<String, dynamic> item) {
    final format = _detectFormat(item);
    if (format == 'VIDEO') {
      _switchVideo(item);
    } else {
      _loadingTimeout?.cancel();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      _controller.loadRequest(Uri.parse('about:blank'));
      Navigator.pushReplacementNamed(
        context,
        Routes.moduleDetail,
        arguments: ModuleDetailArguments(
          title: (item['title'] ?? 'Materi Edukasi').toString(),
          url: (item['url'] ?? '').toString(),
          description: item['description'] as String?,
          moduleTitle: _currentModuleTitle,
          kind: format,
          relatedItems: _relatedVideos,
        ),
      );
    }
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
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
            tooltip: 'Muat Ulang Video',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: _isLoading ? null : _loadVideo,
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

                // 4. Sibling Materials in this Module
                const SizedBox(height: 24),
                const Row(
                  children: [
                    Icon(Icons.video_library_rounded, size: 18, color: Color(0xFF0F172A)),
                    SizedBox(width: 8),
                    Text(
                      'Item Lainnya dalam Modul Ini',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        fontFamily: 'Nunito',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (filteredRelated.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 20, color: Color(0xFF94A3B8)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tidak ada materi lain dalam modul ini.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...filteredRelated.map((item) {
                    final itemTitle = (item['title'] ?? 'Materi Edukasi').toString();
                    final itemUrl = (item['url'] ?? '').toString();
                    final itemDesc = item['description'] as String?;
                    final format = _detectFormat(item);

                    Widget leadingWidget;
                    String badgeLabel;
                    Color badgeBg;
                    Color badgeText;

                    if (format == 'VIDEO') {
                      final thumbUrl = YouTubeHelper.getThumbnailUrl(itemUrl);
                      badgeLabel = 'Video';
                      badgeBg = const Color(0xFFFEE2E2);
                      badgeText = const Color(0xFFDC2626);
                      leadingWidget = ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: 60,
                          height: 44,
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
                      );
                    } else if (format == 'PDF') {
                      badgeLabel = 'Modul PDF';
                      badgeBg = const Color(0xFFFEF2F2);
                      badgeText = const Color(0xFFEF4444);
                      leadingWidget = Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEF4444), size: 22),
                      );
                    } else {
                      badgeLabel = 'Artikel / Link';
                      badgeBg = const Color(0xFFE0F2FE);
                      badgeText = const Color(0xFF0284C7);
                      leadingWidget = Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.article_rounded, color: Color(0xFF0284C7), size: 22),
                      );
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        leading: leadingWidget,
                        title: Text(
                          itemTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  badgeLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: badgeText,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ),
                              if (itemDesc != null && itemDesc.trim().isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    itemDesc.trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                        onTap: () => _handleSiblingTap(item),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
