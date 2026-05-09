import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/health_onboarding_api.dart';
import '../../models/health_draft.dart';
import '../../models/nutrition_plan.dart';
import '../_health_onboarding_scaffold.dart';
import '../../../../features/auth/data/auth_service.dart';

class StepNutritionSummary extends StatefulWidget {
  const StepNutritionSummary({
    super.key,
    required this.draft,
    required this.plan,
    required this.api,
    required this.progress,
    required this.onBack,
    required this.onCompleted,
  });

  final HealthDraft draft;
  final NutritionPlan plan;
  final HealthOnboardingApi api;
  final double progress;
  final VoidCallback onBack;
  final VoidCallback onCompleted;

  @override
  State<StepNutritionSummary> createState() => _StepNutritionSummaryState();
}

class _StepNutritionSummaryState extends State<StepNutritionSummary> {
  bool _saving = false;
  String? _error;

  CalorieGoalOption? get _selected => widget.plan.selectedGoal;

  Future<void> _confirm() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // Primary success criteria: nutrition targets must persist.
      await widget.api.saveTargets(widget.draft);
    } catch (error, stackTrace) {
      dev.log(
        '[StepNutritionSummary] Failed to save nutrition targets '
        '(POST /metrics/targets/save): $error',
        name: 'health_onboarding',
        stackTrace: stackTrace,
      );
      debugPrint(
        '[StepNutritionSummary] saveTargets failed '
        '(POST /metrics/targets/save): $error',
      );

      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save your plan. Please try again.';
      });
      return;
    }

    try {
      // Non-blocking best-effort sync to persist onboarding profile snapshot.
      await widget.api.saveProfile(widget.draft);
    } catch (error, stackTrace) {
      dev.log(
        '[StepNutritionSummary] Onboarding profile sync failed '
        '(POST /metrics): $error',
        name: 'health_onboarding',
        stackTrace: stackTrace,
      );
      debugPrint(
        '[StepNutritionSummary] Non-blocking saveProfile failure '
        '(POST /metrics): $error',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Saved your nutrition plan. Profile snapshot sync will retry later.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    try {
      await AuthService.instance.markHealthOnboardingCompleted().timeout(
        const Duration(seconds: 2),
      );
    } catch (error, stackTrace) {
      dev.log(
        '[StepNutritionSummary] Could not persist local onboarding completion '
        'flag (non-blocking): $error',
        name: 'health_onboarding',
        stackTrace: stackTrace,
      );
      debugPrint(
        '[StepNutritionSummary] Non-blocking completion marker failure: $error',
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final goal = _selected;

    return HealthOnboardingScaffold(
      title: 'Your Plan',
      subtitle: 'Step 6 of 6 — Review your personalised targets.',
      progress: widget.progress,
      stepLabel: '6 / 6',
      onBack: widget.onBack,
      onNext: _saving ? null : _confirm,
      isLoading: _saving,
      nextLabel: 'Save & Start',
      nextIcon: Icons.check_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Error banner
          if (_error != null) ...[
            _ErrorBanner(_error!),
            const SizedBox(height: 14),
          ],

          // ── BMI card ────────────────────────────────────────────────────
          _SummaryCard(
            header: 'Body Assessment',
            children: [
              _StatRow(
                'BMI',
                plan.bmi.toStringAsFixed(1),
                sub: plan.bmiCategory,
              ),
              _StatRow(
                'BMR',
                '${plan.bmrKcal.round()} kcal/day',
                sub: 'calories burned at rest',
              ),
              _StatRow(
                'Maintenance',
                '${plan.maintenanceCaloriesKcal.round()} kcal/day',
                sub: 'with your activity level',
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Calorie target card ─────────────────────────────────────────
          if (goal != null) _CalorieTargetCard(goal: goal, draft: widget.draft),

          // ── Macro targets ───────────────────────────────────────────────
          if (goal != null) ...[
            const SizedBox(height: 14),
            _MacroCard(macros: goal.macros),
          ],

          const SizedBox(height: 14),

          // Weekly projection
          if (goal != null) _ProjectionCard(goal: goal),

          const SizedBox(height: 8),
          Text(
            'Your targets will be saved and used to track daily nutrition progress.',
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.header, required this.children});
  final String header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            header,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value, {this.sub});
  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub!,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalorieTargetCard extends StatelessWidget {
  const _CalorieTargetCard({required this.goal, required this.draft});
  final CalorieGoalOption goal;
  final HealthDraft draft;

  @override
  Widget build(BuildContext context) {
    final isSurplus = goal.dailyDeficitKcal < 0;
    final absAdj = goal.dailyDeficitKcal.abs().round();
    final adjLabel = isSurplus
        ? '+$absAdj kcal surplus'
        : '-$absAdj kcal deficit';
    final adjColor = isSurplus
        ? const Color(0xFF16A34A)
        : const Color(0xFF0EA5E9);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.btnDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Calorie Target',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                goal.targetCaloriesKcal.round().toString(),
                style: GoogleFonts.poppins(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'kcal / day',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white60,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: adjColor.withAlpha(40),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              adjLabel,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: adjColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  const _MacroCard({required this.macros});
  final MacroTargets macros;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Macros',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MacroTile(
                  'Protein',
                  '${macros.proteinG.round()}g',
                  const Color(0xFF0EA5E9),
                ),
              ),
              Expanded(
                child: _MacroTile(
                  'Carbs',
                  '${macros.carbsG.round()}g',
                  const Color(0xFFF59E0B),
                ),
              ),
              Expanded(
                child: _MacroTile(
                  'Fat',
                  '${macros.fatG.round()}g',
                  const Color(0xFFEC4899),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroTile extends StatelessWidget {
  const _MacroTile(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ProjectionCard extends StatelessWidget {
  const _ProjectionCard({required this.goal});
  final CalorieGoalOption goal;

  @override
  Widget build(BuildContext context) {
    final rate = goal.rateKgPerWeek;
    final String message;
    final Color color;
    final IconData icon;

    if (rate > 0) {
      message =
          'At this rate you could lose ~${rate.toStringAsFixed(2)} kg/week.';
      color = const Color(0xFF0EA5E9);
      icon = Icons.trending_down_rounded;
    } else if (rate < 0) {
      message =
          'At this rate you could gain ~${rate.abs().toStringAsFixed(2)} kg/week.';
      color = const Color(0xFF16A34A);
      icon = Icons.trending_up_rounded;
    } else {
      message = 'You\'ll maintain your current weight.';
      color = AppColors.accentGreen;
      icon = Icons.balance_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(60), width: 1.2),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: AppColors.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
