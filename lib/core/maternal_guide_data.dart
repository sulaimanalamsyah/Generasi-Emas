import '../core/storage.dart';
import '../services/api_client.dart';

/// Offline clinical fallback for "Jadwal Harian Kegiatan Partisipasi Ibu di Ruang Neonatal".
const List<Map<String, dynamic>> kDefaultMaternalGuideSlots = [
  {
    'id': 'slot_06_07',
    'phase': 'Pagi',
    'timeRange': '06.00–07.00',
    'startMinutes': 360,
    'endMinutes': 420,
    'title': 'Persiapan dan Pemerahan ASI',
    'action': 'Ibu menjaga kebersihan diri, mencuci tangan, memerah ASI sesuai kebutuhan, dan mempersiapkan kunjungan ke NICU.',
  },
  {
    'id': 'slot_07_08',
    'phase': 'Pagi',
    'timeRange': '07.00–08.00',
    'startMinutes': 420,
    'endMinutes': 480,
    'title': 'Kehadiran dan Orientasi Kondisi Bayi',
    'action': 'Ibu hadir sesuai kesepakatan, melakukan kebersihan tangan, mengamati kondisi bayi, dan meminta informasi perkembangan bayi.',
  },
  {
    'id': 'slot_08_09',
    'phase': 'Pagi',
    'timeRange': '08.00–09.00',
    'startMinutes': 480,
    'endMinutes': 540,
    'title': 'Partisipasi Perawatan Harian',
    'action': 'Ibu membantu mengganti popok, membersihkan bayi, mengganti pakaian, mengamati BAK/BAB, dan mengukur suhu bila diizinkan serta didampingi perawat.',
  },
  {
    'id': 'slot_09_10',
    'phase': 'Pagi',
    'timeRange': '09.00–10.00',
    'startMinutes': 540,
    'endMinutes': 600,
    'title': 'Pemberian Nutrisi',
    'action': 'Ibu menyusui langsung atau memberikan ASI perah dengan metode yang ditetapkan tim klinis; mencatat jumlah asupan bersama perawat.',
  },
  {
    'id': 'slot_10_11',
    'phase': 'Pagi',
    'timeRange': '10.00–11.00',
    'startMinutes': 600,
    'endMinutes': 660,
    'title': 'Komunikasi dengan Tim Kesehatan',
    'action': 'Ibu mengikuti kunjungan dokter jika memungkinkan, menanyakan kondisi klinis, berat badan, rencana perawatan, dan menyampaikan pengamatan.',
  },
  {
    'id': 'slot_11_12',
    'phase': 'Pagi',
    'timeRange': '11.00–12.00',
    'startMinutes': 660,
    'endMinutes': 720,
    'title': 'Kedekatan dan Kenyamanan (PMK)',
    'action': 'Ibu melakukan sentuhan lembut, berbicara kepada bayi, atau Perawatan Metode Kanguru (PMK) bila kondisi bayi memungkinkan dan disetujui perawat.',
  },
  {
    'id': 'slot_12_13',
    'phase': 'Siang',
    'timeRange': '12.00–13.00',
    'startMinutes': 720,
    'endMinutes': 780,
    'title': 'Istirahat Ibu',
    'action': 'Ibu makan, beribadah, beristirahat, dan memerah ASI sesuai kebutuhan.',
  },
  {
    'id': 'slot_13_14',
    'phase': 'Siang',
    'timeRange': '13.00–14.00',
    'startMinutes': 780,
    'endMinutes': 840,
    'title': 'Pembelajaran ENI CARE',
    'action': 'Ibu membaca modul, menonton video, dan mengerjakan kuis sesuai materi yang dipelajari.',
  },
  {
    'id': 'slot_14_15',
    'phase': 'Siang',
    'timeRange': '14.00–15.00',
    'startMinutes': 840,
    'endMinutes': 900,
    'title': 'Edukasi dan Praktik Keterampilan',
    'action': 'Ibu berdiskusi dengan perawat, mencoba keterampilan yang aman dan sesuai kondisi bayi, serta menerima umpan balik.',
  },
  {
    'id': 'slot_15_16',
    'phase': 'Sore',
    'timeRange': '15.00–16.00',
    'startMinutes': 900,
    'endMinutes': 960,
    'title': 'Partisipasi Lanjutan',
    'action': 'Ibu membantu pemberian ASI, mengganti popok, memberikan kenyamanan, atau PMK bila memenuhi kriteria klinis.',
  },
  {
    'id': 'slot_16_17',
    'phase': 'Sore',
    'timeRange': '16.00–17.00',
    'startMinutes': 960,
    'endMinutes': 1020,
    'title': 'Pencatatan dan Evaluasi',
    'action': 'Ibu mengisi Logbook ENI CARE (kehadiran, durasi, target, catatan) dan Jurnal Bayi (ringkasan kondisi/perkembangan).',
  },
  {
    'id': 'slot_17_18',
    'phase': 'Sore',
    'timeRange': '17.00–18.00',
    'startMinutes': 1020,
    'endMinutes': 1080,
    'title': 'Persiapan Meninggalkan NICU',
    'action': 'Ibu mengajukan pertanyaan, menyepakati target partisipasi berikutnya dengan perawat, dan menyiapkan kebutuhan ASI.',
  },
  {
    'id': 'slot_18_21',
    'phase': 'Malam',
    'timeRange': '18.00–21.00',
    'startMinutes': 1080,
    'endMinutes': 1260,
    'title': 'Aktivitas di Luar NICU',
    'action': 'Ibu beristirahat, makan, berkomunikasi dengan keluarga, memerah ASI sesuai kebutuhan, dan dapat mempelajari ulang ENI CARE.',
  },
  {
    'id': 'slot_21_06',
    'phase': 'Malam',
    'timeRange': '21.00–06.00',
    'startMinutes': 1260,
    'endMinutes': 360,
    'title': 'Istirahat Malam dan Laktasi',
    'action': 'Ibu tidur serta memerah ASI sesuai kebutuhan; tim NICU melanjutkan perawatan bayi menurut jadwal klinis.',
  },
];

/// Determines which NICU maternal slot matches current WIB (UTC+7) clock time.
Map<String, dynamic>? activeMaternalGuideSlot(List<Map<String, dynamic>> slots, [DateTime? now]) {
  final wibNow = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7));
  final mins = wibNow.hour * 60 + wibNow.minute;
  for (final slot in slots) {
    final s = (slot['startMinutes'] as num?)?.toInt();
    final e = (slot['endMinutes'] as num?)?.toInt();
    if (s == null || e == null) continue;
    if (s < e) {
      if (mins >= s && mins < e) return slot;
    } else {
      // Overnight interval such as 21.00–06.00
      if (mins >= s || mins < e) return slot;
    }
  }
  return slots.isNotEmpty ? slots.first : null;
}

/// Loads NICU guide from API with automatic local cache + bundled clinical fallback.
Future<List<Map<String, dynamic>>> fetchMaternalGuideWithFallback() async {
  try {
    final remote = await ApiClient().getMaternalGuide();
    if (remote.isNotEmpty) {
      await Prefs.setCachedJson('maternal_guide', remote);
      return remote;
    }
  } catch (_) {}

  final cached = await Prefs.getCachedJson('maternal_guide');
  if (cached is List && cached.isNotEmpty) {
    return cached.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  return kDefaultMaternalGuideSlots;
}
