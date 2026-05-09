import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/landing_page.dart';
import '../../../app.dart' show AppHomeEntry;

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}
class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();

    _timer = Timer(const Duration(milliseconds: 2000), _proceed);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    if (!mounted) return;
    final loggedIn = await AuthService.instance.isLoggedIn();
    if (!mounted) return;

    if (loggedIn) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (ctx, a, b) => const AppHomeEntry(),
          transitionsBuilder: (ctx, animation, b, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (ctx, a, b) => const LandingPage(),
          transitionsBuilder: (ctx, animation, b, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131F17),
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.btnDark,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.btnDark.withAlpha(60),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.fitness_center_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'FlexiCurl',
                style: GoogleFonts.poppins(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Find Flexicurl Nearby!',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.white60,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
