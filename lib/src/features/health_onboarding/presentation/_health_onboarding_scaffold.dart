import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_primary_button.dart';

/// Shared scaffold for every health-onboarding step.
/// Shows: progress bar, step label, title, scrollable child, Next button.
class HealthOnboardingScaffold extends StatelessWidget {
  const HealthOnboardingScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.stepLabel,
    required this.child,
    this.onBack,
    this.onNext,
    this.nextLabel = 'Continue',
    this.nextIcon = Icons.arrow_forward_rounded,
    this.isLoading = false,
  });

  final String title;
  final String subtitle;
  final double progress;
  final String stepLabel;
  final Widget child;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final String nextLabel;
  final IconData nextIcon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back + step counter row
                  Row(
                    children: [
                      if (onBack != null)
                        GestureDetector(
                          onTap: onBack,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.inputBorder, width: 1.5),
                            ),
                            child: const Icon(Icons.arrow_back_rounded,
                                size: 20, color: AppColors.textPrimary),
                          ),
                        )
                      else
                        const SizedBox(width: 40),
                      const Spacer(),
                      Text(
                        stepLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: AppColors.inputBorder,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.btnDark),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // ── Scrollable content ─────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: child,
              ),
            ),

            // ── Bottom button ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: AppPrimaryButton(
                label: nextLabel,
                icon: nextIcon,
                isLoading: isLoading,
                onPressed: onNext,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A selectable option card used on activity/goal steps.
class HealthOptionCard extends StatelessWidget {
  const HealthOptionCard({
    super.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  final String label;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final activeColor = accent ?? AppColors.btnDark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? activeColor : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? activeColor : AppColors.inputBorder,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withAlpha(30)
                    : AppColors.accentGreenSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : AppColors.accentGreen,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: selected
                            ? Colors.white70
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}
