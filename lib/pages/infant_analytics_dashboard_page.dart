import 'package:material_ui/material_ui.dart';
import '../core/age_calculator.dart';
import '../core/storage.dart';
import '../core/weight_formatter.dart';
import '../services/api_client.dart';
import '../widgets/common.dart';
import '../widgets/growth_chart.dart';

class InfantAnalyticsDashboardPage extends StatefulWidget {
  final String? infantId;

  const InfantAnalyticsDashboardPage({
    super.key,
    this.infantId,
  });

  @override
  State<InfantAnalyticsDashboardPage> createState() => _InfantAnalyticsDashboardPageState();
}

class _InfantAnalyticsDashboardPageState extends State<InfantAnalyticsDashboardPage> {
  final _api = ApiClient();

  bool _loading = true;
  String? _errorMessage;
  Map<String, dynamic>? _data;
  GrowthMetricType _activeMetric = GrowthMetricType.weight;
  bool _isSubmitting = false;
  String? _submittingMessage;

  static const List<EnicarePickerOption<String>> _clinicalStatusOptions = [
    EnicarePickerOption(value: 'VALIDATED', label: 'Tervalidasi Sesuai (Tumbuh Baik)'),
    EnicarePickerOption(value: 'MONITORING', label: 'Perlu Pemantauan Khusus'),
    EnicarePickerOption(value: 'NEEDS_ATTENTION', label: 'Perlu Konsultasi Dokter Spesialis'),
  ];

  Widget _buildClinicalStatusField(
    BuildContext sheetContext,
    String currentStatus,
    ValueChanged<String> onSelected,
  ) {
    final currentOpt = _clinicalStatusOptions.firstWhere(
      (o) => o.value == currentStatus,
      orElse: () => _clinicalStatusOptions.first,
    );
    return EnicarePickerField(
      displayText: currentOpt.label,
      isActive: true,
      leadingIcon: Icons.verified_user_outlined,
      onTap: () => showEnicareOptionSheet<String>(
        sheetContext,
        title: 'Status Evaluasi Klinis',
        selectedValue: currentStatus,
        options: _clinicalStatusOptions,
        onSelected: onSelected,
      ),
    );
  }

