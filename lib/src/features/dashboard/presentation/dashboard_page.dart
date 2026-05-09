import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../nutrition/data/nutrition_api.dart';
import '../../nutrition/models/nutrition_models.dart';
import '../../workout/data/workout_api.dart';
import '../../workout/models/workout_models.dart';
import '../data/dashboard_api.dart';
import '../models/dashboard_models.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.dashboardApi,
    required this.nutritionApi,
    required this.workoutApi,
  });

  final DashboardApi dashboardApi;
  final NutritionApi nutritionApi;
  final WorkoutApi workoutApi;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}
class _DashboardPageState extends State<DashboardPage> {
  ProgressDashboard? _dashboard;
  DailyNutritionSummary? _dailyNutrition;
  SessionHistoryPage? _workoutHistory;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        widget.dashboardApi.getDashboard(),
        widget.nutritionApi.getDailySummary(),
        widget.workoutApi.getHistory(page: 1, pageSize: 5),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _dashboard = results[0] as ProgressDashboard;
        _dailyNutrition = results[1] as DailyNutritionSummary;
        _workoutHistory = results[2] as SessionHistoryPage;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = _dashboard;

    if (_loading && dashboard == null) {
      return const SafeArea(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (dashboard == null) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 44, color: Color(0xFFEF4444)),
                const SizedBox(height: 10),
                Text(_error ?? 'Could not load dashboard data.'),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final nutrition = _dailyNutrition;
    final workouts = _workoutHistory;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Dashboard',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Updated ${Formatters.dateTime(dashboard.generatedAt.toLocal())}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Card(
                color: const Color(0xFFFEF3C7),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!),
                ),
              ),
            ],
            const SizedBox(height: 14),
            _TodayStatsCard(today: dashboard.today),
            const SizedBox(height: 12),
            if (nutrition != null) _MacroCard(summary: nutrition),
            if (nutrition != null) const SizedBox(height: 12),
            _WorkoutFrequencyCard(points: dashboard.visualInsights.workoutFrequency),
            const SizedBox(height: 12),
            _RecentWorkoutsCard(history: workouts),
          ],
        ),
      ),
    );
  }
}

class _TodayStatsCard extends StatelessWidget {
  const _TodayStatsCard({required this.today});

  final TodaySummary today;

  @override
  Widget build(BuildContext context) {
    final cells = [
      _Cell(
        title: 'Calories',
        value: '${today.caloriesConsumed.toStringAsFixed(0)} kcal',
        detail: today.caloriesTarget != null
            ? 'Target ${today.caloriesTarget!.toStringAsFixed(0)}'
            : 'No target',
      ),
      _Cell(
        title: 'Steps',
        value: '${today.stepCount}',
        detail: 'Goal ${today.stepGoal}',
      ),
      _Cell(
        title: 'Hydration',
        value: '${today.hydrationMl.toStringAsFixed(0)} ml',
        detail: 'Goal ${today.hydrationGoalMl.toStringAsFixed(0)} ml',
      ),
      _Cell(
        title: 'Workouts',
        value: '${today.workoutsCompleted}',
        detail: '${today.workoutVolume.toStringAsFixed(0)} kg volume',
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              itemCount: cells.length,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.45,
              ),
              itemBuilder: (_, index) => _TodayCell(cell: cells[index]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell {
  const _Cell({
    required this.title,
    required this.value,
    required this.detail,
  });

  final String title;
  final String value;
  final String detail;
}

class _TodayCell extends StatelessWidget {
  const _TodayCell({required this.cell});

  final _Cell cell;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cell.title, style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Text(
              cell.value,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(cell.detail, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  const _MacroCard({required this.summary});

  final DailyNutritionSummary summary;

  @override
  Widget build(BuildContext context) {
    final goal = summary.goalProgress;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nutrition Today',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text('Protein: ${summary.total.proteinG.toStringAsFixed(1)} g'),
            Text('Carbs: ${summary.total.carbsG.toStringAsFixed(1)} g'),
            Text('Fat: ${summary.total.fatG.toStringAsFixed(1)} g'),
            Text('Fiber: ${summary.total.fiberG.toStringAsFixed(1)} g'),
            if (goal != null) ...[
              const SizedBox(height: 8),
              Text(
                'Remaining calories: ${goal.caloriesRemaining?.toStringAsFixed(0) ?? '-'}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkoutFrequencyCard extends StatelessWidget {
  const _WorkoutFrequencyCard({required this.points});

  final List<WorkoutFrequencyPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }

    final latest = points.length > 6 ? points.sublist(points.length - 6) : points;
    final maxCount = latest
        .map((point) => point.sessionCount)
        .fold<int>(0, (prev, next) => prev > next ? prev : next);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workout Frequency',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: latest
                  .map(
                    (point) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${point.sessionCount}'),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 70,
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  height: maxCount == 0
                                      ? 4
                                      : (point.sessionCount / maxCount) * 60 + 4,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4F46E5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _weekLabel(point.weekStart),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _weekLabel(String isoDate) {
    final date = DateTime.parse(isoDate).toLocal();
    return '${date.day}/${date.month}';
  }
}

class _RecentWorkoutsCard extends StatelessWidget {
  const _RecentWorkoutsCard({required this.history});

  final SessionHistoryPage? history;

  @override
  Widget build(BuildContext context) {
    final items = history?.items ?? const <WorkoutSession>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Workouts',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              const Text('No workouts logged yet.')
            else
              ...items.map(
                (session) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    session.title?.trim().isNotEmpty == true
                        ? session.title!
                        : session.exercises.isNotEmpty
                            ? session.exercises.first.exerciseName
                            : 'Workout Session',
                  ),
                  subtitle: Text(
                    '${Formatters.dateTime(session.startedAt)} • '
                    '${session.exercises.length} exercises',
                  ),
                  trailing: Text('${session.totalVolume.toStringAsFixed(0)} kg'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
