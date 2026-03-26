import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebFormPage extends StatefulWidget {
  final String title;
  final String url;
  const WebFormPage({super.key, required this.title, required this.url});

  @override
  State<WebFormPage> createState() => _WebFormPageState();
}

class _WebFormPageState extends State<WebFormPage> {
  late final WebViewController _ctrl;
  bool _loading = true;
  bool _hasError = false; // [BARU] State untuk menangkap error loading

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          // [BARU] Reset error saat mulai memuat halaman
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _loading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          // [BARU] Tangkap error koneksi (Offline / DNS Fail)
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _loading = false;
                _hasError = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  // [BARU] Widget Tampilan Error / Offline
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            "Gagal memuat halaman.",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Periksa koneksi internet Anda.",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _ctrl.reload(), // Coba reload WebView
            icon: const Icon(Icons.refresh),
            label: const Text("Coba Lagi"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          // WebView tetap ada di stack, tapi bisa tertutup error view
          WebViewWidget(controller: _ctrl),

          // [BARU] Loading Indicator (hanya muncul jika tidak error)
          if (_loading && !_hasError) const LinearProgressIndicator(),

          // [BARU] Tampilan Error menutupi WebView jika gagal load
          if (_hasError)
            Container(
              color: Colors.white, // Background putih untuk menutupi webview error default
              child: _buildErrorView(),
            ),
        ],
      ),
    );
  }
}