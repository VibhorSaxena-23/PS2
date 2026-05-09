import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/health_draft.dart';
import '../_health_onboarding_scaffold.dart';

class StepHealthConditions extends StatefulWidget {
  const StepHealthConditions({
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
  State<StepHealthConditions> createState() => _StepHealthConditionsState();
}

class _StepHealthConditionsState extends State<StepHealthConditions> {
  late final Set<String> _selected;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.draft.healthConditions);
    _notesCtrl = TextEditingController(text: widget.draft.healthNotes ?? '');
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  HealthDraft get _current => widget.draft.copyWith(
        healthConditions: _selected.toList(),
        healthNotes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

  void _toggle(String condition) {
    setState(() {
      if (_selected.contains(condition)) {
        _selected.remove(condition);
      } else {
        _selected.add(condition);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return HealthOnboardingScaffold(
      title: 'Health Conditions',
      subtitle: 'Step 4 of 6 — Optional, but helps us personalise your plan.',
      progress: widget.progress,
      stepLabel: '4 / 6',
      onBack: widget.onBack,
      onNext: () => widget.onNext(_current), // always valid — optional step
      nextLabel: _selected.isEmpty && _notesCtrl.text.trim().isEmpty
          ? 'Skip'
          : 'Continue',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Medical disclaimer
          _DisclaimerBanner(),
          const SizedBox(height: 16),

          // Preset chip grid
          Text(
            'Select any that apply',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kPresetConditions.map((c) {
              final sel = _selected.contains(c);
              return FilterChip(
                label: Text(
                  c,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: sel ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                selected: sel,
                onSelected: (_) => _toggle(c),
                backgroundColor: AppColors.white,
                selectedColor: AppColors.btnDark,
                checkmarkColor: Colors.white,
                side: BorderSide(
                  color: sel ? AppColors.btnDark : AppColors.inputBorder,
                  width: sel ? 2 : 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),

          // Free text notes
          Text(
            'Anything else? (optional)',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            maxLength: 300,
            decoration: InputDecoration(
              hintText:
                  'e.g. recovering from shoulder surgery, lactose intolerant…',
              hintStyle:
                  GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.white,
              contentPadding: const EdgeInsets.all(14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.inputBorder, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.btnDark, width: 2),
              ),
            ),
            style:
                GoogleFonts.poppins(fontSize: 13, color: AppColors.textPrimary),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DisclaimerBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBAE6FD), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined,
              color: Color(0xFF0369A1), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This information is used only to personalise your experience. '
              'We do not provide medical advice.',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                color: const Color(0xFF075985),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
