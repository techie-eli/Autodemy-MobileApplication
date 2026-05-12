const mongoose = require('mongoose');

const sectionSchema = new mongoose.Schema({
    sectionName: { type: String, required: true }, // e.g. "STEM-A"
    subject: { type: String, required: true }, // e.g. "General Physics"
    academicYear: { type: String, required: true }, // e.g. "2025-2026"
    strand: { type: String, required: true }, // e.g. "STEM"
    level: { type: String, required: true }, // e.g. "Grade 12"
    teacher: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    students: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    schedule: { type: String }, // e.g. "MWF 9:00 AM - 10:30 AM"
    createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Section', sectionSchema);
