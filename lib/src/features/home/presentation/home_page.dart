import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_service.dart';
import '../../gym/data/gym_api.dart';
import '../../steps/step_service.dart';
import '../../gym/models/gym_models.dart';
import '../../gym/presentation/checkin_flow.dart';
import '../../hydration/data/hydration_api.dart';
import '../../hydration/models/hydration_models.dart';
import '../../nutrition/data/nutrition_api.dart';
import '../../nutrition/data/nutrition_events.dart';
import '../../nutrition/models/nutrition_models.dart';
import '../../workout/data/local_plan_service.dart';
import '../../workout/data/workout_api.dart';
import '../../workout/models/workout_models.dart';

// ── Route-aware mixin so the home tab reloads on tab switch ─────────────────

/// A simple LifecycleObserver that calls [onResume] whenever the app
/// comes back to the foreground or the route becomes active again.
class _ResumeObserver extends WidgetsBindingObserver {
  _ResumeObserver(this.onResume);
  final VoidCallback onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}

class HomeTabPage extends StatefulWidget {
  const HomeTabPage({
    super.key,
    this.workoutApi,
    this.nutritionApi,
    this.gymApi,
    this.hydrationApi,
    this.onSwitchTab,
  });

  final WorkoutApi? workoutApi;
  final NutritionApi? nutritionApi;
  final GymApi? gymApi;
  final HydrationApi? hydrationApi;
  final ValueChanged<int>? onSwitchTab;

  @override
  State<HomeTabPage> createState() => HomeTabPageState();
}

class HomeTabPageState extends State<HomeTabPage> {
  /// Called externally (e.g. from the nav bar) to refresh data when the tab
  /// becomes visible again after the user has been on another tab.
  void reload() => _load();
  int _loadGeneration = 0;
  TodayWorkout? _todayWorkout;
  GymMembership? _membership;
  DailyNutritionSummary? _nutritionSummary;
  MacroGoal? _macroGoal;
  List<WeeklySummaryDay>? _weeklyData;
  HydrationDailySummary? _hydrationSummary;
  List<HydrationWeeklyEntry> _hydrationWeekly = [];
  String? _displayName;

  late final _ResumeObserver _observer;

  // Mood chip state
  String? _selectedMood;

  static const _moods = [
    ('😊', 'Happy'),
    ('😤', 'Angry'),
    ('😴', 'Sleepy'),
    ('😑', 'Bored'),
  ];

  static const _moodPrefKey = 'selected_mood';

  @override
  void initState() {
    super.initState();
    _observer = _ResumeObserver(_load);
    WidgetsBinding.instance.addObserver(_observer);
    NutritionEvents.foodLogged.addListener(_onFoodLogged);
    _load();
    _loadMood();
    _loadName();
  }

  void _onFoodLogged() => _reloadNutrition();

  /// Refreshes only the nutrition-related cards without touching workout/gym data.
  Future<void> _reloadNutrition() async {
    if (widget.nutritionApi == null) return;
    final now = DateTime.now();
    final startDate = DateFormat(
      'yyyy-MM-dd',
    ).format(now.subtract(const Duration(days: 6)));
    final endDate = DateFormat('yyyy-MM-dd').format(now);
    DailyNutritionSummary? nutritionSummary;
    MacroGoal? macroGoal;
    List<WeeklySummaryDay>? weeklyData;
    await Future.wait([
      () async {
        try {
          nutritionSummary = await widget.nutritionApi!.getDailySummary();
        } catch (_) {}
      }(),
      () async {
        try {
          macroGoal = await widget.nutritionApi!.getGoal();
        } catch (_) {}
      }(),
      () async {
        try {
          weeklyData = await widget.nutritionApi!.getWeeklySummary(
            startDate: startDate,
            endDate: endDate,
          );
        } catch (_) {}
      }(),
    ]);
    if (!mounted) return;
    setState(() {
      if (nutritionSummary != null) _nutritionSummary = nutritionSummary;
      if (macroGoal != null) _macroGoal = macroGoal;
      if (weeklyData != null) _weeklyData = weeklyData;
    });
  }

  @override
  void dispose() {
    NutritionEvents.foodLogged.removeListener(_onFoodLogged);
    WidgetsBinding.instance.removeObserver(_observer);
    super.dispose();
  }

  Future<void> _loadName() async {
    final name = await AuthService.instance.getDisplayName();
    if (name != null && name.isNotEmpty && mounted) {
      setState(() => _displayName = name);
    }
  }

