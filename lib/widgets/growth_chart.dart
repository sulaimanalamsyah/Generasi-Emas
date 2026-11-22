import 'package:material_ui/material_ui.dart';
import '../core/weight_formatter.dart';

enum GrowthMetricType { weight, length, head }

class GrowthChart extends StatefulWidget {
  final List<dynamic> measurements;
  final Map<String, dynamic> whoCurves;
  final GrowthMetricType activeMetric;
  final ValueChanged<GrowthMetricType> onMetricChanged;

  const GrowthChart({
    super.key,
    required this.measurements,
    required this.whoCurves,
    required this.activeMetric,
    required this.onMetricChanged,
  });

  @override
  State<GrowthChart> createState() => _GrowthChartState();
}

class _GrowthChartState extends State<GrowthChart> {
  int? _selectedPointIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metric Tab Switcher (Touch Target >= 48dp)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildMetricTab(
                  label: 'Berat (kg)',
                  type: GrowthMetricType.weight,
                  icon: Icons.scale_rounded,
                ),
                _buildMetricTab(
                  label: 'Panjang (cm)',
                  type: GrowthMetricType.length,
                  icon: Icons.straighten_rounded,
                ),
                _buildMetricTab(
                  label: 'Lingkar K (cm)',
                  type: GrowthMetricType.head,
                  icon: Icons.face_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Legend Indicators
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildLegendPill('Titik Ukur Bayi', const Color(0xFF10B981), isCircle: true),
              _buildLegendPill('Median WHO', const Color(0xFF10B981)),
              _buildLegendPill('+2 SD', const Color(0xFF0EA5E9)),
              _buildLegendPill('-2 SD (Batas Bawah)', const Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 16),

          // Selected Point Details Card (if clicked)
          if (_selectedPointIndex != null && _selectedPointIndex! < widget.measurements.length) ...[
            _buildPointDetailCard(widget.measurements[_selectedPointIndex!]),
            const SizedBox(height: 12),
          ],

          // Chart Canvas
          SizedBox(
            height: 220,
            width: double.infinity,
            child: GestureDetector(
              onTapUp: (details) {
                _handleChartTap(details.localPosition);
              },
              child: CustomPaint(
                painter: _GrowthChartPainter(
                  measurements: widget.measurements,
                  whoCurves: widget.whoCurves,
                  metricType: widget.activeMetric,
                  selectedPointIndex: _selectedPointIndex,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // X-Axis Subtitle
          const Center(
            child: Text(
              'Usia Bayi (Bulan: 0 s.d. 24 Bulan)',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTab({
    required String label,
    required GrowthMetricType type,
    required IconData icon,
  }) {
    final bool isSelected = widget.activeMetric == type;
    return Expanded(
      child: SizedBox(
        height: 44,
        child: InkWell(
          onTap: () {
            setState(() => _selectedPointIndex = null);
            widget.onMetricChanged(type);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: isSelected
                  ? const [
                      BoxShadow(
                        color: Color(0x0F0F172A),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? const Color(0xFF10B981) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendPill(String label, Color color, {bool isCircle = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isCircle ? 8 : 14,
          height: isCircle ? 8 : 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(isCircle ? 999 : 2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPointDetailCard(dynamic point) {
    if (point is! Map) return const SizedBox.shrink();
    final date = point['date'] ?? '';
    final age = point['ageFormatted'] ?? '';

    String valStr = '';
    String zStr = '';
    if (widget.activeMetric == GrowthMetricType.weight) {
      valStr = WeightFormatter.formatKgToGrams(point['weightKg']);
      final z = point['zScoreWeight'];
      zStr = z != null ? ' (Z-Score: ${z > 0 ? "+$z" : z})' : '';
    } else if (widget.activeMetric == GrowthMetricType.length) {
      valStr = '${point['lengthCm'] ?? '-'} cm';
      final z = point['zScoreLength'];
      zStr = z != null ? ' (Z-Score: ${z > 0 ? "+$z" : z})' : '';
    } else {
      valStr = '${point['headCircumferenceCm'] ?? '-'} cm';
      final z = point['zScoreHead'];
      zStr = z != null ? ' (Z-Score: ${z > 0 ? "+$z" : z})' : '';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.touch_app_outlined, size: 16, color: Color(0xFF065F46)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$date ($age): $valStr$zStr',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF065F46),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Color(0xFF065F46)),
            onPressed: () => setState(() => _selectedPointIndex = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }

  void _handleChartTap(Offset localPos) {
    if (widget.measurements.isEmpty) return;
    const paddingLeft = 36.0;
    const paddingRight = 16.0;

    final chartWidth = context.size?.width ?? 300;
    final w = chartWidth - paddingLeft - paddingRight;

    int? closestIdx;
    double minDist = 30.0; // Tap hit distance threshold

    for (int i = 0; i < widget.measurements.length; i++) {
      final m = widget.measurements[i];
      if (m is! Map) continue;
      final ageMonths = (m['ageMonths'] as num?)?.toDouble() ?? 0.0;
      final x = paddingLeft + (ageMonths / 24.0) * w;

      final dist = (localPos.dx - x).abs();
      if (dist < minDist) {
        minDist = dist;
        closestIdx = i;
      }
    }

    setState(() {
      _selectedPointIndex = closestIdx;
    });
  }
}

class _GrowthChartPainter extends CustomPainter {
  final List<dynamic> measurements;
  final Map<String, dynamic> whoCurves;
  final GrowthMetricType metricType;
  final int? selectedPointIndex;

  _GrowthChartPainter({
    required this.measurements,
    required this.whoCurves,
    required this.metricType,
    this.selectedPointIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const paddingLeft = 36.0;
    const paddingRight = 16.0;
    const paddingTop = 16.0;
    const paddingBottom = 28.0;

    final w = size.width - paddingLeft - paddingRight;
    final h = size.height - paddingTop - paddingBottom;

    if (w <= 0 || h <= 0) return;

    // Determine Y scale bounds based on metric
    double minY = 0.0;
    double maxY = 15.0; // Default weight kg
    int ySteps = 5;

    if (metricType == GrowthMetricType.weight) {
      minY = 2.0;
      maxY = 16.0;
      ySteps = 7;
    } else if (metricType == GrowthMetricType.length) {
      minY = 40.0;
      maxY = 95.0;
      ySteps = 5;
    } else {
      minY = 30.0;
      maxY = 52.0;
      ySteps = 4;
    }

    // Coordinate converters
    double toX(double month) => paddingLeft + (month.clamp(0.0, 24.0) / 24.0) * w;
    double toY(double val) => paddingTop + h - ((val.clamp(minY, maxY) - minY) / (maxY - minY)) * h;

    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;

    final textStyle = const TextStyle(
      fontFamily: 'Inter',
      fontSize: 10,
      color: Color(0xFF94A3B8),
    );

    // Draw horizontal grid lines and Y-axis labels
    final stepSize = (maxY - minY) / ySteps;
    for (int i = 0; i <= ySteps; i++) {
      final yVal = minY + i * stepSize;
      final yPos = toY(yVal);
      canvas.drawLine(Offset(paddingLeft, yPos), Offset(size.width - paddingRight, yPos), gridPaint);

      final label = yVal.toStringAsFixed(metricType == GrowthMetricType.weight ? 1 : 0);
      final tp = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(paddingLeft - tp.width - 6, yPos - tp.height / 2));
    }

    // Draw vertical grid lines and X-axis month labels (0, 3, 6, 9, 12, 18, 24)
    final months = [0, 3, 6, 9, 12, 18, 24];
    for (final m in months) {
      final xPos = toX(m.toDouble());
      canvas.drawLine(Offset(xPos, paddingTop), Offset(xPos, paddingTop + h), gridPaint);

      final tp = TextPainter(
        text: TextSpan(text: '$m', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(xPos - tp.width / 2, paddingTop + h + 6));
    }

    // Extract WHO curve data
    String curveKey = 'weight';
    if (metricType == GrowthMetricType.length) curveKey = 'length';
    if (metricType == GrowthMetricType.head) curveKey = 'head';

    final rawCurve = whoCurves[curveKey];
    if (rawCurve is List && rawCurve.isNotEmpty) {
      final medianPath = Path();
      final plus2Path = Path();
      final minus2Path = Path();
      final shadedPath = Path();

      bool first = true;
      List<Offset> plus2Points = [];
      List<Offset> minus2Points = [];

      for (final pt in rawCurve) {
        if (pt is! Map) continue;
        final m = (pt['month'] as num?)?.toDouble() ?? 0.0;
        final med = (pt['median'] as num?)?.toDouble() ?? 0.0;
        final p2 = (pt['plus2Sd'] as num?)?.toDouble() ?? 0.0;
        final m2 = (pt['minus2Sd'] as num?)?.toDouble() ?? 0.0;

        final x = toX(m);
        final yMed = toY(med);
        final yP2 = toY(p2);
        final yM2 = toY(m2);

        plus2Points.add(Offset(x, yP2));
        minus2Points.add(Offset(x, yM2));

        if (first) {
          medianPath.moveTo(x, yMed);
          plus2Path.moveTo(x, yP2);
          minus2Path.moveTo(x, yM2);
          first = false;
        } else {
          medianPath.lineTo(x, yMed);
          plus2Path.lineTo(x, yP2);
          minus2Path.lineTo(x, yM2);
        }
      }

      // Draw Shaded Normal Range Band (-2 SD to +2 SD)
      if (plus2Points.isNotEmpty && minus2Points.isNotEmpty) {
        shadedPath.moveTo(plus2Points.first.dx, plus2Points.first.dy);
        for (final p in plus2Points) {
          shadedPath.lineTo(p.dx, p.dy);
        }
        for (int i = minus2Points.length - 1; i >= 0; i--) {
          shadedPath.lineTo(minus2Points[i].dx, minus2Points[i].dy);
        }
        shadedPath.close();

        final shadedPaint = Paint()
          ..color = const Color(0xFFD1FAE5).withValues(alpha: 0.35)
          ..style = PaintingStyle.fill;
        canvas.drawPath(shadedPath, shadedPaint);
      }

      // Draw WHO standard reference lines
      final plus2Paint = Paint()
        ..color = const Color(0xFF0EA5E9)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawPath(plus2Path, plus2Paint);

      final minus2Paint = Paint()
        ..color = const Color(0xFFF59E0B)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawPath(minus2Path, minus2Paint);

      final medianPaint = Paint()
        ..color = const Color(0xFF10B981)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawPath(medianPath, medianPaint);
    }

    // Draw Patient Recorded Data Points
    if (measurements.isNotEmpty) {
      final patientLinePath = Path();
      final List<Offset> patientPoints = [];

      for (int i = 0; i < measurements.length; i++) {
        final m = measurements[i];
        if (m is! Map) continue;
        final ageMonths = (m['ageMonths'] as num?)?.toDouble() ?? 0.0;

        double? val;
        if (metricType == GrowthMetricType.weight) {
          val = (m['weightKg'] as num?)?.toDouble();
        } else if (metricType == GrowthMetricType.length) {
          val = (m['lengthCm'] as num?)?.toDouble();
        } else {
          val = (m['headCircumferenceCm'] as num?)?.toDouble();
        }

        if (val != null && val > 0) {
          final pt = Offset(toX(ageMonths), toY(val));
          patientPoints.add(pt);
          if (patientPoints.length == 1) {
            patientLinePath.moveTo(pt.dx, pt.dy);
          } else {
            patientLinePath.lineTo(pt.dx, pt.dy);
          }
        }
      }

      // Draw line connecting patient data points
      if (patientPoints.length > 1) {
        final patientLinePaint = Paint()
          ..color = const Color(0xFF0F172A)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        canvas.drawPath(patientLinePath, patientLinePaint);
      }

      // Draw individual data dots
      for (int i = 0; i < patientPoints.length; i++) {
        final pt = patientPoints[i];
        final bool isSelected = selectedPointIndex == i;

        // Outer glow/ring if selected
        if (isSelected) {
          final ringPaint = Paint()
            ..color = const Color(0xFF10B981).withValues(alpha: 0.3)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(pt, 12, ringPaint);
        }

        final dotPaint = Paint()
          ..color = const Color(0xFF10B981)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pt, isSelected ? 6 : 4.5, dotPaint);

        final dotInnerPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pt, isSelected ? 3 : 2, dotInnerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GrowthChartPainter oldDelegate) {
    return oldDelegate.measurements != measurements ||
        oldDelegate.metricType != metricType ||
        oldDelegate.selectedPointIndex != selectedPointIndex ||
        oldDelegate.whoCurves != whoCurves;
  }
}
