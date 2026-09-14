import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../routes.dart';
import '../video_detail_page.dart';
import '../module_detail_page.dart';
import '../reference_detail_page.dart';

enum ResourceType { all, video, module, reference }

class EducationalResource {
  final String id;
  final String title;
  final String? description;
  final String url;
  final ResourceType type;
  final String? category;
  final String? author;
  final String? year;
  final String? summary;
  final String? groupTitle;
  final String? doi;
  final List<Map<String, dynamic>> relatedItems;

  const EducationalResource({
    required this.id,
    required this.title,
    this.description,
    required this.url,
    required this.type,
    this.category,
    this.author,
    this.year,
    this.summary,
    this.groupTitle,
    this.doi,
    this.relatedItems = const [],
  });
}

class BrainstormingNursePage extends StatefulWidget {
  const BrainstormingNursePage({super.key});

  @override
  State<BrainstormingNursePage> createState() => _BrainstormingNursePageState();
}

class _BrainstormingNursePageState extends State<BrainstormingNursePage> {
  final _api = ApiClient();

  bool _loading = true;
  bool _initialLoaded = false;
  String? _error;

  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  ResourceType _selectedType = ResourceType.all;

  List<EducationalResource> _allResources = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.getContent('BRAINSTORM', 'NURSE'),
        _api.getContent('MODULE', 'NURSE'),
        _api.getReferences(),
      ]);

      final rawVideos = results[0];
      final rawModules = results[1];
      final rawRefs = results[2];

      final List<EducationalResource> parsed = [];

      // 1. Parse Video Items
      for (final g in rawVideos) {
        final gTitle = (g['title'] as String?) ?? 'Video Edukasi';
        final items = (g['items'] as List?) ?? [];
        for (final it in items) {
          parsed.add(
            EducationalResource(
              id: 'video_${it['id']}',
              title: (it['title'] as String?) ?? 'Video',
              description: it['description'] as String?,
              url: (it['url'] as String?) ?? '',
              type: ResourceType.video,
              category: gTitle,
              groupTitle: gTitle,
              relatedItems: items.map((e) => (e as Map).cast<String, dynamic>()).toList(),
            ),
          );
        }
      }

      // 2. Parse Module Flipbook Items
      for (final g in rawModules) {
        final gTitle = (g['title'] as String?) ?? 'Modul Edukasi';
        final items = (g['items'] as List?) ?? [];
        for (final it in items) {
          parsed.add(
            EducationalResource(
              id: 'module_${it['id']}',
              title: (it['title'] as String?) ?? 'Modul',
              description: it['description'] as String?,
              url: (it['url'] as String?) ?? '',
              type: ResourceType.module,
              category: gTitle,
              groupTitle: gTitle,
              relatedItems: items.map((e) => (e as Map).cast<String, dynamic>()).toList(),
            ),
          );
        }
      }

      // 3. Parse Reference Items
      for (final r in rawRefs) {
        parsed.add(
          EducationalResource(
            id: 'ref_${r['id']}',
            title: (r['title'] as String?) ?? 'Referensi',
            url: (r['url'] as String?) ?? '',
            type: ResourceType.reference,
            author: r['author'] as String?,
            year: r['year']?.toString(),
            category: (r['category'] as String?) ?? 'JURNAL',
            summary: r['summary'] as String?,
            doi: r['doi'] as String?,
            relatedItems: rawRefs.map((e) => (e as Map).cast<String, dynamic>()).toList(),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _allResources = parsed;
        _loading = false;
        _initialLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (e is ApiError && e.status == 0) {
          _error = 'Tidak ada koneksi internet.\nPeriksa jaringan Anda.';
        } else {
          _error = '$e';
        }
        _loading = false;
        _initialLoaded = true;
      });
    }
  }

  List<EducationalResource> get _filteredResources {
    final query = _searchCtrl.text.trim().toLowerCase();

    return _allResources.where((res) {
      // Type matching
      if (_selectedType != ResourceType.all && res.type != _selectedType) {
        return false;
      }

      // Query matching
      if (query.isEmpty) return true;

      final titleMatch = res.title.toLowerCase().contains(query);
      final descMatch = (res.description ?? '').toLowerCase().contains(query);
      final summaryMatch = (res.summary ?? '').toLowerCase().contains(query);
      final authorMatch = (res.author ?? '').toLowerCase().contains(query);
      final catMatch = (res.category ?? '').toLowerCase().contains(query);
      final groupMatch = (res.groupTitle ?? '').toLowerCase().contains(query);

      return titleMatch || descMatch || summaryMatch || authorMatch || catMatch || groupMatch;
    }).toList();
  }

  int _countFor(ResourceType type) {
    if (type == ResourceType.all) return _allResources.length;
    return _allResources.where((r) => r.type == type).length;
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      setState(() {});
    });
  }

  void _openResource(EducationalResource item) {
    switch (item.type) {
      case ResourceType.video:
        Navigator.pushNamed(
          context,
          Routes.videoDetail,
          arguments: VideoDetailArguments(
            title: item.title,
            url: item.url,
            description: item.description,
            moduleTitle: item.groupTitle,
            relatedVideos: item.relatedItems,
          ),
        );
        break;

      case ResourceType.module:
        Navigator.pushNamed(
          context,
          Routes.moduleDetail,
          arguments: ModuleDetailArguments(
            title: item.title,
            url: item.url,
            description: item.description,
            moduleTitle: item.groupTitle,
            kind: 'PDF',
            relatedItems: item.relatedItems,
          ),
        );
        break;

      case ResourceType.reference:
        Navigator.pushNamed(
          context,
          Routes.referenceDetail,
          arguments: ReferenceDetailArguments(
            title: item.title,
            url: item.url,
            author: item.author,
            year: item.year,
            category: item.category,
            summary: item.summary,
            doi: item.doi,
            relatedReferences: item.relatedItems,
          ),
        );
        break;

      case ResourceType.all:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final showRefreshBar = _loading && _initialLoaded;
    final items = _filteredResources;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Pusat Edukasi & Referensi',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          IconButton(
            tooltip: 'Perbarui Materi',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
            onPressed: _loadData,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Container
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Cari video, modul flipbook, atau jurnal...',
                  hintStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8), size: 20),
                          onPressed: () {
                            _debounce?.cancel();
                            _searchCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                  ),
                ),
              ),
            ),

            // Horizontal Filter Chips
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildFilterChip('Semua', ResourceType.all, _countFor(ResourceType.all), Icons.apps_rounded),
                  const SizedBox(width: 8),
                  _buildFilterChip('Video', ResourceType.video, _countFor(ResourceType.video), Icons.play_circle_outline_rounded),
                  const SizedBox(width: 8),
                  _buildFilterChip('Modul Flipbook', ResourceType.module, _countFor(ResourceType.module), Icons.menu_book_rounded),
                  const SizedBox(width: 8),
                  _buildFilterChip('Artikel & Jurnal', ResourceType.reference, _countFor(ResourceType.reference), Icons.article_outlined),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Non-blocking refresh indicator
            if (showRefreshBar)
              const LinearProgressIndicator(
                minHeight: 3,
                color: Color(0xFF10B981),
                backgroundColor: Color(0xFFD1FAE5),
              ),

            // Main Content Area
            Expanded(
              child: _buildBody(items),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, ResourceType type, int count, IconData icon) {
    final isSelected = _selectedType == type;

    return InkWell(
      onTap: () {
        setState(() => _selectedType = type);
      },
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF064E3B) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? const Color(0xFF064E3B) : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF064E3B).withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              '$label ($count)',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<EducationalResource> items) {
    if (_loading && !_initialLoaded) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_off_rounded, size: 32, color: Color(0xFFEF4444)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Gagal Memuat Materi',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _loadData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Coba Lagi', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                ),
              )
            ],
          ),
        ),
      );
    }

    if (items.isEmpty) {
      final isSearching = _searchCtrl.text.trim().isNotEmpty;

      if (isSearching) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.search_off_rounded, size: 36, color: Color(0xFFF59E0B)),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Materi Tidak Ditemukan',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tidak ada video, modul, atau jurnal yang cocok dengan kata kunci "${_searchCtrl.text.trim()}".',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {});
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: const Text('Reset Pencarian', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.folder_open_rounded, size: 36, color: Color(0xFF10B981)),
              ),
              const SizedBox(height: 18),
              const Text(
                'Belum Ada Materi',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Materi edukasi klinis dan referensi jurnal akan ditampilkan di sini.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF64748B), height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF10B981),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildResourceCard(item);
        },
      ),
    );
  }

  Widget _buildResourceCard(EducationalResource item) {
    Color typeBg;
    Color typeColor;
    IconData typeIcon;
    String typeLabel;
    String actionLabel;
    IconData actionIcon;

    switch (item.type) {
      case ResourceType.video:
        typeBg = const Color(0xFFFEE2E2);
        typeColor = const Color(0xFFDC2626);
        typeIcon = Icons.play_circle_fill_rounded;
        typeLabel = 'Video Edukasi';
        actionLabel = 'Putar Video';
        actionIcon = Icons.play_arrow_rounded;
        break;
      case ResourceType.module:
        typeBg = const Color(0xFFE0F2FE);
        typeColor = const Color(0xFF0284C7);
        typeIcon = Icons.auto_stories_rounded;
        typeLabel = 'Modul Flipbook';
        actionLabel = 'Baca Flipbook';
        actionIcon = Icons.menu_book_rounded;
        break;
      case ResourceType.reference:
        typeBg = const Color(0xFFEEF2FF);
        typeColor = const Color(0xFF4F46E5);
        typeIcon = Icons.article_rounded;
        typeLabel = item.category ?? 'Jurnal Medis';
        actionLabel = 'Lihat Jurnal';
        actionIcon = Icons.open_in_new_rounded;
        break;
      case ResourceType.all:
        typeBg = const Color(0xFFF1F5F9);
        typeColor = const Color(0xFF475569);
        typeIcon = Icons.insert_drive_file_rounded;
        typeLabel = 'Materi';
        actionLabel = 'Buka';
        actionIcon = Icons.arrow_forward_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        border: Border.fromBorderSide(BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openResource(item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tag Bar
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeIcon, size: 14, color: typeColor),
                          const SizedBox(width: 5),
                          Text(
                            typeLabel,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: typeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (item.groupTitle != null && item.groupTitle!.isNotEmpty)
                      Expanded(
                        child: Text(
                          item.groupTitle!,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else if (item.author != null && item.author!.isNotEmpty)
                      Expanded(
                        child: Text(
                          '${item.author!}${item.year != null ? ' (${item.year})' : ''}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                // Resource Title
                Text(
                  item.title,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                // Description / Summary Preview
                if (item.summary != null && item.summary!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.summary!.trim(),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Color(0xFF475569),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else if (item.description != null && item.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.description!.trim(),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Color(0xFF475569),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 14),

                // Bottom Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(),
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(actionIcon, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            actionLabel,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}