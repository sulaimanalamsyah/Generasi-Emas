import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../routes.dart';
import '../services/api_client.dart';
import 'reference_detail_page.dart';

class ReferencesPage extends StatefulWidget {
  const ReferencesPage({super.key});

  @override
  State<ReferencesPage> createState() => _ReferencesPageState();
}

class _ReferencesPageState extends State<ReferencesPage> {
  final _api = ApiClient();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allReferences = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isOffline = false;

  String _searchQuery = '';
  String? _selectedCategory; // null = all

  @override
  void initState() {
    super.initState();
    _fetchReferences();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchReferences() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isOffline = false;
    });

    try {
      final data = await _api.getContent('REFERENCE', 'MOTHER');
      if (mounted) {
        setState(() {
          _allReferences = data;
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

  List<String> _getAvailableCategories() {
    final Set<String> categories = {};
    for (final raw in _allReferences) {
      final item = Map<String, dynamic>.from(raw as Map);
      final cat = item['category'] as String?;
      if (cat != null && cat.trim().isNotEmpty) {
        categories.add(cat.trim().toUpperCase());
      }
    }
    return categories.toList()..sort();
  }

  List<Map<String, dynamic>> _getFilteredReferences() {
    final query = _searchQuery.trim().toLowerCase();
    final List<Map<String, dynamic>> results = [];

    for (final raw in _allReferences) {
      final item = Map<String, dynamic>.from(raw as Map);
      final title = (item['title'] ?? '').toString().toLowerCase();
      final author = (item['author'] ?? '').toString().toLowerCase();
      final year = (item['year'] ?? '').toString().toLowerCase();
      final category = (item['category'] ?? 'JURNAL').toString().toUpperCase();
      final summary = (item['summary'] ?? '').toString().toLowerCase();
      final doi = (item['doi'] ?? '').toString().toLowerCase();

      // Filter by category chip
      if (_selectedCategory != null && category != _selectedCategory) {
        continue;
      }

      // Filter by search query
      if (query.isEmpty ||
          title.contains(query) ||
          author.contains(query) ||
          year.contains(query) ||
          summary.contains(query) ||
          category.toLowerCase().contains(query) ||
          doi.contains(query)) {
        results.add(item);
      }
    }

    return results;
  }

  void _openReferenceDetail(Map<String, dynamic> item) {
    final allList = _allReferences
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();

    Navigator.pushNamed(
      context,
      Routes.referenceDetail,
      arguments: ReferenceDetailArguments(
        title: (item['title'] ?? 'Referensi Medis').toString(),
        url: (item['url'] ?? '').toString(),
        author: item['author'] as String?,
        year: item['year'] as String?,
        category: item['category'] as String?,
        summary: item['summary'] as String?,
        doi: item['doi'] as String?,
        relatedReferences: allList,
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
          'Referensi & Jurnal Medis',
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
                'Periksa koneksi internet Anda untuk mengakses daftar referensi dan jurnal medis terbaru.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchReferences,
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
                'Gagal memuat referensi: $_errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 14,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchReferences,
                child: const Text('Muat Ulang'),
              ),
            ],
          ),
        ),
      );
    }

    final filteredReferences = _getFilteredReferences();
    final categories = _getAvailableCategories();

    return RefreshIndicator(
      onRefresh: _fetchReferences,
      color: kPrimary,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // 1. Top Search Bar
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
                hintText: 'Cari judul artikel, penulis, topik, atau DOI...',
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

          // 2. Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Semua'),
                  selected: _selectedCategory == null,
                  selectedColor: const Color(0xFFD1FAE5),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: _selectedCategory == null
                        ? kPrimary
                        : const Color(0xFFE2E8F0),
                  ),
                  labelStyle: TextStyle(
                    color: _selectedCategory == null
                        ? const Color(0xFF047857)
                        : const Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  onSelected: (_) =>
                      setState(() => _selectedCategory = null),
                ),
                const SizedBox(width: 8),
                ...categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
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
                          setState(() => _selectedCategory = cat),
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Evidence-Based Medical Info Banner
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
                Icon(Icons.local_hospital_rounded, color: kPrimary, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Kumpulan literatur ilmiah, jurnal kedokteran, dan panduan klinis berbasis bukti (Evidence-Based Practice) yang mendasari Model Asuhan I-FINC.',
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

          // 4. Medical References List
          if (filteredReferences.isEmpty) ...[
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  const Icon(Icons.search_off_rounded,
                      size: 56, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 12),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'Tidak ada referensi yang cocok dengan "$_searchQuery"'
                        : 'Belum ada referensi medis.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                      fontFamily: 'Nunito',
                    ),
                  ),
                  if (_searchQuery.isNotEmpty || _selectedCategory != null) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _selectedCategory = null;
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
            ...filteredReferences.map((item) {
              final title = (item['title'] ?? 'Referensi Medis').toString();
              final author = item['author'] as String?;
              final year = item['year'] as String?;
              final category = (item['category'] ?? 'JURNAL').toString();
              final summary = item['summary'] as String?;

              return RepaintBoundary(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
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
                  child: InkWell(
                  onTap: () => _openReferenceDetail(item),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // PDF / Journal Icon Box (88x64 dp)
                        Container(
                          width: 80,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.picture_as_pdf_rounded,
                                color: Color(0xFFEF4444),
                                size: 24,
                              ),
                              SizedBox(height: 2),
                              Text(
                                'JURNAL',
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

                        const SizedBox(width: 14),

                        // Title, Authors, Year, Summary
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Category Tag & Year
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD1FAE5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      category.toUpperCase(),
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF047857),
                                      ),
                                    ),
                                  ),
                                  if (year != null &&
                                      year.trim().isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '• $year',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ],
                              ),

                              const SizedBox(height: 6),

                              // Article Title
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                  fontFamily: 'Nunito',
                                  height: 1.25,
                                ),
                              ),

                              // Author Line
                              if (author != null &&
                                  author.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  author.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF047857),
                                    fontFamily: 'Nunito',
                                  ),
                                ),
                              ],

                              // Summary Snippet
                              if (summary != null &&
                                  summary.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  summary.trim(),
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

                              const SizedBox(height: 8),

                              // Action indicator
                              Row(
                                children: const [
                                  Icon(
                                    Icons.menu_book_rounded,
                                    color: kPrimary,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Baca Jurnal / Artikel',
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

                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Color(0xFFCBD5E1),
                        ),
                      ],
                    ),
                  ),
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