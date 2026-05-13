import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/api_service.dart';
import '../support/request_support_screen.dart';
import '../auth/login_screen.dart';
import '../../../data/app_data.dart';

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../../../data/app_data.dart';

class ProfileScreen extends StatefulWidget {
  final String userName;
  final String userRole;
  final String? idNumber;
  final bool embedded;

  const ProfileScreen({
    super.key,
    required this.userName,
    required this.userRole,
    this.idNumber,
    this.embedded = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _profileImage;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    _loadBiometricSettings();
  }

  Future<void> _loadBiometricSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = await ApiService.getUserData();
    final userId = userData?['id']?.toString();
    
    setState(() {
      bool isEnabled = false;
      if (userId != null) {
        isEnabled = prefs.getBool('biometric_enabled_$userId') ?? false;
      }
      // Fallback to name for legacy settings or Admin screen mismatch
      if (!isEnabled) {
        isEnabled = prefs.getBool('biometric_enabled_${widget.userName}') ?? false;
      }
      _biometricEnabled = isEnabled;
    });
  }

  Future<void> _toggleBiometric(bool enable) async {
    final auth = LocalAuthentication();
    
    // Check if biometrics are even supported on this device
    final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
    final bool isDeviceSupported = await auth.isDeviceSupported();

    if (!canAuthenticateWithBiometrics || !isDeviceSupported) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometrics are not supported or set up on this device.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      setState(() => _biometricEnabled = false);
      return;
    }

    if (enable) {
      try {
        final didAuth = await auth.authenticate(
          localizedReason: 'Please authenticate to enable biometric login.',
          options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
        );
        if (didAuth) {
          setState(() => _biometricEnabled = true);
          final prefs = await SharedPreferences.getInstance();
          final userData = await ApiService.getUserData();
          final userId = userData?['id']?.toString() ?? widget.userName;

          await prefs.setBool('biometric_enabled_$userId', true);
          AppData.isLocked.value = false; // Ensure it's unlocked first
          AppData.biometricEnabled.value = true; // Then enable the overlay
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App Lock Enabled'), backgroundColor: Colors.green));
          }
        } else {
          setState(() => _biometricEnabled = false);
        }
      } catch (e) {
        setState(() => _biometricEnabled = false);
        if (mounted) {
          String msg = e.toString();
          if (msg.contains('NotAvailable')) msg = 'Biometric security is not enrolled on this device.';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Security error: $msg'), backgroundColor: Colors.redAccent));
        }
      }
    } else {
      setState(() => _biometricEnabled = false);
      final prefs = await SharedPreferences.getInstance();
      final userData = await ApiService.getUserData();
      final userId = userData?['id']?.toString() ?? widget.userName;

      await prefs.setBool('biometric_enabled_$userId', false);
      // Also clear legacy name-based key if it exists
      await prefs.setBool('biometric_enabled_${widget.userName}', false);
      
      AppData.biometricEnabled.value = false;
    }
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profile_image_${widget.userName}');
    if (imagePath != null && File(imagePath).existsSync()) {
      setState(() {
        _profileImage = File(imagePath);
      });
    }
  }

  Future<void> _pickImage() async {
    AppData.preventLock = true;
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
        // Save the selected image path locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image_${widget.userName}', pickedFile.path);
      }
    } finally {
      // Extended delay to ensure OS transition is finished before re-enabling lock observer
      Future.delayed(const Duration(seconds: 1), () {
        AppData.preventLock = false;
      });
    }
  }

  void _logout(BuildContext context) async {
    // Reset security state on logout
    AppData.biometricEnabled.value = false;
    AppData.isLocked.value = true; // Default for next session
    
    await ApiService.clearToken();
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Future<void> _editProfile() async {
    final TextEditingController nameCtrl = TextEditingController(text: widget.userName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != widget.userName) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saving...')));
      final success = await ApiService.updateProfile(newName);
      if (mounted) {
        if (success) {
          AppData.currentUserName.value = newName;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update profile.'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Password reset link sent to ${user.email}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send reset email: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active Firebase session found. Please log out and log in again.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.embedded ? Colors.transparent : Colors.grey.shade50,
      body: Column(
        children: [
          // ── Blue Header Cap for consistency across all screens
          Container(
            height: MediaQuery.of(context).padding.top + 32,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
              children: [
                // ── Profile Identity Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(24),
                                image: _profileImage != null 
                                    ? DecorationImage(image: FileImage(_profileImage!), fit: BoxFit.cover)
                                    : null,
                              ),
                              child: _profileImage == null
                                  ? const Icon(Icons.person_rounded, size: 40, color: AppTheme.primary)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ValueListenableBuilder<String>(
                              valueListenable: AppData.currentUserName,
                              builder: (context, currentName, _) {
                                return Text(
                                  currentName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                widget.userRole.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primary,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
          
          _buildMenuTitle('ACCOUNT'),
          _buildMenuTile(
            icon: Icons.edit_rounded,
            title: 'Edit Profile',
            onTap: _editProfile,
          ),
          _buildMenuTile(
            icon: Icons.lock_outline_rounded,
            title: 'Change Password',
            onTap: _changePassword,
          ),
          _buildSwitchTile(
            icon: Icons.fingerprint_rounded,
            title: 'App Lock (PIN/Biometric)',
            value: _biometricEnabled,
            onChanged: _toggleBiometric,
          ),

          const SizedBox(height: 24),
          _buildMenuTitle('HELP & SUPPORT'),
          if (widget.userRole != 'Admin')
            _buildMenuTile(
              icon: Icons.support_agent_rounded,
              title: 'Request Support',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RequestSupportScreen(
                      senderName: widget.userName,
                      senderRole: widget.userRole,
                      embedded: false,
                    ),
                  ),
                );
              },
            ),
          _buildMenuTile(
            icon: Icons.info_outline_rounded,
            title: 'About Autodemy',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Autodemy',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(Icons.school_rounded, size: 48, color: AppTheme.primary),
                applicationLegalese: '© 2026 Autodemy Solutions',
                children: const [
                  SizedBox(height: 16),
                  Text('Autodemy is an automated student attendance and records management system designed to make school operations seamless and secure.'),
                ],
              );
            },
          ),

          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: () => _logout(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red.shade700,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('LOGOUT', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMenuTile({required IconData icon, required String title, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSwitchTile({required IconData icon, required String title, required bool value, required ValueChanged<bool> onChanged}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        trailing: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.primary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
