import 'package:flutter/material.dart';

const kAppName = 'Generasi Emas';
const kPrimary = Color(0xFF00A67E);
const kWarning = Color(0xFFFFB300);
const kDanger  = Color(0xFFE53935);
const kGrey    = Color(0xFF9E9E9E);

const kStartGateHours = 96;
const kOtpResendCooldown = 60;
const kConsentLastUpdated = '2025-08-01';

// === Brainstorm ===
const List<String> kBrainModuleTitleKeys = ['brainstorm', 'orientasi ruangan'];

const String kBrainVideoUrl = '';

const String kBrainTextVisitDaily = '''
Kunjungan harian orang tua berpengaruh pada kestabilan kondisi bayi, keberhasilan menyusui, serta bonding.
''';
const String kBrainTextParentsRole = '''
Peran orang tua di ruang perawatan neonatus: KMC (bila direkomendasikan), dukungan ASI/perah, tindakan sederhana 
(dengan arahan perawat), komunikasi aktif, dan kepatuhan protokol kebersihan.
''';

// ========== Fallback VIDEO (Modul 1 & 4) ==========
const kVideoOrientasiUrl     = '';
const kVideoAsiUrl           = '';
const kVideoMenyusuiUrl      = '';
const kVideoKmcUrl           = '';
const kVideoMemandikanUrl    = '';
const kVideoPijatOksitosinUrl= '';
const kVideoStimulasiUrl     = '';

// ========== Fallback FLIP/PDF (Modul 2) ==========
const kFlipAsiUrl            = '';
const kFlipMenyusuiUrl       = '';
const kFlipKmcUrl            = '';
const kFlipMemandikanUrl     = '';
const kFlipPijatOksitosinUrl = '';
const kFlipStimulasiUrl      = '';

// ========== Dukungan emosional (Modul 3) ==========
const kGroupWaIbuUrl         = '';
const kCopingInfoUrl         = '';

// ========== API Environment ==========
const String kApiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://10.0.2.2:4000', // Ganti dengan link Vercel Anda
);