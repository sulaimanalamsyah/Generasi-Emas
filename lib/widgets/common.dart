import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 96});
  @override
  Widget build(BuildContext context) => Image.asset('assets/logo.png', width: size, height: size);
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
  title: Text(title),
  centerTitle: false,
  leadingWidth: 56,
  leading: const Padding(padding: EdgeInsets.only(left: 12), child: AppLogo(size: 28)),
  actions: actions,
);

Widget sectionTitle(String s) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Text(s, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
);
