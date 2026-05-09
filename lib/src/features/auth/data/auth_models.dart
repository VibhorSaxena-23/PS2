// ── Request models ────────────────────────────────────────────────────────────

class LoginRequest {
  const LoginRequest({this.email, this.phoneNumber, required this.password});
  final String? email;
  final String? phoneNumber;
  final String password;

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{'password': password};
    if (email != null) m['email'] = email;
    if (phoneNumber != null) m['phoneNumber'] = phoneNumber;
    return m;
  }
}

class RegisterRequest {
  const RegisterRequest({
    required this.firstName,
    required this.lastName,
    this.email,
    this.phoneNumber,
    required this.password,
    this.role = 'MEMBER',
  });
  final String firstName;
  final String lastName;
  final String? email;
  final String? phoneNumber;
  final String password;
  final String role;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'password': password,
      'role': role,
    };
    if (email != null && email!.trim().isNotEmpty) {
      json['email'] = email!.trim();
    }
    if (phoneNumber != null && phoneNumber!.trim().isNotEmpty) {
      json['phoneNumber'] = phoneNumber!.trim();
    }
    return json;
  }
}

class OtpRequest {
  const OtpRequest({
    this.email,
    this.phoneNumber,
    this.channel,
    required this.purpose,
  });
  final String? email;
  final String? phoneNumber;
  final String? channel; // EMAIL | PHONE
  final String purpose;  // VERIFY | LOGIN | PASSWORD_RESET

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{'purpose': purpose};
    if (email != null) m['email'] = email;
    if (phoneNumber != null) m['phoneNumber'] = phoneNumber;
    if (channel != null) m['channel'] = channel;
    return m;
  }
}

class VerifyOtpRequest {
  const VerifyOtpRequest({
    this.email,
    this.phoneNumber,
    this.channel,
    required this.code,
    required this.purpose,
  });
  final String? email;
  final String? phoneNumber;
  final String? channel;
  final String code;
  final String purpose;

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{'code': code, 'purpose': purpose};
    if (email != null) m['email'] = email;
    if (phoneNumber != null) m['phoneNumber'] = phoneNumber;
    if (channel != null) m['channel'] = channel;
    return m;
  }
}

class ForgotPasswordRequest {
  const ForgotPasswordRequest({this.email, this.phoneNumber, this.channel});
  final String? email;
  final String? phoneNumber;
  final String? channel;

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{};
    if (email != null) m['email'] = email;
    if (phoneNumber != null) m['phoneNumber'] = phoneNumber;
    if (channel != null) m['channel'] = channel;
    return m;
  }
}

class ResetPasswordRequest {
  const ResetPasswordRequest({required this.token, required this.newPassword});
  final String token;
  final String newPassword;

  Map<String, dynamic> toJson() => {
        'token': token,
        'new_password': newPassword,
      };
}

// ── Response models ───────────────────────────────────────────────────────────

class LoginResponse {
  const LoginResponse({required this.accessToken, this.message});
  final String accessToken;
  final String? message;

  factory LoginResponse.fromJson(Map<String, dynamic> j) => LoginResponse(
        accessToken: j['access_token'] as String,
        message: j['message'] as String?,
      );
}

class RegisterResponse {
  const RegisterResponse({
    this.accessToken,
    required this.requiresOtp,
    this.message,
    this.otpChannel,
    this.purpose,
  });
  final String? accessToken; // null when requiresOtp == true
  final bool requiresOtp;
  final String? message;
  final Map<String, dynamic>? otpChannel;
  final String? purpose;

  factory RegisterResponse.fromJson(Map<String, dynamic> j) => RegisterResponse(
        accessToken: j['access_token'] as String?,
        requiresOtp: (j['requires_otp'] as bool?) ?? false,
        message: j['message'] as String?,
        otpChannel: j['otp_channel'] as Map<String, dynamic>?,
        purpose: j['purpose'] as String?,
      );
}

class VerifyOtpResponse {
  const VerifyOtpResponse({this.accessToken, this.success, this.resetToken});
  final String? accessToken;
  final bool? success;
  final String? resetToken;

  factory VerifyOtpResponse.fromJson(Map<String, dynamic> j) => VerifyOtpResponse(
        accessToken: j['access_token'] as String?,
        success: j['success'] as bool?,
        resetToken: j['resetToken'] as String?,
      );
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.firstName,
    this.lastName,
    this.email,
    this.phoneNumber,
    required this.role,
  });
  final String id;
  final String firstName;
  final String? lastName;
  final String? email;
  final String? phoneNumber;
  final String role;

  String get fullName => [
        firstName.trim(),
        (lastName ?? '').trim(),
      ].where((part) => part.isNotEmpty).join(' ');

  factory AuthUser.fromJson(Map<String, dynamic> j) {
    final u = j['user'] as Map<String, dynamic>? ?? j;
    return AuthUser(
      id: u['id'] as String,
      firstName: u['firstName'] as String,
      lastName: u['lastName'] as String?,
      email: u['email'] as String?,
      phoneNumber: u['phoneNumber'] as String?,
      role: u['role'] as String? ?? 'MEMBER',
    );
  }
}
