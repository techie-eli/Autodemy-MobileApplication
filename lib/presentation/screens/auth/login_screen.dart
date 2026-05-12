import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/student_model.dart';
import '../admin/admin_home.dart';
import '../teacher/teacher_home.dart';
import '../student/student_home.dart';
import '../support/request_support_screen.dart';
import './forgot_password.dart';
import './register_screen.dart';
import '../../../data/app_data.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  void _attemptLogin() async {
    final inputEmail = _usernameController.text.trim();
    final inputPass = _passwordController.text.trim();

    if (inputEmail.isEmpty || inputPass.isEmpty) {
      _showError('Please fill all fields');
      return;
    }

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();

    try {
      // 1. Firebase Authentication
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: inputEmail,
        password: inputPass,
      );

      final user = userCredential.user;
      if (user != null && mounted) {
        if (!user.emailVerified) {
          await FirebaseAuth.instance.signOut();
          _showError('Please verify your email address before logging in. Check your inbox.');
          setState(() => _isLoading = false);
          return;
        }

        // 2. Fetch User Profile from our Node.js Backend
        final loginResponse = await ApiService.login(inputEmail, inputPass);
        if (loginResponse != null) {
          final userData = loginResponse['user'];
          final role = userData['role'];

          // ── SAVE FOR PERSISTENT LOGIN ─────────────────────────────────────
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_data', jsonEncode(userData));
          
          NotificationService.showLocalNotification(
            'Login Successful',
            'Welcome back, ${userData['name']}!',
            type: 'system',
          );

          // Sync biometric state for the logged in user
          final userId = userData['id']?.toString();
          final userName = userData['name']?.toString();
          bool isEnabled = false;
          if (userId != null) {
            isEnabled = prefs.getBool('biometric_enabled_$userId') ?? false;
          }
          if (!isEnabled && userName != null) {
            isEnabled = prefs.getBool('biometric_enabled_$userName') ?? false;
          }

          AppData.isLocked.value = false; // Set unlocked first
          AppData.biometricEnabled.value = isEnabled; // Then enable if needed
          AppData.currentUserName.value = userData['name']?.toString() ?? '';

          if (!mounted) return;
          if (role == 'ADMIN') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminHomeScreen()));
          } else if (role == 'TEACHER') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => TeacherHomeScreen(
                teacherId: userData['id'].toString(),
                teacherName: userData['name'].toString(),
              )),
            );
          } else if (role == 'STUDENT') {
            final student = Student.fromMap(userData);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => StudentHomeScreen(student: student)),
            );
          } else {
            _showError('Unknown user role. Please contact your admin.');
            setState(() => _isLoading = false);
          }
        } else {
          _showError('Account not found in the system. Please contact your admin.');
        }
      }
    } catch (e) {
      _showError('Login Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primary, Color(0xFF0D123D)],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.school_rounded,
                          color: AppTheme.accent, size: 80),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'AUTODEMY',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                    ),
                    Text(
                      'Smart Academic Management',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                    const SizedBox(height: 50),

                    // Login Card
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Login',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _usernameController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'University Email',
                              hintText: 'e.g. user@shs.nu-dasma.edu.ph',
                              prefixIcon: const Icon(Icons.email_outlined),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Enter your password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordScreen(),
                                ),
                              ),
                              child: const Text('Forgot Password?',
                                  style: TextStyle(color: AppTheme.primary)),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Removed Register Here from the card
                          // Fingerprint Loging
                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : SizedBox(
                                  width: double.infinity,
                                  height: 60,
                                  child: ElevatedButton(
                                    onPressed: _attemptLogin,
                                    child: const Text('LOG IN'),
                                  ),
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(color: Colors.white70, fontSize: 15),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RegisterScreen()),
                            );
                          },
                          child: const Text(
                            'Register Here',
                            style: TextStyle(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
