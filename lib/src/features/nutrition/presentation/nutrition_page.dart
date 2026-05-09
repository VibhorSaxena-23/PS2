import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../health_onboarding/data/health_onboarding_api.dart';
import '../../health_onboarding/presentation/health_onboarding_flow.dart';
import '../../profile/data/profile_api.dart';
import '../data/nutrition_api.dart';
import '../data/nutrition_events.dart';
import '../models/nutrition_models.dart';

// ── Meal type helpers ────────────────────────────────────────────────────────

const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

const _mealMeta = <String, _MealMeta>{
  'breakfast': _MealMeta('Breakfast', Icons.wb_sunny_rounded, Color(0xFFF59E0B)),
  'lunch': _MealMeta('Lunch', Icons.restaurant_rounded, Color(0xFF3B82F6)),
  'dinner': _MealMeta('Dinner', Icons.nights_stay_rounded, Color(0xFF8B5CF6)),
  'snack': _MealMeta('Snack', Icons.cookie_rounded, Color(0xFF10B981)),
};

class _MealMeta {
  const _MealMeta(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

_MealMeta _meta(String mealType) =>
    _mealMeta[mealType] ?? _MealMeta(mealType, Icons.fastfood, Colors.grey);

enum _MacroKey { protein, carbs, fat }

class _MacroChoice {
  const _MacroChoice({
    required this.label,
    required this.consumed,
    required this.target,
    required this.color,
  });

  final String label;
  final double consumed;
  final double target;
  final Color color;
}

// ── Main Page ────────────────────────────────────────────────────────────────

class NutritionPage extends StatefulWidget {
  const NutritionPage({super.key, required this.nutritionApi});

  final NutritionApi nutritionApi;

  @override
  State<NutritionPage> createState() => _NutritionPageState();
}

class _NutritionPageState extends State<NutritionPage> {
  DateTime _selectedDate = DateTime.now();
  DailyNutritionSummary? _summary;
  MacroGoal? _macroGoal;
  bool _loading = true;
  String? _error;
  _MacroKey _selectedMacro = _MacroKey.protein;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _dateKey => DateFormat('yyyy-MM-dd').format(_selectedDate);
  bool get _isToday =>
      DateFormat('yyyy-MM-dd').format(_selectedDate) ==
      DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // Fetch daily summary
    try {
      final summary = await widget.nutritionApi.getDailySummary(logDate: _dateKey);
      if (!mounted) return;
      setState(() => _summary = summary);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
    // Fetch goal separately.
    // Only reset to null (→ show wizard) when the server explicitly says no goal
    // exists (404). On network/server errors keep whatever we already had so
    // the wizard doesn't flash spuriously.
    try {
      final goal = await widget.nutritionApi.getGoal();
      if (!mounted) return;
      setState(() => _macroGoal = goal);
    } catch (e) {
      if (!mounted) return;
      final is404 = e.toString().contains('404') ||
          e.toString().contains('not found') ||
          e.toString().contains('Not Found');
      if (is404) {
        setState(() => _macroGoal = null);
      }
      // Network / 5xx errors: leave _macroGoal unchanged — don't show wizard
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _changeDate(int delta) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: delta)));
    _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _load();
    }
  }

  MealGroup? _mealGroup(String type) {
    final meals = _summary?.meals ?? [];
    for (final m in meals) {
      if (m.mealType == type) return m;
    }
    return null;
  }

  Future<void> _addFood(String mealType) async {
    final logged = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FoodSearchSheet(
        nutritionApi: widget.nutritionApi,
        mealType: mealType,
        logDate: _dateKey,
      ),
    );
    if (logged == true) {
      NutritionEvents.notifyFoodLogged();
      _load();
    }
  }

  Future<void> _editLog(FoodLog log) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditLogSheet(log: log, nutritionApi: widget.nutritionApi),
    );
    if (result != null) {
      NutritionEvents.notifyFoodLogged();
      _load();
    }
  }

  Widget _buildWizardPrompt() {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF16A34A),
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Nutrition',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.restaurant_menu_rounded,
                    size: 44, color: Color(0xFF16A34A)),
              ),
              const SizedBox(height: 28),
              Text('Set Up Your Nutrition',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 24, fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              Text(
                'Answer a few quick questions and we\'ll calculate your personalised daily calorie and macro targets.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _openGoalSetup,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text('Get Started',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
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

  @override
  Widget build(BuildContext context) {
    // First load — show spinner
    if (_loading && _macroGoal == null && _summary == null) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        appBar: AppBar(
          backgroundColor: const Color(0xFF16A34A),
          surfaceTintColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text('Nutrition',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.white)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // No goal set → wizard prompt
    if (!_loading && _macroGoal == null) {
      return _buildWizardPrompt();
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF16A34A),
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Nutrition',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        actions: [
          TextButton.icon(
            onPressed: _openGoalSetup,
            icon: const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
            label: Text('Edit Goal',
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateBar(),
          Expanded(
            child: _loading && _summary == null
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _summary == null
                    ? _buildError()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          children: [
                            _buildCalorieCard(),
                            const SizedBox(height: 14),
                            _buildMacroRow(),
                            const SizedBox(height: 10),
                            _buildSelectedMacroDetail(),
                            const SizedBox(height: 18),
                            ..._mealTypes.map(_buildMealCard),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ── Date bar ───────────────────────────────────────────────────────────────

  Widget _buildDateBar() {
    final label = _isToday
        ? 'Today'
        : DateFormat('EEE, MMM d').format(_selectedDate);
    return Container(
      color: const Color(0xFF16A34A),
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: () => _changeDate(-1),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _pickDate,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: _isToday ? null : () => _changeDate(1),
          ),
        ],
      ),
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────

  Widget _buildError() {
    // Show a friendly message — the raw exception is too noisy for users.
    final isNetworkError = _error != null &&
        (_error!.contains('Network error') ||
            _error!.contains('SocketException') ||
            _error!.contains('statusCode: -1'));
    final friendlyMessage = isNetworkError
        ? 'Could not reach the server.\nCheck your connection and try again.'
        : 'Could not load nutrition data.\nPull down to refresh.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isNetworkError ? Icons.wifi_off_rounded : Icons.error_outline,
              size: 44,
              color: AppColors.error,
            ),
            const SizedBox(height: 10),
            Text(
              friendlyMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
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
    );
  }

  // ── Calorie ring card ──────────────────────────────────────────────────────

  void _openGoalSetup() {
    final mobileClient = ApiClient(
        baseUrl: AppConfig.apiBaseUrl, userId: AppConfig.userId);
    final webClient = ApiClient(
        baseUrl: AppConfig.webApiBaseUrl, userId: AppConfig.userId);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HealthOnboardingFlow(
          api: HealthOnboardingApi(mobileClient),
          profileApi: ProfileApi(webClient),
          onCompleted: () {
            Navigator.of(context).pop();
            _load();
          },
        ),
      ),
    );
  }

  Widget _buildCalorieCard() {
    final summary = _summary;
    final consumed = summary?.total.calories ?? 0;
    final target = _macroGoal?.dailyCalories;
    final hasGoal = _macroGoal != null;
    final remaining = hasGoal ? target! - consumed : 0.0;
    final percent = hasGoal ? (consumed / target!).clamp(0.0, 1.5) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            width: 180,
            child: CustomPaint(
              painter: _CalorieRingPainter(
                percent: percent,
                consumed: consumed,
                target: target ?? 0,
              ),
              child: Center(
                child: hasGoal
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            remaining.round().abs().toString(),
                            style: GoogleFonts.poppins(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: remaining >= 0
                                  ? const Color(0xFF16A34A)
                                  : AppColors.error,
                            ),
                          ),
                          Text(
                            remaining >= 0 ? 'kcal left' : 'kcal over',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      )
                    : GestureDetector(
                        onTap: _openGoalSetup,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_circle_outline_rounded,
                                size: 28, color: Color(0xFF16A34A)),
                            const SizedBox(height: 6),
                            Text(
                              'Set Goal',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                            Text(
                              consumed.round() > 0
                                  ? '${consumed.round()} eaten'
                                  : 'No goal set',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (hasGoal)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CalorieStat(
                  label: 'Goal',
                  value: target!.round().toString(),
                  color: AppColors.textSecondary,
                ),
                _CalorieStat(
                  label: 'Eaten',
                  value: consumed.round().toString(),
                  color: const Color(0xFF16A34A),
                ),
                _CalorieStat(
                  label: remaining >= 0 ? 'Left' : 'Over',
                  value: remaining.round().abs().toString(),
                  color: remaining >= 0
                      ? const Color(0xFF3B82F6)
                      : AppColors.error,
                ),
              ],
            )
          else
            // No goal set — prompt the user
            GestureDetector(
              onTap: _openGoalSetup,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.track_changes_rounded,
                        size: 16, color: Color(0xFF16A34A)),
                    const SizedBox(width: 6),
                    Text(
                      'Set your calorie goal',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF16A34A),
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

  // ── Macro row ──────────────────────────────────────────────────────────────

  Widget _buildMacroRow() {
    final total = _summary?.total;

    return Row(
      children: [
        Expanded(
          child: _MacroBar(
            label: 'Protein',
            consumed: total?.proteinG ?? 0,
            target: _macroGoal?.proteinG ?? 0,
            color: const Color(0xFF3B82F6),
            unit: 'g',
            selected: _selectedMacro == _MacroKey.protein,
            onTap: () => setState(() => _selectedMacro = _MacroKey.protein),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MacroBar(
            label: 'Carbs',
            consumed: total?.carbsG ?? 0,
            target: _macroGoal?.carbsG ?? 0,
            color: const Color(0xFFF59E0B),
            unit: 'g',
            selected: _selectedMacro == _MacroKey.carbs,
            onTap: () => setState(() => _selectedMacro = _MacroKey.carbs),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MacroBar(
            label: 'Fat',
            consumed: total?.fatG ?? 0,
            target: _macroGoal?.fatG ?? 0,
            color: const Color(0xFFEF4444),
            unit: 'g',
            selected: _selectedMacro == _MacroKey.fat,
            onTap: () => setState(() => _selectedMacro = _MacroKey.fat),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedMacroDetail() {
    final total = _summary?.total;

    final selected = switch (_selectedMacro) {
      _MacroKey.protein => _MacroChoice(
          label: 'Protein',
          consumed: total?.proteinG ?? 0,
          target: _macroGoal?.proteinG ?? 0,
          color: const Color(0xFF3B82F6),
        ),
      _MacroKey.carbs => _MacroChoice(
          label: 'Carbs',
          consumed: total?.carbsG ?? 0,
          target: _macroGoal?.carbsG ?? 0,
          color: const Color(0xFFF59E0B),
        ),
      _MacroKey.fat => _MacroChoice(
          label: 'Fat',
          consumed: total?.fatG ?? 0,
          target: _macroGoal?.fatG ?? 0,
          color: const Color(0xFFEF4444),
        ),
    };

    final remaining = selected.target > 0 ? selected.target - selected.consumed : 0.0;
    final pct = selected.target > 0
        ? (selected.consumed / selected.target).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected.color.withAlpha(45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${selected.label} details',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: selected.color.withAlpha(30),
              color: selected.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            selected.target > 0
                ? '${selected.consumed.toStringAsFixed(1)}g consumed • ${selected.target.toStringAsFixed(1)}g target • ${remaining >= 0 ? remaining.toStringAsFixed(1) : remaining.abs().toStringAsFixed(1)}g ${remaining >= 0 ? 'left' : 'over'}'
                : '${selected.consumed.toStringAsFixed(1)}g consumed',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Meal card ──────────────────────────────────────────────────────────────

  Widget _buildMealCard(String mealType) {
    final meta = _meta(mealType);
    final group = _mealGroup(mealType);
    final cals = group?.subtotal.calories ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: meta.color.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(meta.icon, size: 20, color: meta.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meta.label,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${cals.round()} kcal',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _addFood(mealType),
                  icon: Icon(Icons.add_rounded, size: 18, color: meta.color),
                  label: Text(
                    'Add',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: meta.color,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Logs
          if (group != null && group.logs.isNotEmpty) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            ...group.logs.map(
              (log) => InkWell(
                onTap: () => _editLog(log),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.foodName,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${log.quantityG.round()} g',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${log.calories.round()} kcal',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(bottom: 14, top: 4),
              child: Text(
                'No items logged',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Calorie ring painter ─────────────────────────────────────────────────────

class _CalorieRingPainter extends CustomPainter {
  _CalorieRingPainter({
    required this.percent,
    required this.consumed,
    required this.target,
  });

  final double percent;
  final double consumed;
  final double target;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;
    const strokeWidth = 12.0;

    // Track
    final trackPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (percent <= 1.0) {
      arcPaint.color = const Color(0xFF16A34A);
    } else {
      arcPaint.color = const Color(0xFFEF4444);
    }

    final sweepAngle = 2 * math.pi * percent.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CalorieRingPainter old) =>
      old.percent != percent;
}

// ── Small stat under the ring ────────────────────────────────────────────────

class _CalorieStat extends StatelessWidget {
  const _CalorieStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

// ── Macro progress bar ───────────────────────────────────────────────────────

class _MacroBar extends StatelessWidget {
  const _MacroBar({
    required this.label,
    required this.consumed,
    required this.target,
    required this.color,
    required this.unit,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final double consumed;
  final double target;
  final Color color;
  final String unit;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pct = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    final left = target > 0 ? (target - consumed).clamp(0, target) : 0.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: color.withAlpha(30),
                color: color,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              target > 0
                  ? '${left.round()}$unit left'
                  : '${consumed.round()}$unit',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Food Search Bottom Sheet ─────────────────────────────────────────────────

class _FoodSearchSheet extends StatefulWidget {
  const _FoodSearchSheet({
    required this.nutritionApi,
    required this.mealType,
    required this.logDate,
  });

  final NutritionApi nutritionApi;
  final String mealType;
  final String logDate;

  @override
  State<_FoodSearchSheet> createState() => _FoodSearchSheetState();
}

class _FoodSearchSheetState extends State<_FoodSearchSheet> {
  final _searchCtrl = TextEditingController();
  List<FoodSearchItem> _results = [];
  bool _searching = false;
  String? _selectedCategory;
  List<String> _categories = [];
  bool _categoriesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() => _searching = true);
    try {
      final futures = await Future.wait([
        widget.nutritionApi.searchFoods(),
        widget.nutritionApi.getFoodCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _results = futures[0] as List<FoodSearchItem>;
        _categories = futures[1] as List<String>;
        _categoriesLoaded = true;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    try {
      final results = await widget.nutritionApi.searchFoods(
        query: query.isEmpty ? null : query,
        category: _selectedCategory,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  void _onCategoryChanged(String? cat) {
    setState(() => _selectedCategory = cat);
    _search(_searchCtrl.text);
  }

  Future<void> _selectFood(FoodSearchItem food) async {
    final logged = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LogFoodSheet(
        nutritionApi: widget.nutritionApi,
        food: food,
        mealType: widget.mealType,
        logDate: widget.logDate,
      ),
    );
    if (logged == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final meta = _meta(widget.mealType);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Icon(meta.icon, color: meta.color, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Add to ${meta.label}',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (q) => _search(q),
              decoration: InputDecoration(
                hintText: 'Search foods...',
                hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: AppColors.scaffoldBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Category chips
          if (_categoriesLoaded)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _CategoryChip(
                    label: 'All',
                    selected: _selectedCategory == null,
                    onTap: () => _onCategoryChanged(null),
                  ),
                  ..._categories.map(
                    (c) => _CategoryChip(
                      label: c,
                      selected: _selectedCategory == c,
                      onTap: () => _onCategoryChanged(c),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 4),

          // Results
          Expanded(
            child: _searching
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          'No foods found',
                          style: GoogleFonts.poppins(
                            color: AppColors.textMuted,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.only(bottom: bottomInset + 16),
                        itemCount: _results.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 16, endIndent: 16),
                        itemBuilder: (_, i) {
                          final food = _results[i];
                          return ListTile(
                            title: Text(
                              food.name,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              '${food.caloriesPer100g.round()} kcal / 100g  ·  ${food.category}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.add_circle_outline,
                              color: Color(0xFF16A34A),
                            ),
                            onTap: () => _selectFood(food),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Category chip ────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Chip(
          label: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
          backgroundColor:
              selected ? const Color(0xFF16A34A) : AppColors.scaffoldBg,
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

// ── Log Food Sheet (quantity picker + preview) ───────────────────────────────

class _LogFoodSheet extends StatefulWidget {
  const _LogFoodSheet({
    required this.nutritionApi,
    required this.food,
    required this.mealType,
    required this.logDate,
  });

  final NutritionApi nutritionApi;
  final FoodSearchItem food;
  final String mealType;
  final String logDate;

  @override
  State<_LogFoodSheet> createState() => _LogFoodSheetState();
}

class _LogFoodSheetState extends State<_LogFoodSheet> {
  final _qtyCtrl = TextEditingController(text: '100');
  double _quantity = 100;
  MacroPreview? _preview;
  bool _loadingPreview = false;
  bool _logging = false;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    if (_quantity <= 0) return;
    setState(() => _loadingPreview = true);
    try {
      final preview = await widget.nutritionApi.previewMacros(
        foodId: widget.food.id,
        quantityG: _quantity,
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _loadingPreview = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPreview = false);
    }
  }

  void _onQtyChanged(String val) {
    final q = double.tryParse(val);
    if (q != null && q > 0) {
      _quantity = q;
      _loadPreview();
    }
  }

  void _setQuantity(double q) {
    _quantity = q;
    _qtyCtrl.text = q.round().toString();
    _loadPreview();
  }

  Future<void> _logMeal() async {
    if (_quantity <= 0) return;
    setState(() => _logging = true);
    try {
      await widget.nutritionApi.logMeal(
        foodId: widget.food.id,
        quantityG: _quantity,
        mealType: widget.mealType,
        logDate: widget.logDate,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      setState(() => _logging = false);
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final preview = _preview;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Food name
            Text(
              food.name,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${food.category}  ·  ${food.caloriesPer100g.round()} kcal per 100g',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),

            // Quantity input
            Text(
              'Quantity (g)',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: _onQtyChanged,
              decoration: InputDecoration(
                suffixText: 'g',
                filled: true,
                fillColor: AppColors.scaffoldBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Quick-pick buttons
            Wrap(
              spacing: 8,
              children: [50, 100, 150, 200, 250].map((g) {
                final isActive = _quantity == g.toDouble();
                return ChoiceChip(
                  label: Text('${g}g'),
                  selected: isActive,
                  selectedColor: const Color(0xFF16A34A).withAlpha(30),
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? const Color(0xFF16A34A)
                        : AppColors.textSecondary,
                  ),
                  onSelected: (_) => _setQuantity(g.toDouble()),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Macro preview
            if (_loadingPreview)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (preview != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.scaffoldBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _PreviewStat('Calories', '${preview.calories.round()}', 'kcal'),
                    _PreviewStat('Protein', preview.proteinG.toStringAsFixed(1), 'g'),
                    _PreviewStat('Carbs', preview.carbsG.toStringAsFixed(1), 'g'),
                    _PreviewStat('Fat', preview.fatG.toStringAsFixed(1), 'g'),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Log button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _logging ? null : _logMeal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: _logging
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Log Food'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Preview stat ─────────────────────────────────────────────────────────────

class _PreviewStat extends StatelessWidget {
  const _PreviewStat(this.label, this.value, this.unit);

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          '$label ($unit)',
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

// ── Edit / Delete Log Sheet ──────────────────────────────────────────────────

class _EditLogSheet extends StatefulWidget {
  const _EditLogSheet({required this.log, required this.nutritionApi});

  final FoodLog log;
  final NutritionApi nutritionApi;

  @override
  State<_EditLogSheet> createState() => _EditLogSheetState();
}

class _EditLogSheetState extends State<_EditLogSheet> {
  late final TextEditingController _qtyCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
      text: widget.log.quantityG.round().toString(),
    );
  }

  Future<void> _save() async {
    final q = double.tryParse(_qtyCtrl.text);
    if (q == null || q <= 0) return;
    setState(() => _saving = true);
    try {
      await widget.nutritionApi.updateLog(
        logId: widget.log.id,
        quantityG: q,
      );
      if (mounted) Navigator.of(context).pop('updated');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete log?'),
        content: Text('Remove ${widget.log.foodName} from this meal?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      await widget.nutritionApi.deleteLog(widget.log.id);
      if (mounted) Navigator.of(context).pop('deleted');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text(
            log.foodName,
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            '${log.calories.round()} kcal  ·  P ${log.proteinG.toStringAsFixed(1)}g  ·  '
            'C ${log.carbsG.toStringAsFixed(1)}g  ·  F ${log.fatG.toStringAsFixed(1)}g',
            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),

          Text(
            'Quantity (g)',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              suffixText: 'g',
              filled: true,
              fillColor: AppColors.scaffoldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _delete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Update'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
