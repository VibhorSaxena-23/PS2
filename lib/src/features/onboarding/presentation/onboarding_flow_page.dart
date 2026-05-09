import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../gym/data/gym_api.dart';
import '../../gym/models/gym_models.dart';
import '../../profile/data/profile_api.dart';
import 'gym_selection_page.dart';
import 'plan_enroll_page.dart';
import 'profile_setup_page.dart';

enum _OnboardingStep {
  profile,
  gym,
  plan,
}

class OnboardingFlowPage extends StatefulWidget {
  const OnboardingFlowPage({
    super.key,
    required this.profileApi,
    required this.gymApi,
    required this.onCompleted,
  });

  final ProfileApi profileApi;
  final GymApi gymApi;
  final VoidCallback onCompleted;

  @override
  State<OnboardingFlowPage> createState() => _OnboardingFlowPageState();
}

class _OnboardingFlowPageState extends State<OnboardingFlowPage> {
  _OnboardingStep _step = _OnboardingStep.profile;
  GymMembership? _membership;

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _OnboardingStep.profile:
        return ProfileSetupPage(
          profileApi: widget.profileApi,
          onComplete: (_) {
            setState(() {
              _step = _OnboardingStep.gym;
            });
          },
        );
      case _OnboardingStep.gym:
        return GymSelectionPage(
          gymApi: widget.gymApi,
          onGymJoined: (membership, _) {
            setState(() {
              _membership = membership;
              _step = _OnboardingStep.plan;
            });
          },
          onSkip: widget.onCompleted,
          onBack: () => setState(() => _step = _OnboardingStep.profile),
        );
      case _OnboardingStep.plan:
        final membership = _membership;
        if (membership == null) {
          return const SizedBox.shrink();
        }

        return PlanEnrollPage(
          gymApi: widget.gymApi,
          gymId: membership.gymId,
          gymName: membership.gymName,
          onComplete: (_) => widget.onCompleted(),
          onSkip: widget.onCompleted,
          onBack: () => setState(() => _step = _OnboardingStep.gym),
        );
    }
  }
}

bool isProfileMissingError(Object error) {
  if (error is ApiException && error.statusCode == 404) {
    return true;
  }

  final text = error.toString().toLowerCase();
  return text.contains('profile not found');
}
