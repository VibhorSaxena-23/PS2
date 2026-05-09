import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/landing_page.dart';
import '../../dashboard/data/dashboard_api.dart';
import '../../dashboard/models/dashboard_models.dart';
import '../../gym/data/gym_api.dart';
import '../../gym/models/gym_models.dart';
import '../../workout/data/local_plan_service.dart';
import '../../workout/data/workout_api.dart';
import '../data/profile_api.dart';
import '../models/profile_models.dart';

// ── Main Page ────────────────────────────────────────────────────────────────

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.profileApi,
    this.workoutApi,
    this.gymApi,
    this.dashboardApi,
    this.onSwitchTab,
  });

  final ProfileApi profileApi;
  final WorkoutApi? workoutApi;
  final GymApi? gymApi;
  final DashboardApi? dashboardApi;

  /// Callback to switch to another bottom-nav tab by index.
  /// 0=Home, 1=Discover, 2=Activity, 3=Profile
  final ValueChanged<int>? onSwitchTab;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  UserProfile? _profile;
  ProgressDashboard? _dashboard;
  String? _activePlanType;
  GymMembership? _membership;
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
      // Fetch profile (required) and other data (optional, in parallel)
      final results = await Future.wait<dynamic>([
        widget.profileApi.get(),
        _fetchDashboard(),
        _fetchActivePlan(),
        _fetchMembership(),
      ]);

      if (!mounted) return;
      setState(() {
        _profile = results[0] as UserProfile?;
        _dashboard = results[1] as ProgressDashboard?;
        _activePlanType = results[2] as String?;
        _membership = results[3] as GymMembership?;
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

  Future<ProgressDashboard?> _fetchDashboard() async {
    try {
      return await widget.dashboardApi?.getDashboard();
    } catch (_) {
      return null;
    }
  }

  Future<String?> _fetchActivePlan() async {
    try {
      if (widget.workoutApi != null) {
        final plan = await widget.workoutApi!.getActivePlan();
        if (plan != null) {
          return plan.planType;
        }
      } else {
        return await LocalPlanService.getPlanType();
      }
    } catch (_) {
      try {
        return await LocalPlanService.getPlanType();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<GymMembership?> _fetchMembership() async {
    try {
      final memberships = await widget.gymApi?.getMemberships();
      return memberships
          ?.where((m) => m.status.toUpperCase() == 'ACTIVE')
          .firstOrNull;
    } catch (_) {
      return null;
    }
  }

  int get _workoutCount => _dashboard?.today.workoutsCompleted ?? 0;

  int get _activePlanCount => _activePlanType != null ? 1 : 0;

  int get _dayStreak => _dashboard?.last7Days.activeDays ?? 0;

  void _switchTab(int index) {
    widget.onSwitchTab?.call(index);
  }

  void _showEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditProfileSheet(
        profile: _profile,
        api: widget.profileApi,
        onSaved: (updated) {
          setState(() => _profile = updated);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showMembershipDetails() {
    if (_membership == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MembershipDetailsPage(
          membership: _membership!,
          activePlanType: _activePlanType,
          onOpenDiscover: () => _switchTab(1),
          onOpenActivity: () => _switchTab(2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: _loading && _profile == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _profile == null
          ? _buildError()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildHeader(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        _buildStatsRow(),
                        const SizedBox(height: 24),
                        _buildMembershipSection(),
                        const SizedBox(height: 24),
                        _buildSection('Payment & Billing', [
                          _MenuTile(
                            icon: Icons.credit_card_rounded,
                            title: 'Payment Summary',
                            subtitle: 'Membership payment status',
                            onTap: () => _showPlaceholder('Payment Summary'),
                          ),
                          _MenuTile(
                            icon: Icons.receipt_long_rounded,
                            title: 'Billing History',
                            subtitle: 'View membership records',
                            onTap: () => _showPlaceholder('Billing History'),
                          ),
                        ]),
                        const SizedBox(height: 24),
                        // Sessions tile — below Payment & Billing (matches screenshot)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: _MenuTile(
                            icon: Icons.calendar_month_rounded,
                            title: 'Sessions',
                            subtitle: 'View all sessions',
                            onTap: () => _switchTab(2),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSection('Settings', [
                          _MenuTile(
                            icon: Icons.notifications_outlined,
                            title: 'Notifications',
                            subtitle: 'Manage alerts',
                            onTap: () => _showPlaceholder('Notifications'),
                          ),
                          _MenuTile(
                            icon: Icons.lock_outline_rounded,
                            title: 'Privacy',
                            subtitle: 'Data & security',
                            onTap: () => _showPlaceholder('Privacy'),
                          ),
                          _MenuTile(
                            icon: Icons.settings_outlined,
                            title: 'Preferences',
                            subtitle: 'App settings',
                            onTap: () => _showPlaceholder('Preferences'),
                          ),
                        ]),
                        const SizedBox(height: 24),
                        _buildSection('Help & Support', [
                          _MenuTile(
                            icon: Icons.headset_mic_outlined,
                            title: 'Contact Support',
                            subtitle: 'Help center and next steps',
                            onTap: () => _showPlaceholder('Contact Support'),
                          ),
                          _MenuTile(
                            icon: Icons.help_outline_rounded,
                            title: 'FAQ',
                            subtitle: 'Quick app answers',
                            onTap: () => _showPlaceholder('FAQ'),
                          ),
                        ]),
                        const SizedBox(height: 24),
                        _buildLogout(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44, color: AppColors.error),
            const SizedBox(height: 10),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
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

  // ── Header with avatar ─────────────────────────────────────────────────────

  Widget _buildHeader() {
    final displayName = _profile?.displayName ?? 'Flex Athlete';

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 28,
        bottom: 28,
        left: 16,
        right: 16,
      ),
      color: Colors.white,
      child: Column(
        children: [
          // Avatar
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.divider, width: 2),
                ),
                child: const Center(
                  child: Icon(
                    Icons.person_rounded,
                    size: 42,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _showEditSheet,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.btnDark,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.edit, size: 13, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Display name
          Text(
            displayName,
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          // Goal badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 13,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 4),
                Text(
                  _profile?.role ?? 'MEMBER',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats row ──────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          _StatCell(
            value: '$_workoutCount',
            label: 'Workouts',
            onTap: () => _switchTab(2),
          ),
          Container(width: 1, height: 36, color: AppColors.divider),
          _StatCell(
            value: '$_activePlanCount',
            label: 'Active Plan',
            onTap: () => _switchTab(2),
          ),
          Container(width: 1, height: 36, color: AppColors.divider),
          _StatCell(
            value: '$_dayStreak',
            label: 'Day Streak',
            onTap: () => _switchTab(0),
          ),
        ],
      ),
    );
  }

  // ── Membership ─────────────────────────────────────────────────────────────

  Widget _buildMembershipSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Membership',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _membership != null
            ? GestureDetector(
                onTap: _showMembershipDetails,
                child: _buildActiveMembershipCard(),
              )
            : _buildNoMembershipCard(),
      ],
    );
  }

  Widget _buildActiveMembershipCard() {
    final m = _membership!;
    final endLabel = m.endDate != null
        ? DateFormat('MMMM d, yyyy').format(m.endDate!)
        : 'Ongoing';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(40),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Active Plan',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  m.gymName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Valid until\n$endLabel',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withAlpha(180),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.badge_outlined,
            size: 36,
            color: Colors.white.withAlpha(60),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: Colors.white.withAlpha(120)),
        ],
      ),
    );
  }

  Widget _buildNoMembershipCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(
            Icons.card_membership_outlined,
            size: 36,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 8),
          Text(
            'No active membership',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Join a gym to see your plan here',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section builder ────────────────────────────────────────────────────────

  Widget _buildSection(String title, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              for (int i = 0; i < tiles.length; i++) ...[
                tiles[i],
                if (i < tiles.length - 1)
                  const Divider(height: 1, indent: 56, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  Widget _buildLogout() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showLogoutDialog(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.logout_rounded,
                size: 20,
                color: AppColors.error,
              ),
              const SizedBox(width: 8),
              Text(
                'Log Out',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Log Out',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await AuthApi.instance.logout();
              await AuthService.instance.clearAll();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LandingPage()),
                (route) => false,
              );
            },
            child: const Text(
              'Log Out',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showPlaceholder(String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PlaceholderPage(
          title: title,
          profile: _profile,
          dashboard: _dashboard,
          activePlanType: _activePlanType,
          membership: _membership,
          onSwitchTab: widget.onSwitchTab,
        ),
      ),
    );
  }
}

// ── Stat cell ────────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label, this.onTap});

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Menu tile ────────────────────────────────────────────────────────────────

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.scaffoldBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Edit Profile Sheet ───────────────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    this.profile,
    required this.api,
    required this.onSaved,
  });

  final UserProfile? profile;
  final ProfileApi api;
  final ValueChanged<UserProfile> onSaved;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _firstNameCtrl = TextEditingController(text: p?.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: p?.lastName ?? '');
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final result = await widget.api.update(
        firstName: _firstNameCtrl.text.trim().isEmpty
            ? null
            : _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim().isEmpty
            ? null
            : _lastNameCtrl.text.trim(),
      );
      widget.onSaved(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            'Edit Profile',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _firstNameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'First Name',
              filled: true,
              fillColor: AppColors.scaffoldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lastNameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Last Name',
              filled: true,
              fillColor: AppColors.scaffoldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.btnDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profile info page ────────────────────────────────────────────────────────

class _PlaceholderPage extends StatefulWidget {
  const _PlaceholderPage({
    required this.title,
    this.profile,
    this.dashboard,
    this.activePlanType,
    this.membership,
    this.onSwitchTab,
  });

  final String title;
  final UserProfile? profile;
  final ProgressDashboard? dashboard;
  final String? activePlanType;
  final GymMembership? membership;
  final ValueChanged<int>? onSwitchTab;

  @override
  State<_PlaceholderPage> createState() => _PlaceholderPageState();
}

class _PlaceholderPageState extends State<_PlaceholderPage> {
  static const _notifWorkoutKey = 'profile_notif_workout';
  static const _notifGymKey = 'profile_notif_gym';

  bool _loadingPrefs = true;
  bool _workoutReminders = true;
  bool _gymAlerts = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    if (widget.title != 'Notifications') {
      if (mounted) setState(() => _loadingPrefs = false);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _workoutReminders = prefs.getBool(_notifWorkoutKey) ?? true;
      _gymAlerts = prefs.getBool(_notifGymKey) ?? true;
      _loadingPrefs = false;
    });
  }

  Future<void> _setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _clearSavedPlan() async {
    await LocalPlanService.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Saved active plan cleared')));
  }

  String _planLabel(String? planType) {
    if (planType == null || planType.trim().isEmpty) return 'No active plan';
    switch (planType) {
      case 'ppl':
        return 'PPL';
      case 'bro':
        return 'Bro Split';
      case 'full_body':
        return 'Full Body';
      default:
        return planType.startsWith('custom:') ? 'Custom' : planType;
    }
  }

  String _membershipStatus() {
    final m = widget.membership;
    if (m == null) return 'No active membership';
    final end = m.endDate;
    if (end == null) return '${m.gymName} · Active';
    return '${m.gymName} · Expires ${DateFormat('MMM d, yyyy').format(end)}';
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _factRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final dashboard = widget.dashboard;
    final title = widget.title;
    final workoutsCompleted = dashboard?.today.workoutsCompleted ?? 0;
    final activeDays = dashboard?.last7Days.activeDays ?? 0;
    final activePlanLabel = _planLabel(widget.activePlanType);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
      ),
      body: _loadingPrefs && title == 'Notifications'
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionCard(
                  title: 'Live account',
                  children: [
                    _factRow('Name', profile?.displayName ?? 'Flex Athlete'),
                    _factRow('Role', profile?.role ?? 'Member'),
                    _factRow('Membership', _membershipStatus()),
                    _factRow('Active plan', activePlanLabel),
                    _factRow('Today workouts', '$workoutsCompleted'),
                    _factRow('Active days', '$activeDays'),
                  ],
                ),
                const SizedBox(height: 16),
                if (title == 'Payment Summary' || title == 'Billing History')
                  _sectionCard(
                    title: 'Membership details',
                    children: [
                      _factRow(
                        'Gym',
                        widget.membership?.gymName ?? 'No gym connected',
                      ),
                      _factRow(
                        'Status',
                        widget.membership?.status ?? 'Inactive',
                      ),
                      _factRow(
                        'Plan',
                        widget.activePlanType == null
                            ? 'None'
                            : _planLabel(widget.activePlanType),
                      ),
                    ],
                  ),
                if (title == 'Payment Summary' || title == 'Billing History')
                  const SizedBox(height: 16),
                if (title == 'Notifications')
                  _sectionCard(
                    title: 'Notification preferences',
                    children: [
                      SwitchListTile.adaptive(
                        value: _workoutReminders,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Workout reminders'),
                        subtitle: const Text('Saved locally on this device'),
                        onChanged: (value) async {
                          setState(() => _workoutReminders = value);
                          await _setBool(_notifWorkoutKey, value);
                        },
                      ),
                      SwitchListTile.adaptive(
                        value: _gymAlerts,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Gym updates'),
                        subtitle: const Text('Saved locally on this device'),
                        onChanged: (value) async {
                          setState(() => _gymAlerts = value);
                          await _setBool(_notifGymKey, value);
                        },
                      ),
                    ],
                  ),
                if (title == 'Notifications') const SizedBox(height: 16),
                if (title == 'Privacy')
                  _sectionCard(
                    title: 'Privacy controls',
                    children: [
                      _factRow(
                        'Stored on device',
                        'Active plan, mood, preferences',
                      ),
                      _factRow('Cloud data', 'Profile, workouts, memberships'),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _clearSavedPlan,
                          child: const Text('Clear saved active plan'),
                        ),
                      ),
                    ],
                  ),
                if (title == 'Privacy') const SizedBox(height: 16),
                if (title == 'Preferences')
                  _sectionCard(
                    title: 'Training preferences',
                    children: [
                      _factRow('Current focus', activePlanLabel),
                      _factRow(
                        'Membership',
                        widget.membership?.gymName ?? 'No gym selected',
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ActionPill(
                            label: 'Open Workout Tab',
                            onTap: () => widget.onSwitchTab?.call(2),
                          ),
                          _ActionPill(
                            label: 'Open Discover',
                            onTap: () => widget.onSwitchTab?.call(1),
                          ),
                        ],
                      ),
                    ],
                  ),
                if (title == 'Preferences') const SizedBox(height: 16),
                if (title == 'Contact Support' || title == 'FAQ')
                  _sectionCard(
                    title: 'Help center',
                    children: [
                      _factRow(
                        'QR check-in',
                        'Use Home tab to scan your gym QR',
                      ),
                      _factRow(
                        'Active plan',
                        'Set once in Workout tab and keep it',
                      ),
                      _factRow(
                        'Discover',
                        'Search gyms by name, location, or description',
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ActionPill(
                            label: 'Open Home',
                            onTap: () => widget.onSwitchTab?.call(0),
                          ),
                          _ActionPill(
                            label: 'Open Workout',
                            onTap: () => widget.onSwitchTab?.call(2),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _MembershipDetailsPage extends StatelessWidget {
  const _MembershipDetailsPage({
    required this.membership,
    required this.activePlanType,
    required this.onOpenDiscover,
    required this.onOpenActivity,
  });

  final GymMembership membership;
  final String? activePlanType;
  final VoidCallback onOpenDiscover;
  final VoidCallback onOpenActivity;

  String _formatPlanLabel() {
    final planType = activePlanType;
    if (planType == null || planType.trim().isEmpty) return 'Not linked yet';
    switch (planType) {
      case 'ppl':
        return 'PPL';
      case 'bro':
        return 'Bro Split';
      case 'full_body':
        return 'Full Body';
      default:
        return planType.startsWith('custom:') ? 'Custom' : planType;
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Ongoing';
    return DateFormat('MMMM d, yyyy').format(value);
  }

  Widget _factRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          'Membership Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(40),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    membership.status.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  membership.gymName,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your current gym membership and linked training details.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withAlpha(190),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Membership summary',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                _factRow('Gym', membership.gymName),
                _factRow('Membership ID', membership.id),
                _factRow('Status', membership.status),
                _factRow('Workout plan', _formatPlanLabel()),
                _factRow('Start date', _formatDate(membership.startDate)),
                _factRow('End date', _formatDate(membership.endDate)),
                _factRow('Joined on', _formatDate(membership.createdAt)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick actions',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ActionPill(
                      label: 'Open Discover',
                      onTap: () {
                        Navigator.of(context).pop();
                        onOpenDiscover();
                      },
                    ),
                    _ActionPill(
                      label: 'Open Activity',
                      onTap: () {
                        Navigator.of(context).pop();
                        onOpenActivity();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
