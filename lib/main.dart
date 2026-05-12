import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'core/theme/app_theme.dart';
import 'presentation/screens/auth/splash_screen.dart';
import 'presentation/screens/auth/biometric_lock_screen.dart';
import 'data/services/offline_service.dart';
import 'data/services/notification_service.dart';
import 'data/app_data.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Offline Queue
  await OfflineService.init();

  // Initialize Notifications
  await NotificationService.initialize();
  
  // Check Biometric Preference for the last user
  final prefs = await SharedPreferences.getInstance();
  final userDataStr = prefs.getString('user_data');
  if (userDataStr != null) {
    try {
      final userData = jsonDecode(userDataStr);
      final userId = userData['id']?.toString();
      final userName = userData['name']?.toString();
      
      // Try ID first (more reliable), then Name (legacy)
      bool isEnabled = false;
      if (userId != null) {
        isEnabled = prefs.getBool('biometric_enabled_$userId') ?? false;
      }
      if (!isEnabled && userName != null) {
        isEnabled = prefs.getBool('biometric_enabled_$userName') ?? false;
      }
      
      AppData.biometricEnabled.value = isEnabled;
      if (userName != null) {
        AppData.currentUserName.value = userName;
      }
    } catch (e) {
      debugPrint("Error parsing user data for biometrics: $e");
    }
  }
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint("AUTODEMY: Firebase initialized successfully.");
  } catch (e) {
    debugPrint("AUTODEMY: Firebase initialization failed: $e");
    // For unsupported platforms like Linux, continue without Firebase
  }

  runApp(GlobalNotificationListener(child: const AutodemyApp()));
}

class GlobalNotificationListener extends StatefulWidget {
  final Widget child;
  const GlobalNotificationListener({super.key, required this.child});

  @override
  State<GlobalNotificationListener> createState() => _GlobalNotificationListenerState();
}

class _GlobalNotificationListenerState extends State<GlobalNotificationListener> {
  StreamSubscription? _notifSub;

  @override
  void initState() {
    super.initState();
    _notifSub = NotificationService.notifications.listen((notif) {
      _showGlobalOverlay(notif);
    });
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  void _showGlobalOverlay(Map<String, dynamic> notif) {
    scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.campaign_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notif['title'] ?? 'New Announcement', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(notif['body'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: AppTheme.accent,
          onPressed: () => scaffoldMessengerKey.currentState?.hideCurrentSnackBar(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class AutodemyApp extends StatefulWidget {
  const AutodemyApp({super.key});

  @override
  State<AutodemyApp> createState() => _AutodemyAppState();
}

class _AutodemyAppState extends State<AutodemyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!AppData.biometricEnabled.value) return;

    // ONLY lock when the app is fully backgrounded (paused)
    // Avoid locking on 'inactive' which triggers during screenshots or system dialogs
    if (state == AppLifecycleState.paused) {
      if (!AppData.preventLock) {
        // App is going to background, lock it immediately for privacy
        AppData.isLocked.value = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppData.biometricEnabled,
      builder: (context, isEnabled, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: AppData.isLocked,
          builder: (context, isLocked, child) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              scaffoldMessengerKey: scaffoldMessengerKey,
              title: 'Autodemy',
              theme: AppTheme.lightTheme,
              home: const SplashScreen(),
              builder: (context, child) {
                if (isEnabled && child != null) {
                  return BiometricLockScreen(
                    key: const ValueKey('biometric_lock'),
                    isLocked: isLocked,
                    onUnlocked: () {
                      AppData.isLocked.value = false;
                    },
                    child: child,
                  );
                }
                return child ?? const SizedBox.shrink();
              },
            );
          }
        );
      }
    );
  }
}