  List<Map<String, dynamic>> _sortMeasurementsByDateDesc(List<dynamic> rawMeasurements) {
    final list = rawMeasurements.map((e) => (e as Map).cast<String, dynamic>()).toList();
    list.sort((a, b) {
      final dateA = ApiClient.parseDate(a['date']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = ApiClient.parseDate(b['date']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateCmp = dateB.compareTo(dateA); // Newest first
      if (dateCmp != 0) return dateCmp;
      final idA = a['id'] is int ? a['id'] as int : int.tryParse(a['id']?.toString() ?? '') ?? 0;
      final idB = b['id'] is int ? b['id'] as int : int.tryParse(b['id']?.toString() ?? '') ?? 0;
      return idB.compareTo(idA);
    });
    return list;
  }

  List<Map<String, dynamic>> _sortReviewsByDateDesc(List<dynamic> rawReviews) {
    final list = rawReviews.map((e) => (e as Map).cast<String, dynamic>()).toList();
    list.sort((a, b) {
      final dateA = ApiClient.parseDate(a['reviewDate']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = ApiClient.parseDate(b['reviewDate']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateCmp = dateB.compareTo(dateA); // Newest first
      if (dateCmp != 0) return dateCmp;
      final idA = a['id'] is int ? a['id'] as int : int.tryParse(a['id']?.toString() ?? '') ?? 0;
      final idB = b['id'] is int ? b['id'] as int : int.tryParse(b['id']?.toString() ?? '') ?? 0;
      return idB.compareTo(idA);
    });
    return list;
  }

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  int? _parseIntVal(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString().trim());
  }

  String get _analyticsCacheKey => 'infant_analytics_v1_${widget.infantId ?? 'me'}';

  Future<void> _loadAnalytics({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final res = await _api.getInfantAnalytics(widget.infantId);
      await Prefs.setCachedJson(_analyticsCacheKey, res);
      if (!mounted) return;
      setState(() {
        _data = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is ApiError && e.status == 0) {
        final cached = await Prefs.getCachedJson(_analyticsCacheKey);
        if (!mounted) return;
        if (cached is Map) {
          setState(() {
            _data = Map<String, dynamic>.from(cached);
            _loading = false;
            _errorMessage = null;
          });
          showAppSnackBar(
            context,
            message: 'Menampilkan data analitik tersimpan (mode luring).',
          );
          return;
        }
      }
      String msg = 'Gagal memuat analitik bayi: $e';
      if (e is ApiError) {
        if (e.status == 0) {
          msg = 'Tidak ada koneksi internet. Silakan periksa jaringan Anda.';
        } else if (e.status == 404) {
          msg = 'Data profil bayi belum ditemukan atau belum diisi.';
        } else if (e.status == 403) {
          msg = 'Akses ditolak: Anda tidak memiliki wewenang untuk melihat data bayi ini.';
        }
      }
      setState(() {
        _errorMessage = msg;
        _loading = false;
      });
    }
  }

  /* ======================== ACTIONS: MEASUREMENT ======================== */

  void _showAddMeasurementBottomSheet(String resolvedInfantId) {
    final formKey = GlobalKey<FormState>();
    final weightCtrl = TextEditingController();
    final lengthCtrl = TextEditingController();
    final headCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: sheetBottomPadding(context, top: 20, extra: 20),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Catat Pengukuran Baru',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Tanggal Pengukuran
                      const Text(
                        'Tanggal Pengukuran',
                        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showEnicareDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setSheetState(() => selectedDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF10B981)),
                              const SizedBox(width: 10),
                              Text(
                                '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Berat Badan
                      const Text(
                        'Berat Badan (gram) *',
                        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: weightCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Contoh: 3450',
                          hintStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8), fontSize: 14),
                          suffixText: 'gram',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Berat badan wajib diisi';
                          final val = WeightFormatter.parseGramsInputToKg(v);
                          if (val == null || val < 0.5 || val > 35.0) return 'Masukkan berat valid (500 - 35.000 gram)';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Panjang / Tinggi Badan
                      const Text(
                        'Panjang Badan (cm) *',
                        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: lengthCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: 'Contoh: 51.5',
                          hintStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8), fontSize: 14),
                          suffixText: 'cm',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Panjang badan wajib diisi';
                          final num = double.tryParse(v.trim().replaceAll(',', '.'));
                          if (num == null || num <= 0 || num > 130) return 'Masukkan panjang valid (0 - 130 cm)';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Lingkar Kepala
                      const Text(
                        'Lingkar Kepala (cm) [Opsional]',
                        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: headCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: 'Contoh: 36.0',
                          hintStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8), fontSize: 14),
                          suffixText: 'cm',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            final num = double.tryParse(v.trim().replaceAll(',', '.'));
                            if (num == null || num <= 0 || num > 60) return 'Masukkan lingkar kepala valid (0 - 60 cm)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Gejala / Catatan
                      const Text(
                        'Catatan / Gejala [Opsional]',
                        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Kondisi nafsu makan, imunisasi, atau keluhan...',
                          hintStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8), fontSize: 13),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tombol Simpan
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  Navigator.pop(ctx);
                                  await _submitMeasurement(
                                    resolvedInfantId,
                                    date: '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                                    weight: WeightFormatter.parseGramsInputToKg(weightCtrl.text)!,
                                    length: double.parse(lengthCtrl.text.trim().replaceAll(',', '.')),
                                    head: headCtrl.text.trim().isNotEmpty
                                        ? double.parse(headCtrl.text.trim().replaceAll(',', '.'))
                                        : null,
                                    notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Simpan Pengukuran',
                            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitMeasurement(
    String infantId, {
    required String date,
    required double weight,
    required double length,
    double? head,
    String? notes,
  }) async {
    setState(() {
      _isSubmitting = true;
      _submittingMessage = 'Menyimpan pengukuran baru...';
    });
    try {
      await _api.addGrowthMeasurement(infantId, {
        'date': date,
        'weightKg': weight,
        'lengthCm': length,
        if (head != null) 'headCircumferenceCm': head,
        if (notes != null) ...{
          'symptoms': notes,
          'symptomsNotes': notes,
        },
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengukuran berhasil disimpan!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      await _loadAnalytics();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan pengukuran: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submittingMessage = null;
        });
      }
    }
  }

  Future<void> _deleteMeasurement(
    String infantId,
    int measurementId, {
    VoidCallback? onStartMutating,
    VoidCallback? onDeleted,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Pengukuran?', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.bold)),
        content: const Text('Data pengukuran tanggal ini akan dihapus permanen dari grafik.', style: TextStyle(fontFamily: 'Inter')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(fontFamily: 'Inter', color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Hapus', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    onStartMutating?.call();
    setState(() {
      _isSubmitting = true;
      _submittingMessage = 'Menghapus data pengukuran...';
    });
    try {
      await _api.deleteGrowthMeasurement(infantId, measurementId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data pengukuran berhasil dihapus.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      await _loadAnalytics(silent: true);
      onDeleted?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus pengukuran: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submittingMessage = null;
        });
      }
    }
  }

  void _showEditMeasurementBottomSheet(
    Map<String, dynamic> measurement,
    String resolvedInfantId, {
    VoidCallback? onStartMutating,
    VoidCallback? onSaved,
  }) {
    final formKey = GlobalKey<FormState>();
    final initialWeightGrams = measurement['weightKg'] != null
        ? ((measurement['weightKg'] as num).toDouble() * 1000).round().toString()
        : '';
    final weightCtrl = TextEditingController(text: initialWeightGrams);
    final lengthCtrl = TextEditingController(text: measurement['lengthCm']?.toString() ?? '');
    final headCtrl = TextEditingController(text: measurement['headCircumferenceCm']?.toString() ?? '');
    final notesCtrl = TextEditingController(text: (measurement['symptomsNotes'] ?? measurement['symptoms'])?.toString() ?? '');

    DateTime selectedDate = DateTime.now();
    if (measurement['date'] != null) {
      final parsed = ApiClient.parseDate(measurement['date']);
      if (parsed != null) selectedDate = parsed;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: sheetBottomPadding(context, top: 20, extra: 20),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Ubah Data Pengukuran',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tanggal Pengukuran',
                        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showEnicareDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setSheetState(() => selectedDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF10B981)),
                              const SizedBox(width: 10),
                              Text(
                                '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Berat Badan (gram) *',
                        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: weightCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Contoh: 3450',
                          hintStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8)),
                          suffixText: 'gram',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Berat badan wajib diisi';
                          final d = WeightFormatter.parseGramsInputToKg(val);
                          if (d == null || d < 0.5 || d > 30.0) return 'Masukkan berat yang valid (500 - 30.000 gram)';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Panjang / Tinggi Badan (cm) *',
                        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: lengthCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Contoh: 50.5',
                          hintStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8)),
                          suffixText: 'cm',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Panjang badan wajib diisi';
                          final d = double.tryParse(val.trim().replaceAll(',', '.'));
                          if (d == null || d < 20 || d > 150) return 'Masukkan panjang yang valid (20 - 150 cm)';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Lingkar Kepala (cm) (Opsional)',
                        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: headCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Contoh: 35.0',
                          hintStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8)),
                          suffixText: 'cm',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return null;
                          final d = double.tryParse(val.trim().replaceAll(',', '.'));
                          if (d == null || d < 15 || d > 70) return 'Masukkan lingkar kepala valid (15 - 70 cm)';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Catatan Gejala / Keluhan (Opsional)',
                        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: notesCtrl,
                        maxLines: 2,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Contoh: Bayi agak rewel, nafsu makan baik',
                          hintStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  Navigator.pop(ctx);
                                  onStartMutating?.call();
                                  await _submitUpdateMeasurement(
                                    resolvedInfantId,
                                    measurement['id'] as int,
                                    date: '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                                    weight: WeightFormatter.parseGramsInputToKg(weightCtrl.text)!,
                                    length: double.parse(lengthCtrl.text.trim().replaceAll(',', '.')),
                                    head: headCtrl.text.trim().isNotEmpty
                                        ? double.parse(headCtrl.text.trim().replaceAll(',', '.'))
                                        : null,
                                    notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                                    onStartMutating: onStartMutating,
                                    onSaved: onSaved,
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0EA5E9),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Simpan Perubahan',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitUpdateMeasurement(
    String infantId,
    int measurementId, {
    required String date,
    required double weight,
    required double length,
    double? head,
    String? notes,
    VoidCallback? onStartMutating,
    VoidCallback? onSaved,
  }) async {
    onStartMutating?.call();
    setState(() {
      _isSubmitting = true;
      _submittingMessage = 'Menyimpan perubahan pengukuran...';
    });
    try {
      await _api.updateGrowthMeasurement(infantId, measurementId, {
        'date': date,
        'weightKg': weight,
        'lengthCm': length,
        if (head != null) 'headCircumferenceCm': head,
        if (notes != null) ...{
          'symptoms': notes,
          'symptomsNotes': notes,
        },
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengukuran berhasil diperbarui!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      await _loadAnalytics(silent: true);
      onSaved?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui pengukuran: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submittingMessage = null;
        });
      }
    }
  }

  void _showPerItemNurseReviewBottomSheet(
    int measurementId,
    Map<String, dynamic> currentMeasurement,
    String resolvedInfantId, {
    VoidCallback? onStartMutating,
    VoidCallback? onReviewed,
  }) {
    String currentStatus = (currentMeasurement['reviewStatus'] as String?) ?? 'VALID';
    if (currentStatus != 'VALID' && currentStatus != 'NEEDS_ATTENTION') {
      currentStatus = 'VALID';
    }
    final notesCtrl = TextEditingController(text: (currentMeasurement['nurseNotes'] as String?) ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: sheetBottomPadding(context, top: 20, extra: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Tinjau Data Pengukuran',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tanggal Pengukuran: ${currentMeasurement['date'] ?? '-'}',
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Status Validasi Pengukuran *',
                      style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (statusCtx) {
                        final isLargeText = MediaQuery.textScalerOf(statusCtx).scale(12) > 16;
                        final validBox = InkWell(
                          onTap: () => setSheetState(() => currentStatus = 'VALID'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: currentStatus == 'VALID' ? const Color(0xFFD1FAE5) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: currentStatus == 'VALID' ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                                width: currentStatus == 'VALID' ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 16,
                                  color: currentStatus == 'VALID' ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Valid (Normal)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: currentStatus == 'VALID' ? const Color(0xFF065F46) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        final attentionBox = InkWell(
                          onTap: () => setSheetState(() => currentStatus = 'NEEDS_ATTENTION'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: currentStatus == 'NEEDS_ATTENTION' ? const Color(0xFFFEF3C7) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: currentStatus == 'NEEDS_ATTENTION' ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                                width: currentStatus == 'NEEDS_ATTENTION' ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 16,
                                  color: currentStatus == 'NEEDS_ATTENTION' ? const Color(0xFFD97706) : const Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Perlu Perhatian',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: currentStatus == 'NEEDS_ATTENTION' ? const Color(0xFF92400E) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        if (isLargeText) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              validBox,
                              const SizedBox(height: 8),
                              attentionBox,
                            ],
                          );
                        }
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: validBox),
                              const SizedBox(width: 10),
                              Expanded(child: attentionBox),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Catatan Klinis Perawat (Opsional)',
                      style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: notesCtrl,
                      maxLines: 3,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Beri umpan balik atau instruksi untuk ibu mengenai hasil pengukuran ini...',
                        hintStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                Navigator.pop(ctx);
                                onStartMutating?.call();
                                await _submitItemNurseReview(
                                  resolvedInfantId,
                                  measurementId,
                                  reviewStatus: currentStatus,
                                  nurseNotes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                                  onStartMutating: onStartMutating,
                                  onReviewed: onReviewed,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'Simpan Validasi Pengukuran',
                          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitItemNurseReview(
    String infantId,
    int measurementId, {
    required String reviewStatus,
    String? nurseNotes,
    VoidCallback? onStartMutating,
    VoidCallback? onReviewed,
  }) async {
    onStartMutating?.call();
    setState(() {
      _isSubmitting = true;
      _submittingMessage = 'Menyimpan validasi pengukuran...';
    });
    try {
      await _api.reviewGrowthMeasurement(infantId, measurementId, {
        'reviewStatus': reviewStatus,
        if (nurseNotes != null) 'nurseNotes': nurseNotes,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Validasi pengukuran berhasil disimpan!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      await _loadAnalytics(silent: true);
      onReviewed?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan validasi pengukuran: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submittingMessage = null;
        });
      }
    }
  }

  /* ======================== ACTIONS: NURSE REVIEW ======================== */

  void _showAddNurseReviewBottomSheet(String resolvedInfantId) {
    final formKey = GlobalKey<FormState>();
    final adviceCtrl = TextEditingController();
    String validationStatus = 'VALIDATED';
    DateTime reviewDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: sheetBottomPadding(context, top: 20, extra: 20),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Tinjauan & Review Klinis Perawat',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Status Validasi Dropdown
                      const Text(
                        'Status Evaluasi Klinis *',
                        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      _buildClinicalStatusField(
                        context,
                        validationStatus,
                        (val) => setSheetState(() => validationStatus = val),
                      ),
                      const SizedBox(height: 14),

                      // Saran & Anjuran Klinis
                      const Text(
                        'Anjuran & Saran Klinis untuk Orang Tua *',
                        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: adviceCtrl,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Tuliskan anjuran nutrisi, jadwal pengukuran berkala, atau rujukan...',
                          hintStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8), fontSize: 13),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Saran & anjuran klinis wajib diisi';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Tombol Simpan
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  Navigator.pop(ctx);
                                  await _submitNurseReview(
                                    resolvedInfantId,
                                    date: '${reviewDate.year}-${reviewDate.month.toString().padLeft(2, '0')}-${reviewDate.day.toString().padLeft(2, '0')}',
                                    status: validationStatus,
                                    advice: adviceCtrl.text.trim(),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0EA5E9),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Kirim Review Klinis',
                            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitNurseReview(
    String infantId, {
    required String date,
    required String status,
    required String advice,
  }) async {
    setState(() {
      _isSubmitting = true;
      _submittingMessage = 'Menyimpan catatan review...';
    });
    try {
      await _api.addNurseReview(infantId, {
        'reviewDate': date,
        'status': status,
        'validationStatus': status,
        'clinicalAdvice': advice,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review klinis berhasil dikirim!'),
          backgroundColor: Color(0xFF0EA5E9),
        ),
      );
      await _loadAnalytics();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengirim review: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submittingMessage = null;
        });
      }
    }
  }

  void _showEditNurseReviewBottomSheet(
    Map<String, dynamic> review,
    String resolvedInfantId, {
    VoidCallback? onStartMutating,
    VoidCallback? onSaved,
  }) {
    final formKey = GlobalKey<FormState>();
    final reviewId = review['id'] is int ? review['id'] as int : int.tryParse(review['id']?.toString() ?? '') ?? 0;
    final adviceCtrl = TextEditingController(text: (review['clinicalAdvice'] as String?) ?? '');

    String validationStatus = (review['status'] ?? review['validationStatus'] ?? 'VALIDATED').toString();
    if (validationStatus.contains('Pemantauan') || validationStatus == 'MONITORING') {
      validationStatus = 'MONITORING';
    } else if (validationStatus.contains('Konsultasi') || validationStatus.contains('Perhatian') || validationStatus == 'NEEDS_ATTENTION') {
      validationStatus = 'NEEDS_ATTENTION';
    } else {
      validationStatus = 'VALIDATED';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: sheetBottomPadding(context, top: 20, extra: 20),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Ubah Review Klinis Perawat',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Status Validasi Dropdown
                      const Text(
                        'Status Evaluasi Klinis *',
                        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      _buildClinicalStatusField(
                        context,
                        validationStatus,
                        (val) => setSheetState(() => validationStatus = val),
                      ),
                      const SizedBox(height: 14),

                      // Saran & Anjuran Klinis
                      const Text(
                        'Anjuran & Saran Klinis untuk Orang Tua *',
                        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: adviceCtrl,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Tuliskan anjuran nutrisi, jadwal pengukuran berkala, atau rujukan...',
                          hintStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8), fontSize: 13),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Saran & anjuran klinis wajib diisi';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Tombol Simpan Perubahan
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  Navigator.pop(ctx);
                                  onStartMutating?.call();
                                  await _submitUpdateNurseReview(
                                    resolvedInfantId,
                                    reviewId,
                                    status: validationStatus,
                                    advice: adviceCtrl.text.trim(),
                                    onStartMutating: onStartMutating,
                                    onSaved: onSaved,
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0EA5E9),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Simpan Perubahan Review',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitUpdateNurseReview(
    String infantId,
    int reviewId, {
    required String status,
    required String advice,
    VoidCallback? onStartMutating,
    VoidCallback? onSaved,
  }) async {
    onStartMutating?.call();
    setState(() {
      _isSubmitting = true;
      _submittingMessage = 'Menyimpan perubahan review klinis...';
    });
    try {
      await _api.updateNurseReview(infantId, reviewId, {
        'status': status,
        'validationStatus': status,
        'clinicalAdvice': advice,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review klinis berhasil diperbarui!'),
          backgroundColor: Color(0xFF0EA5E9),
        ),
      );
      await _loadAnalytics(silent: true);
      onSaved?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui review: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submittingMessage = null;
        });
      }
    }
  }

  Future<void> _confirmDeleteNurseReview(
    int reviewId,
    String infantId, {
    VoidCallback? onStartMutating,
    VoidCallback? onDeleted,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Catatan Tinjauan?',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        content: const Text(
          'Tindakan ini tidak dapat dibatalkan. Catatan ulasan klinis ini akan dihapus secara permanen.',
          style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Hapus', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    onStartMutating?.call();
    setState(() {
      _isSubmitting = true;
      _submittingMessage = 'Menghapus catatan review...';
    });
    try {
      await _api.deleteNurseReview(infantId, reviewId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Catatan review berhasil dihapus.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      await _loadAnalytics(silent: true);
      onDeleted?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus review: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submittingMessage = null;
        });
      }
    }
  }

  /* ======================== BUILD VIEWS ======================== */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: evaluationAppBar(
        context: context,
        title: 'Analitik Tumbuh Kembang',
        onRefresh: _loading ? null : _loadAnalytics,
        showBackButton: true,
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
            : (_errorMessage != null
                ? _buildErrorView()
                : Column(
                  children: [
                    if (_isSubmitting) ...[
                      const LinearProgressIndicator(
                        minHeight: 3,
                        backgroundColor: Color(0xFFBAE6FD),
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: const Color(0xFFE0F2FE),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _submittingMessage ?? 'Memperbarui data analitik...',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0369A1),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Expanded(
                      child: RefreshIndicator(
                        color: const Color(0xFF10B981),
                        onRefresh: _loadAnalytics,
                        child: _buildDashboardContent(),
                      ),
                    ),
                  ],
                )),
      ),
      bottomNavigationBar: (!_loading && _errorMessage == null && _data != null)
          ? _buildBottomActionBar()
          : null,
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Terjadi kesalahan.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadAnalytics,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    final infant = (_data?['infant'] as Map?)?.cast<String, dynamic>() ?? {};
    final measurements = (_data?['measurements'] as List?) ?? [];
    final nurseReviews = (_data?['nurseReviews'] as List?) ?? [];
    final whoCurves = (_data?['whoCurves'] as Map?)?.cast<String, dynamic>() ?? {};
    final role = (_data?['userRole'] as String?) ?? (_data?['role'] as String?) ?? 'mother';

    // Sesuai umpan balik pengguna: Menampilkan nama bayi langsung, bukan nama ibu
    final rawInfantName = (infant['name'] as String?)?.trim();
    final babyName = (rawInfantName != null && rawInfantName.isNotEmpty) ? rawInfantName : 'Nama Bayi Belum Diisi';

    // Usia dinamis dari currentAge atau infant['birthDate']
    String ageStr = (_data?['currentAge']?['formatted'] as String?) ?? '';
    if (ageStr.isEmpty && infant['birthDate'] != null) {
      final parsedDob = ApiClient.parseDate(infant['birthDate']);
      if (parsedDob != null) {
        ageStr = InfantAge.calculate(parsedDob).formatted;
      }
    }
    if (ageStr.isEmpty) ageStr = (infant['age'] as String?) ?? '-';

    final gender = (infant['babyGender'] as String?) ?? (infant['gender'] as String?) ?? '-';
    final gestationalWeeks = infant['gestationalWeeks'];
    final diagnosis = (infant['medicalDiagnosis'] as String?) ?? '-';

    final latestMeasurement = (_data?['latestMeasurement'] as Map?)?.cast<String, dynamic>() ?? {};
    final stuntingStatus = (_data?['stuntingStatus'] as Map?)?.cast<String, dynamic>() ?? {};
    final weightStatus = (_data?['weightStatus'] as Map?)?.cast<String, dynamic>() ?? {};
    final resolvedInfantId = infant['id']?.toString() ?? (widget.infantId ?? 'me');

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Card Identitas Bayi
          _buildInfantProfileCard(
            babyName: babyName,
            ageStr: ageStr,
            gender: gender,
            gestationalWeeks: gestationalWeeks,
            diagnosis: diagnosis,
            infant: infant,
          ),
          const SizedBox(height: 16),

          // 2. Disclaimer Card Wajib (Pediatric Clinical Disclaimer)
          _buildClinicalDisclaimerCard(),
          const SizedBox(height: 16),

          // 3. Status Stunting & Berat Badan Saat Ini
          _buildStatusSummaryCards(
            latestMeasurement: latestMeasurement,
            stuntingStatus: stuntingStatus,
            weightStatus: weightStatus,
            birthWeightGrams: _parseIntVal(infant['birthWeight']),
          ),
          const SizedBox(height: 20),

          // 4. Kurva Pertumbuhan WHO Interaktif
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                const Text(
                  'Kurva Pertumbuhan WHO',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Standar WHO (Z-Score)',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0369A1)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GrowthChart(
            measurements: measurements,
            whoCurves: whoCurves,
            activeMetric: _activeMetric,
            onMetricChanged: (metric) => setState(() => _activeMetric = metric),
            birthWeightGrams: _parseIntVal(infant['birthWeight']),
            gestationalWeeks: _parseIntVal(gestationalWeeks),
          ),
          const SizedBox(height: 24),

          // 5. Riwayat Pengukuran Berkala
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                const Text(
                  'Riwayat Pengukuran Berkala',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '${measurements.length} Catatan',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildMeasurementHistorySection(measurements, role, resolvedInfantId),
          const SizedBox(height: 24),

          // 6. Review & Validasi Tenaga Medis (Nurse Clinical Supervision)
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                const Text(
                  'Catatan & Tinjauan Tenaga Medis',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '${nurseReviews.length} Catatan',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildNurseReviewsSection(nurseReviews, role, resolvedInfantId),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /* ======================== SUB-WIDGETS ======================== */

  Widget _buildInfantProfileCard({
    required String babyName,
    required String ageStr,
    required String gender,
    required dynamic gestationalWeeks,
    required String diagnosis,
    required Map<String, dynamic> infant,
  }) {
    final isMale = gender.toLowerCase().contains('laki') || gender.toLowerCase().contains('male');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isMale ? const Color(0xFFE0F2FE) : const Color(0xFFFCE7F3),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.child_care_rounded,
                  color: isMale ? const Color(0xFF0284C7) : const Color(0xFFDB2777),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      babyName,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Usia: $ageStr',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isMale ? const Color(0xFFE0F2FE) : const Color(0xFFFCE7F3),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isMale ? 'Laki-laki' : 'Perempuan',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isMale ? const Color(0xFF0369A1) : const Color(0xFFBE185D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Detail Klinis Kelahiran
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (gestationalWeeks != null)
                _buildInfoChip(
                  icon: Icons.access_time_rounded,
                  label: 'Gestasi',
                  value: '$gestationalWeeks Mgg',
                ),
              if (infant['birthWeight'] != null)
                _buildInfoChip(
                  icon: Icons.scale_rounded,
                  label: 'BBL',
                  value: WeightFormatter.formatGrams(infant['birthWeight']),
                ),
              if (infant['birthLength'] != null)
                _buildInfoChip(
                  icon: Icons.straighten_rounded,
                  label: 'PBL',
                  value: '${infant['birthLength']} cm',
                ),
              if (diagnosis != '-' && diagnosis.isNotEmpty)
                _buildInfoChip(
                  icon: Icons.local_hospital_outlined,
                  label: 'Dx',
                  value: diagnosis,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF64748B)),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF64748B)),
          ),
          Text(
            value,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalDisclaimerCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Catatan Pemantauan Klinis',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFF92400E),
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Grafik dan status tumbuh kembang ini diolah berdasarkan standar WHO sebagai skrining awal di rumah. Hasil analisis ini tidak menggantikan pemeriksaan medis maupun konsultasi klinis langsung dengan Dokter Spesialis Anak.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSummaryCards({
    required Map<String, dynamic> latestMeasurement,
    required Map<String, dynamic> stuntingStatus,
    required Map<String, dynamic> weightStatus,
    int? birthWeightGrams,
  }) {
    final stuntingLabel = (stuntingStatus['label'] as String?) ?? 'Belum Ada Data';
    final weightLabel = (weightStatus['label'] as String?) ?? 'Belum Ada Data';
    final rawStuntingCat = (stuntingStatus['category'] as String?) ?? '';
    final rawWeightCat = (weightStatus['category'] as String?) ?? '';

    final weightKg = latestMeasurement['weightKg'];
    final lengthCm = latestMeasurement['lengthCm'];
    final headCm = latestMeasurement['headCircumferenceCm'];
    final dateStr = (latestMeasurement['date'] as String?) ?? '-';
    final zLength = latestMeasurement['zScoreLength'];
    final zWeight = latestMeasurement['zScoreWeight'];

    Color stuntingColor = const Color(0xFF10B981);
    Color stuntingBg = const Color(0xFFD1FAE5);
    if (rawStuntingCat == 'SEVERELY_STUNTED' || stuntingLabel.contains('Sangat Pendek')) {
      stuntingColor = const Color(0xFFDC2626);
      stuntingBg = const Color(0xFFFEE2E2);
    } else if (rawStuntingCat == 'STUNTED' || stuntingLabel.contains('Pendek')) {
      stuntingColor = const Color(0xFFD97706);
      stuntingBg = const Color(0xFFFEF3C7);
    } else if (rawStuntingCat == 'TALL' || stuntingLabel.contains('Tinggi')) {
      stuntingColor = const Color(0xFF0284C7);
      stuntingBg = const Color(0xFFE0F2FE);
    }

    Color weightColor = const Color(0xFF10B981);
    Color weightBg = const Color(0xFFD1FAE5);
    if (rawWeightCat == 'SEVERELY_UNDERWEIGHT' || weightLabel.contains('Sangat Kurang')) {
      weightColor = const Color(0xFFDC2626);
      weightBg = const Color(0xFFFEE2E2);
    } else if (rawWeightCat == 'UNDERWEIGHT' || weightLabel.contains('Kurang')) {
      weightColor = const Color(0xFFD97706);
      weightBg = const Color(0xFFFEF3C7);
    } else if (rawWeightCat == 'OVERWEIGHT' || weightLabel.contains('Lebih')) {
      weightColor = const Color(0xFF0284C7);
      weightBg = const Color(0xFFE0F2FE);
    }

    final isLargeText = MediaQuery.textScalerOf(context).scale(14) > 18;
    final num? latestWeightKg = weightKg is num ? weightKg : num.tryParse('${weightKg ?? ''}');
    final int? latestWeightGrams = latestWeightKg != null ? (latestWeightKg * 1000).round() : null;
    final int? weightDeltaGrams = (birthWeightGrams != null && latestWeightGrams != null)
        ? (latestWeightGrams - birthWeightGrams)
        : null;
    final String? deltaLabel = weightDeltaGrams != null
        ? '${weightDeltaGrams >= 0 ? '+' : ''}$weightDeltaGrams g vs BBL'
        : null;

    Widget buildStatusCard(String heading, String label, Color fg, Color bg, dynamic zVal) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              heading,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: fg,
                ),
              ),
            ),
            if (zVal != null) ...[
              const SizedBox(height: 6),
              Text(
                'Z-Score: $zVal SD',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        // Kartu Kategori Status Pertumbuhan
        if (isLargeText) ...[
          buildStatusCard('Status Tinggi/Panjang', stuntingLabel, stuntingColor, stuntingBg, zLength),
          const SizedBox(height: 10),
          buildStatusCard('Status Berat Badan', weightLabel, weightColor, weightBg, zWeight),
        ] else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: buildStatusCard('Status Tinggi/Panjang', stuntingLabel, stuntingColor, stuntingBg, zLength),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: buildStatusCard('Status Berat Badan', weightLabel, weightColor, weightBg, zWeight),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),

        // Grid 2x2 Metrik Utama: Berat Saat Lahir, Berat Terakhir (+delta), Panjang Terakhir, Lingkar Kepala
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildMetricStatColumn(
                      label: 'Berat Saat Lahir',
                      value: birthWeightGrams != null ? WeightFormatter.formatGrams(birthWeightGrams) : '-',
                      icon: Icons.child_friendly_rounded,
                      color: const Color(0xFF0284C7),
                    ),
                  ),
                  Container(width: 1, height: 48, color: const Color(0xFFF1F5F9)),
                  Expanded(
                    child: _buildMetricStatColumn(
                      label: 'Berat Terakhir',
                      value: WeightFormatter.formatKgToGrams(weightKg),
                      deltaText: deltaLabel,
                      isDeltaPositive: (weightDeltaGrams ?? 0) >= 0,
                      icon: Icons.scale_rounded,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: Color(0xFFF1F5F9)),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildMetricStatColumn(
                      label: 'Panjang Terakhir',
                      value: lengthCm != null ? '$lengthCm cm' : '-',
                      icon: Icons.straighten_rounded,
                      color: const Color(0xFF0EA5E9),
                    ),
                  ),
                  Container(width: 1, height: 48, color: const Color(0xFFF1F5F9)),
                  Expanded(
                    child: _buildMetricStatColumn(
                      label: 'Lingkar Kepala',
                      value: headCm != null ? '$headCm cm' : '-',
                      icon: Icons.face_rounded,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (dateStr != '-') ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Pengukuran terakhir: $dateStr',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetricStatColumn({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    String? deltaText,
    bool isDeltaPositive = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          if (deltaText != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isDeltaPositive ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                deltaText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDeltaPositive ? const Color(0xFF065F46) : const Color(0xFF92400E),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMeasurementHistorySection(List<dynamic> measurements, String role, String infantId) {
    if (measurements.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: const [
            Icon(Icons.straighten_rounded, size: 36, color: Color(0xFFCBD5E1)),
            SizedBox(height: 8),
            Text(
              'Belum ada data pengukuran berkala',
              style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF64748B)),
            ),
            SizedBox(height: 4),
            Text(
              'Catat pengukuran berat & panjang secara rutin untuk melihat grafik tumbuh kembang anak.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    // Tampilkan riwayat terurut tanggal terbaru di atas
    final sortedMeasurements = _sortMeasurementsByDateDesc(measurements);
    final displayList = sortedMeasurements.take(3).toList();

    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayList.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) {
            final m = (displayList[i] as Map).cast<String, dynamic>();
            return _buildMeasurementCard(m, role, infantId);
          },
        ),
        if (sortedMeasurements.length > 3) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showAllMeasurementsBottomSheet(role, infantId),
              icon: const Icon(Icons.history_rounded, size: 18, color: Color(0xFF10B981)),
              label: Text(
                'Lihat Semua Riwayat (${measurements.length} Catatan)',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF10B981),
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showAllMeasurementsBottomSheet(String role, String infantId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final measurements = (_data?['measurements'] as List?) ?? [];
            final allMeasurements = _sortMeasurementsByDateDesc(measurements);

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Riwayat Lengkap (${allMeasurements.length})',
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  if (_isSubmitting) ...[
                    const LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: Color(0xFFBAE6FD),
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: const Color(0xFFE0F2FE),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _submittingMessage ?? 'Memperbarui data...',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0369A1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Expanded(
                    child: allMeasurements.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.straighten_rounded, size: 48, color: Color(0xFFCBD5E1)),
                                  SizedBox(height: 12),
                                  Text(
                                    'Belum ada data pengukuran',
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.paddingOf(sheetCtx).bottom + 24),
                            itemCount: allMeasurements.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final m = (allMeasurements[i] as Map).cast<String, dynamic>();
                              return _buildMeasurementCard(
                                m,
                                role,
                                infantId,
                                onStartMutating: () {
                                  if (sheetCtx.mounted) setModalState(() {});
                                },
                                onMutated: () {
                                  if (sheetCtx.mounted) setModalState(() {});
                                },
                              );
                            },
                          ),
                  ),
                ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMeasurementCard(
    Map<String, dynamic> m,
    String role,
    String infantId, {
    VoidCallback? onStartMutating,
    VoidCallback? onMutated,
  }) {
        final id = m['id'] as int;
        final date = (m['date'] as String?) ?? '-';
        final ageFormatted = (m['ageFormatted'] as String?) ?? (m['ageInMonths'] != null ? '${m['ageInMonths']} bln' : null);
        final weight = m['weightKg'];
        final length = m['lengthCm'];
        final head = m['headCircumferenceCm'];
        final notes = (m['symptomsNotes'] ?? m['symptoms'])?.toString().trim();
        final reviewStatus = m['reviewStatus'] as String?;
        final nurseNotes = (m['nurseNotes'] as String?)?.trim();

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x040F172A),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Tanggal, Usia, dan Aksi Role
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF10B981)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                date,
                                style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                              ),
                            ),
                          ],
                        ),
                        if (ageFormatted != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              ageFormatted,
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (role == 'mother')
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Color(0xFF0EA5E9), size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          tooltip: 'Ubah Data',
                          onPressed: _isSubmitting
                              ? null
                              : () => _showEditMeasurementBottomSheet(
                                    m,
                                    infantId,
                                    onStartMutating: onStartMutating,
                                    onSaved: onMutated,
                                  ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          tooltip: 'Hapus Catatan',
                          onPressed: _isSubmitting
                              ? null
                              : () => _deleteMeasurement(
                                    infantId,
                                    id,
                                    onStartMutating: onStartMutating,
                                    onDeleted: onMutated,
                                  ),
                        ),
                      ],
                    )
                  else if (role == 'nurse')
                    TextButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => _showPerItemNurseReviewBottomSheet(
                                id,
                                m,
                                infantId,
                                onStartMutating: onStartMutating,
                                onReviewed: onMutated,
                              ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(48, 48),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.rate_review_outlined, size: 15, color: Color(0xFF10B981)),
                      label: const Text(
                        'Tinjau',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // 3-Column Balanced Grid: Berat, Panjang, Lingkar Kepala (wraps on large font)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: MediaQuery.textScalerOf(context).scale(13) > 17
                    ? Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Berat', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF64748B))),
                              Text(WeightFormatter.formatKgToGrams(weight), style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Panjang', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF64748B))),
                              Text(length != null ? '$length cm' : '-', style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Lingkar Kepala', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF64748B))),
                              Text(head != null ? '$head cm' : '-', style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Berat',
                                  style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  WeightFormatter.formatKgToGrams(weight),
                                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Panjang',
                                  style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  length != null ? '$length cm' : '-',
                                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Lingkar Kepala',
                                  style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  head != null ? '$head cm' : '-',
                                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),

              // Status Review Perawat per-item
              if (reviewStatus == 'VALID') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 13),
                      SizedBox(width: 5),
                      Text(
                        'Diverifikasi Perawat',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                      ),
                    ],
                  ),
                ),
              ] else if (reviewStatus == 'NEEDS_ATTENTION') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 13),
                      SizedBox(width: 5),
                      Text(
                        'Perlu Perhatian Klinis',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                      ),
                    ],
                  ),
                ),
              ],

              // Catatan Perawat
              if (nurseNotes != null && nurseNotes.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.rate_review_rounded, size: 14, color: Color(0xFF16A34A)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Catatan Perawat: $nurseNotes',
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF15803D)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Catatan Keluhan Ibu
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Keluhan: $notes',
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF475569), fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ],
          ),
        );
  }

  Widget _buildNurseReviewsSection(List<dynamic> reviews, String role, String infantId) {
    if (reviews.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080F172A),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: const [
            Icon(Icons.rate_review_outlined, size: 36, color: Color(0xFFCBD5E1)),
            SizedBox(height: 8),
            Text(
              'Belum ada catatan review klinis',
              style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF64748B)),
            ),
            SizedBox(height: 4),
            Text(
              'Tenaga medis akan memberikan anjuran & evaluasi tumbuh kembang setelah memeriksa grafik.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    // Tampilkan catatan review klinis terurut tanggal terbaru di atas
    final sortedReviews = _sortReviewsByDateDesc(reviews);
    final displayList = sortedReviews.take(2).toList(); // Compact 2 items to prevent page overload

    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayList.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final r = (displayList[i] as Map).cast<String, dynamic>();
            return _buildNurseReviewCard(r, role, infantId);
          },
        ),
        if (sortedReviews.length > 2) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showAllNurseReviewsBottomSheet(role, infantId),
              icon: const Icon(Icons.history_edu_rounded, size: 18, color: Color(0xFF0284C7)),
              label: Text(
                'Lihat Semua Tinjauan (${reviews.length} Catatan)',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0284C7),
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: Color(0xFF0284C7), width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: const Color(0xFFF0F9FF),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showAllNurseReviewsBottomSheet(String role, String infantId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final reviews = (_data?['nurseReviews'] as List?) ?? [];
            final allReviews = _sortReviewsByDateDesc(reviews);

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Semua Catatan Tinjauan (${allReviews.length})',
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  if (_isSubmitting) ...[
                    const LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: Color(0xFFBAE6FD),
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: const Color(0xFFE0F2FE),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _submittingMessage ?? 'Memperbarui data...',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0369A1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Expanded(
                    child: allReviews.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.rate_review_outlined, size: 48, color: Color(0xFFCBD5E1)),
                                  SizedBox(height: 12),
                                  Text(
                                    'Belum ada catatan review klinis',
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.paddingOf(sheetCtx).bottom + 24),
                            itemCount: allReviews.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (_, i) {
                              final r = (allReviews[i] as Map).cast<String, dynamic>();
                              return _buildNurseReviewCard(
                                r,
                                role,
                                infantId,
                                onStartMutating: () {
                                  if (sheetCtx.mounted) setModalState(() {});
                                },
                                onMutated: () {
                                  if (sheetCtx.mounted) setModalState(() {});
                                },
                              );
                            },
                          ),
                  ),
                ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNurseReviewCard(
    Map<String, dynamic> r,
    String role,
    String infantId, {
    VoidCallback? onStartMutating,
    VoidCallback? onMutated,
  }) {
    final reviewId = r['id'] is int ? r['id'] as int : int.tryParse(r['id']?.toString() ?? '');
    final nurse = (r['nurse'] as Map?)?.cast<String, dynamic>() ?? {};
    final rawNurseName = (nurse['name'] as String?)?.trim();
    final nurseName = (rawNurseName != null && rawNurseName.isNotEmpty) ? rawNurseName : 'Perawat Klinis';
    final advice = (r['clinicalAdvice'] as String?)?.trim() ?? '-';
    final notes = (r['notes'] as String?)?.trim();

    final rawStatus = (r['status'] ?? r['validationStatus']) as String? ?? 'VALIDATED';
    String statusLabel;
    Color badgeBg;
    Color badgeText;
    Color badgeBorder;
    Color statusAccent;
    IconData badgeIcon;

    if (rawStatus == 'MONITORING' || rawStatus.contains('Pemantauan')) {
      statusLabel = 'Perlu Pemantauan Khusus';
      badgeBg = const Color(0xFFFEF3C7);
      badgeText = const Color(0xFF92400E);
      badgeBorder = const Color(0xFFFCD34D);
      statusAccent = const Color(0xFFF59E0B);
      badgeIcon = Icons.visibility_rounded;
    } else if (rawStatus == 'NEEDS_ATTENTION' || rawStatus.contains('Konsultasi') || rawStatus.contains('Perhatian')) {
      statusLabel = 'Perlu Konsultasi Dokter Spesialis';
      badgeBg = const Color(0xFFFEE2E2);
      badgeText = const Color(0xFF991B1B);
      badgeBorder = const Color(0xFFFCA5A5);
      statusAccent = const Color(0xFFEF4444);
      badgeIcon = Icons.warning_amber_rounded;
    } else {
      statusLabel = 'Tervalidasi Sesuai (Tumbuh Baik)';
      badgeBg = const Color(0xFFD1FAE5);
      badgeText = const Color(0xFF065F46);
      badgeBorder = const Color(0xFF86EFAC);
      statusAccent = const Color(0xFF10B981);
      badgeIcon = Icons.check_circle_rounded;
    }

    DateTime? parsedDate = ApiClient.parseDate(r['reviewDate']);
    final date = parsedDate != null
        ? '${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year}'
        : ((r['reviewDate'] as String?) ?? '-');

    // Inisial perawat untuk Avatar Circle
    final initials = nurseName.trim().isNotEmpty
        ? nurseName.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join().toUpperCase()
        : 'N';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              color: statusAccent,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
          // Row 1: Header (Avatar + Nurse Details + Action Icons)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar Circle
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Nurse Name & Metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nurseName,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Perawat Klinis',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const Text(
                          '•',
                          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 10, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 3),
                            Text(
                              date,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions: Edit & Delete (Nurse Role Only)
              if (role == 'nurse' && reviewId != null) ...[
                const SizedBox(width: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      padding: const EdgeInsets.all(5),
                      icon: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF0284C7)),
                      ),
                      tooltip: 'Ubah Review',
                      onPressed: _isSubmitting
                          ? null
                          : () => _showEditNurseReviewBottomSheet(
                                r,
                                infantId,
                                onStartMutating: onStartMutating,
                                onSaved: onMutated,
                              ),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      padding: const EdgeInsets.all(5),
                      icon: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                      ),
                      tooltip: 'Hapus Review',
                      onPressed: _isSubmitting
                          ? null
                          : () => _confirmDeleteNurseReview(
                                reviewId,
                                infantId,
                                onStartMutating: onStartMutating,
                                onDeleted: onMutated,
                              ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Status Pill Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: badgeBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, size: 13, color: badgeText),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Row 3: Styled Clinical Recommendation Container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.chat_bubble_outline_rounded, size: 13, color: Color(0xFF0284C7)),
                    SizedBox(width: 6),
                    Text(
                      'Anjuran & Saran Klinis:',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  advice.isNotEmpty ? advice : '-',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFF1E293B),
                    height: 1.45,
                  ),
                ),
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.note_alt_outlined, size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Catatan Tambahan: $notes',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildBottomActionBar() {
    final role = (_data?['userRole'] as String?) ?? (_data?['role'] as String?) ?? 'mother';
    final infant = (_data?['infant'] as Map?)?.cast<String, dynamic>() ?? {};
    final resolvedInfantId = infant['id']?.toString() ?? (widget.infantId ?? 'me');

    if (role == 'mother') {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : () => _showAddMeasurementBottomSheet(resolvedInfantId),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'Catat Pengukuran Baru',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } else if (role == 'nurse') {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : () => _showAddNurseReviewBottomSheet(resolvedInfantId),
                  icon: const Icon(Icons.rate_review_rounded),
                  label: const Text(
                    'Beri Tinjauan Klinis Perawat',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } else if (role == 'father') {
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF1F5F9),
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: const SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF64748B)),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Mode Pemantau (Ayah) - Hak Akses Baca',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return null;
  }
}
