import 'dart:async';
import 'package:flutter/material.dart';

class LoadingOverlay extends StatefulWidget {
  final String? message;
  const LoadingOverlay({super.key, this.message});

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay> {
  // Pesan berganti-ganti agar user tidak bosan
  final List<String> _messages = [
    "Menghubungkan ke server...",
    "Mengambil data terbaru...",
    "Sinkronisasi hasil formulir...",
    "Sedikit lagi...",
  ];
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Ganti pesan setiap 2 detik
    _timer = Timer.periodic(const Duration(seconds: 2), (t) {
      if (!mounted) return;
      setState(() {
        _index = (_index + 1) % _messages.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            widget.message ?? _messages[_index],
            style: const TextStyle(color: Colors.grey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}