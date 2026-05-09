import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../dashboard/data/dashboard_api.dart';
import '../../gym/data/gym_api.dart';
import '../../hydration/data/hydration_api.dart';
import '../../profile/data/profile_api.dart';
import '../../workout/data/workout_api.dart';

// Entry point after successful auth — navigates into the real app shell.
class GetStartedPage extends StatelessWidget {
  const GetStartedPage({super.key});

  static const _features = [
    _Feature(
      icon: Icons.explore_outlined,
      title: 'Discover Gyms',
      subtitle: 'Find fitness partners in your area',
    ),
    _Feature(
      icon: Icons.bolt_outlined,
      title: 'Track Progress',
      subtitle: 'Monitor your fitness journey',
    ),
    _Feature(
      icon: Icons.card_membership_outlined,
      title: 'Flexible Passes',
      subtitle: 'Personalised plans set for you',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBgMint,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),

              // ── Heading ───────────────────────────────────────────────────
              Text(
                'Get Started With',
                style: GoogleFonts.poppins(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Everything you need for Fitness',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 40),

              // ── Feature list ──────────────────────────────────────────────
              ..._features.map((f) => _FeatureRow(feature: f)),

              const Spacer(flex: 3),

              // ── Get Started button ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.btnDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () {
                    final mobileClient = ApiClient(
                      baseUrl: AppConfig.apiBaseUrl,
                      userId: AppConfig.userId,
                    );
                    final webClient = ApiClient(
                      baseUrl: AppConfig.webApiBaseUrl,
                      userId: AppConfig.userId,
                    );
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => HomePage(
                          gymApi: GymApi(webClient),
                          profileApi: ProfileApi(webClient),
                          dashboardApi: DashboardApi(mobileClient),
                          workoutApi: WorkoutApi(mobileClient),
                          hydrationApi: HydrationApi(mobileClient),
                        ),
                      ),
                      (route) => false,
                    );
                  },
                  child: const Text('Get Started'),
                ),
              ),
              const SizedBox(height: 16),

              // ── Terms / skip ──────────────────────────────────────────────
              Center(
                child: Text.rich(
                  TextSpan(
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                    children: [
                      const TextSpan(text: 'By signing in, you agree to our '),
                      TextSpan(
                        text: 'Terms',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Feature row ───────────────────────────────────────────────────────────────

class _Feature {
  const _Feature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature});
  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.047),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(feature.icon, size: 26, color: AppColors.accent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  feature.subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
