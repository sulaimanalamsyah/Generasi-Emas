import 'package:url_launcher/url_launcher.dart';

Future<bool> openExternalUrl(String url) async {
  final uri = Uri.parse(url);
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

String normalizeIdPhone(String raw) {
  var p = raw.replaceAll(RegExp(r'\D'), '');
  if (p.startsWith('0')) p = '62${p.substring(1)}';
  if (p.startsWith('8')) p = '62$p';
  if (p.startsWith('62')) return p;
  return p;
}

Future<void> callPhone(String phoneRaw) async {
  final p = normalizeIdPhone(phoneRaw);
  final uri = Uri.parse('tel:$p');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> openWhatsApp(String phoneRaw, {String text = ''}) async {
  final p = normalizeIdPhone(phoneRaw);
  final uri = Uri.parse('https://wa.me/$p?text=${Uri.encodeComponent(text)}');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
