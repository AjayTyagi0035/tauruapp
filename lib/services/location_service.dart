import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class LocationService {
  static const String _baseUrl = 'https://adminsurveyapp.vercel.app/api/locations';
  static const String _propertySurveyBaseUrl =
      'https://adminsurveyapp.vercel.app/api/property-surveys';
  static const String _imageUploadUrl =
      'https://adminsurveyapp.vercel.app/api/upload-image';

  static String? _normalizeUploadedImageUrl(String? imageUrl) {
    final trimmed = imageUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    const blobPrefix = 'https://surveystorage0035.blob.core.windows.net/';
    if (trimmed.startsWith(blobPrefix)) {
      return trimmed.substring(blobPrefix.length);
    }

    try {
      final uri = Uri.parse(trimmed);
      if (uri.path.isEmpty) return null;
      return uri.path.startsWith('/') ? uri.path : '/${uri.path}';
    } catch (_) {
      return trimmed;
    }
  }

  static Map<String, dynamic>? _decodeSurveyResponse(http.Response response) {
    if (response.body.isEmpty) return null;

    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic>) {
      final survey = data['survey'];
      if (survey is Map<String, dynamic>) {
        return survey;
      }
      return data;
    }

    return null;
  }

  static Future<List<dynamic>> getDistricts() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/districts'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : (data['districts'] ?? data['data'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  static Future<List<dynamic>> getUlbs(String districtId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/districts/$districtId/ulbs'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : (data['ulbs'] ?? data['data'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  static Future<List<dynamic>> getWards(String ulbId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/ulbs/$ulbId/wards'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : (data['wards'] ?? data['data'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  static Future<List<dynamic>> getMohallas(String wardId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/wards/$wardId/mohallas'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : (data['mohallas'] ?? data['data'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  static Future<String?> uploadSurveyImage(File imageFile) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_imageUploadUrl));
      request.headers.addAll({
        'Accept': 'application/json',
      });
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return _normalizeUploadedImageUrl(data['imageUrl']?.toString());
        }
      }
    } catch (_) {}

    return null;
  }

  static Future<Map<String, dynamic>?> searchPropertySurvey({
    required String wardNo,
    required String houseNo,
    String? mohallaName,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final trimmedMohallaName = mohallaName?.trim();

      final queryParts = <String>[
        'ward_no=${Uri.encodeQueryComponent(wardNo)}',
        'house_no=$houseNo',
        'page=$page',
        'limit=$limit',
      ];

      if (trimmedMohallaName != null && trimmedMohallaName.isNotEmpty) {
        queryParts.add(
          'mohalla_name=${Uri.encodeQueryComponent(trimmedMohallaName)}',
        );
      }

      final response = await http.get(
        Uri.parse('$_propertySurveyBaseUrl/search?${queryParts.join('&')}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // If the API returned a plain message (e.g. { "message": "Record already completed" })
        // expose it to callers so the UI can show it instead of treating it as "not found".
        if (data is Map<String, dynamic>) {
          final msg = data['message'] as String?;
          final records = data['data'];
          if ((records == null || (records is List && records.isEmpty)) && msg != null && msg.isNotEmpty) {
            return {'__api_message': msg};
          }
        }

        final records = data is Map<String, dynamic> ? data['data'] : data;
        if (records is List && records.isNotEmpty && records.first is Map) {
          return Map<String, dynamic>.from(records.first as Map);
        }
      }
    } catch (_) {}

    return null;
  }

  static Future<Map<String, dynamic>?> createPropertySurvey(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(_propertySurveyBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return _decodeSurveyResponse(response);
      }

      if (response.statusCode == 409) {
        final data = response.body.isEmpty ? null : jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final message = data['message']?.toString();
          if (message != null && message.isNotEmpty) {
            return {'__api_message': message};
          }
          return {'__api_message': 'Duplicate survey already exists.'};
        }

        return {'__api_message': 'Duplicate survey already exists.'};
      }
    } catch (_) {}

    return null;
  }

  static Future<Map<String, dynamic>?> updatePropertySurvey(
    int surveyId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$_propertySurveyBaseUrl/$surveyId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return _decodeSurveyResponse(response) ?? payload;
      }

      if (response.statusCode == 409) {
        final data = response.body.isEmpty ? null : jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final message = data['message']?.toString();
          if (message != null && message.isNotEmpty) {
            return {'__api_message': message};
          }
          return {'__api_message': 'Duplicate survey already exists.'};
        }

        return {'__api_message': 'Duplicate survey already exists.'};
      }
    } catch (_) {}

    return null;
  }

  /// Fetches property-survey pins for the map view.
  /// Mirrors the JS `buildMapApiUrl` helper:
  ///   /api/property-surveys/map?ward_id=&ne_lat=&ne_lng=&sw_lat=&sw_lng=
  static Future<List<Map<String, dynamic>>> getMapPropertySurveys({
    String? wardId,
    double? neLat,
    double? neLng,
    double? swLat,
    double? swLng,
  }) async {
    try {
      final params = <String, String>{};
      if (wardId != null && wardId.isNotEmpty) params['ward_id'] = wardId;
      if (neLat != null) params['ne_lat'] = neLat.toString();
      if (neLng != null) params['ne_lng'] = neLng.toString();
      if (swLat != null) params['sw_lat'] = swLat.toString();
      if (swLng != null) params['sw_lng'] = swLng.toString();

      final uri = Uri.parse('$_propertySurveyBaseUrl/map')
          .replace(queryParameters: params.isEmpty ? null : params);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final records = data is Map<String, dynamic>
            ? (data['data'] ?? data['surveys'] ?? data['results'])
            : data;
        if (records is List) {
          return records
              .whereType<Map>()
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Map<String, dynamic>>> getPropertySurveysByCreatedBy(
    int createdBy, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_propertySurveyBaseUrl/by-created-by?created_by=$createdBy&page=$page&limit=$limit',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final records = data is Map<String, dynamic> ? data['data'] : data;
        if (records is List) {
          return records
              .whereType<Map>()
              .map((record) => Map<String, dynamic>.from(record as Map))
              .toList();
        }
      }
    } catch (_) {}

    return [];
  }
}
