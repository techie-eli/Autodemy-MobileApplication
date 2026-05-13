import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/utils/platform_detector.dart';
import '../../data/services/student_webauthn_service.dart';

class StudentQrGenerationScreen extends StatefulWidget {
  const StudentQrGenerationScreen({super.key});

  @override
  State<StudentQrGenerationScreen> createState() => _StudentQrGenerationScreenState();
}

class _StudentQrGenerationScreenState extends State<StudentQrGenerationScreen> {
  String? _qrData;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _errorMessage;
  bool _hasPasskey = false;

  @override
  void initState() {
    super.initState();
    _checkPasskeyStatus();
  }

  Future<void> _checkPasskeyStatus() async {
    try {
      final result = await StudentWebAuthnService.checkHasPasskey();
      setState(() {
        _hasPasskey = result['hasPasskey'] ?? false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to check passkey status: $e';
      });
    }
  }

  Future<void> _registerPasskey() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get registration options from server
      final serverOptions = await StudentWebAuthnService.getRegistrationOptions(
        user.displayName ?? user.email ?? 'Student'
      );

      // Register passkey using cross-platform API
      final credential = await StudentWebAuthnService.registerPasskey(serverOptions);

      // Verify with server
      await StudentWebAuthnService.verifyRegistration(credential);

      setState(() {
        _hasPasskey = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passkey registered successfully!')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to register passkey: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _authenticateAndGenerateQR() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get authentication options from server
      final serverOptions = await StudentWebAuthnService.getAuthenticationOptions();
      final challengeId = serverOptions['challengeId'];

      // Authenticate using cross-platform API
      final assertion = await StudentWebAuthnService.authenticatePasskey(serverOptions);

      // Verify with server
      await StudentWebAuthnService.verifyAuthentication(
        assertion,
        challengeId,
        user.uid,
      );

      setState(() {
        _isAuthenticated = true;
      });

      // Generate QR code data
      _generateQRCode();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication successful!')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Authentication failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _generateQRCode() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Generate QR data with timestamp for uniqueness
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        _qrData = 'STUDENT:${user.uid}:$timestamp';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student QR Code'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            if (PlatformDetector.isWeb && !_hasPasskey)
              _buildPasskeySetupSection()
            else if (PlatformDetector.isWeb && !_isAuthenticated)
              _buildAuthenticationSection()
            else
              _buildQRCodeSection(),

            if (PlatformDetector.isMobile)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Mobile users are already authenticated via app lock.',
                  style: TextStyle(color: Colors.green),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasskeySetupSection() {
    return Column(
      children: [
        const Icon(Icons.security, size: 64, color: Colors.blue),
        const SizedBox(height: 16),
        const Text(
          'Set up Biometric Authentication',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Register a passkey to securely authenticate before generating QR codes.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _registerPasskey,
          child: _isLoading
              ? const CircularProgressIndicator()
              : const Text('Register Passkey'),
        ),
      ],
    );
  }

  Widget _buildAuthenticationSection() {
    return Column(
      children: [
        const Icon(Icons.fingerprint, size: 64, color: Colors.blue),
        const SizedBox(height: 16),
        const Text(
          'Biometric Authentication Required',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Use your fingerprint, Face ID, or device PIN to authenticate.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _authenticateAndGenerateQR,
          child: _isLoading
              ? const CircularProgressIndicator()
              : const Text('Authenticate & Generate QR'),
        ),
      ],
    );
  }

  Widget _buildQRCodeSection() {
    return Column(
      children: [
        if (_qrData != null) ...[
          const Text(
            'Your QR Code',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: _qrData!,
              version: QrVersions.auto,
              size: 200.0,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Generated at: ${DateTime.now().toString()}',
            style: const TextStyle(color: Colors.grey),
          ),
        ] else if (PlatformDetector.isMobile) ...[
          const Icon(Icons.qr_code, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          const Text(
            'Ready to Generate QR Code',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _generateQRCode,
            child: const Text('Generate QR Code'),
          ),
        ],
      ],
    );
  }
}