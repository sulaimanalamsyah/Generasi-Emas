import 'package:url_launcher/url_launcher.dart';

String normalizeIdPhone(String raw) {
  var p = raw.replaceAll(RegExp(r'\D'), '');
  if (p.startsWith('0')) p = '62${p.substring(1)}';
  if (p.startsWith('8')) p = '62$p';
  return p;
}

Future<void> openWhatsApp(String phoneRaw, {String text = ''}) async {
  final p = normalizeIdPhone(phoneRaw);
  final uri = Uri.parse('https://wa.me/$p?text=${Uri.encodeComponent(text)}');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

