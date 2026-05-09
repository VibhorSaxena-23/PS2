import 'package:flutter/material.dart';

import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/onboarding_scaffold.dart';
import '../../profile/data/profile_api.dart';
import '../../profile/models/profile_models.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({
    super.key,
    required this.profileApi,
    required this.onComplete,
  });

  final ProfileApi profileApi;
  final ValueChanged<UserProfile> onComplete;

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _ageCtrl    = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  String? _sex;
  String? _goal;
  String? _activity;
  bool _saving = false;
  String? _error;

  static const _goals = [
    ('weight_loss', 'Weight Loss'),
    ('muscle_gain', 'Muscle Gain'),
    ('strength', 'Strength'),
    ('endurance', 'Endurance'),
    ('maintenance', 'Maintenance'),
  ];

  static const _activities = [
    ('sedentary', 'Sedentary'),
    ('light', 'Lightly Active'),
    ('moderate', 'Moderate'),
    ('very_active', 'Very Active'),
    ('athlete', 'Athlete'),
  ];

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _ageCtrl.text.trim().isNotEmpty &&
      _sex != null &&
      _heightCtrl.text.trim().isNotEmpty &&
      _weightCtrl.text.trim().isNotEmpty &&
      _goal != null &&
      _activity != null;

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Fitness fields (age, height, weight, sex, goal, activity) are stored
      // in the mobile service metrics — saved later via the health onboarding flow.
      // Here we fetch the current profile to move forward in the onboarding.
      final profile = await widget.profileApi.get();
      widget.onComplete(profile);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Set Up Your Profile',
      subtitle: 'Tell us about yourself so we can personalise your experience.',
      progress: 0.33,
      bottom: AppPrimaryButton(
        label: 'Continue',
        icon: Icons.arrow_forward,
        isLoading: _saving,
        onPressed: _isValid ? _submit : null,
      ),
      child: Column(
        children: [
          if (_error != null) ...[
            Card(
              color: const Color(0xFFFEE2E2),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFEF4444), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFB91C1C)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Age'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _sex,
                  decoration: const InputDecoration(labelText: 'Sex'),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                  ],
                  onChanged: (v) => setState(() => _sex = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _heightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Height',
                    suffixText: 'cm',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _weightCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Weight',
                    suffixText: 'kg',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _goal,
            decoration: const InputDecoration(labelText: 'Fitness Goal'),
            items: _goals
                .map((g) => DropdownMenuItem(value: g.$1, child: Text(g.$2)))
                .toList(),
            onChanged: (v) => setState(() => _goal = v),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _activity,
            decoration: const InputDecoration(labelText: 'Activity Level'),
            items: _activities
                .map((a) => DropdownMenuItem(value: a.$1, child: Text(a.$2)))
                .toList(),
            onChanged: (v) => setState(() => _activity = v),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
