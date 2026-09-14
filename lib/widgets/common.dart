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

class PrimaryBtn extends StatelessWidget {
  final String label; final VoidCallback? onPressed;
  const PrimaryBtn({super.key, required this.label, required this.onPressed});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: onPressed,
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(label)),
    ),
  );
}

class SecondaryBtn extends StatelessWidget {
  final String label; final VoidCallback? onPressed;
  const SecondaryBtn({super.key, required this.label, required this.onPressed});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      onPressed: onPressed,
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(label)),
    ),
  );
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

Widget sectionTitle(String s) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Text(s, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
);
