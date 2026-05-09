import '../../../core/network/api_client.dart';
import '../models/gym_models.dart';

// All GymApi calls target the WEB service (not the mobile service).
// The ApiClient passed here must use AppConfig.webApiBaseUrl.
class GymApi {
  GymApi(this._client);

  final ApiClient _client;

  Future<List<GymDiscover>> discoverGyms({
    required double lat,
    required double lng,
    double? radiusKm,
    int limit = 50,
  }) async {
    final query = <String, dynamic>{'lat': lat, 'lng': lng, 'limit': limit};
    if (radiusKm != null) {
      query['radius'] = radiusKm;
    }
    final response = await _client.get(
      '/gyms/discover',
      queryParameters: query,
    );
    final items = response is Map<String, dynamic>
        ? response['items'] as List<dynamic>? ?? const <dynamic>[]
        : response as List<dynamic>;
    final gyms = <GymDiscover>[];
    for (final item in items) {
      try {
        gyms.add(GymDiscover.fromJson(Map<String, dynamic>.from(item)));
      } on FormatException {
        // Skip malformed gym records that cannot be plotted on map.
      }
    }
    return gyms;
  }

  Future<GymDetail> getGymDetail(String gymId) async {
    final response = await _client.get('/gyms/$gymId');
    return GymDetail.fromJson(Map<String, dynamic>.from(response));
  }

  Future<List<GymPlan>> getGymPlans(String gymId) async {
    final response = await _client.get('/plans/gym/$gymId');
    return (response as List<dynamic>)
        .map((item) => GymPlan.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<GymEnrollment> subscribe({
    required String gymId,
    required String planId,
    String? gymName,
    String? planName,
    double? planPrice,
  }) async {
    final response = await _client.post(
      '/memberships/cash',
      body: {'gymPlanId': planId},
    );
    return GymEnrollment.fromJson(
      Map<String, dynamic>.from(response),
      fallbackGymName: gymName,
      fallbackPlanName: planName,
      fallbackPlanPrice: planPrice,
    );
  }

  Future<GymEnrollment> enroll({
    required String gymId,
    required String planId,
    String? gymName,
    String? planName,
    double? planPrice,
    String provider = 'manual',
  }) => subscribe(
    gymId: gymId,
    planId: planId,
    gymName: gymName,
    planName: planName,
    planPrice: planPrice,
  );

  Future<GymMembership> joinGym({required String gymId}) async {
    throw UnsupportedError(
      'Direct gym join is no longer supported. Select a gym plan first.',
    );
  }

  Future<List<GymMembership>> getMemberships() async {
    final response = await _client.get('/memberships/me');
    return (response as List<dynamic>)
        .map((item) => GymMembership.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<GymInfo> getInfo() async {
    final memberships = await getMemberships();
    return GymInfo(memberships: memberships);
  }

  Future<List<GymAttendance>> getAttendance({
    String? gymId,
    int limit = 20,
    int offset = 0,
  }) async {
    final query = <String, dynamic>{'limit': limit, 'offset': offset};
    if (gymId != null && gymId.isNotEmpty) query['gymId'] = gymId;
    final response = await _client.get(
      '/attendance/me',
      queryParameters: query,
    );
    return (response as List<dynamic>)
        .map((item) => GymAttendance.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<GymAttendance> checkIn(
    String gymId,
    String token, {
    int? timestamp,
  }) async {
    final body = <String, dynamic>{'gymId': gymId, 'token': token};
    if (timestamp != null) body['timestamp'] = timestamp;
    final response = await _client.post('/attendance/check-in', body: body);
    return GymAttendance.fromJson(Map<String, dynamic>.from(response));
  }

  Future<GymAttendance> checkOut(String gymId) async {
    final response = await _client.post(
      '/attendance/check-out',
      body: {'gymId': gymId},
    );
    return GymAttendance.fromJson(Map<String, dynamic>.from(response));
  }

  Future<int> getGymCrowd(String gymId) async {
    final response = await _client.get('/attendance/gym/$gymId/crowd');
    return (response as Map<String, dynamic>)['count'] as int? ?? 0;
  }
}
