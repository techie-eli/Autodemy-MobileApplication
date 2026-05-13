const mongoose = require('mongoose');

/**
 * Stores WebAuthn/Passkey credentials for students
 * Used for biometric authentication on web version before QR generation
 */
const studentWebAuthnCredentialSchema = new mongoose.Schema({
  firebaseUid: {
    type: String,
    required: true,
    unique: true,
    sparse: true,
    index: true
  },
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    sparse: true,
    index: true
  },
  credentialID: {
    type: Buffer,
    required: true,
    unique: true,
    sparse: true
  },
  credentialPublicKey: {
    type: Buffer,
    required: true
  },
  counter: {
    type: Number,
    default: 0,
    required: true
  },
  credentialDeviceType: {
    type: String,
    enum: ['singleDevice', 'multiDevice'],
    default: 'multiDevice'
  },
  credentialBackedUp: {
    type: Boolean,
    default: false
  },
  transports: [{
    type: String
  }],
  nickname: String,
  deviceName: String,
  lastUsedAt: Date,
  createdAt: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('StudentWebAuthnCredential', studentWebAuthnCredentialSchema);