  Future<void> _loadMood() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_moodPrefKey);
    if (saved != null && mounted) setState(() => _selectedMood = saved);
  }

  Future<void> _saveMood(String? mood) async {
    final prefs = await SharedPreferences.getInstance();
    if (mood == null) {
      await prefs.remove(_moodPrefKey);
    } else {
      await prefs.setString(_moodPrefKey, mood);
    }
  }

  Future<void> _load() async {
    final loadId = ++_loadGeneration;
    TodayWorkout? todayWorkout;
    GymMembership? membership;
    DailyNutritionSummary? nutritionSummary;
    MacroGoal? macroGoal;
    List<WeeklySummaryDay>? weeklyData;
    HydrationDailySummary? hydrationSummary;
    List<HydrationWeeklyEntry>? hydrationWeekly;

    final now = DateTime.now();
    final startDate = DateFormat(
      'yyyy-MM-dd',
    ).format(now.subtract(const Duration(days: 6)));
    final endDate = DateFormat('yyyy-MM-dd').format(now);

    // All calls are individually guarded so a single failure never kills the rest.
    await Future.wait([
      () async {
        try {
          if (widget.workoutApi != null) {
            todayWorkout = await widget.workoutApi!.getTodayWorkout();
          } else {
            todayWorkout = await LocalPlanService.getTodayWorkout();
          }
        } catch (_) {}
      }(),
      if (widget.gymApi != null)
        () async {
          try {
            final info = await widget.gymApi!.getInfo();
            membership = info.memberships
                .where((m) => m.status.toUpperCase() == 'ACTIVE')
                .firstOrNull;
          } catch (_) {}
        }(),
      if (widget.nutritionApi != null)
        () async {
          try {
            nutritionSummary = await widget.nutritionApi!.getDailySummary();
          } catch (_) {}
        }(),
      if (widget.nutritionApi != null)
        () async {
          try {
            macroGoal = await widget.nutritionApi!.getGoal();
          } catch (_) {}
        }(),
      if (widget.nutritionApi != null)
        () async {
          try {
            weeklyData = await widget.nutritionApi!.getWeeklySummary(
              startDate: startDate,
              endDate: endDate,
            );
          } catch (_) {}
        }(),
      if (widget.hydrationApi != null)
        () async {
          try {
            hydrationSummary = await widget.hydrationApi!.getDailySummary();
          } catch (_) {}
        }(),
      if (widget.hydrationApi != null)
        () async {
          try {
            hydrationWeekly = await widget.hydrationApi!.getWeeklySummary();
          } catch (_) {}
        }(),
    ]);

    if (!mounted || loadId != _loadGeneration) return;
    setState(() {
      if (todayWorkout != null) _todayWorkout = todayWorkout;
      if (membership != null) _membership = membership;
      if (nutritionSummary != null) _nutritionSummary = nutritionSummary;
      if (macroGoal != null) _macroGoal = macroGoal;
      if (weeklyData != null) _weeklyData = weeklyData;
      if (hydrationSummary != null) _hydrationSummary = hydrationSummary;
      if (hydrationWeekly != null) _hydrationWeekly = hydrationWeekly!;
    });
  }

  Future<void> _logHydration(int ml) async {
    if (widget.hydrationApi == null) return;
    try {
      await widget.hydrationApi!.createLog(amountMl: ml);
      final summary = await widget.hydrationApi!.getDailySummary();
      if (!mounted) return;
      setState(() => _hydrationSummary = summary);
    } catch (_) {}
  }

  String get _userName {
    // Prefer the stored display name from AuthService (set on login)
    if (_displayName != null && _displayName!.isNotEmpty) {
      return _displayName!.split(' ').first; // first name only
    }
    // Fallback: derive from userId
    final parts = AppConfig.userId.split('_');
    final raw = parts.first;
    if (raw.isEmpty || raw == 'demo') return 'there';
    return raw[0].toUpperCase() + raw.substring(1);
  }

  int get _daysUntilExpiry {
    final end = _membership?.endDate;
    if (end == null) return 0;
    return end.difference(DateTime.now()).inDays.clamp(0, 9999);
  }

  @override
  Widget build(BuildContext context) {
    assert(() {
      _buildSummaryHeader();
      _buildSummaryCards();
      return true;
    }());
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(child: _buildDailyGoalCard()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              sliver: SliverToBoxAdapter(child: _buildTwoColumnRow()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              sliver: SliverToBoxAdapter(child: _buildMembershipCard()),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFFE8F5E9)),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date row
          Text(
            DateFormat('MMM d, yyyy').format(DateTime.now()),
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF4CAF50),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          // Greeting
          Text(
            'Hello $_userName! How are you\nfeeling today?',
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 16),
          // Mood chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _moods.map((mood) {
                final isSelected = _selectedMood == mood.$2;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      final next = isSelected ? null : mood.$2;
                      setState(() => _selectedMood = next);
                      _saveMood(next);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF22C55E)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(mood.$1, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            mood.$2,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Daily Goal card ────────────────────────────────────────────────────────

  Widget _buildDailyGoalCard() {
    final now = DateTime.now();
    final weekday = now.weekday; // 1=Mon … 7=Sun
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final consumed = _nutritionSummary?.total.calories.round() ?? 0;
    final target =
        (_macroGoal?.dailyCalories ??
                _nutritionSummary?.goalProgress?.caloriesTarget ??
                2200.0)
            .round();

    // Build date→calories and date→logCount maps from weekly data
    final calMap = <String, int>{};
    final logMap = <String, int>{};
    for (final d in _weeklyData ?? []) {
      calMap[d.date] = d.calories.round();
      logMap[d.date] = d.logCount;
    }

    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily Goal',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              Text(
                '$consumed / $target kcal',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final isToday = (i + 1) == weekday;
              final isPast = (i + 1) < weekday;
              // Resolve the calendar date for slot i (Mon=0 … Sun=6)
              final slotDate = now.subtract(Duration(days: weekday - 1 - i));
              final dateKey = DateFormat('yyyy-MM-dd').format(slotDate);
              final dayCal = isToday ? consumed : (calMap[dateKey] ?? 0);
              // Only show tick if meals were actually logged that day
              final hadActivity = isToday
                  ? consumed > 0
                  : (logMap[dateKey] ?? 0) > 0;
              return _DayChip(
                label: days[i],
                isToday: isToday,
                isPast: isPast,
                hadActivity: hadActivity,
                calories: (isPast || isToday) ? dayCal : null,
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Two-column row ────────────────────────────────────────────────────────

  Widget _buildTwoColumnRow() {
    return Row(
      children: [
        Expanded(child: _buildScanQrCard()),
        const SizedBox(width: 12),
        Expanded(child: _buildTodayActivityCard()),
      ],
    );
  }

  Widget _buildScanQrCard() {
    final hasMembership = _membership != null;
    final canScan = hasMembership && widget.gymApi != null;
    return GestureDetector(
      onTap: canScan
          ? () => launchCheckInFlow(
              context: context,
              gymApi: widget.gymApi!,
              membership: _membership!,
              onFlowComplete: _load,
            )
          : null,
      child: Container(
        height: 178,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_scanner_rounded,
              size: 56,
              color: canScan
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 10),
            Text(
              canScan
                  ? 'Scan QR'
                  : hasMembership
                  ? 'Scanner Unavailable'
                  : 'No Membership',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: canScan
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.5),
              ),
            ),
            if (canScan) ...[
              const SizedBox(height: 4),
              Text(
                'Open camera and scan to check in',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTodayActivityCard() {
    final workout = _todayWorkout;
    final exercises = workout?.exercises ?? [];
    final focusMuscles = _workoutFocusMuscles(workout);
    final isRest = workout == null || exercises.isEmpty;
    final planTypeLabel = workout == null
        ? null
        : _planTypeLabel(workout.planType);
    final label = workout == null
        ? 'Set Active Plan'
        : planTypeLabel == null
        ? workout.dayLabel
        : '${workout.dayLabel} • $planTypeLabel';
    final detailText = workout == null
        ? 'Choose a plan to see today\'s training split.'
        : isRest
        ? 'Recovery day. Keep it light and come back tomorrow.'
        : focusMuscles.isEmpty
        ? '${exercises.length} exercises selected.'
        : focusMuscles.take(3).join(' / ');
    final footerText = workout == null
        ? 'Open the workout tab to set an active plan.'
        : isRest
        ? 'Rest day'
        : '${exercises.length} exercises • active until changed';

    return GestureDetector(
      onTap: () => widget.onSwitchTab?.call(2),
      child: Container(
        height: 178,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Color(0xFF22C55E),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Today's Activity",
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: const Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              detailText,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: const Color(0xFF6B7280),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              footerText,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF22C55E),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String? _planTypeLabel(String planType) {
    if (planType.startsWith('custom:')) return 'Custom';
    switch (planType) {
      case 'ppl':
        return 'PPL';
      case 'bro':
        return 'Bro Split';
      case 'full_body':
        return 'Full Body';
      default:
        return planType.trim().isEmpty ? null : planType.toUpperCase();
    }
  }

  List<String> _workoutFocusMuscles(TodayWorkout? workout) {
    if (workout == null) return const [];
    final seen = <String>{};
    final muscles = <String>[];
    for (final exercise in workout.exercises) {
      final muscle = exercise.primaryMuscle?.trim();
      if (muscle == null || muscle.isEmpty) continue;
      if (seen.add(muscle.toLowerCase())) {
        muscles.add(muscle);
      }
    }
    return muscles;
  }

  // ── Summary header ────────────────────────────────────────────────────────

  Widget _buildSummaryHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Summary',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111827),
          ),
        ),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.edit_outlined,
            size: 16,
            color: Color(0xFF374151),
          ),
        ),
      ],
    );
  }

  // ── Sparkline helper — builds 7-day normalized bar values ─────────────────

  /// Returns 7 values (0.05–1.0) for the sparkline, oldest→newest.
  /// The last bar (today) is overridden with [todayValue] / [target]
  /// from the real-time daily summary so it stays in sync while typing.
  List<double> _sparkBars({
    required double Function(WeeklySummaryDay) selector,
    required double target,
    double? todayValue,
  }) {
    final today = DateTime.now();
    return List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      final key = DateFormat('yyyy-MM-dd').format(day);
      // Last slot: prefer real-time value from daily summary
      if (i == 6 && todayValue != null && target > 0) {
        return (todayValue / target).clamp(0.05, 1.0);
      }
      final found = _weeklyData?.where((w) => w.date == key).firstOrNull;
      if (found == null) return 0.05;
      return (selector(found) / target).clamp(0.05, 1.0);
    });
  }

  // ── Summary cards (Apple Health style) ───────────────────────────────────

  Widget _buildSummaryCards() {
    final nutrition = _nutritionSummary;
    final calories = nutrition?.total.calories ?? 0.0;
    final protein = nutrition?.total.proteinG ?? 0.0;
    final carbs = nutrition?.total.carbsG ?? 0.0;

    final calorieTarget =
        _macroGoal?.dailyCalories ??
        nutrition?.goalProgress?.caloriesTarget ??
        2200.0;
    final proteinTarget = _macroGoal?.proteinG ?? 150.0;
    final carbsTarget = _macroGoal?.carbsG ?? 250.0;

    return Column(
      children: [
        // ── Steps card (Apple Move ring style) ─────────────────────────────
        ListenableBuilder(
          listenable: StepService.instance,
          builder: (context, child) {
            final svc = StepService.instance;
            final steps = svc.todaySteps;
            final weekRaw = svc.weekSteps;
            final stepBars = weekRaw
                .map((s) => (s / StepService.dailyGoal).clamp(0.05, 1.0))
                .toList();
            // If service not yet delivering data, show flat min bars
            final bars = stepBars.length == 7 ? stepBars : List.filled(7, 0.05);
            return _SummaryCard(
              icon: Icons.directions_walk_rounded,
              iconBg: const Color(0xFFFFEDD5),
              iconColor: const Color(0xFFEA580C),
              bg: const Color(0xFFFFEDD5),
              label: 'Steps',
              timeLabel: 'Today',
              valueText: steps >= 1000
                  ? '${(steps / 1000).toStringAsFixed(1)}k'
                  : '$steps',
              unit: '',
              bars: bars,
              barColor: const Color(0xFFEA580C),
              onTap: () => widget.onSwitchTab?.call(2),
              subtitle: '${svc.activeCalories.round()} kcal active',
            );
          },
        ),
        const SizedBox(height: 10),
        _SummaryCard(
          icon: Icons.restaurant_rounded,
          iconBg: const Color(0xFFDCFCE7),
          iconColor: const Color(0xFF16A34A),
          bg: const Color(0xFFDCFCE7),
          label: 'Calories Eaten',
          timeLabel: 'Today',
          valueText: '${calories.round()}',
          unit: 'kcal',
          bars: _sparkBars(
            selector: (w) => w.calories,
            target: calorieTarget,
            todayValue: calories,
          ),
          barColor: const Color(0xFF16A34A),
          onTap: () => widget.onSwitchTab?.call(2),
        ),
        const SizedBox(height: 10),
        _SummaryCard(
          icon: Icons.water_drop_rounded,
          iconBg: const Color(0xFFDBEAFE),
          iconColor: const Color(0xFF1D4ED8),
          bg: const Color(0xFFDBEAFE),
          label: 'Protein',
          timeLabel: 'Today',
          valueText: '${protein.round()}',
          unit: 'g',
          bars: _sparkBars(
            selector: (w) => w.proteinG,
            target: proteinTarget,
            todayValue: protein,
          ),
          barColor: const Color(0xFF1D4ED8),
          onTap: () => widget.onSwitchTab?.call(2),
        ),
        const SizedBox(height: 10),
        _SummaryCard(
          icon: Icons.local_fire_department_rounded,
          iconBg: const Color(0xFFFEF9C3),
          iconColor: const Color(0xFFCA8A04),
          bg: const Color(0xFFFEF9C3),
          label: 'Carbs',
          timeLabel: 'Today',
          valueText: '${carbs.round()}',
          unit: 'g',
          bars: _sparkBars(
            selector: (w) => w.carbsG,
            target: carbsTarget,
            todayValue: carbs,
          ),
          barColor: const Color(0xFFCA8A04),
          onTap: () => widget.onSwitchTab?.call(2),
        ),
        const SizedBox(height: 10),
        _WorkoutSummaryCard(
          todayWorkout: _todayWorkout,
          onTap: () => widget.onSwitchTab?.call(2),
        ),
        const SizedBox(height: 10),
        _HydrationCard(
          summary: _hydrationSummary,
          weekly: _hydrationWeekly,
          onAdd: _logHydration,
        ),
      ],
    );
  }

  // ── Membership card ────────────────────────────────────────────────────────

  Widget _buildMembershipCard() {
    final m = _membership;
    if (m == null) {
      return _buildFindGymCard();
    }

    return GestureDetector(
      onTap: () => widget.onSwitchTab?.call(1),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Membership',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                _OutlinedWhiteButton(
                  label: 'Scan QR',
                  onTap: () => launchCheckInFlow(
                    context: context,
                    gymApi: widget.gymApi!,
                    membership: m,
                    onFlowComplete: _load,
                  ),
                  small: true,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              m.gymName,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Expires in $_daysUntilExpiry days',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            _OutlinedWhiteButton(
              label: 'View Membership',
              onTap: () => widget.onSwitchTab?.call(1),
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFindGymCard() {
    return GestureDetector(
      onTap: () => widget.onSwitchTab?.call(1),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.explore_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Active Membership',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Discover and join a gym near you',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.isToday,
    required this.isPast,
    required this.hadActivity,
    this.calories,
  });
  final String label;
  final bool isToday;
  final bool isPast;

  /// True if food was actually logged on this day.
  final bool hadActivity;

  /// Actual kcal for this day — shown below the dot when available.
  final int? calories;

  @override
  Widget build(BuildContext context) {
    final cal = calories;
    // Green filled = today OR past day with activity
    final isDone = isToday ? hadActivity : (isPast && hadActivity);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: isToday ? const Color(0xFF22C55E) : const Color(0xFF9CA3AF),
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDone ? const Color(0xFF22C55E) : Colors.transparent,
            shape: BoxShape.circle,
            border: isDone
                ? null
                : Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : isToday
                ? const Icon(Icons.circle, size: 8, color: Color(0xFF9CA3AF))
                : isPast
                ? const Icon(
                    Icons.remove_rounded,
                    size: 14,
                    color: Color(0xFFD1D5DB),
                  )
                : const Icon(
                    Icons.more_horiz_rounded,
                    size: 14,
                    color: Color(0xFFD1D5DB),
                  ),
          ),
        ),
        if (cal != null && cal > 0) ...[
          const SizedBox(height: 4),
          Text(
            '${cal > 999 ? '${(cal / 1000).toStringAsFixed(1)}k' : cal}',
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: isToday
                  ? const Color(0xFF22C55E)
                  : const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Summary Card (Apple Health style) ────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.bg,
    required this.label,
    required this.timeLabel,
    required this.valueText,
    required this.unit,
    required this.bars,
    required this.barColor,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color bg;
  final String label;
  final String timeLabel;
  final String valueText;
  final String unit;
  final List<double> bars; // 7 values 0.05–1.0, oldest→newest
  final Color barColor;
  final VoidCallback onTap;

  /// Optional small line shown below the value (e.g. "139 kcal active").
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: icon + label + time + chevron
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 17, color: iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
                Text(
                  timeLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Color(0xFF9CA3AF),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Value row + sparkline bars
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Value + optional subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: valueText,
                              style: GoogleFonts.poppins(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            if (unit.isNotEmpty)
                              TextSpan(
                                text: unit,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Sparkline bars
                _Sparkline(bars: bars, color: barColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sparkline mini bar chart ──────────────────────────────────────────────────

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.bars, required this.color});

  /// 7 normalized values (0.05–1.0), oldest→newest. Last bar is today.
  final List<double> bars;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 32,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(bars.length, (i) {
          final isLast = i == bars.length - 1;
          final height = (bars[i] * 32).clamp(4.0, 32.0);
          return Container(
            width: 6,
            height: height,
            decoration: BoxDecoration(
              color: isLast ? color : color.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }
}

class _OutlinedWhiteButton extends StatelessWidget {
  const _OutlinedWhiteButton({
    required this.label,
    required this.onTap,
    this.fullWidth = false,
    this.small = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool fullWidth;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          horizontal: small ? 12 : 16,
          vertical: small ? 6 : 10,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          textAlign: fullWidth ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.poppins(
            fontSize: small ? 11 : 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── Workout Summary Card ──────────────────────────────────────────────────────

class _WorkoutSummaryCard extends StatelessWidget {
  const _WorkoutSummaryCard({required this.todayWorkout, required this.onTap});
  final TodayWorkout? todayWorkout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final workout = todayWorkout;
    final isRest = workout == null || workout.exercises.isEmpty;
    final exercises = workout?.exercises ?? [];
    final planLabel = workout != null
        ? workout.planType.toUpperCase().replaceAll('_', ' ')
        : '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE4E6),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFE4E6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fitness_center_rounded,
                    size: 17,
                    color: Color(0xFFBE123C),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Workout',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
                Text(
                  isRest ? 'Rest Day' : 'Planned',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Color(0xFF9CA3AF),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRest ? 'Rest' : workout.dayLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!isRest) ...[
                        const SizedBox(height: 2),
                        Text(
                          '$planLabel · ${exercises.length} exercises',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          exercises
                                  .take(3)
                                  .map((e) => e.exerciseName)
                                  .join(', ') +
                              (exercises.length > 3 ? '…' : ''),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF374151),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                _Sparkline(
                  bars: List.generate(7, (i) => i == 6 && !isRest ? 0.8 : 0.05),
                  color: const Color(0xFFBE123C),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hydration Card ────────────────────────────────────────────────────────────

class _HydrationCard extends StatelessWidget {
  const _HydrationCard({
    required this.summary,
    required this.weekly,
    required this.onAdd,
  });
  final HydrationDailySummary? summary;
  final List<HydrationWeeklyEntry> weekly;
  final void Function(int ml) onAdd;

  @override
  Widget build(BuildContext context) {
    final totalMl = summary?.totalMl ?? 0.0;
    final goalMl = summary?.dailyGoalMl ?? 2500.0;
    final pct = (totalMl / goalMl).clamp(0.0, 1.0);

    final bars = weekly.isNotEmpty
        ? weekly.map((e) => (e.totalMl / e.goalMl).clamp(0.05, 1.0)).toList()
        : List.filled(7, 0.05);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFDBEAFE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  size: 17,
                  color: Color(0xFF1D4ED8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Hydration',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
              Text(
                'Today',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFF9CA3AF),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: totalMl >= 1000
                                ? (totalMl / 1000).toStringAsFixed(1)
                                : totalMl.round().toString(),
                            style: GoogleFonts.poppins(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          TextSpan(
                            text: totalMl >= 1000 ? 'L' : 'ml',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 5,
                        backgroundColor: const Color(0xFF93C5FD),
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${(goalMl / 1000).toStringAsFixed(1)}L goal · ${(pct * 100).round()}% done',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _Sparkline(bars: bars, color: const Color(0xFF1D4ED8)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _QuickAddButton(label: '+250ml', onTap: () => onAdd(250)),
              const SizedBox(width: 8),
              _QuickAddButton(label: '+500ml', onTap: () => onAdd(500)),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAddButton extends StatelessWidget {
  const _QuickAddButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1D4ED8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
