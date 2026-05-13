import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:webauthn/webauthn.dart';
import 'package:universal_html/html.dart' as html;

class StudentWebAuthnService {
  static const String baseUrl = 'http://localhost:3000/api/student-webauthn';

  static Future<Map<String, dynamic>> getRegistrationOptions(String studentName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final token = await user.getIdToken();

    final response = await http.post(
      Uri.parse('$baseUrl/register/options'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'studentName': studentName}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get registration options: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> verifyRegistration(Map<String, dynamic> response) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final token = await user.getIdToken();

    final httpResponse = await http.post(
      Uri.parse('$baseUrl/register/verify'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'response': response}),
    );

    if (httpResponse.statusCode == 200) {
      return jsonDecode(httpResponse.body);
    } else {
      throw Exception('Failed to verify registration: ${httpResponse.body}');
    }
  }

  static Future<Map<String, dynamic>> getAuthenticationOptions() async {
    final response = await http.post(
      Uri.parse('$baseUrl/authenticate/options'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get authentication options: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> verifyAuthentication(
    Map<String, dynamic> response,
    String challengeId,
    String firebaseUid,
  ) async {
    final httpResponse = await http.post(
      Uri.parse('$baseUrl/authenticate/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'response': response,
        'challengeId': challengeId,
        'firebaseUid': firebaseUid,
      }),
    );

    if (httpResponse.statusCode == 200) {
      return jsonDecode(httpResponse.body);
    } else {
      throw Exception('Failed to verify authentication: ${httpResponse.body}');
    }
  }

  static Future<Map<String, dynamic>> checkHasPasskey() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final token = await user.getIdToken();

    final response = await http.get(
      Uri.parse('$baseUrl/has-passkey'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to check passkey: ${response.body}');
    }
  }

  static Future<void> deletePasskey() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final token = await user.getIdToken();

    final response = await http.delete(
      Uri.parse('$baseUrl/credential'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete passkey: ${response.body}');
    }
  }

  // Cross-platform WebAuthn registration
  static Future<Map<String, dynamic>> registerPasskey(Map<String, dynamic> serverOptions) async {
    if (kIsWeb) {
      return _registerPasskeyWeb(serverOptions);
    } else {
      return _registerPasskeyMobile(serverOptions);
    }
  }

  // Cross-platform WebAuthn authentication
  static Future<Map<String, dynamic>> authenticatePasskey(Map<String, dynamic> serverOptions) async {
    if (kIsWeb) {
      return _authenticatePasskeyWeb(serverOptions);
    } else {
      return _authenticatePasskeyMobile(serverOptions);
    }
  }

  // Web implementation using browser WebAuthn API
  static Future<Map<String, dynamic>> _registerPasskeyWeb(Map<String, dynamic> serverOptions) async {
    final options = serverOptions['options'];

    try {
      // Dart's html library expects a standard Map for JS dictionaries
      final credential = await html.window.navigator.credentials!.create({
        'publicKey': {
          'challenge': _base64UrlDecode(options['challenge']),
          'rp': {
            'name': options['rp']['name'],
            'id': options['rp']['id'],
          },
          'user': {
            'id': _base64UrlDecode(options['user']['id']),
            'name': options['user']['name'],
            'displayName': options['user']['displayName'],
          },
          'pubKeyCredParams': options['pubKeyCredParams'],
          'authenticatorSelection': {
            'authenticatorAttachment': 'platform',
            'requireResidentKey': false,
            'userVerification': 'preferred',
          },
          'timeout': 60000,
          'attestation': 'direct',
        }
      }) as html.PublicKeyCredential;

      // FIX: Cast to dynamic to bypass Dart's incomplete HTML type definitions
      final dynamic response = credential.response;

      // Convert to the format expected by the server
      return {
        'type': 'public-key',
        'id': credential.id,
        'rawId': _base64UrlEncode((credential.rawId as dynamic).asUint8List()),
        'response': {
          'clientDataJSON': _base64UrlEncode((response.clientDataJSON as dynamic).asUint8List()),
          'attestationObject': _base64UrlEncode((response.attestationObject as dynamic).asUint8List()),
        },
      };
    } catch (e) {
      throw Exception('WebAuthn registration failed: $e');
    }
  }

  // Mobile implementation using webauthn package
  static Future<Map<String, dynamic>> _registerPasskeyMobile(Map<String, dynamic> serverOptions) async {
    final auth = Authenticator(true, false);
    final options = StudentWebAuthnService.createMakeCredentialOptions(serverOptions);

    try {
      final attestation = await auth.makeCredential(options);

      final webApi = WebAPI();
      final collectedClientData = await webApi.createMakeCredentialOptions(
        'http://localhost:3000',
        CreateCredentialOptions.fromJson(serverOptions['options']),
        true,
      );

      await webApi.createAttestationResponse(
        collectedClientData.$1,
        attestation,
      );

      return {
        'type': 'public-key',
        'id': WebAPI.base64Encode(attestation.getCredentialId()),
        'rawId': WebAPI.base64Encode(attestation.getCredentialId()),
        'response': {
          'clientDataJSON': WebAPI.base64Encode(collectedClientData.$1.encode()),
          'attestationObject': WebAPI.base64Encode(attestation.asCBOR()),
        },
      };
    } catch (e) {
      throw Exception('WebAuthn registration failed: $e');
    }
  }

  // Web implementation for authentication
  static Future<Map<String, dynamic>> _authenticatePasskeyWeb(Map<String, dynamic> serverOptions) async {
    final options = serverOptions['options'];

    try {
      final assertion = await html.window.navigator.credentials!.get({
        'publicKey': {
          'challenge': _base64UrlDecode(options['challenge']),
          'rpId': options['rpId'],
          'allowCredentials': (options['allowCredentials'] as List?)?.map((cred) {
            return {
              'type': 'public-key',
              'id': _base64UrlDecode(cred['id']),
            };
          }).toList(),
          'userVerification': 'preferred',
          'timeout': 60000,
        }
      }) as html.PublicKeyCredential;

      // FIX: Cast to dynamic to bypass Dart's incomplete HTML type definitions
      final dynamic response = assertion.response;

      return {
        'type': 'public-key',
        'id': assertion.id,
        'rawId': _base64UrlEncode((assertion.rawId as dynamic).asUint8List()),
        'response': {
          'clientDataJSON': _base64UrlEncode((response.clientDataJSON as dynamic).asUint8List()),
          'authenticatorData': _base64UrlEncode((response.authenticatorData as dynamic).asUint8List()),
          'signature': _base64UrlEncode((response.signature as dynamic).asUint8List()),
          'userHandle': response.userHandle != null
              ? _base64UrlEncode((response.userHandle as dynamic).asUint8List())
              : null,
        },
      };
    } catch (e) {
      throw Exception('WebAuthn authentication failed: $e');
    }
  }

  // Mobile implementation for authentication
  static Future<Map<String, dynamic>> _authenticatePasskeyMobile(Map<String, dynamic> serverOptions) async {
    final auth = Authenticator(true, false);
    final options = StudentWebAuthnService.createGetAssertionOptions(serverOptions);

    try {
      final assertion = await auth.getAssertion(options);

      final webApi = WebAPI();
      final collectedClientData = await webApi.createGetAssertionOptions(
        'http://localhost:3000',
        CredentialRequestOptions.fromJson(serverOptions['options']),
        true,
      );

      await webApi.createAssertionResponse(
        collectedClientData.$1,
        assertion,
      );

      return {
        'type': 'public-key',
        'id': WebAPI.base64Encode(assertion.selectedCredentialId),
        'rawId': WebAPI.base64Encode(assertion.selectedCredentialId),
        'response': {
          'clientDataJSON': WebAPI.base64Encode(collectedClientData.$1.encode()),
          'authenticatorData': WebAPI.base64Encode(assertion.authenticatorData),
          'signature': WebAPI.base64Encode(assertion.signature),
          'userHandle': WebAPI.base64Encode(assertion.selectedCredentialUserHandle),
        },
      };
    } catch (e) {
      throw Exception('WebAuthn authentication failed: $e');
    }
  }

  // Helper methods for base64url encoding/decoding
  static Uint8List _base64UrlDecode(String base64Url) {
    String base64 = base64Url.replaceAll('-', '+').replaceAll('_', '/');
    while (base64.length % 4 != 0) {
      base64 += '=';
    }
    return base64Decode(base64);
  }

  static String _base64UrlEncode(Uint8List bytes) {
    return base64Encode(bytes).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
  }

  // Helper method to create WebAuthn options from server response
  static MakeCredentialOptions createMakeCredentialOptions(Map<String, dynamic> serverOptions) {
    final options = serverOptions['options'];
    final publicKey = options['publicKey'];

    return MakeCredentialOptions(
      clientDataHash: WebAPI.base64Decode(options['challenge']),
      rpEntity: RpEntity(
        id: publicKey['rp']['id'],
        name: publicKey['rp']['name'],
      ),
      userEntity: UserEntity(
        id: Uint8List.fromList(publicKey['user']['id'].codeUnits),
        name: publicKey['user']['name'],
        displayName: publicKey['user']['displayName'],
      ),
      requireResidentKey: publicKey['authenticatorSelection']['requireResidentKey'] ?? false,
      requireUserPresence: publicKey['authenticatorSelection']['userVerification'] != 'required',
      requireUserVerification: publicKey['authenticatorSelection']['userVerification'] == 'required',
      credTypesAndPubKeyAlgs: (publicKey['pubKeyCredParams'] as List)
          .map((param) => CredTypePubKeyAlgoPair(
                credType: PublicKeyCredentialType.publicKey,
                pubKeyAlgo: param['alg'],
              ))
          .toList(),
    );
  }

  // Helper method to create WebAuthn assertion options from server response
  static GetAssertionOptions createGetAssertionOptions(Map<String, dynamic> serverOptions) {
    final options = serverOptions['options'];
    final publicKey = options['publicKey'];

    return GetAssertionOptions(
      rpId: publicKey['rpId'],
      clientDataHash: WebAPI.base64Decode(options['challenge']),
      requireUserPresence: publicKey['userVerification'] != 'required',
      requireUserVerification: publicKey['userVerification'] == 'required',
      allowCredentialDescriptorList: (publicKey['allowCredentials'] as List?)
          ?.map((cred) => PublicKeyCredentialDescriptor(
                id: WebAPI.base64Decode(cred['id']),
                type: PublicKeyCredentialType.publicKey,
              ))
          .toList(),
    );
  }
}