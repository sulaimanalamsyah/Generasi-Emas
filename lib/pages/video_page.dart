import 'package:flutter/material.dart';
import '../core/youtube_helper.dart';
import '../routes.dart';
import '../services/api_client.dart';
import 'video_detail_page.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({super.key});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  final _api = ApiClient();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allModules = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isOffline = false;

  String _searchQuery = '';
  int? _selectedModuleId; // null = all modules

  @override
  void initState() {
    super.initState();
    _fetchModules();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchModules() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isOffline = false;
    });

    try {
      // Fetch video content for MOTHER audience
      final data = await _api.getContent('VIDEO', 'MOTHER');
      if (mounted) {
        setState(() {
          _allModules = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (e is ApiError && e.status == 0) {
            _isOffline = true;
          } else {
            _errorMessage = e.toString();
          }
        });
      }
    }
  }

  /// Filters modules and their video items based on query and selected category
  List<Map<String, dynamic>> _getFilteredModules() {
    final query = _searchQuery.trim().toLowerCase();
    final List<Map<String, dynamic>> results = [];

    for (final rawModule in _allModules) {
      final module = Map<String, dynamic>.from(rawModule as Map);
      final moduleId = module['id'] as int?;
      final moduleTitle = (module['title'] ?? '').toString();
      final moduleDesc = (module['description'] ?? '').toString();
      final rawItems = (module['items'] as List?) ?? [];

      // Filter by selected module chip if active
      if (_selectedModuleId != null && moduleId != _selectedModuleId) {
        continue;
      }

      // Check module match or filter matching child items
      final List<Map<String, dynamic>> matchedItems = [];
      for (final rawItem in rawItems) {
        final item = Map<String, dynamic>.from(rawItem as Map);
        final itemTitle = (item['title'] ?? '').toString().toLowerCase();
        final itemDesc = (item['description'] ?? '').toString().toLowerCase();

        if (query.isEmpty ||
            itemTitle.contains(query) ||
            itemDesc.contains(query) ||
            moduleTitle.toLowerCase().contains(query) ||
            moduleDesc.toLowerCase().contains(query)) {
          matchedItems.add(item);
        }
      }

      if (matchedItems.isNotEmpty || (query.isEmpty && rawItems.isEmpty)) {
        final filteredModule = Map<String, dynamic>.from(module);
        filteredModule['items'] = matchedItems;
        results.add(filteredModule);
      }
    }

    return results;
  }

  void _openVideoDetail({
    required String title,
    required String url,
    String? description,
    String? moduleTitle,
    required List<dynamic> allModuleItems,
  }) {
    final related = allModuleItems
        .map((it) => Map<String, dynamic>.from(it as Map))
        .toList();

    Navigator.pushNamed(
      context,
      Routes.videoDetail,
      arguments: VideoDetailArguments(
        title: title,
        url: url,
        description: description,
        moduleTitle: moduleTitle,
        relatedVideos: related,
      ),
    );
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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Video Edukasi',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 18,
            fontFamily: 'Nunito',
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
        ),
      );
    }

    if (_isOffline) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.signal_wifi_off_rounded, size: 64, color: Color(0xFF94A3B8)),
              const SizedBox(height: 16),
              const Text(
                'Anda Sedang Offline',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Periksa koneksi internet Anda untuk melihat materi video edukasi terbaru.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchModules,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 56, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                'Gagal memuat video: $_errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF334155), fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchModules,
                child: const Text('Muat Ulang'),
              ),
            ],
          ),
        ),
      );
    }

    final filteredModules = _getFilteredModules();

    return RefreshIndicator(
      onRefresh: _fetchModules,
      color: const Color(0xFF10B981),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // 1. Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Cari judul video atau materi modul...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Color(0xFF64748B)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 2. Module Filter Chips
          if (_allModules.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Semua'),
                    selected: _selectedModuleId == null,
                    selectedColor: const Color(0xFFD1FAE5),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: _selectedModuleId == null ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                    ),
                    labelStyle: TextStyle(
                      color: _selectedModuleId == null ? const Color(0xFF047857) : const Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    onSelected: (_) => setState(() => _selectedModuleId = null),
                  ),
                  const SizedBox(width: 8),
                  ..._allModules.map((m) {
                    final mId = m['id'] as int?;
                    final mTitle = (m['title'] ?? 'Modul').toString();
                    final isSelected = _selectedModuleId == mId;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(mTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                        selected: isSelected,
                        selectedColor: const Color(0xFFD1FAE5),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                        ),
                        labelStyle: TextStyle(
                          color: isSelected ? const Color(0xFF047857) : const Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        onSelected: (_) => setState(() => _selectedModuleId = mId),
                      ),
                    );
                  }),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // 3. Info Banner Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.video_library_rounded, color: Color(0xFF10B981), size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tonton video panduan interaktif metode kanguru dan perawatan neonatal untuk menunjang kesehatan optimal buah hati Anda.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF166534), height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 4. Filtered Video Module List
          if (filteredModules.isEmpty) ...[
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  const Icon(Icons.search_off_rounded, size: 56, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 12),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'Tidak ada video yang cocok dengan "$_searchQuery"'
                        : 'Belum ada materi video edukasi.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                  if (_searchQuery.isNotEmpty || _selectedModuleId != null) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _selectedModuleId = null;
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xFF10B981)),
                      label: const Text('Reset Filter', style: TextStyle(color: Color(0xFF10B981))),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            ...filteredModules.map((module) {
              final mTitle = (module['title'] ?? 'Modul Edukasi').toString();
              final mDesc = module['description'] as String?;
              final items = (module['items'] as List?) ?? [];

              return RepaintBoundary(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    border: Border.fromBorderSide(
                        BorderSide(color: Color(0xFFE2E8F0))),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // Module Header
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.auto_stories_rounded, color: Color(0xFF047857), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  mTitle,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    fontFamily: 'Nunito',
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${items.length} Video',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (mDesc != null && mDesc.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              mDesc.trim(),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const Divider(height: 1, color: Color(0xFFF1F5F9)),

                    // Video Items in this module
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Belum ada video pada modul ini.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontStyle: FontStyle.italic),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF8FAFC)),
                        itemBuilder: (context, idx) {
                          final item = items[idx];
                          final itemTitle = (item['title'] ?? 'Video Edukasi').toString();
                          final itemUrl = (item['url'] ?? '').toString();
                          final itemDesc = item['description'] as String?;
                          final thumbUrl = YouTubeHelper.getThumbnailUrl(itemUrl);

                          return InkWell(
                            onTap: () => _openVideoDetail(
                              title: itemTitle,
                              url: itemUrl,
                              description: itemDesc,
                              moduleTitle: mTitle,
                              allModuleItems: items,
                            ),
                            borderRadius: idx == items.length - 1
                                ? const BorderRadius.vertical(bottom: Radius.circular(16))
                                : BorderRadius.zero,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Video Thumbnail with Play Button Overlay
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          width: 104,
                                          height: 64,
                                          color: const Color(0xFFCBD5E1),
                                          child: thumbUrl.isNotEmpty
                                              ? Image.network(
                                                  thumbUrl,
                                                  fit: BoxFit.cover,
                                                  cacheWidth: 208,
                                                  cacheHeight: 128,
                                                  errorBuilder: (_, __, ___) => const Center(
                                                    child: Icon(Icons.play_circle_outline, color: Color(0xFF10B981)),
                                                  ),
                                                )
                                              : const Center(
                                                  child: Icon(Icons.play_circle_outline, color: Color(0xFF10B981)),
                                                ),
                                        ),
                                      ),
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withAlpha(140),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(width: 14),

                                  // Video Title and Description snippet
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          itemTitle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                            fontFamily: 'Nunito',
                                            height: 1.25,
                                          ),
                                        ),
                                        if (itemDesc != null && itemDesc.trim().isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            itemDesc.trim(),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF10B981), size: 14),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Tonton Video',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF10B981),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 14,
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
            }),
          ],
        ],
      ),
    );
  }
}

/// Backwards compatibility alias for legacy imports
typedef BrainstormingPage = VideoPage;
