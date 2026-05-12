import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authCodeController = TextEditingController();

  String _selectedRole = 'STUDENT'; // default role
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirmPass = true;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final name = _selectedRole == 'STUDENT' ? _nameController.text.trim() : email.split('@')[0];
    final password = _passwordController.text.trim();
    final idNumber = _selectedRole == 'STUDENT' ? _idController.text.trim() : 'N/A';

    // Secret keys removed per user request - security now relies on official email domains.

    // Enforce domain for Production
    if (_selectedRole == 'STUDENT') {
      if (!email.endsWith('@shs.nu-dasma.edu.ph')) {
        _showError('Students must use an @shs.nu-dasma.edu.ph email address.');
        return;
      }
    } else {
      // Teacher or Admin
      if (!email.endsWith('@nu-dasma.edu.ph')) {
        _showError('Faculty and Staff must use an @nu-dasma.edu.ph email address.');
        return;
      }
    }

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();

    try {
      // 1. Create User
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        // 2. Send Verification Email
        await user.sendEmailVerification();

        // 3. Save profile to MongoDB via Node.js API
        final result = await ApiService.registerWithResult({
          'name': name,
          'username': email,
          'email': email,
          'password': password,
          'role': _selectedRole,
          'idNumber': idNumber,
          'firebaseUid': user.uid,
        });

        if (!result['success']) {
           // Rollback: Delete the Firebase user since backend sync failed
           try {
             await user.delete();
             print('Rolled back Firebase user creation due to backend sync failure.');
           } catch (rollbackError) {
             print('Rollback failed: $rollbackError');
           }
           _showError('Backend Sync Failed: ${result['message']}');
           return;
        }

        if (!mounted) return;
        
        // Send email verification
        try {
          await user.sendEmailVerification();
          print('Verification email sent.');
        } catch (e) {
          print('Failed to send verification email: $e');
        }
        
        // 4. Show premium success dialog
        _showSuccessDialog(email);
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Registration failed.');
    } catch (e) {
      _showError('An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String email) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Success',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              contentPadding: const EdgeInsets.all(32),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mark_email_read_rounded, color: Colors.green, size: 48),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Verification Sent',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We\'ve sent a link to $email. Please verify your email to activate your account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text('GOT IT, THANKS!', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo or Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_add_alt_1_rounded, size: 64, color: AppTheme.primary),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Create an Account',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Register using your university email',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                ),
                const SizedBox(height: 40),

                // Role Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: InputDecoration(
                    labelText: 'Select Role',
                    prefixIcon: const Icon(Icons.badge_rounded, color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'STUDENT', child: Text('Student')),
                    DropdownMenuItem(value: 'TEACHER', child: Text('Teacher/Professor')),
                    DropdownMenuItem(value: 'ADMIN', child: Text('Administrator')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRole = val);
                  },
                ),
                const SizedBox(height: 16),

                if (_selectedRole == 'STUDENT') ...[
                  // Name Field
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: const Icon(Icons.person_rounded, color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: 16),

                  // ID Number Field
                  TextFormField(
                    controller: _idController,
                    decoration: InputDecoration(
                      labelText: 'ID / Student Number',
                      prefixIcon: const Icon(Icons.badge_rounded, color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Enter your ID number' : null,
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  // Authorization Code Field for Admins/Teachers
                  TextFormField(
                    controller: _authCodeController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Authorization Code',
                      hintText: 'Enter secret key',
                      prefixIcon: const Icon(Icons.key_rounded, color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Required for this role' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'University Email',
                    hintText: 'e.g., @shs.nu-dasma.edu.ph or @students.national-u.edu.ph',
                    prefixIcon: const Icon(Icons.email_rounded, color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Enter your email';
                    if (!val.contains('@')) return 'Invalid email address';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePass,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_rounded, color: AppTheme.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Enter a password';
                    if (val.length < 8) return 'Min 8 characters';
                    if (!RegExp(r'[A-Z]').hasMatch(val)) return 'Requires uppercase letter';
                    if (!RegExp(r'[a-z]').hasMatch(val)) return 'Requires lowercase letter';
                    if (!RegExp(r'[0-9]').hasMatch(val)) return 'Requires a number';
                    if (!RegExp(r'[!@#\$&*~]').hasMatch(val)) return 'Requires special character (!@#\$&*~)';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm Password
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPass,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_clock_rounded, color: AppTheme.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPass ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  validator: (val) {
                    if (val != _passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Register Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isLoading ? Colors.grey.shade300 : AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: _isLoading ? 0 : 8,
                        shadowColor: AppTheme.primary.withOpacity(0.4),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppTheme.primary,
                              ),
                            )
                          : const Text(
                              'REGISTER NOW',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
