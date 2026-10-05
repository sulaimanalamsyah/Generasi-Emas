import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double? size;
  final BoxFit fit;

  const AppLogo({
    super.key,
    this.size = 96,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icon.png',
      width: size,
      height: size,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.health_and_safety,
          size: size ?? 64,
          color: const Color(0xFF10B981),
        );
      },
    );
  }
}

PreferredSizeWidget commonAppBar(String title, {List<Widget>? actions}) => AppBar(
  title: Text(
    title,
    style: const TextStyle(
      fontFamily: 'Nunito',
      fontWeight: FontWeight.bold,
      fontSize: 18,
      color: Color(0xFF0F172A),
    ),
  ),
  centerTitle: false,
  elevation: 0,
  backgroundColor: const Color(0xFFF8FAFC),
  surfaceTintColor: Colors.transparent,
  bottom: const PreferredSize(
    preferredSize: Size.fromHeight(1),
    child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
  ),
  leadingWidth: 56,
  leading: const Padding(padding: EdgeInsets.only(left: 16), child: AppLogo(size: 28)),
  actions: actions,
);

PreferredSizeWidget evaluationAppBar({
  required BuildContext context,
  required String title,
  VoidCallback? onRefresh,
  bool showBackButton = true,
}) => AppBar(
  title: Text(
    title,
    style: const TextStyle(
      fontFamily: 'Nunito',
      fontWeight: FontWeight.bold,
      fontSize: 18,
      color: Color(0xFF0F172A),
    ),
  ),
  centerTitle: false,
  elevation: 0,
  backgroundColor: const Color(0xFFF8FAFC),
  surfaceTintColor: Colors.transparent,
  bottom: const PreferredSize(
    preferredSize: Size.fromHeight(1),
    child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
  ),
  leading: showBackButton
      ? IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Kembali',
        )
      : const Padding(
          padding: EdgeInsets.only(left: 16),
          child: AppLogo(size: 28),
        ),
  actions: [
    if (onRefresh != null)
      IconButton(
        icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
        onPressed: onRefresh,
        tooltip: 'Refresh Data',
      ),
  ],
);

/// Dialog informasi / error standar aplikasi Generasi Emas
/// Mengikuti standar .agents/DESIGN.md: touch target >= 48dp, warna semantik, tipografi Nunito/Inter
Future<void> showAppInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
  bool isError = false,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                color: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: const TextStyle(
          fontFamily: 'Inter',
          color: Color(0xFF0F172A),
          fontSize: 14,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          style: TextButton.styleFrom(
            minimumSize: const Size(64, 48),
          ),
          child: const Text(
            'OK',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              color: Color(0xFF10B981),
            ),
          ),
        ),
      ],
    ),
  );
}

