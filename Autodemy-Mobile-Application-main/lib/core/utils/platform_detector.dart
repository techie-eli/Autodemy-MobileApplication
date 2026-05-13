import 'package:flutter/foundation.dart';

class PlatformDetector {
  static bool get isWeb => kIsWeb;

  static bool get isMobile => !kIsWeb;

  static bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isWindows => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static bool get isMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  static bool get isLinux => !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
}