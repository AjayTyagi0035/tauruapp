/// Base URL of the admin survey backend (Next.js app "adminsurveyapp").
/// Override for local testing: --dart-define=API_BASE_URL=http://10.0.2.2:3000
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://adminsurveyapp.vercel.app',
  );

  static Uri uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  static const Duration timeout = Duration(seconds: 30);

  /// Photos are stored as `container/blob` and served through this CDN.
  static const String photoCdnBaseUrl = 'https://cdn.omgauamrit.in';

  /// Full URL for a stored photo path (older rows may hold a full URL).
  static String photoUrl(String path) =>
      path.startsWith(RegExp(r'https?://'))
          ? path
          : '$photoCdnBaseUrl/${path.replaceFirst(RegExp(r'^/+'), '')}';
}
