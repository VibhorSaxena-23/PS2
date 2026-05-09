import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/health_draft.dart';
import '../_health_onboarding_scaffold.dart';

class StepBodyBasics extends StatefulWidget {
  const StepBodyBasics({
    super.key,
    required this.draft,
    required this.progress,
    required this.onNext,
    this.onBack,
  });

  final HealthDraft draft;
  final double progress;
  final ValueChanged<HealthDraft> onNext;
  final VoidCallback? onBack;

  @override
  State<StepBodyBasics> createState() => _StepBodyBasicsState();
}

class _StepBodyBasicsState extends State<StepBodyBasics> {
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _ageCtrl;
  BiologicalSex? _sex;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _heightCtrl = TextEditingController(
        text: d.heightCm != null ? d.heightCm!.toStringAsFixed(1) : '');
    _weightCtrl = TextEditingController(
        text: d.weightKg != null ? d.weightKg!.toStringAsFixed(1) : '');
    _ageCtrl =
        TextEditingController(text: d.age != null ? d.age.toString() : '');
    _sex = d.sex;
  }

  @override
  void dispose() {
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  HealthDraft get _current => widget.draft.copyWith(
        heightCm: double.tryParse(_heightCtrl.text),
        weightKg: double.tryParse(_weightCtrl.text),
        age: int.tryParse(_ageCtrl.text),
        sex: _sex,
      );

  bool get _valid => _current.isBodyValid;

  String? _heightError() {
    final v = double.tryParse(_heightCtrl.text);
    if (_heightCtrl.text.isEmpty) return null;
    if (v == null || v < 100 || v > 250) return '100–250 cm';
    return null;
  }

  String? _weightError() {
    final v = double.tryParse(_weightCtrl.text);
    if (_weightCtrl.text.isEmpty) return null;
    if (v == null || v < 25 || v > 300) return '25–300 kg';
    return null;
  }

  String? _ageError() {
    final v = int.tryParse(_ageCtrl.text);
    if (_ageCtrl.text.isEmpty) return null;
    if (v == null || v < 13 || v > 100) return '13–100 years';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return HealthOnboardingScaffold(
      title: 'Your Body',
      subtitle: 'Step 1 of 6 — We use this to personalise your calorie targets.',
      progress: widget.progress,
      stepLabel: '1 / 6',
      onBack: widget.onBack,
      onNext: _valid ? () => widget.onNext(_current) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Sex selector ──────────────────────────────────────────────────
          _SectionLabel('Biological Sex'),
          const SizedBox(height: 8),
          Row(
            children: BiologicalSex.values.map((s) {
              final selected = _sex == s;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _SexCard(
                    label: s.label,
                    icon: s == BiologicalSex.male
                        ? Icons.male_rounded
                        : Icons.female_rounded,
                    selected: selected,
                    onTap: () => setState(() => _sex = s),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),

          // ── Age ───────────────────────────────────────────────────────────
          _SectionLabel('Age'),
          const SizedBox(height: 8),
          _NumberField(
            controller: _ageCtrl,
            hint: 'e.g. 25',
            suffix: 'yrs',
            decimal: false,
            error: _ageError(),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 22),

          // ── Height / Weight ───────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel('Height'),
                    const SizedBox(height: 8),
                    _NumberField(
                      controller: _heightCtrl,
                      hint: 'e.g. 170',
                      suffix: 'cm',
                      error: _heightError(),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel('Weight'),
                    const SizedBox(height: 8),
                    _NumberField(
                      controller: _weightCtrl,
                      hint: 'e.g. 70',
                      suffix: 'kg',
                      error: _weightError(),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Tip
          Text(
            'Height and weight determine your BMI and base metabolic rate.',
            style: GoogleFonts.poppins(
                fontSize: 11.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Local widgets ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.3,
        ),
      );
}

class _SexCard extends StatelessWidget {
  const _SexCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 72,
        decoration: BoxDecoration(
          color: selected ? AppColors.btnDark : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.btnDark : AppColors.inputBorder,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: selected ? Colors.white : AppColors.textSecondary,
                size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.hint,
    required this.suffix,
    required this.onChanged,
    this.decimal = true,
    this.error,
  });
  final TextEditingController controller;
  final String hint;
  final String suffix;
  final bool decimal;
  final String? error;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType:
          decimal ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(
            decimal ? RegExp(r'[\d.]') : RegExp(r'\d')),
      ],
      decoration: InputDecoration(
        hintText: hint,
        suffixText: suffix,
        errorText: error,
        hintStyle:
            GoogleFonts.poppins(fontSize: 14, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.inputBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.btnDark, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
      ),
      style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary),
    );
  }
}
