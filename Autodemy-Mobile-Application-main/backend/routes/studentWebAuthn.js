const express = require('express');
const router = express.Router();
const StudentWebAuthnService = require('../services/studentWebAuthnService');
const admin = require('firebase-admin');

// Middleware to verify Firebase token
const verifyFirebaseToken = async (req, res, next) => {
  const token = req.headers.authorization?.split('Bearer ')[1];
  if (!token) {
    return res.status(401).json({ error: 'No token provided' });
  }

  try {
    const decodedToken = await admin.auth().verifyIdToken(token);

    // Only allow students
    if (decodedToken.role && decodedToken.role !== 'STUDENT') {
      return res.status(403).json({ error: 'Only students can use passkeys' });
    }

    req.firebaseUid = decodedToken.uid;
    req.email = decodedToken.email;
    next();
  } catch (error) {
    res.status(401).json({ error: 'Invalid token' });
  }
};

// Store challenges temporarily (use Redis in production)
const sessionChallenges = new Map();
const SESSION_TIMEOUT = 5 * 60 * 1000; // 5 minutes

/**
 * POST /api/student-webauthn/register/options
 * Generate registration options for student's first passkey setup
 */
router.post('/register/options', verifyFirebaseToken, async (req, res) => {
  try {
    const { studentName } = req.body;

    const { options, challenge } = await StudentWebAuthnService.generateRegistrationOptions(
      req.firebaseUid,
      studentName || req.email
    );

    // Store challenge with timeout
    const challengeKey = `reg-${req.firebaseUid}`;
    sessionChallenges.set(challengeKey, challenge);
    setTimeout(() => sessionChallenges.delete(challengeKey), SESSION_TIMEOUT);

    res.json({
      options: {
        ...options,
        challenge: options.challenge
      }
    });
  } catch (error) {
    console.error('Student registration options error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/student-webauthn/register/verify
 * Verify and save student's passkey
 */
router.post('/register/verify', verifyFirebaseToken, async (req, res) => {
  try {
    const expectedChallenge = sessionChallenges.get(`reg-${req.firebaseUid}`);

    if (!expectedChallenge) {
      return res.status(400).json({ error: 'Registration session expired' });
    }

    const credential = await StudentWebAuthnService.verifyRegistrationResponse(
      req.firebaseUid,
      req.body.response,
      expectedChallenge
    );

    sessionChallenges.delete(`reg-${req.firebaseUid}`);

    res.json({
      verified: true,
      message: 'Passkey registered successfully',
      credential: {
        id: credential._id,
        nickname: credential.nickname,
        createdAt: credential.createdAt
      }
    });
  } catch (error) {
    console.error('Student registration verification error:', error);
    res.status(400).json({ error: error.message });
  }
});

/**
 * POST /api/student-webauthn/authenticate/options
 * Get authentication options for student
 */
router.post('/authenticate/options', async (req, res) => {
  try {
    const { options, challenge } = await StudentWebAuthnService.generateAuthenticationOptions();

    const challengeId = require('crypto').randomBytes(16).toString('hex');
    sessionChallenges.set(`auth-${challengeId}`, challenge);
    setTimeout(() => sessionChallenges.delete(`auth-${challengeId}`), SESSION_TIMEOUT);

    res.json({
      options: {
        ...options,
        challenge: options.challenge
      },
      challengeId
    });
  } catch (error) {
    console.error('Student authentication options error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/student-webauthn/authenticate/verify
 * Verify student authentication
 */
router.post('/authenticate/verify', async (req, res) => {
  try {
    const { response, challengeId, firebaseUid } = req.body;

    if (!challengeId || !firebaseUid || !response) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const expectedChallenge = sessionChallenges.get(`auth-${challengeId}`);

    if (!expectedChallenge) {
      return res.status(400).json({ error: 'Authentication session expired' });
    }

    // Verify student authentication
    await StudentWebAuthnService.verifyAuthenticationResponse(
      firebaseUid,
      response,
      expectedChallenge
    );

    sessionChallenges.delete(`auth-${challengeId}`);

    res.json({
      verified: true,
      message: 'Student authenticated successfully'
    });
  } catch (error) {
    console.error('Student authentication verification error:', error);
    res.status(400).json({ error: error.message });
  }
});

/**
 * GET /api/student-webauthn/has-passkey
 * Check if student has registered a passkey
 */
router.get('/has-passkey', verifyFirebaseToken, async (req, res) => {
  try {
    const hasPasskey = await StudentWebAuthnService.hasRegisteredPasskey(req.firebaseUid);
    const credentialInfo = hasPasskey
      ? await StudentWebAuthnService.getCredentialInfo(req.firebaseUid)
      : null;

    res.json({
      hasPasskey,
      credential: credentialInfo
    });
  } catch (error) {
    console.error('Check passkey error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * DELETE /api/student-webauthn/credential
 * Remove student's passkey
 */
router.delete('/credential', verifyFirebaseToken, async (req, res) => {
  try {
    await StudentWebAuthnService.deleteCredential(req.firebaseUid);
    res.json({ message: 'Passkey deleted successfully' });
  } catch (error) {
    console.error('Delete credential error:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;