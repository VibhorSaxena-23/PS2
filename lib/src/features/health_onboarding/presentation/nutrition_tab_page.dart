import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/data/auth_service.dart';
import '../../profile/data/profile_api.dart';
import '../data/health_onboarding_api.dart';
import '../models/nutrition_plan.dart';
import 'health_onboarding_flow.dart';

/// Shown on the Nutrition tab.
/// • First time (onboarding not done) → full health wizard
/// • Subsequent visits → calorie/macro summary card + edit button
class NutritionTabPage extends StatefulWidget {
  const NutritionTabPage({super.key});

  @override
  State<NutritionTabPage> createState() => _NutritionTabPageState();
}

class _NutritionTabPageState extends State<NutritionTabPage> {
  bool _loading = true;
  bool _onboardingDone = false;
  SavedNutritionPlan? _plan;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final done = await AuthService.instance.isHealthOnboardingCompleted();
    if (!mounted) return;
    if (!done) {
      setState(() { _loading = false; _onboardingDone = false; });
      return;
    }
    // Try to load saved plan
    try {
      final client = ApiClient(
          baseUrl: AppConfig.apiBaseUrl, userId: AppConfig.userId);
      final raw = await client.get('/metrics/targets/latest');
      final plan = SavedNutritionPlan.fromJson(
          Map<String, dynamic>.from(raw as Map));
      if (!mounted) return;
      setState(() { _loading = false; _onboardingDone = true; _plan = plan; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _onboardingDone = true; });
    }
  }

  void _startWizard() {
    final mobileClient = ApiClient(
        baseUrl: AppConfig.apiBaseUrl, userId: AppConfig.userId);
    final webClient = ApiClient(
        baseUrl: AppConfig.webApiBaseUrl, userId: AppConfig.userId);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => HealthOnboardingFlow(
          api: HealthOnboardingApi(mobileClient),
          profileApi: ProfileApi(webClient),
          onCompleted: () {
            Navigator.of(context).pop();
            _check();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (!_onboardingDone) {
      return _WizardPrompt(onStart: _startWizard);
    }
    return _PlanSummary(plan: _plan, onEdit: _startWizard);
  }
}

// ── Wizard prompt (first visit) ───────────────────────────────────────────────

class _WizardPrompt extends StatelessWidget {
  const _WizardPrompt({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.accentGreenSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.restaurant_menu_rounded,
                    size: 40, color: AppColors.accentGreen),
              ),
              const SizedBox(height: 24),
              Text('Set Up Your Nutrition',
                  style: GoogleFonts.poppins(
                      fontSize: 24, fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                'Answer a few quick questions and we\'ll calculate your personalised daily calorie and macro targets.',
                style: GoogleFonts.poppins(
                    fontSize: 14, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text('Get Started',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Plan summary (after onboarding) ──────────────────────────────────────────

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.plan, required this.onEdit});
  final SavedNutritionPlan? plan;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text('Nutrition Goals',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        actions: [
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: Text('Edit', style: GoogleFonts.poppins(fontSize: 13)),
          ),
        ],
      ),
      body: plan == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('No plan saved yet.',
                      style: GoogleFonts.poppins(color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  OutlinedButton(
                      onPressed: onEdit, child: const Text('Set Up Now')),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Calorie hero card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.btnDark,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daily Target',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.white60,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${plan!.targetCaloriesKcal.round()}',
                              style: GoogleFonts.poppins(
                                  fontSize: 48, fontWeight: FontWeight.w900,
                                  color: Colors.white, height: 1)),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text('kcal / day',
                                style: GoogleFonts.poppins(
                                    fontSize: 14, color: Colors.white60)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Maintenance: ${plan!.maintenanceCaloriesKcal.round()} kcal  ·  BMI ${plan!.bmi.toStringAsFixed(1)} (${plan!.bmiCategory})',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Macro row
                Row(children: [
                  _MacroCard('Protein', '${plan!.macros.proteinG.round()}g',
                      const Color(0xFF0EA5E9)),
                  const SizedBox(width: 10),
                  _MacroCard('Carbs', '${plan!.macros.carbsG.round()}g',
                      const Color(0xFFF59E0B)),
                  const SizedBox(width: 10),
                  _MacroCard('Fat', '${plan!.macros.fatG.round()}g',
                      const Color(0xFFEC4899)),
                ]),
              ],
            ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  const _MacroCard(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(60), width: 1.2),
        ),
        child: Column(children: [
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }
}
