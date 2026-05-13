import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/theme/app_theme.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_screen.dart';
import '../student/student_home.dart';
import '../teacher/teacher_home.dart';
import '../admin/admin_home.dart';
import '../../../data/models/student_model.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  // 3 distinct animations
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotateAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup animations with 2.5 seconds total duration
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // 1. Logo Scale Animation (0.0 to 1.0 time)
    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    // 2. Logo Rotate Animation (0.0 to 1.0 time)
    _logoRotateAnimation = Tween<double>(begin: -0.5, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // 3. Text Slide Up Animation (0.4 to 0.8 time)
    _textSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    // Overall Fade for text & loader (0.4 to 1.0 time)
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // ── PERSISTENT LOGIN & AUTO-REDIRECT ───────────────────────────────────
    Timer(const Duration(seconds: 4), () async {
      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      final userDataStr = prefs.getString('user_data');

      if (userDataStr != null) {
        try {
          final userData = jsonDecode(userDataStr);
          final String role = (userData['role'] ?? 'STUDENT').toString().toUpperCase();

          Widget nextScreen;
          if (role == 'TEACHER') {
            nextScreen = TeacherHomeScreen(
              teacherId: userData['id']?.toString() ?? 'T1',
              teacherName: userData['name']?.toString() ?? 'Teacher',
            );
          } else if (role == 'ADMIN') {
            nextScreen = const AdminHomeScreen();
          } else {
            // STUDENT
            nextScreen = StudentHomeScreen(student: Student.fromMap(userData));
          }

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => nextScreen),
            );
          }
          return;
        } catch (e) {
          debugPrint("Auto-login error: $e");
        }
      }

      // Default to Onboarding if no user found
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animation 1 & 2: Scale and Rotate the Logo
            ScaleTransition(
              scale: _logoScaleAnimation,
              child: RotationTransition(
                turns: _logoRotateAnimation,
                child: Container(
                  height: 180,
                  width: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.school_rounded,
                      size: 120,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Animation 3: Slide and Fade for the App Name
            SlideTransition(
              position: _textSlideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    const Text(
                      'AUTODEMY',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Intelligent School Management',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.8),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 64),
            
            // Fade for the Loading Indicator
            FadeTransition(
              opacity: _fadeAnimation,
              child: const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
