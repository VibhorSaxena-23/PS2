// Gym domain models — aligned to the web service's v1 API schemas.
//
// Web service endpoints used:
//   GET  /gyms/discover          → GymDiscover
//   GET  /gyms/{id}              → GymDetail
//   GET  /plans/gym/{id}         → GymPlan
//   POST /subscription/          → GymEnrollment (nested subscription + payment)
//   GET  /memberships/me         → GymMembership (Prisma Membership + gym relation)
//   GET  /attendance/me          → GymAttendance (AttendanceHistoryEntry)
//   POST /attendance/check-in    → GymAttendance (AttendanceResponse)
//   POST /attendance/check-out   → GymAttendance (AttendanceResponse)

class GymDiscover {
  GymDiscover({
    required this.id,
    required this.name,
    required this.location,
    required this.latitude,
    required this.longitude,
    this.distanceKm,
    this.description,
    this.phoneNumber,
    this.email,
    this.gymLogo,
    this.coverImage,
    this.gymType,
    this.institutionType,
    this.capacity,
    this.openingTime,
    this.closingTime,
    this.workingDays = const [],
    this.membershipRequired = false,
    this.trialAvailable = false,
    this.checkInEnabled = false,
    this.autoCheckoutMinutes,
    this.facilities = const [],
    this.minPrice,
    this.planCount = 0,
  });

  final String id;
  final String name;
  final String location;
  final double latitude;
  final double longitude;
  final double? distanceKm;
  final String? description;
  final String? phoneNumber;
  final String? email;
  final String? gymLogo;
  final String? coverImage;
  final String? gymType;
  final String? institutionType;
  final int? capacity;
  final String? openingTime;
  final String? closingTime;
  final List<String> workingDays;
  final bool membershipRequired;
  final bool trialAvailable;
  final bool checkInEnabled;
  final int? autoCheckoutMinutes;
  final List<String> facilities;
  final double? minPrice;
  final int planCount;

  factory GymDiscover.fromJson(Map<String, dynamic> json) {
    final address = _asMap(json['address']);
    final institution = _asMap(json['institution']);
    final lat = _toNullableDouble(json['latitude'] ?? address?['latitude']);
    final lng = _toNullableDouble(json['longitude'] ?? address?['longitude']);
    if (lat == null || lng == null) {
      throw const FormatException('Gym is missing latitude/longitude');
    }
    return GymDiscover(
      id: json['id'] as String,
      name: json['name'] as String,
      location: _buildAddressLabel(json, address, institution: institution),
      latitude: lat,
      longitude: lng,
      distanceKm: _toNullableDouble(json['distance_km'] ?? json['distanceKm']),
      description: json['description'] as String?,
      phoneNumber: (json['phone_number'] ?? json['phoneNumber']) as String?,
      email: json['email'] as String?,
      gymLogo: (json['gym_logo'] ?? json['gymLogo']) as String?,
      coverImage: (json['cover_image'] ?? json['coverImage']) as String?,
      gymType: (json['gym_type'] ?? json['gymType']) as String?,
      institutionType: institution?['type'] as String?,
      capacity: _toNullableInt(json['capacity']),
      openingTime: (json['opening_time'] ?? json['openingTime']) as String?,
      closingTime: (json['closing_time'] ?? json['closingTime']) as String?,
      workingDays: _toStringList(json['working_days'] ?? json['workingDays']),
      membershipRequired:
          (json['membership_required'] ?? json['membershipRequired']) as bool? ??
              false,
      trialAvailable:
          (json['trial_available'] ?? json['trialAvailable']) as bool? ?? false,
      checkInEnabled:
          (json['check_in_enabled'] ?? json['checkInEnabled']) as bool? ?? false,
      autoCheckoutMinutes: _toNullableInt(
          json['auto_checkout_minutes'] ?? json['autoCheckoutMinutes']),
      facilities: _toFacilityNames(json['facilities']),
      minPrice: _toNullableDouble(json['min_price'] ?? json['minPrice']),
      planCount: _toNullableInt(json['plan_count'] ?? json['planCount']) ?? 0,
    );
  }
}

// GymDetail is returned by GET /gyms/{id}.
// Plans are NOT included — fetch them separately via GET /plans/gym/{id}.
class GymDetail {
  GymDetail({
    required this.id,
    required this.name,
    required this.location,
    required this.latitude,
    required this.longitude,
    this.description,
    this.phoneNumber,
    this.email,
    this.gymLogo,
    this.coverImage,
    this.gymType,
    this.capacity,
    this.openingTime,
    this.closingTime,
    this.workingDays = const [],
    this.membershipRequired = false,
    this.trialAvailable = false,
    this.checkInEnabled = false,
    this.autoCheckoutMinutes,
    this.facilities = const [],
    this.gymImages = const [],
    this.isApproved = false,
  });

