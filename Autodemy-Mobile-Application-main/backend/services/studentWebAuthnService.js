const {
  generateRegistrationOptions,
  verifyRegistrationResponse,
  generateAuthenticationOptions,
  verifyAuthenticationResponse
} = require('@simplewebauthn/server');
const StudentWebAuthnCredential = require('../models/StudentWebAuthnCredential');

const rpName = process.env.WEBAUTHN_RP_NAME || 'Autodemy';
const rpID = process.env.WEBAUTHN_RP_ID || 'localhost';
const origin = process.env.WEBAUTHN_ORIGIN || 'http://localhost:3000';

class StudentWebAuthnService {
  /**
   * Generate registration options for a student's new passkey
   */
  static async generateRegistrationOptions(firebaseUid, studentName) {
    const options = await generateRegistrationOptions({
      rpName,
      rpID,
      userID: firebaseUid,
      userName: firebaseUid,
      userDisplayName: studentName || firebaseUid,
      attestationType: 'direct',
      authenticatorSelection: {
        authenticatorAttachment: 'platform',
        residentKey: 'preferred',
        userVerification: 'preferred'
      },
      supportedAlgorithmIDs: [-7, -257]
    });

    return {
      options,
      challenge: options.challenge
    };
  }

  /**
   * Verify and save student's passkey
   */
  static async verifyRegistrationResponse(firebaseUid, registrationResponse, expectedChallenge) {
    try {
      const verification = await verifyRegistrationResponse({
        response: registrationResponse,
        expectedChallenge,
        expectedOrigin: origin,
        expectedRPID: rpID,
        supportedAlgorithmIDs: [-7, -257]
      });

      if (!verification.verified) {
        throw new Error('Passkey registration failed');
      }

      const { registrationInfo } = verification;

      // Check if student already has a credential
      const existingCredential = await StudentWebAuthnCredential.findOne({ firebaseUid });

      let credential;
      if (existingCredential) {
        // Update existing
        existingCredential.credentialID = Buffer.from(registrationInfo.credentialID);
        existingCredential.credentialPublicKey = Buffer.from(registrationInfo.credentialPublicKey);
        existingCredential.counter = registrationInfo.counter;
        existingCredential.credentialDeviceType = registrationInfo.credentialDeviceType;
        existingCredential.credentialBackedUp = registrationInfo.credentialBackedUp;
        existingCredential.transports = registrationInfo.aaguid ? ['usb', 'nfc', 'ble'] : ['internal'];
        existingCredential.nickname = `Passkey - ${new Date().toLocaleDateString()}`;
        await existingCredential.save();
        credential = existingCredential;
      } else {
        // Create new
        credential = new StudentWebAuthnCredential({
          firebaseUid,
          credentialID: Buffer.from(registrationInfo.credentialID),
          credentialPublicKey: Buffer.from(registrationInfo.credentialPublicKey),
          counter: registrationInfo.counter,
          credentialDeviceType: registrationInfo.credentialDeviceType,
          credentialBackedUp: registrationInfo.credentialBackedUp,
          transports: registrationInfo.aaguid ? ['usb', 'nfc', 'ble'] : ['internal'],
          nickname: `Passkey - ${new Date().toLocaleDateString()}`
        });
        await credential.save();
      }

      return credential;
    } catch (error) {
      console.error('Student registration verification error:', error);
      throw error;
    }
  }

  /**
   * Generate authentication options for student
   */
  static async generateAuthenticationOptions() {
    const options = await generateAuthenticationOptions({
      rpID,
      userVerification: 'preferred'
    });

    return {
      options,
      challenge: options.challenge
    };
  }

  /**
   * Verify student's authentication
   */
  static async verifyAuthenticationResponse(firebaseUid, authenticationResponse, expectedChallenge) {
    try {
      // Find the student's credential
      const credential = await StudentWebAuthnCredential.findOne({
        firebaseUid,
        credentialID: Buffer.from(authenticationResponse.id, 'base64url')
      });

      if (!credential) {
        throw new Error('Student credential not found');
      }

      const verification = await verifyAuthenticationResponse({
        response: authenticationResponse,
        expectedChallenge,
        expectedOrigin: origin,
        expectedRPID: rpID,
        credential: {
          id: credential.credentialID,
          publicKey: credential.credentialPublicKey,
          counter: credential.counter,
          transports: credential.transports
        }
      });

      if (!verification.verified) {
        throw new Error('Student authentication failed');
      }

      // Update counter and last used
      credential.counter = verification.authenticationInfo.newCounter;
      credential.lastUsedAt = new Date();
      await credential.save();

      return true;
    } catch (error) {
      console.error('Student authentication verification error:', error);
      throw error;
    }
  }

  /**
   * Check if student has a registered passkey
   */
  static async hasRegisteredPasskey(firebaseUid) {
    const credential = await StudentWebAuthnCredential.findOne({ firebaseUid });
    return !!credential;
  }

  /**
   * Get student's credential info
   */
  static async getCredentialInfo(firebaseUid) {
    const credential = await StudentWebAuthnCredential.findOne({ firebaseUid }).select('-credentialPublicKey');
    if (!credential) {
      return null;
    }
    return {
      id: credential._id,
      nickname: credential.nickname,
      createdAt: credential.createdAt,
      lastUsedAt: credential.lastUsedAt,
      deviceType: credential.credentialDeviceType
    };
  }

  /**
   * Delete student's credential
   */
  static async deleteCredential(firebaseUid) {
    await StudentWebAuthnCredential.deleteOne({ firebaseUid });
  }
}

module.exports = StudentWebAuthnService;