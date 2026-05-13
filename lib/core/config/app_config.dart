class AppConfig {
  // ─── PRODUCTION TOGGLE ─────────────────────────────────────────────────────
  // Set this to true when building the APK for the actual school release!
  static const bool isProduction = true; 

  // ─── SERVER URLS ───────────────────────────────────────────────────────────
  // Replace these with your actual live server URLs when you deploy.
  static const String devUrl = 'http://192.168.254.109:5000';
  static const String prodUrl = 'https://autodemy-mobile-app.onrender.com'; // Live Render Server

  // ─── COMPUTED BASE URL ─────────────────────────────────────────────────────
  static String get baseUrl => isProduction ? prodUrl : devUrl;
  static String get apiBaseUrl => '$baseUrl/api';
}
