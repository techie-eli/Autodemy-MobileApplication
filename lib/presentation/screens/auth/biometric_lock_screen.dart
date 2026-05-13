import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/theme/app_theme.dart';

class BiometricLockScreen extends StatefulWidget {
  final Widget child; // The screen to show after successful auth
  final bool isOverlay; // Whether this is showing as a privacy overlay
  final bool isLocked; // Control from parent whether it should lock
  final VoidCallback? onUnlocked;
  const BiometricLockScreen({super.key, required this.child, this.isOverlay = false, this.isLocked = true, this.onUnlocked});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> with SingleTickerProviderStateMixin {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticated = false;
  bool _isAuthenticating = false;
  String _errorMessage = '';

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _isAuthenticated = !widget.isLocked;
    
    _animController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 1500)
    )..repeat(reverse: true);
    
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.5, curve: Curves.easeIn))
    );
    
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut)
    );
    
    // Automatically trigger auth on start if locked
    if (widget.isLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _authenticate();
      });
    }
  }

  @override
  void didUpdateWidget(BiometricLockScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLocked && !oldWidget.isLocked && _isAuthenticated) {
      setState(() {
        _isAuthenticated = false;
      });
      _authenticate();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _errorMessage = '';
    });

    try {
      final didAuth = await _auth.authenticate(
        localizedReason: 'Secure Identity Verification Required',
        options: const AuthenticationOptions(
          biometricOnly: false, // Allow PIN/Passcode/Pattern fallbacks
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (didAuth) {
        setState(() => _isAuthenticated = true);
        widget.onUnlocked?.call();
      } else {
        setState(() => _errorMessage = 'Authentication required to proceed.');
      }
    } catch (e) {
      // Fallback if biometric fails or not available
      try {
        final didAuthFallback = await _auth.authenticate(
          localizedReason: 'Please verify your identity',
          options: const AuthenticationOptions(
            biometricOnly: false,
            stickyAuth: true,
          ),
        );
        if (didAuthFallback) setState(() => _isAuthenticated = true);
      } catch (e2) {
        setState(() => _errorMessage = 'Security System Error: Device lock not configured.');
      }
    } finally {
      setState(() => _isAuthenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated) return widget.child;

    return Scaffold(
      backgroundColor: Colors.black, // Pure black for OLED/Premium feel
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withOpacity(0.05),
              blurRadius: 100,
              spreadRadius: 10,
            )
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Animated Shield/Lock Icon
              ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.accent.withOpacity(0.2), 
                      width: 1.5
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.fingerprint_rounded,
                        size: 80,
                        color: AppTheme.accent.withOpacity(0.8),
                      ),
                      // Outer rotating circle could go here for more "tech" feel
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 48),

              const Text(
                'SECURE MODE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline_rounded, color: AppTheme.accent, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      'ENCRYPTED SESSION',
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Main Unlock Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton(
                      onPressed: _isAuthenticating ? null : _authenticate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 0,
                      ),
                      child: _isAuthenticating 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.black))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.fingerprint, size: 28),
                              const SizedBox(width: 12),
                              const Text(
                                'AUTHENTICATE',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5),
                              ),
                            ],
                          ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
              
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                )
              else
                Text(
                  'Place your finger on the sensor',
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                ),

              const Spacer(flex: 2),

              // Bottom Branding
              Text(
                'AUTODEMY INTELLIGENT SECURITY',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.2), 
                  fontSize: 9, 
                  letterSpacing: 3, 
                  fontWeight: FontWeight.bold
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

