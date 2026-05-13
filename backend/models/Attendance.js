const mongoose = require('mongoose');

const attendanceRecordSchema = new mongoose.Schema({
    studentId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    studentName: String,
    status: { type: String, enum: ['present', 'late', 'absent', 'pending'], default: 'pending' },
    timestamp: Date
});

const attendanceSessionSchema = new mongoose.Schema({
    teacherId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    subject: { type: String, required: true },
    section: { type: String, required: true },
    isEvent: { type: Boolean, default: false },
    isActive: { type: Boolean, default: true },
    
    startTime: { type: Date, default: Date.now },
    endTime: Date,
    
    lateThresholdMinutes: { type: Number, default: 5 },
    absentThresholdMinutes: { type: Number, default: 10 },
    
    records: [attendanceRecordSchema]
});

module.exports = mongoose.model('AttendanceSession', attendanceSessionSchema);