  final String id;
  final String name;
  final String location;
  final double latitude;
  final double longitude;
  final String? description;
  final String? phoneNumber;
  final String? email;
  final String? gymLogo;
  final String? coverImage;
  final String? gymType;
  final int? capacity;
  final String? openingTime;
  final String? closingTime;
  final List<String> workingDays;
  final bool membershipRequired;
  final bool trialAvailable;
  final bool checkInEnabled;
  final int? autoCheckoutMinutes;
  final List<String> facilities;
  final List<String> gymImages;
  final bool isApproved;

  factory GymDetail.fromJson(Map<String, dynamic> json) {
    final address = _asMap(json['address']);
    final lat = _toNullableDouble(json['latitude'] ?? address?['latitude']) ?? 0;
    final lng = _toNullableDouble(json['longitude'] ?? address?['longitude']) ?? 0;
    final rawImages = json['gymImages'] as List<dynamic>? ?? [];
    final imageUrls = rawImages
        .cast<Map<String, dynamic>>()
        .where((img) => img['isActive'] != false)
        .map((img) => (img['url'] ?? img['s3Key'] ?? '') as String)
        .where((url) => url.isNotEmpty)
        .toList();

    return GymDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      location: _buildAddressLabel(json, address),
      latitude: lat,
      longitude: lng,
      description: json['description'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      email: json['email'] as String?,
      gymLogo: json['gymLogo'] as String?,
      coverImage: json['coverImage'] as String?,
      gymType: json['gymType'] as String?,
      capacity: _toNullableInt(json['capacity']),
      openingTime: json['openingTime'] as String?,
      closingTime: json['closingTime'] as String?,
      workingDays: _toStringList(json['workingDays']),
      membershipRequired: json['membershipRequired'] as bool? ?? false,
      trialAvailable: json['trialAvailable'] as bool? ?? false,
      checkInEnabled: json['checkInEnabled'] as bool? ?? false,
      autoCheckoutMinutes: _toNullableInt(json['autoCheckoutMinutes']),
      facilities: _toFacilityNames(json['facilities']),
      gymImages: imageUrls,
      isApproved: json['isApproved'] as bool? ?? false,
    );
  }
}

// GymPlan is returned by GET /plans/gym/{id}.
// The Prisma Plan model uses `duration` (days).
class GymPlan {
  GymPlan({
    required this.id,
    required this.gymId,
    required this.name,
    required this.price,
    required this.duration,
    required this.createdAt,
  });

  final String id;
  final String gymId;
  final String name;
  final double price;
  final int duration; // days
  final DateTime createdAt;

  factory GymPlan.fromJson(Map<String, dynamic> json) {
    return GymPlan(
      id: json['id'] as String,
      gymId: (json['gymId'] ?? json['gym_id'] ?? '') as String,
      name: json['name'] as String,
      price: _toDouble(json['price']),
      duration: (json['duration'] ?? json['duration_days'] ?? 30) as int,
      createdAt: _toDate(json['createdAt'] ?? json['created_at']),
    );
  }
}

