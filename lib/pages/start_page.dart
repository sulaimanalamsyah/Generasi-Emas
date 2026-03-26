import 'package:flutter/material.dart';
import '../core/storage.dart';
import '../routes.dart';
import '../widgets/common.dart'; // Menggunakan AppLogo dari sini

class StartPage extends StatefulWidget {
  const StartPage({super.key});
  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  @override
  void initState() {
    super.initState();
    // [LOGIC LAMA] Tetap dipertahankan
    Prefs.setLastStartSeenNow();
  }

  @override
  Widget build(BuildContext context) {
    // Ukuran layar untuk responsivitas
    final size = MediaQuery.of(context).size;

    return Scaffold(
      // [UI FIGMA] Background utama (Hijau)
      backgroundColor: const Color(0xFF14AE5C),
      body: Stack(
        children: [
          // 1. BACKGROUND GRADIENT CARD (Layer Bawah)
          // Ini adalah kotak abu-abu/hijau melengkung di bagian bawah desain Figma
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: 250, // Mulai dari agak ke bawah
            child: Container(
              decoration: const ShapeDecoration(
                gradient: LinearGradient(
                  begin: Alignment(0.50, -0.00),
                  end: Alignment(0.50, 1.00),
                  colors: [Color(0xFFDADADA), Color(0x9914AE5C)],
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(35),
                    topRight: Radius.circular(35),
                  ),
                ),
              ),
            ),
          ),

          // 2. CONTENT (Layer Atas)
          // Menggunakan SingleChildScrollView agar tidak overflow di layar kecil
          SingleChildScrollView(
            child: SizedBox(
              width: size.width,
              // Tinggi minimum setidaknya setinggi layar
              height: size.height > 800 ? size.height : 800,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),

                  // [UI FIGMA] Logo Area
                  // Menggabungkan desain kotak Figma dengan Widget AppLogo Anda
                  Container(
                    width: 200,
                    height: 200,
                    decoration: const BoxDecoration(
                      // Placeholder background jika transparan
                      // color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const AppLogo(size: 180), // Menggunakan widget logo asli
                  ),

                  const SizedBox(height: 24),

                  // [UI FIGMA] Text Judul
                  const Text(
                    'Selamat Datang \nDi Generasi Emas',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black, // Sesuai Figma (di atas background hijau mungkin perlu putih, tapi saya ikut Figma: Hitam)
                      fontSize: 30,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                    ),
                  ),

                  const SizedBox(height: 40), // Spasi sebelum tombol

                  // [UI FIGMA] Tombol-tombol
                  // 1. Masuk (Login)
                  _FigmaButton(
                    text: 'Masuk (Login)',
                    color: Colors.white,
                    textColor: Colors.black,
                    onTap: () => Navigator.pushNamed(context, Routes.login),
                  ),

                  const SizedBox(height: 24),

                  // 2. Registrasi
                  _FigmaButton(
                    text: 'Registrasi',
                    color: Colors.white,
                    textColor: Colors.black,
                    onTap: () => Navigator.pushNamed(context, Routes.register),
                  ),

                  const SizedBox(height: 24),

                  // 3. Masuk Sebagai Tamu
                  const _FigmaButton(
                    text: 'Masuk Sebagai Tamu (Nonaktif)',
                    color: Color(0xFF91908F), // Warna abu-abu sesuai Figma
                    textColor: Colors.white,  // Teks putih agar kontras
                    onTap: null, // Disabled
                  ),

                  const SizedBox(height: 30),
                  // const Spacer(), // Dorong link ke bawah

                  // [UI FIGMA] Links di bawah
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, Routes.consent),
                    child: const Text(
                      'Informed Consent',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.underline,
                        letterSpacing: -0.33,
                      ),
                    ),
                  ),

                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, Routes.privacyPolicy),
                    child: const Text(
                      'Privacy Policy',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.underline,
                        letterSpacing: -0.33,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// [HELPER WIDGET] Untuk membuat tombol sesuai gaya Figma
class _FigmaButton extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;
  final VoidCallback? onTap;

  const _FigmaButton({
    required this.text,
    required this.color,
    required this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Lebar tombol 274 sesuai Figma, tapi kita batasi max-width agar responsif
    return Container(
      width: 350,
      height: 50, // Sedikit lebih tinggi dari 31 agar area sentuh jari nyaman
      decoration: ShapeDecoration(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        shadows: const [
          BoxShadow(
            color: Color(0x3F000000),
            blurRadius: 4,
            offset: Offset(0, 4),
            spreadRadius: 0,
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800, // Sedikit dipertebal agar terbaca
                letterSpacing: -0.33,
              ),
            ),
          ),
        ),
      ),
    );
  }
}