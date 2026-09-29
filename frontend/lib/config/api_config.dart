import 'package:flutter/foundation.dart';

/// API configuration for the Crux Climbing Gym app
class ApiConfig {
  // Private constructor to prevent instantiation
  ApiConfig._();

  /// WordPress API endpoint for web platform (same-origin)
  static const String wordPressApiPath = '/wp-json/crux/v1';

  /// Full WordPress API URL (for non-web platforms that need absolute URL)
  static const String wordPressApiUrl = 'http://cruxclub.fr/wp-json/crux/v1';

  /// Get the appropriate base URL based on platform
  static String get baseUrl => kIsWeb ? wordPressApiPath : wordPressApiUrl;

  /// Get the full WordPress API URL (useful for role service, etc.)
  static String get fullWordPressUrl => wordPressApiUrl;
}
