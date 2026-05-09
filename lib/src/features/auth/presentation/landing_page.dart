import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'register_step1_page.dart';
import 'sign_in_page.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background ─────────────────────────────────────────────────
          // Branded gradient hero background for the logged-out entry screen.
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF7A9B6E), // warm sage (gym plants / natural light)
                  Color(0xFF4E6B50),
                  Color(0xFF2B4030),
                  Color(0xFF131F17),
                ],
                stops: [0.0, 0.28, 0.55, 1.0],
              ),
            ),
          ),

          // Simulate some gym equipment silhouettes (geometric shapes)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.12,
            left: 20,
            right: 20,
            child: Opacity(
              opacity: 0.18,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _GymEquipmentSilhouette(
                    width: 40,
                    height: 120,
                    color: Colors.white,
                  ),
                  _GymEquipmentSilhouette(
                    width: 40,
                    height: 100,
                    color: Colors.white,
                  ),
                  _GymEquipmentSilhouette(
                    width: 30,
                    height: 140,
                    color: Colors.white,
                  ),
                  _GymEquipmentSilhouette(
                    width: 40,
                    height: 110,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),

          // ── Dark gradient overlay (for text readability) ────────────────
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Color(0x66000000),
                  Color(0xCC000000),
                  Color(0xF2000000),
                ],
                stops: [0.0, 0.35, 0.55, 0.75, 1.0],
              ),
            ),
          ),

          // ── Content ────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 4),

                  // Headline
                  Text(
                    'Unlock your\nFlexibility\nto choose',
                    style: GoogleFonts.poppins(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.12,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Sub-headline
                  Text(
                    'Discover and Start Now !',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white70,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const Spacer(),

                  // Register button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1A1A2E),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterStep1Page(),
                        ),
                      ),
                      child: const Text('Register'),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Sign-in link
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignInPage()),
                      ),
                      child: Text.rich(
                        TextSpan(
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.white54,
                          ),
                          children: [
                            const TextSpan(text: 'Already Have Account?  '),
                            TextSpan(
                              text: 'Sign In',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple geometric shape to simulate gym equipment in the hero background.
class _GymEquipmentSilhouette extends StatelessWidget {
  const _GymEquipmentSilhouette({
    required this.width,
    required this.height,
    required this.color,
  });
  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top handle bar
        Container(
          width: width * 2.4,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 4),
        // Column/upright
        Container(
          width: 8,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        // Base
        Container(
          width: width * 2,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}
