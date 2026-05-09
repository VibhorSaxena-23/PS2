import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../app.dart';
import '../../auth/data/auth_service.dart';
import '../../dashboard/data/dashboard_api.dart';
import '../../gym/data/gym_api.dart';
import '../../hydration/data/hydration_api.dart';
import '../../onboarding/presentation/onboarding_flow_page.dart';
import '../../profile/data/profile_api.dart';
import '../../workout/data/workout_api.dart';
import '../data/health_onboarding_api.dart';
import 'health_onboarding_flow.dart';

/// Called after every successful login or registration.
///
/// Decision tree:
///   1. Health onboarding NOT done  -> HealthOnboardingFlow
///   2. Profile NOT set up (404)    -> existing OnboardingFlowPage
///   3. All done                    -> HomePage
///
/// All navigation is push-and-remove-until so the stack is always clean.
class PostAuthRouter extends StatefulWidget {
  const PostAuthRouter({super.key});

  @override
  State<PostAuthRouter> createState() => _PostAuthRouterState();
}

class _PostAuthRouterState extends State<PostAuthRouter> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    // Small delay so the splash transition is visible.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final mobileClient = ApiClient(
      baseUrl: AppConfig.apiBaseUrl,
      userId: AppConfig.userId,
    );
    final webClient = ApiClient(
      baseUrl: AppConfig.webApiBaseUrl,
      userId: AppConfig.userId,
    );

    // 1. Health onboarding gate
    final healthDone = await AuthService.instance.isHealthOnboardingCompleted();
    if (!mounted) return;

    if (!healthDone) {
      _push(
        HealthOnboardingFlow(
          api: HealthOnboardingApi(mobileClient),
          profileApi: ProfileApi(webClient),
          onCompleted: () => _goHome(mobileClient, webClient),
        ),
      );
      return;
    }

    // 2. Check if profile exists
    final profileApi = ProfileApi(webClient);
    try {
      await profileApi.get();
    } catch (e) {
      if (!mounted) return;
      if (isProfileMissingError(e)) {
        _push(
          OnboardingFlowPage(
            profileApi: profileApi,
            gymApi: GymApi(webClient),
            onCompleted: () => _goHome(mobileClient, webClient),
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    _goHome(mobileClient, webClient);
  }

  void _push(Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (ctx, a, b) => page,
        transitionsBuilder: (ctx, animation, b, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _goHome(ApiClient mobileClient, ApiClient webClient) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (ctx, a, b) => HomePage(
          gymApi: GymApi(webClient),
          profileApi: ProfileApi(webClient),
          dashboardApi: DashboardApi(mobileClient),
          workoutApi: WorkoutApi(mobileClient),
          hydrationApi: HydrationApi(mobileClient),
        ),
        transitionsBuilder: (ctx, animation, b, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
