import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../routes.dart';
import '../services/api_client.dart';
import 'module_detail_page.dart';

class ModulesPage extends StatefulWidget {
  const ModulesPage({super.key});

  @override
  State<ModulesPage> createState() => _ModulesPageState();
}

class _ModulesPageState extends State<ModulesPage> {
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
      // Fetch module content for MOTHER audience
      final data = await _api.getContent('MODULE', 'MOTHER');
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

  /// Filters modules and their PDF items based on query and selected category
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

  void _openModuleDetail({
    required String title,
    required String url,
    String? description,
    String? moduleTitle,
    String? kind,
    required List<dynamic> allModuleItems,
  }) {
    final related = allModuleItems
        .map((it) => Map<String, dynamic>.from(it as Map))
        .toList();

    Navigator.pushNamed(
      context,
      Routes.moduleDetail,
      arguments: ModuleDetailArguments(
        title: title,
        url: url,
        description: description,
        moduleTitle: moduleTitle,
        kind: kind,
        relatedItems: related,
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
          'Modul Pembelajaran',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 18,
            fontFamily: 'Nunito',
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(kPrimary),
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
              const Icon(Icons.signal_wifi_off_rounded,
                  size: 64, color: Color(0xFF94A3B8)),
              const SizedBox(height: 16),
              const Text(
                'Anda Sedang Offline',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Periksa koneksi internet Anda untuk membaca materi modul pembelajaran terbaru.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchModules,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
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
              const Icon(Icons.error_outline_rounded,
                  size: 56, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                'Gagal memuat modul: $_errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 14,
                  fontFamily: 'Inter',
                ),
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
      color: kPrimary,
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
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Cari judul materi, panduan, atau modul...',
                hintStyle:
                    const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            color: Color(0xFF64748B)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 2. Module Category Filter Chips
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
                      color: _selectedModuleId == null
                          ? kPrimary
                          : const Color(0xFFE2E8F0),
                    ),
                    labelStyle: TextStyle(
                      color: _selectedModuleId == null
                          ? const Color(0xFF047857)
                          : const Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    onSelected: (_) =>
                        setState(() => _selectedModuleId = null),
                  ),
                  const SizedBox(width: 8),
                  ..._allModules.map((m) {
                    final mId = m['id'] as int?;
                    final mTitle = (m['title'] ?? 'Modul').toString();
                    final isSelected = _selectedModuleId == mId;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(mTitle,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        selected: isSelected,
                        selectedColor: const Color(0xFFD1FAE5),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: isSelected
                              ? kPrimary
                              : const Color(0xFFE2E8F0),
                        ),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? const Color(0xFF047857)
                              : const Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedModuleId = mId),
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
                Icon(Icons.menu_book_rounded, color: kPrimary, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Modul pembelajaran terstruktur sebagai panduan asuhan Model I-FINC untuk mendukung tumbuh kembang optimal bayi Anda.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF166534),
                      height: 1.4,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 4. Filtered Educational Module List
          if (filteredModules.isEmpty) ...[
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  const Icon(Icons.search_off_rounded,
                      size: 56, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 12),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'Tidak ada modul yang cocok dengan "$_searchQuery"'
                        : 'Belum ada materi modul pembelajaran.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                      fontFamily: 'Nunito',
                    ),
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
                      icon: const Icon(Icons.refresh_rounded, color: kPrimary),
                      label: const Text('Reset Filter',
                          style: TextStyle(color: kPrimary)),
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
                        color: Color(0x0A000000),
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
                                child: const Icon(Icons.auto_stories_rounded,
                                    color: Color(0xFF047857), size: 20),
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${items.length} Materi',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                    fontFamily: 'Inter',
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
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const Divider(height: 1, color: Color(0xFFF1F5F9)),

                    // Document Items in this module
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Belum ada materi pada modul ini.',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Color(0xFFF8FAFC)),
                        itemBuilder: (context, idx) {
                          final item = items[idx];
                          final itemTitle =
                              (item['title'] ?? 'Dokumen Panduan').toString();
                          final itemUrl = (item['url'] ?? '').toString();
                          final itemDesc = item['description'] as String?;
                          final itemKind =
                              (item['kind'] ?? 'PDF').toString().toUpperCase();

                          return InkWell(
                            onTap: () => _openModuleDetail(
                              title: itemTitle,
                              url: itemUrl,
                              description: itemDesc,
                              moduleTitle: mTitle,
                              kind: itemKind,
                              allModuleItems: items,
                            ),
                            borderRadius: idx == items.length - 1
                                ? const BorderRadius.vertical(
                                    bottom: Radius.circular(16))
                                : BorderRadius.zero,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // PDF Document Preview Box
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        width: 88,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF2F2),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: const Color(0xFFFECACA)),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Icon(
                                              Icons.picture_as_pdf_rounded,
                                              color: Color(0xFFEF4444),
                                              size: 26,
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'PDF DOC',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF991B1B),
                                                fontFamily: 'Inter',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(width: 14),

                                  // Document Title and Description snippet
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                        if (itemDesc != null &&
                                            itemDesc.trim().isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            itemDesc.trim(),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                              height: 1.3,
                                              fontFamily: 'Inter',
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Row(
                                          children: const [
                                            Icon(
                                              Icons.menu_book_rounded,
                                              color: kPrimary,
                                              size: 14,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Baca Dokumen',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: kPrimary,
                                                fontFamily: 'Inter',
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