const mongoose = require('mongoose');

const academicYearSchema = new mongoose.Schema({
    year: { type: String, required: true, unique: true }, // e.g. "2025-2026"
    isCurrent: { type: Boolean, default: false },
    createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('AcademicYear', academicYearSchema);
