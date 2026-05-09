import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/onboarding_scaffold.dart';
import '../../gym/data/gym_api.dart';
import '../../gym/models/gym_models.dart';

class PlanEnrollPage extends StatefulWidget {
  const PlanEnrollPage({
    super.key,
    required this.gymApi,
    required this.gymId,
    required this.gymName,
    required this.onComplete,
    required this.onSkip,
    this.onBack,
  });

  final GymApi gymApi;
  final String gymId;
  final String gymName;
  final ValueChanged<GymEnrollment> onComplete;
  final VoidCallback onSkip;
  final VoidCallback? onBack;

  @override
  State<PlanEnrollPage> createState() => _PlanEnrollPageState();
}

class _PlanEnrollPageState extends State<PlanEnrollPage> {
  List<GymPlan>? _plans;
  bool _loading = true;
  String? _error;
  String? _selectedPlanId;
  bool _enrolling = false;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plans = await widget.gymApi.getGymPlans(widget.gymId);
      setState(() {
        _plans = plans;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _enroll() async {
    if (_selectedPlanId == null) return;
    final selectedPlan = _plans?.firstWhere((plan) => plan.id == _selectedPlanId!);
    if (selectedPlan == null) return;
    setState(() {
      _enrolling = true;
      _error = null;
    });
    try {
      final enrollment = await widget.gymApi.enroll(
        gymId: widget.gymId,
        planId: _selectedPlanId!,
        gymName: widget.gymName,
        planName: selectedPlan.name,
        planPrice: selectedPlan.price,
      );
      widget.onComplete(enrollment);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _enrolling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Pick a Plan',
      subtitle: 'Choose a membership plan at ${widget.gymName}.',
      progress: 1.0,
      showBack: true,
      onBack: widget.onBack,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppPrimaryButton(
            label: 'Enroll',
            icon: Icons.check_circle_outline,
            isLoading: _enrolling,
            onPressed: _selectedPlanId != null ? _enroll : null,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: widget.onSkip,
            child: const Text('Skip for now'),
          ),
        ],
      ),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Card(
        color: const Color(0xFFFEE2E2),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _loadPlans,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_plans == null || _plans!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No plans available for this gym.')),
      );
    }

    return Column(
      children: _plans!.map((plan) {
        final selected = plan.id == _selectedPlanId;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _PlanCard(
            plan: plan,
            isSelected: selected,
            onTap: () => setState(() => _selectedPlanId = plan.id),
          ),
        );
      }).toList(),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
  });

  final GymPlan plan;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFD1D5DB),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${plan.duration} days',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Text(
                Formatters.price(plan.price),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4F46E5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
