import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../workout/data/workout_api.dart';
import '../../workout/presentation/workout_page.dart';

class WorkoutStatDetailPage extends StatelessWidget {
  const WorkoutStatDetailPage({super.key});

  static const _weekFreq = [1, 0, 1, 1, 0, 1, 0]; // Mon–Sun
  static const _weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _prs = [
    _PR('Bench Press', '82.5 kg', '+2.5 kg', Color(0xFF4F46E5)),
    _PR('Deadlift', '125 kg', '+5 kg', Color(0xFF059669)),
    _PR('Barbell Squat', '105 kg', '+2.5 kg', Color(0xFF7C3AED)),
  ];

  WorkoutApi _createWorkoutApi() {
    final client = ApiClient(
      baseUrl: AppConfig.apiBaseUrl,
      userId: AppConfig.userId,
    );
    return WorkoutApi(client);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C3AED),
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(
          'Workout Stats',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WorkoutPage(workoutApi: _createWorkoutApi()),
              ),
            ),
            child: Text(
              'View All',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Summary header ───────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _HeaderStat(label: 'This Week', value: '4'),
                    _Divider(),
                    _HeaderStat(label: 'Volume', value: '24.5k kg'),
                    _Divider(),
                    _HeaderStat(label: 'Avg Duration', value: '62 min'),
                  ],
                ),
                const SizedBox(height: 24),
                // Weekly frequency dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(_weekDays.length, (i) {
                    final done = _weekFreq[i] == 1;
                    return Column(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: done
                                ? Colors.white
                                : Colors.white.withAlpha(30),
                            shape: BoxShape.circle,
                          ),
                          child: done
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: Color(0xFF7C3AED),
                                )
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _weekDays[i],
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.white.withAlpha(200),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Monthly stats ────────────────────────────────────────────
          Row(
            children: [
              _StatCard(
                label: 'This Month',
                value: '14',
                sub: 'sessions',
                color: const Color(0xFF7C3AED),
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Streak',
                value: '6',
                sub: 'days',
                color: const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Total Volume',
                value: '98k',
                sub: 'kg this month',
                color: const Color(0xFF059669),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Personal records ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personal Records',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                ..._prs.map(
                  (pr) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: pr.color.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.fitness_center_rounded,
                            size: 20,
                            color: pr.color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pr.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                pr.weight,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentGreenSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            pr.gain,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentGreen,
                            ),
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
      ),
    );
  }
}

class _PR {
  const _PR(this.name, this.weight, this.gain, this.color);
  final String name;
  final String weight;
  final String gain;
  final Color color;
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.white.withAlpha(180),
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: Colors.white.withAlpha(60));
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });
  final String label;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              sub,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
