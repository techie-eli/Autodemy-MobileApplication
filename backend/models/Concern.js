const mongoose = require('mongoose');

const concernSchema = new mongoose.Schema({
    student: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    subject: { type: String, required: true },
    category: { type: String, required: true }, // e.g. "Excuse Letter", "Technical Issue"
    message: { type: String, required: true },
    status: { type: String, enum: ['PENDING', 'APPROVED', 'RESOLVED', 'REJECTED'], default: 'PENDING' },
    target: { type: String, required: true }, // e.g. "System Administrator" or Teacher's Name
    attachments: [String], // URLs to files
    createdAt: { type: Date, default: Date.now },
    updatedAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Concern', concernSchema);
