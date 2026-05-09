import '../../../core/network/api_client.dart';
import '../models/profile_models.dart';

// ProfileApi targets the WEB service (not the mobile service).
// The ApiClient passed here must use AppConfig.webApiBaseUrl.
//
// Endpoints:
//   GET  /profile/  → get current user's account profile
//   PATCH /profile/ → update firstName, lastName, avatarUrl
//
// Note: fitness data (age, height, weight, goals) lives in the mobile
// service under /metrics/ — not in the account profile.

class ProfileApi {
  ProfileApi(this._client);

  final ApiClient _client;

  Future<UserProfile> get() async {
    final response = await _client.get('/profile/');
    return UserProfile.fromJson(Map<String, dynamic>.from(response));
  }

  Future<UserProfile> update({
    String? firstName,
    String? lastName,
    String? avatarUrl,
  }) async {
    final body = <String, dynamic>{};
    if (firstName != null) body['firstName'] = firstName;
    if (lastName != null) body['lastName'] = lastName;
    if (avatarUrl != null) body['avatarUrl'] = avatarUrl;

    final response = await _client.patch('/profile/', body: body);
    return UserProfile.fromJson(Map<String, dynamic>.from(response));
  }
}
