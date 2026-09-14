import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/constants.dart';
import '../core/pdf_helper.dart';

class ModuleDetailArguments {
  final String title;
  final String url;
  final String? description;
  final String? moduleTitle;
  final String? kind;
  final List<Map<String, dynamic>> relatedItems;

  const ModuleDetailArguments({
    required this.title,
    required this.url,
    this.description,
    this.moduleTitle,
    this.kind,
    this.relatedItems = const [],
  });
}

class ModuleDetailPage extends StatefulWidget {
  final ModuleDetailArguments args;

  const ModuleDetailPage({super.key, required this.args});

  @override
  State<ModuleDetailPage> createState() => _ModuleDetailPageState();
}

class _ModuleDetailPageState extends State<ModuleDetailPage> {
  late String _currentTitle;
  late String _currentUrl;
  String? _currentDescription;
  String? _currentModuleTitle;
  late List<Map<String, dynamic>> _relatedItems;

  late WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _currentTitle = widget.args.title;
    _currentUrl = widget.args.url;
    _currentDescription = widget.args.description;
    _currentModuleTitle = widget.args.moduleTitle;
    _relatedItems = List.from(widget.args.relatedItems);

    _initReader();
  }

  @override
  void dispose() {
    _controller.loadRequest(Uri.parse('about:blank'));
    super.dispose();
  }

  void _initReader() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final targetUrl = PdfHelper.getPlayablePdfUrl(_currentUrl);
    if (targetUrl.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = "URL dokumen tidak valid atau kosong.";
      });
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
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
              if (error.description.contains("ERR_UNKNOWN_URL_SCHEME")) return;
              setState(() {
                _isLoading = false;
                _errorMessage =
                    "Gagal memuat dokumen langsung: ${error.description}";
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.parse(request.url);
            if (request.url.contains("drive.google.com") ||
                request.url.contains("docs.google.com") ||
                request.url.contains("google.com") ||
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
      )
      ..loadRequest(Uri.parse(targetUrl));
  }

  void _switchDocument(Map<String, dynamic> doc) {
    setState(() {
      _currentTitle = (doc['title'] ?? 'Dokumen Modul').toString();
      _currentUrl = (doc['url'] ?? '').toString();
      _currentDescription = doc['description'] as String?;
    });
    _initReader();
  }

  Future<void> _openInExternalBrowser() async {
    if (_currentUrl.isEmpty) return;
    try {
      final uri = Uri.parse(_currentUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak dapat membuka browser.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _copyLinkToClipboard() {
    if (_currentUrl.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _currentUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tautan dokumen berhasil disalin ke clipboard.'),
        backgroundColor: kPrimary,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          tooltip: 'Kembali',
          onPressed: () {
            if (_isFullscreen) {
              setState(() => _isFullscreen = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _isFullscreen ? _currentTitle : 'Detail Modul Pembelajaran',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 17,
            fontFamily: 'Nunito',
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFullscreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              color: const Color(0xFF0F172A),
            ),
            tooltip: _isFullscreen ? 'Keluar Layar Penuh' : 'Layar Penuh',
            onPressed: _toggleFullscreen,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
            tooltip: 'Muat Ulang Dokumen',
            onPressed: _initReader,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded,
                color: Color(0xFF0F172A)),
            tooltip: 'Buka Dokumen Asli',
            onPressed: _openInExternalBrowser,
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: _isFullscreen
          ? _buildReaderView()
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // 1. Metadata Info Card
                _buildMetadataCard(),

                const SizedBox(height: 16),

                // 2. Interactive In-App Flipbook Reader Viewport
                _buildReaderSection(),

                const SizedBox(height: 14),

                // 3. Reader Quick Actions Bar
                _buildQuickActionsBar(),

                const SizedBox(height: 24),

                // 4. Related Module Materials
                _buildRelatedMaterialsSection(),

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildMetadataCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Module Topic Pill Tag
          if (_currentModuleTitle != null &&
              _currentModuleTitle!.trim().isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_stories_rounded,
                      size: 14, color: Color(0xFF047857)),
                  const SizedBox(width: 6),
                  Text(
                    _currentModuleTitle!,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF047857),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Document Title
          Text(
            _currentTitle,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              height: 1.3,
            ),
          ),

          // Document Description
          if (_currentDescription != null &&
              _currentDescription!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _currentDescription!.trim(),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Color(0xFF475569),
                height: 1.45,
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Badges Row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildBadge(
                icon: Icons.picture_as_pdf_rounded,
                label: "Dokumen Panduan PDF",
                color: const Color(0xFFEF4444),
              ),
              _buildBadge(
                icon: Icons.menu_book_rounded,
                label: "Flipbook Interaktif",
                color: kPrimary,
              ),
              _buildBadge(
                icon: Icons.touch_app_rounded,
                label: "Swipe / Pinch Zoom",
                color: const Color(0xFF0EA5E9),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReaderSection() {
    return Container(
      height: 440,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildReaderView(),
    );
  }

  Widget _buildReaderView() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFF334155),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _initReader,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Coba Lagi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _openInExternalBrowser,
                    icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                    label: const Text('Buka Dokumen'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        RepaintBoundary(
          child: WebViewWidget(
            controller: _controller,
            gestureRecognizers: {
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.white.withValues(alpha: 0.9),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(kPrimary),
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Menyiapkan Reader Dokumen...',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickActionsBar() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _toggleFullscreen,
            icon: Icon(
              _isFullscreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              size: 18,
              color: const Color(0xFF0F172A),
            ),
            label: Text(
              _isFullscreen ? 'Keluar Fullscreen' : 'Layar Penuh',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              minimumSize: const Size(48, 48),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _copyLinkToClipboard,
            icon: const Icon(Icons.link_rounded, size: 18, color: kPrimary),
            label: const Text(
              'Salin Tautan',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kPrimary,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: Color(0xFFD1FAE5)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              minimumSize: const Size(48, 48),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _openInExternalBrowser,
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text(
              'Buka Asli',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              minimumSize: const Size(48, 48),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedMaterialsSection() {
    final otherItems = _relatedItems
        .where((it) => (it['url'] ?? '').toString() != _currentUrl)
        .toList();

    if (otherItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.library_books_rounded, size: 18, color: Color(0xFF0F172A)),
            SizedBox(width: 8),
            Text(
              "Materi Lain Dalam Modul Ini",
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: otherItems.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, idx) {
            final item = otherItems[idx];
            final itemTitle = (item['title'] ?? 'Dokumen Panduan').toString();
            final itemDesc = item['description'] as String?;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListTile(
                onTap: () => _switchDocument(item),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded,
                      color: Color(0xFFEF4444), size: 22),
                ),
                title: Text(
                  itemTitle,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                subtitle: itemDesc != null && itemDesc.trim().isNotEmpty
                    ? Text(
                        itemDesc.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      )
                    : null,
                trailing: const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: kPrimary),
              ),
            );
          },
        ),
      ],
    );
  }
}
