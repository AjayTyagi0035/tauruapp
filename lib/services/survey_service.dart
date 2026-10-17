import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/survey_submission.dart';
import 'api_config.dart';

/// Talks to the Tauru endpoints of the admin backend (`/api/tauru`).
class SurveyService {
  /// Uploads a photo to the "tauruimage" blob container; returns its URL.
  static Future<String?> uploadPhoto(File file) async {
    try {
      final request =
          http.MultipartRequest('POST', ApiConfig.uri('/api/tauru/upload-image'))
            ..files.add(await http.MultipartFile.fromPath('image', file.path));
      final response = await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 90)),
      );
      if (response.statusCode != 200) {
        debugPrint('Photo upload failed: ${response.statusCode} ${response.body}');
        return null;
      }
      return (jsonDecode(response.body) as Map<String, dynamic>)['imageUrl']
          as String?;
    } catch (e) {
      debugPrint('Photo upload error: $e');
      return null;
    }
  }

  /// Creates a new record. Returns null on success, else an error message.
  static Future<String?> submitSurvey(SurveySubmission submission) =>
      _send('POST', '/api/tauru', submission);

  /// Updates an existing record. Returns null on success, else an error message.
  static Future<String?> updateSurvey(int id, SurveySubmission submission) =>
      _send('PUT', '/api/tauru/$id', submission);

  static Future<String?> _send(
    String method,
    String path,
    SurveySubmission submission,
  ) async {
    try {
      final request =
          http.Request(method, ApiConfig.uri(path))
            ..headers['Content-Type'] = 'application/json'
            ..body = jsonEncode(submission.toJson());
      final response = await http.Response.fromStream(
        await request.send().timeout(ApiConfig.timeout),
      );
      if (response.statusCode == 200 || response.statusCode == 201) return null;
      return _errorFrom(response) ?? 'Server error (${response.statusCode}).';
    } catch (e) {
      debugPrint('Survey $method error: $e');
      return 'Network error. Please check your connection.';
    }
  }

  /// One page of the surveyor's own records, newest first.
  static Future<HistoryPage> fetchHistory({
    required Object submittedBy,
    int page = 1,
    int limit = 20,
    String search = '',
  }) async {
    final response = await http
        .get(
          ApiConfig.uri('/api/tauru', {
            'submitted_by': '$submittedBy',
            'page': '$page',
            'limit': '$limit',
            if (search.trim().isNotEmpty) 'q': search.trim(),
          }),
        )
        .timeout(ApiConfig.timeout);
    if (response.statusCode != 200) {
      throw Exception(_errorFrom(response) ?? 'Failed to load history');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final pagination = body['pagination'] as Map<String, dynamic>? ?? {};
    return HistoryPage(
      records:
          (body['data'] as List? ?? [])
              .map((e) => SurveySubmission.fromJson(e as Map<String, dynamic>))
              .toList(),
      total: (pagination['total'] as num?)?.toInt() ?? 0,
      totalPages: (pagination['total_pages'] as num?)?.toInt() ?? 1,
    );
  }

  static String? _errorFrom(http.Response response) {
    try {
      return (jsonDecode(response.body) as Map<String, dynamic>)['error']
          as String?;
    } catch (_) {
      return null;
    }
  }
}

class HistoryPage {
  final List<SurveySubmission> records;
  final int total;
  final int totalPages;

  const HistoryPage({
    required this.records,
    required this.total,
    required this.totalPages,
  });
}
