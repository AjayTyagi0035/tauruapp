import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/survey_submission.dart';

class SurveyService {
  /// TODO: Bind the new image upload API here and return the stored URL.
  /// Until then the local file path is returned so the payload is complete.
  static Future<String?> uploadPhoto(File file) async {
    return file.path;
  }

  /// TODO: Bind the new submit API here (POST to surveyor_s_submissions).
  /// Until then the payload is only logged to the debug console.
  static Future<bool> submitSurvey(SurveySubmission submission) async {
    debugPrint('Survey payload: ${jsonEncode(submission.toJson())}');
    return true;
  }
}
