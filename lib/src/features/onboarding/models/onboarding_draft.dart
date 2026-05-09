import '../../gym/models/gym_models.dart';

enum AuthMode { login, register }

enum FitnessGoal { weightLoss, muscleGain, strength, endurance }

enum ExperienceLevel { beginner, intermediate, advanced }

enum TrainingPreference { gym, home, both }

extension FitnessGoalLabel on FitnessGoal {
  String get label {
    switch (this) {
      case FitnessGoal.weightLoss:
        return 'Weight Loss';
      case FitnessGoal.muscleGain:
        return 'Muscle Gain';
      case FitnessGoal.strength:
        return 'Strength';
      case FitnessGoal.endurance:
        return 'Endurance';
    }
  }
}

extension ExperienceLevelLabel on ExperienceLevel {
  String get label {
    switch (this) {
      case ExperienceLevel.beginner:
        return 'Beginner';
      case ExperienceLevel.intermediate:
        return 'Intermediate';
      case ExperienceLevel.advanced:
        return 'Advanced';
    }
  }
}

extension TrainingPreferenceLabel on TrainingPreference {
  String get label {
    switch (this) {
      case TrainingPreference.gym:
        return 'Gym';
      case TrainingPreference.home:
        return 'Home';
      case TrainingPreference.both:
        return 'Both';
    }
  }
}

class OnboardingDraft {
  const OnboardingDraft({
    this.authMode,
    this.fullName = '',
    this.phoneNumber = '',
    this.password = '',
    this.age,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.goal,
    this.experience,
    this.trainingPreference,
    this.selectedGym,
    this.selectedPlan,
  });

  final AuthMode? authMode;
  final String fullName;
  final String phoneNumber;
  final String password;
  final int? age;
  final String? gender;
  final double? heightCm;
  final double? weightKg;
  final FitnessGoal? goal;
  final ExperienceLevel? experience;
  final TrainingPreference? trainingPreference;
  final GymDiscover? selectedGym;
  final GymPlan? selectedPlan;

  bool get isProfileComplete =>
      fullName.trim().isNotEmpty &&
      phoneNumber.trim().isNotEmpty &&
      age != null &&
      gender != null &&
      heightCm != null &&
      weightKg != null &&
      goal != null &&
      experience != null &&
      trainingPreference != null;

  OnboardingDraft copyWith({
    AuthMode? authMode,
    String? fullName,
    String? phoneNumber,
    String? password,
    int? age,
    bool clearAge = false,
    String? gender,
    bool clearGender = false,
    double? heightCm,
    bool clearHeight = false,
    double? weightKg,
    bool clearWeight = false,
    FitnessGoal? goal,
    bool clearGoal = false,
    ExperienceLevel? experience,
    bool clearExperience = false,
    TrainingPreference? trainingPreference,
    bool clearTrainingPreference = false,
    GymDiscover? selectedGym,
    bool clearSelectedGym = false,
    GymPlan? selectedPlan,
    bool clearSelectedPlan = false,
  }) {
    return OnboardingDraft(
      authMode: authMode ?? this.authMode,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      password: password ?? this.password,
      age: clearAge ? null : (age ?? this.age),
      gender: clearGender ? null : (gender ?? this.gender),
      heightCm: clearHeight ? null : (heightCm ?? this.heightCm),
      weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
      goal: clearGoal ? null : (goal ?? this.goal),
      experience:
          clearExperience ? null : (experience ?? this.experience),
      trainingPreference: clearTrainingPreference
          ? null
          : (trainingPreference ?? this.trainingPreference),
      selectedGym:
          clearSelectedGym ? null : (selectedGym ?? this.selectedGym),
      selectedPlan:
          clearSelectedPlan ? null : (selectedPlan ?? this.selectedPlan),
    );
  }
}
