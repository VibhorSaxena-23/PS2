import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/health_draft.dart';
import '../_health_onboarding_scaffold.dart';

class StepWeeklyRate extends StatefulWidget {
  const StepWeeklyRate({
    super.key,
    required this.draft,
    required this.progress,
    required this.onNext,
    required this.onBack,
  });

  final HealthDraft draft;
  final double progress;
  final ValueChanged<HealthDraft> onNext;
  final VoidCallback onBack;

  @override
  State<StepWeeklyRate> createState() => _StepWeeklyRateState();
}

class _StepWeeklyRateState extends State<StepWeeklyRate> {
  double? _rate;

  @override
  void initState() {
    super.initState();
    if (widget.draft.goalType == GoalType.maintain) {
      _rate = kWeeklyRateMaintain;
    } else {
      _rate = widget.draft.weeklyRateKg;
    }
  }

  bool get _valid {
    if (widget.draft.goalType == GoalType.maintain) return true;
    return _rate != null;
  }

  HealthDraft get _current => widget.draft.copyWith(weeklyRateKg: _rate);

  @override
  Widget build(BuildContext context) {
    final isMaintain = widget.draft.goalType == GoalType.maintain;
    final isLose     = widget.draft.goalType == GoalType.loseWeight;

    if (isMaintain) {
      // Auto-advance — just show a confirmation card
      return HealthOnboardingScaffold(
        title: 'Maintain Weight',
        subtitle: 'Step 3 of 6 — You\'ll eat at your maintenance calories.',
        progress: widget.progress,
        stepLabel: '3 / 6',
        onBack: widget.onBack,
        onNext: () => widget.onNext(_current.copyWith(weeklyRateKg: kWeeklyRateMaintain)),
        child: _MaintainCard(),
      );
    }

    final rates = isLose ? kWeeklyRatesLose : kWeeklyRatesGain;
    final verb  = isLose ? 'Lose' : 'Gain';

    return HealthOnboardingScaffold(
      title: 'Weekly Target',
      subtitle: 'Step 3 of 6 — How fast do you want to $verb weight?',
      progress: widget.progress,
      stepLabel: '3 / 6',
      onBack: widget.onBack,
      onNext: _valid ? () => widget.onNext(_current) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Safety note
          _InfoBanner(isLose
              ? 'Sustainable loss: 0.25–0.5 kg/week is recommended for beginners.'
              : 'Sustainable gain: 0.25–0.5 kg/week minimises fat accumulation.'),
          const SizedBox(height: 16),

          ...rates.map((r) {
            // For gain, r is negative; display absolute value with +/- label
            final absRate = r.abs();
            final apiRate = isLose ? r : -r; // negative stored for gain
            final selected = _rate == apiRate;

            return _RateCard(
              rateAbs: absRate,
              verb: verb,
              selected: selected,
              onTap: () => setState(() => _rate = apiRate),
              isLose: isLose,
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _RateCard extends StatelessWidget {
  const _RateCard({
    required this.rateAbs,
    required this.verb,
    required this.selected,
    required this.onTap,
    required this.isLose,
  });

  final double rateAbs;
  final String verb;
  final bool selected;
  final VoidCallback onTap;
  final bool isLose;

  String get _intensity {
    if (rateAbs <= 0.25) return 'Gentle · low deficit';
    if (rateAbs <= 0.5)  return 'Moderate · recommended';
    return 'Aggressive · harder to sustain';
  }

  Color get _accentColor {
    if (rateAbs <= 0.25) return const Color(0xFF16A34A);
    if (rateAbs <= 0.5)  return const Color(0xFF0EA5E9);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.btnDark : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.btnDark : AppColors.inputBorder,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withAlpha(30)
                    : _accentColor.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '${rateAbs.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')} kg',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : _accentColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$verb $rateAbs kg / week',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _intensity,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: selected ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
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

class _MaintainCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.accentGreenSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentGreen, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.balance_rounded,
              color: AppColors.accentGreen, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'We\'ll set your calories to match your daily maintenance needs — no deficit, no surplus.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF065F46),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFFEA580C), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF9A3412),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
