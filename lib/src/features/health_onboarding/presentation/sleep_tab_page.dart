import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';

/// Sleep & Routine tab — lets the user set / edit their daily schedule times.
class SleepTabPage extends StatefulWidget {
  const SleepTabPage({super.key});

  @override
  State<SleepTabPage> createState() => _SleepTabPageState();
}

class _SleepTabPageState extends State<SleepTabPage> {
  static const _kWake    = 'routine_wake_time';
  static const _kSleep   = 'routine_sleep_time';
  static const _kWorkout = 'routine_workout_time';

  String? _wakeTime;
  String? _sleepTime;
  String? _workoutTime;
  bool _loading = true;
  bool _saving  = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _wakeTime    = p.getString(_kWake);
      _sleepTime   = p.getString(_kSleep);
      _workoutTime = p.getString(_kWorkout);
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final p = await SharedPreferences.getInstance();
    if (_wakeTime    != null) await p.setString(_kWake,    _wakeTime!);
    if (_sleepTime   != null) await p.setString(_kSleep,   _sleepTime!);
    if (_workoutTime != null) await p.setString(_kWorkout, _workoutTime!);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Routine saved')),
    );
  }

  Future<void> _pick(String label, ValueChanged<String> onPicked) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Set $label time',
    );
    if (picked != null) {
      onPicked(
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
      );
    }
  }

  // Duration between sleep and wake in hours (approximate)
  String get _sleepDuration {
    if (_wakeTime == null || _sleepTime == null) return '—';
    final wParts = _wakeTime!.split(':');
    final sParts = _sleepTime!.split(':');
    final wMins  = int.parse(wParts[0]) * 60 + int.parse(wParts[1]);
    var   sMins  = int.parse(sParts[0]) * 60 + int.parse(sParts[1]);
    var   diff   = wMins - sMins;
    if (diff <= 0) diff += 24 * 60;   // crosses midnight
    final h = diff ~/ 60;
    final m = diff % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text('Sleep & Routine',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Sleep duration hero card ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B4B),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.bedtime_rounded, color: Color(0xFFA78BFA), size: 40),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sleep Duration',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.white54,
                            fontWeight: FontWeight.w600)),
                    Text(_sleepDuration,
                        style: GoogleFonts.poppins(
                            fontSize: 36, fontWeight: FontWeight.w900,
                            color: Colors.white, height: 1.1)),
                    if (_wakeTime != null && _sleepTime != null)
                      Text('$_sleepTime  →  $_wakeTime',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.white38)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Time pickers ─────────────────────────────────────────────────
          _SectionLabel('Daily Schedule'),
          const SizedBox(height: 12),

          _TimeRow(
            icon: Icons.wb_sunny_rounded,
            iconColor: const Color(0xFFF59E0B),
            label: 'Wake Up',
            value: _wakeTime,
            onTap: () => _pick('wake-up', (t) => setState(() => _wakeTime = t)),
          ),
          const SizedBox(height: 10),
          _TimeRow(
            icon: Icons.bedtime_rounded,
            iconColor: const Color(0xFF6366F1),
            label: 'Bedtime',
            value: _sleepTime,
            onTap: () => _pick('bedtime', (t) => setState(() => _sleepTime = t)),
          ),
          const SizedBox(height: 10),
          _TimeRow(
            icon: Icons.fitness_center_rounded,
            iconColor: AppColors.accentGreen,
            label: 'Workout',
            value: _workoutTime,
            onTap: () => _pick('workout', (t) => setState(() => _workoutTime = t)),
          ),

          const SizedBox(height: 28),

          // ── Tips ──────────────────────────────────────────────────────────
          _SectionLabel('Sleep Tips'),
          const SizedBox(height: 12),
          _TipCard(Icons.nights_stay_rounded, const Color(0xFF6366F1),
              'Aim for 7–9 hours', 'Adults need 7–9 hrs for optimal recovery and metabolism.'),
          const SizedBox(height: 8),
          _TipCard(Icons.no_drinks_rounded, const Color(0xFF0EA5E9),
              'Limit caffeine after 2 PM', 'Caffeine has a 5–6 hour half-life — avoid it late in the day.'),
          const SizedBox(height: 8),
          _TipCard(Icons.phone_android_rounded, const Color(0xFFF59E0B),
              'No screens 30 min before bed', 'Blue light suppresses melatonin and delays sleep onset.'),

          const SizedBox(height: 28),

          // ── Save button ───────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Save Routine',
                      style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.3,
        ),
      );
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.inputBorder, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ),
            Text(
              value ?? 'Tap to set',
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: value != null ? AppColors.textPrimary : AppColors.textMuted),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard(this.icon, this.color, this.title, this.body);
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(body,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
