import 'dart:math' show pi, min;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../nutrition/data/nutrition_api.dart';
import '../../nutrition/models/nutrition_models.dart';

class CaloriesDetailPage extends StatefulWidget {
  const CaloriesDetailPage({super.key, this.nutritionApi});

  final NutritionApi? nutritionApi;

  @override
  State<CaloriesDetailPage> createState() => _CaloriesDetailPageState();
}

class _CaloriesDetailPageState extends State<CaloriesDetailPage> {
  DailyNutritionSummary? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = widget.nutritionApi;
    if (api == null) {
      setState(() {
        _loading = false;
        _error = 'Nutrition API is not configured.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final summary = await api.getDailySummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFFEA580C),
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text('Calories',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, color: Colors.white)),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _summary == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 44, color: AppColors.error),
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.btnDark,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _buildContent(),
                ),
    );
  }

  Widget _buildContent() {
    final summary = _summary;
    final consumed = summary?.total.calories.round() ?? 0;
    final goal = summary?.goalProgress;
    final target = goal?.caloriesTarget?.round() ?? 2200;
    final remaining = target - consumed;
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;

    final proteinG = summary?.total.proteinG ?? 0;
    final carbsG = summary?.total.carbsG ?? 0;
    final fatG = summary?.total.fatG ?? 0;

    final proteinTarget = goal?.proteinTargetG?.round() ?? 160;
    final carbsTarget = goal?.carbsTargetG?.round() ?? 260;
    final fatTarget = goal?.fatTargetG?.round() ?? 80;

    // Build meal breakdown from summary
    final meals = <_MealData>[];
    for (final group in summary?.meals ?? <MealGroup>[]) {
      final meta = _mealMeta[group.mealType];
      if (meta != null) {
        meals.add(_MealData(
          meta.name,
          group.subtotal.calories.round(),
          meta.icon,
          meta.color,
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Ring card
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFEA580C), Color(0xFFF59E0B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(160, 160),
                      painter: _RingPainter(progress: progress),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$consumed',
                          style: GoogleFonts.poppins(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.0),
                        ),
                        Text('kcal eaten',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white.withAlpha(200))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _RingStat(label: 'Goal', value: '$target kcal'),
                  Container(
                      width: 1,
                      height: 30,
                      color: Colors.white.withAlpha(60)),
                  _RingStat(
                      label: remaining >= 0 ? 'Remaining' : 'Over',
                      value: '${remaining.abs()} kcal'),
                  Container(
                      width: 1,
                      height: 30,
                      color: Colors.white.withAlpha(60)),
                  _RingStat(
                      label: 'Meals',
                      value: '${summary?.meals.length ?? 0}'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Macros
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 10,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Macronutrients',
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              _MacroBar(
                  label: 'Carbs',
                  grams: carbsG.round(),
                  goalG: carbsTarget,
                  color: const Color(0xFFF59E0B)),
              const SizedBox(height: 12),
              _MacroBar(
                  label: 'Protein',
                  grams: proteinG.round(),
                  goalG: proteinTarget,
                  color: const Color(0xFF4F46E5)),
              const SizedBox(height: 12),
              _MacroBar(
                  label: 'Fat',
                  grams: fatG.round(),
                  goalG: fatTarget,
                  color: const Color(0xFFEA580C)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Meal breakdown
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 10,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Meal Breakdown',
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 14),
              if (meals.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No meals logged today.',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.textMuted),
                  ),
                )
              else
                ...meals.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: m.color.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(m.icon, size: 20, color: m.color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(m.name,
                                        style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary)),
                                  ),
                                  Text('${m.kcal} kcal',
                                      style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: m.color)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: consumed > 0
                                      ? (m.kcal / consumed).clamp(0.0, 1.0)
                                      : 0,
                                  backgroundColor: AppColors.divider,
                                  valueColor:
                                      AlwaysStoppedAnimation(m.color),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Meal metadata ────────────────────────────────────────────────────────────

class _MealMetaInfo {
  const _MealMetaInfo(this.name, this.icon, this.color);
  final String name;
  final IconData icon;
  final Color color;
}

const _mealMeta = <String, _MealMetaInfo>{
  'breakfast': _MealMetaInfo(
      'Breakfast', Icons.free_breakfast_rounded, Color(0xFFF59E0B)),
  'lunch':
      _MealMetaInfo('Lunch', Icons.lunch_dining_rounded, Color(0xFF0891B2)),
  'dinner':
      _MealMetaInfo('Dinner', Icons.dinner_dining_rounded, Color(0xFF7C3AED)),
  'snack': _MealMetaInfo('Snacks', Icons.cookie_rounded, Color(0xFF059669)),
  'pre_workout':
      _MealMetaInfo('Pre-Workout', Icons.bolt_rounded, Color(0xFF3B82F6)),
  'post_workout': _MealMetaInfo(
      'Post-Workout', Icons.sports_score_rounded, Color(0xFFEC4899)),
};

class _MealData {
  const _MealData(this.name, this.kcal, this.icon, this.color);
  final String name;
  final int kcal;
  final IconData icon;
  final Color color;
}

// ── Ring stat ────────────────────────────────────────────────────────────────

class _RingStat extends StatelessWidget {
  const _RingStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 11, color: Colors.white.withAlpha(180))),
      ],
    );
  }
}

// ── Macro bar ────────────────────────────────────────────────────────────────

class _MacroBar extends StatelessWidget {
  const _MacroBar({
    required this.label,
    required this.grams,
    required this.goalG,
    required this.color,
  });
  final String label;
  final int grams;
  final int goalG;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = goalG > 0 ? (grams / goalG).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const Spacer(),
            Text('${grams}g / ${goalG}g',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 10,
          ),
        ),
      ],
    );
  }
}

// ── Ring painter ─────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = min(size.width, size.height) / 2 - 10;
    const start = -pi / 2;

    canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = Colors.white.withAlpha(40)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      start,
      2 * pi * progress,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}
