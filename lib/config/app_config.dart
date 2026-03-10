import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central place to access environment-based config.
/// All secrets are loaded from `.env` at startup — never hardcoded.
class AppConfig {
  AppConfig._();

  static String get apiKey =>
      dotenv.env['MUSCLE_WIKI_API_KEY'] ?? '';

  static Map<String, String> get apiHeaders => {
        'X-API-Key': apiKey,
        'Content-Type': 'application/json',
      };

  /// Headers without Content-Type (for media requests like images/videos).
  static Map<String, String> get mediaHeaders => {
        'X-API-Key': apiKey,
      };
}
