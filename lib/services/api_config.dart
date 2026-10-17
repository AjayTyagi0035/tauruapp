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
}