// GymMembership is returned by GET /memberships/me.
// Each entry is a Prisma Membership with an included gym relation.
class GymMembership {
  GymMembership({
    required this.id,
    required this.userId,
    required this.gymId,
    required this.gymName,
    required this.status,
    required this.startDate,
    this.endDate,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String gymId;
  final String gymName;
  final String status;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime createdAt;

  factory GymMembership.fromJson(Map<String, dynamic> json) {
    final gym = json['gym'] as Map<String, dynamic>?;
    return GymMembership(
      id: json['id'] as String,
      userId: (json['userId'] ?? json['user_id']) as String,
      gymId: (json['gymId'] ?? json['gym_id']) as String,
      gymName: gym?['name'] as String? ?? '',
      status: json['status'] as String? ?? 'ACTIVE',
      startDate: _toDate(json['startDate'] ?? json['start_date']),
      endDate: _toNullableDate(json['endDate'] ?? json['end_date']),
      createdAt: _toDate(json['createdAt'] ?? json['created_at']),
    );
  }
}

// GymEnrollment is returned by POST /subscription/.
// Response shape: {"subscription": {..., plan, gym, user}, "payment": {...}}
class GymEnrollment {
  GymEnrollment({
    required this.subscriptionId,
    required this.userId,
    required this.gymId,
    required this.gymName,
    required this.planId,
    required this.planName,
    required this.planPrice,
    required this.status,
    this.startDate,
    this.endDate,
    this.paymentId,
    this.paymentStatus,
    this.paymentProvider,
    this.paymentAmount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String subscriptionId;
  final String userId;
  final String gymId;
  final String gymName;
  final String planId;
  final String planName;
  final double planPrice;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? paymentId;
  final String? paymentStatus;
  final String? paymentProvider;
  final double? paymentAmount;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory GymEnrollment.fromJson(
    Map<String, dynamic> json, {
    String? fallbackGymName,
    String? fallbackPlanName,
    double? fallbackPlanPrice,
  }) {
    final sub = _asMap(json['subscription']) ?? json;
    final payment = _asMap(json['payment']);
    final plan = _asMap(sub['plan']);
    final gym = _asMap(sub['gym']);
    final createdAt = _toDate(sub['createdAt'] ?? sub['created_at']);
    final updatedAt = sub['updatedAt'] ?? sub['updated_at'];
    return GymEnrollment(
      subscriptionId: sub['id'] as String,
      userId: (sub['userId'] ?? sub['user_id']) as String,
      gymId: (sub['gymId'] ?? sub['gym_id']) as String,
      gymName: gym?['name'] as String? ?? fallbackGymName ?? '',
      planId: (sub['planId'] ?? sub['plan_id']) as String,
      planName: plan?['name'] as String? ?? fallbackPlanName ?? '',
      planPrice: _toNullableDouble(plan?['price']) ?? fallbackPlanPrice ?? 0,
      status: sub['status'] as String? ?? 'PENDING',
      startDate: _toNullableDate(sub['startDate'] ?? sub['start_date']),
      endDate: _toNullableDate(sub['endDate'] ?? sub['end_date']),
      paymentId: payment?['id'] as String?,
      paymentStatus: payment?['status'] as String?,
      paymentProvider: payment?['provider'] as String?,
      paymentAmount: _toNullableDouble(payment?['amount']),
      createdAt: createdAt,
      updatedAt: updatedAt != null ? _toDate(updatedAt) : createdAt,
    );
  }
}

// GymAttendance is returned by check-in, check-out, and GET /attendance/me.
// Backend uses camelCase keys: checkedIn, checkOut (note: not checkedOut).
class GymAttendance {
  GymAttendance({
    required this.id,
    required this.userId,
    required this.gymId,
    required this.checkedIn,
    this.checkOut,
    required this.status,
    required this.createdAt,
    this.gymName,
  });

  final String id;
  final String userId;
  final String gymId;
  final DateTime checkedIn;
  final DateTime? checkOut;
  final String status;
  final DateTime createdAt;
  final String? gymName;

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  // checkedOut is an alias kept for backward compatibility
  DateTime? get checkedOut => checkOut;

  factory GymAttendance.fromJson(Map<String, dynamic> json) {
    final gym = json['gym'] as Map<String, dynamic>?;
    return GymAttendance(
      id: json['id'] as String,
      userId: (json['userId'] ?? json['user_id']) as String,
      gymId: (json['gymId'] ?? json['gym_id']) as String,
      checkedIn: _toDate(json['checkedIn'] ?? json['checked_in']),
      checkOut: _toNullableDate(
          json['checkOut'] ?? json['check_out'] ?? json['checkedOut']),
      status: json['status'] as String? ?? 'ACTIVE',
      createdAt: _toDate(json['createdAt'] ?? json['created_at']),
      gymName: gym?['name'] as String? ?? json['gymName'] as String?,
    );
  }
}

// GymAttendancePage wraps a paginated attendance list.
class GymAttendancePage {
  GymAttendancePage({required this.items, this.total = 0});
  final List<GymAttendance> items;
  final int total;
}

// GymInfo wraps membership data loaded via GET /memberships/me.
class GymInfo {
  GymInfo({required this.memberships});

  final List<GymMembership> memberships;

  factory GymInfo.fromList(List<dynamic> json) {
    return GymInfo(
      memberships: json
          .cast<Map<String, dynamic>>()
          .map(GymMembership.fromJson)
          .toList(),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.parse(value);
  throw FormatException('Could not parse numeric value: $value');
}

double? _toNullableDouble(dynamic value) {
  if (value == null) return null;
  return _toDouble(value);
}

int? _toNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? double.tryParse(value)?.toInt();
  return null;
}

DateTime _toDate(dynamic value) {
  return DateTime.parse(value as String).toLocal();
}

DateTime? _toNullableDate(dynamic value) {
  if (value == null) return null;
  return _toDate(value);
}

List<String> _toStringList(dynamic value) {
  if (value is List) return value.map((e) => e.toString()).toList();
  return const [];
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<String> _toFacilityNames(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((entry) {
        if (entry is Map<String, dynamic>) return entry['name']?.toString() ?? '';
        if (entry is Map) return entry['name']?.toString() ?? '';
        return entry.toString();
      })
      .where((name) => name.trim().isNotEmpty)
      .toList();
}

String _buildAddressLabel(
  Map<String, dynamic> root,
  Map<String, dynamic>? address, {
  Map<String, dynamic>? institution,
}) {
  final legacyLocation = root['location'];
  if (legacyLocation is String && legacyLocation.trim().isNotEmpty) {
    return legacyLocation;
  }

  final parts = <String>[
    address?['street']?.toString() ?? '',
    address?['city']?.toString() ?? '',
    address?['state']?.toString() ?? '',
    address?['country']?.toString() ?? '',
  ].where((part) => part.trim().isNotEmpty).toList();

  if (parts.isNotEmpty) return parts.join(', ');

  final institutionName = institution?['name']?.toString();
  if (institutionName != null && institutionName.trim().isNotEmpty) {
    return institutionName;
  }

  return '';
}
