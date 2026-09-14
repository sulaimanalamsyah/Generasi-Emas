import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/storage.dart';
import '../routes.dart';
import '../widgets/common.dart';

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  @override
  void initState() {
    super.initState();
    // Preserved existing logic
    Prefs.setLastStartSeenNow();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0F0F172A),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Centralized Responsive Logo
                      const AppLogo(size: 110),
                      const SizedBox(height: 12),

                      // Tagline / Subtitle directly below Logo explaining "ENI Care"
                      const Text(
                        'Empowering Neonatal Integrated Care',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                          letterSpacing: 0.2,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Main Greeting Headline
                      const Text(
                        'Selamat Datang',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Primary Button: Masuk
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pushNamed(context, Routes.login),
                          child: const Text(
                            'Masuk',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Secondary Button: Registrasi
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                            side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pushNamed(context, Routes.register),
                          child: const Text(
                            'Registrasi',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Guest Link / Button
                      TextButton(
                        onPressed: null, // Disabled guest login preserving logic
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          minimumSize: const Size(48, 48),
                        ),
                        child: const Text(
                          'Masuk sebagai tamu',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 12),

                      // Legal Links with guaranteed min 48x48dp touch targets (wrapped for small screens)
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pushNamed(context, Routes.consent),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              minimumSize: const Size(48, 48),
                            ),
                            child: const Text(
                              'Informed Consent',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0EA5E9),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const Text(
                            ' • ',
                            style: TextStyle(color: Color(0xFF94A3B8)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pushNamed(context, Routes.privacyPolicy),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              minimumSize: const Size(48, 48),
                            ),
                            child: const Text(
                              'Privacy Policy',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0EA5E9),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}