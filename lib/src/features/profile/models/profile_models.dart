// UserProfile matches the web service's ProfileResponse schema.
// Web endpoint: GET /profile/  and  PATCH /profile/
//
// Fields returned by backend:
//   id, email, phoneNumber, firstName, lastName, avatarUrl,
//   role, isVerified, isProfileComplete, createdAt, updatedAt

class UserProfile {
  UserProfile({
    required this.id,
    this.email,
    this.phoneNumber,
    required this.firstName,
    this.lastName,
    this.avatarUrl,
    required this.role,
    required this.isVerified,
    required this.isProfileComplete,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? email;
  final String? phoneNumber;
  final String firstName;
  final String? lastName;
  final String? avatarUrl;
  final String role;
  final bool isVerified;
  final bool isProfileComplete;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName {
    final parts = [firstName, ?lastName]
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isNotEmpty ? parts.join(' ') : email ?? phoneNumber ?? 'User';
  }

  String get displayIdentifier => email ?? phoneNumber ?? '';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      role: json['role'] as String? ?? 'MEMBER',
      isVerified: json['isVerified'] as bool? ?? false,
      isProfileComplete: json['isProfileComplete'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
    );
  }
}
