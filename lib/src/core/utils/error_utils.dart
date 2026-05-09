import '../network/api_exception.dart';

/// Returns true when the API error indicates the user profile does not exist yet
/// (HTTP 404 from GET /profile). Used in app.dart bootstrap to decide whether
/// to show the onboarding flow.
bool isProfileMissingError(Object error) {
  if (error is ApiException) {
    return error.statusCode == 404;
  }
  return false;
}
