import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_service.dart';
import 'features/auth/presentation/landing_page.dart';
import 'features/gym/data/gym_api.dart';
import 'features/gym/presentation/gym_hub_page.dart';
import 'features/activity/presentation/activity_page.dart';
import 'features/hydration/data/hydration_api.dart';
import 'features/home/presentation/home_page.dart'
    show HomeTabPage, HomeTabPageState;
import 'features/profile/data/profile_api.dart';
import 'features/profile/presentation/profile_page.dart';
import 'features/dashboard/data/dashboard_api.dart';
import 'features/workout/data/workout_api.dart';

enum _AppStage { bootstrapping, auth, home }

class FlexiCurlApp extends StatefulWidget {
  const FlexiCurlApp({super.key});

  @override
  State<FlexiCurlApp> createState() => _FlexiCurlAppState();
}

class _FlexiCurlAppState extends State<FlexiCurlApp> {
  _AppStage _stage = _AppStage.bootstrapping;
  String? _startupWarning;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final loggedIn = await AuthService.instance.isLoggedIn();
    if (!mounted) return;

    final warn = !kDebugMode && AppConfig.isUsingLocalBackend
        ? 'App is using local API URLs. Set API_BASE_URL/WEB_API_BASE_URL for production.'
        : null;
    setState(() {
      _stage = loggedIn ? _AppStage.home : _AppStage.auth;
      _startupWarning = warn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlexiCurl',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: switch (_stage) {
        _AppStage.bootstrapping => const _BootPage(),
        _AppStage.auth => const LandingPage(),
        _AppStage.home => AppHomeEntry(startupWarning: _startupWarning),
      },
    );
  }
}

class AppHomeEntry extends StatefulWidget {
  const AppHomeEntry({super.key, this.startupWarning});

  final String? startupWarning;

  @override
  State<AppHomeEntry> createState() => _AppHomeEntryState();
}

class _AppHomeEntryState extends State<AppHomeEntry> {
  late final ApiClient _mobileClient;
  late final ApiClient _webClient;

  @override
  void initState() {
    super.initState();
    _mobileClient = ApiClient(
      baseUrl: AppConfig.apiBaseUrl,
      userId: AppConfig.userId,
    );
    _webClient = ApiClient(
      baseUrl: AppConfig.webApiBaseUrl,
      userId: AppConfig.userId,
    );
  }

  @override
  void dispose() {
    _mobileClient.dispose();
    _webClient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HomePage(
      gymApi: GymApi(_webClient),
      profileApi: ProfileApi(_webClient),
      dashboardApi: DashboardApi(_mobileClient),
      workoutApi: WorkoutApi(_mobileClient),
      hydrationApi: HydrationApi(_mobileClient),
      startupWarning: widget.startupWarning,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.gymApi,
    required this.profileApi,
    required this.dashboardApi,
    required this.workoutApi,
    required this.hydrationApi,
    this.startupWarning,
  });

  final GymApi gymApi;
  final ProfileApi profileApi;
  final DashboardApi dashboardApi;
  final WorkoutApi workoutApi;
  final HydrationApi hydrationApi;
  final String? startupWarning;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  bool _warned = false;
  final _homeKey = GlobalKey<HomeTabPageState>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_warned && widget.startupWarning != null) {
      _warned = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(widget.startupWarning!)));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeTabPage(
        key: _homeKey,
        workoutApi: widget.workoutApi,
        gymApi: widget.gymApi,
        hydrationApi: widget.hydrationApi,
        onSwitchTab: (i) => setState(() => _index = i),
      ),
      GymHubPage(gymApi: widget.gymApi),
      ActivityPage(
        gymApi: widget.gymApi,
        workoutApi: widget.workoutApi,
        hydrationApi: widget.hydrationApi,
      ),
      ProfilePage(
        profileApi: widget.profileApi,
        workoutApi: widget.workoutApi,
        gymApi: widget.gymApi,
        dashboardApi: widget.dashboardApi,
        onSwitchTab: (index) => setState(() => _index = index),
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected
                  ? const Color(0xFF15803D)
                  : const Color(0xFF6B7280),
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: selected ? 24 : 23,
              color: selected
                  ? const Color(0xFF16A34A)
                  : const Color(0xFF6B7280),
            );
          }),
        ),
        child: NavigationBar(
          height: 74,
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          indicatorColor: const Color(0xFFEAF8F0),
          shadowColor: Colors.black.withValues(alpha: 0.08),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: _index,
          onDestinationSelected: (value) {
            setState(() => _index = value);
            if (value == 0) _homeKey.currentState?.reload();
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore_rounded),
              label: 'Discover',
            ),
            NavigationDestination(
              icon: Icon(Icons.directions_run_outlined),
              selectedIcon: Icon(Icons.directions_run_rounded),
              label: 'Activity',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _BootPage extends StatelessWidget {
  const _BootPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 14),
                Text('Preparing FlexiCurl...'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
