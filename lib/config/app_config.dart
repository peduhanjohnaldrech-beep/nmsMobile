import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  // Default server URL — override via Profile/Settings screen
  static const String defaultBaseUrl = 'https://kabnms.duckdns.org/api';

  // SharedPreferences / SecureStorage keys
  static const String tokenKey     = 'nms_token';
  static const String userKey      = 'nms_user';
  static const String serverUrlKey = 'nms_server_url';
  static const String lastSyncKey      = 'last_sync_at';
  static const String offlineCredsKey  = 'nms_offline_creds';

  // App info
  static const String appName    = 'NMS Mobile';
  static const String appVersion = '1.0.0';

  /// Returns the active base URL (from prefs or default).
  /// Auto-migrates old IP-based URLs to the current domain.
  static Future<String> getBaseUrl() async {
    final prefs  = await SharedPreferences.getInstance();
    final saved  = prefs.getString(serverUrlKey);
    if (saved != null && saved.contains('152.42.197.110')) {
      await prefs.setString(serverUrlKey, defaultBaseUrl);
      return defaultBaseUrl;
    }
    return saved ?? defaultBaseUrl;
  }

  /// Saves a custom server URL to prefs
  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(serverUrlKey, url);
  }
}
