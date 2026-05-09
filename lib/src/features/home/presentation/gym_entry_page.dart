import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

class GymEntryPage extends StatelessWidget {
  const GymEntryPage({super.key});

  static const _checkIns = [
    ('Today', '9:14 AM', '58 min'),
    ('Yesterday', '7:30 AM', '72 min'),
    ('Mon, Mar 24', '8:00 AM', '65 min'),
    ('Sat, Mar 22', '10:15 AM', '45 min'),
    ('Thu, Mar 20', '7:45 AM', '80 min'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF059669),
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text('Gym Entry',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, color: Colors.white)),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Membership card ──────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Iron House Gym',
                              style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          Text('Premium Membership',
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.white.withAlpha(200))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF059669),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('Active',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF059669))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // QR code placeholder
                Center(
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.qr_code_2_rounded,
                            size: 80, color: Color(0xFF1A1A2E)),
                        Text('Scan to Enter',
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white24),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _CardInfo(
                        label: 'Member Since', value: 'Jan 2025'),
                    _CardInfo(
                        label: 'Expires', value: 'Dec 2025'),
                    _CardInfo(
                        label: 'Visits', value: '42'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── This month stats ─────────────────────────────────────────
          Row(
            children: [
              _StatBox(
                  icon: Icons.calendar_month_rounded,
                  label: 'This Month',
                  value: '14 visits',
                  color: const Color(0xFF059669)),
              const SizedBox(width: 12),
              _StatBox(
                  icon: Icons.timer_rounded,
                  label: 'Avg Duration',
                  value: '64 min',
                  color: const Color(0xFF0891B2)),
            ],
          ),
          const SizedBox(height: 16),

          // ── Recent check-ins ─────────────────────────────────────────
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
                Text('Recent Check-ins',
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                ..._checkIns.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF059669).withAlpha(15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.login_rounded,
                              size: 20, color: Color(0xFF059669)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.$1,
                                  style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary)),
                              Text(c.$2,
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.scaffoldBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(c.$3,
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary)),
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

class _CardInfo extends StatelessWidget {
  const _CardInfo({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.white.withAlpha(180))),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: color.withAlpha(20), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  Text(label,
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
