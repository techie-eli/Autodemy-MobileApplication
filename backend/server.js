require('dotenv').config();
// Autodemy Backend Server - Production Ready
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const admin = require('firebase-admin');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Initialize Firebase Admin
let serviceAccount;
if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    try {
        serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
        console.log('Firebase Admin initialized from environment variable');
    } catch (e) {
        console.error('Failed to parse FIREBASE_SERVICE_ACCOUNT env var:', e);
    }
} else {
    try {
        serviceAccount = require('./config/firebase-admin.json');
        console.log('Firebase Admin initialized from local config file');
    } catch (e) {
        console.error('Local firebase-admin.json not found');
    }
}

if (serviceAccount) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
    cors: { origin: "*" }
});
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());

// Health Check Endpoint (for Render Keep-Alive)
app.get('/health', (req, res) => {
    res.status(200).send('OK');
});

// Multer Setup
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        const uploadPath = 'uploads/';
        if (!fs.existsSync(uploadPath)) {
            fs.mkdirSync(uploadPath);
        }
        cb(null, uploadPath);
    },
    filename: (req, file, cb) => {
        cb(null, Date.now() + path.extname(file.originalname));
    }
});
const upload = multer({ storage: storage });
app.use('/uploads', express.static('uploads'));

// MongoDB Connection
mongoose.connect(process.env.MONGODB_URI)
    .then(() => {
        console.log('Connected to MongoDB');
    })
    .catch(err => console.error('MongoDB connection error:', err));

// Models
const User = require('./models/User');
const AttendanceSession = require('./models/Attendance');
const Section = require('./models/Section');
const AcademicYear = require('./models/AcademicYear');
const Concern = require('./models/Concern');
const Message = require('./models/Message');

// New Announcement Model
const announcementSchema = new mongoose.Schema({
    title: String,
    description: String,
    time: String,
    location: String,
    dateTime: Date,
    invitedSections: [String],
    targetType: String,
    authorName: String,
    authorRole: String,
    createdAt: { type: Date, default: Date.now }
});
const Announcement = mongoose.model('Announcement', announcementSchema);

// Socket.io Logic
io.on('connection', (socket) => {
    console.log('User connected:', socket.id);

    socket.on('join_room', (room) => {
        socket.join(room);
        console.log(`User ${socket.id} joined room: ${room}`);
    });

    socket.on('send_notification', (data) => {
        const { room } = data;
        if (room) {
            io.to(room).emit('receive_notification', data);
            console.log(`Notification sent to room ${room}: ${data.title}`);
        } else {
            socket.broadcast.emit('receive_notification', data);
        }
    });

    socket.on('disconnect', () => {
        console.log('User disconnected:', socket.id);
    });
});

// Helper to seed initial data
async function seedData() {
    const adminExists = await User.findOne({ username: 'admin' });
    if (!adminExists) {
        await User.create({
            name: 'System Administrator',
            username: 'admin',
            password: 'admin_password', // Better to use a specific password
            role: 'ADMIN'
        });
        console.log('Default admin account created: admin / admin_password');
    }

    const teacherExists = await User.findOne({ username: 'teacher1' });
    if (!teacherExists) {
        await User.create({
            name: 'Ma. Santos',
            username: 'teacher1',
            password: 'password123',
            role: 'TEACHER',
            assignedSubject: 'English',
            section: 'E-122'
        });
        console.log('Teacher account synchronized: teacher1 / password123');
    }

    const studentExists = await User.findOne({ username: 'student1' });
    if (!studentExists) {
        await User.create({
            name: 'Santos, Rizal',
            username: 'student1',
            password: 'password123',
            role: 'STUDENT',
            section: 'STEM-A',
            grade: '12',
            strand: 'STEM',
            assignedSubject: 'English',
            assignedTime: '08:00 AM - 09:30 AM'
        });
        console.log('Student account synchronized: student1 / password123');
    }
}

// Authentication Middleware
const verifyToken = (req, res, next) => {
    const token = req.headers['authorization']?.split(' ')[1];
    if (!token) return res.status(403).json({ message: 'No token provided' });

    jwt.verify(token, process.env.JWT_SECRET, (err, decoded) => {
        if (err) return res.status(401).json({ message: 'Unauthorized' });
        req.userId = decoded.id;
        req.userRole = decoded.role;
        next();
    });
};

// Socket.io Logic
io.on('connection', (socket) => {
    console.log('User connected:', socket.id);
    
    socket.on('join_room', (room) => {
        socket.join(room);
        console.log(`Socket ${socket.id} joined room: ${room}`);
    });

    socket.on('send_message', (data) => {
        // data: { room, sender, body, timestamp }
        io.to(data.room).emit('receive_message', data);
    });

    socket.on('send_notification', (data) => {
        // data: { room, title, body, type, timestamp }
        // If room is 'ALL', broadcast to everyone, else broadcast to specific room
        if (data.room === 'ALL') {
            io.emit('receive_notification', data);
        } else {
            io.to(data.room).emit('receive_notification', data);
        }
    });

    socket.on('disconnect', () => {
        console.log('User disconnected:', socket.id);
    });
});

// Routes
app.get('/', (req, res) => res.send('Autodemy API is running...'));

// Auth Route
app.post('/api/auth/register', async (req, res) => {
    console.log('Registration Attempt:', req.body);
    try {
        const { name, username, email, password, role, idNumber, firebaseUid } = req.body;
        
        // 1. Validate with Firebase Admin (Optional but secure)
        if (firebaseUid) {
            try {
                if (admin.apps.length === 0) {
                    console.error('CRITICAL: Firebase Admin SDK is not initialized! Check FIREBASE_SERVICE_ACCOUNT env var.');
                    throw new Error('Firebase Admin uninitialized');
                }
                const fbUser = await admin.auth().getUser(firebaseUid);
                console.log('Firebase user verified:', fbUser.email);
            } catch (fbErr) {
                console.error('Firebase User Validation Failed:', fbErr.message);
                return res.status(400).json({ message: 'Invalid Firebase UID or Sync Error: ' + fbErr.message });
            }
        }

        // 2. Check if user already exists in MongoDB
        const existing = await User.findOne({ $or: [{ username }, { email }] });
        if (existing) {
            console.log('Registration failed: User already exists in MongoDB');
            return res.status(400).json({ message: 'User already exists' });
        }

        // 3. Create MongoDB User
        const user = await User.create({
            name,
            username,
            email,
            password,
            role,
            idNumber,
            firebaseUid
        });

        console.log('User registered in MongoDB:', user.username);
        res.status(201).json({ message: 'User registered successfully', user });
    } catch (err) {
        console.error('Registration Error Details:', err);
        res.status(500).json({ message: err.message || 'Internal Server Error' });
    }
});

app.post('/api/auth/login', async (req, res) => {
    const { username, password } = req.body;
    try {
        // Search by email OR username so both work
        const user = await User.findOne({ $or: [{ username }, { email: username }] });
        if (!user) return res.status(401).json({ message: 'Invalid credentials' });
        
        const isMatch = await user.comparePassword(password);
        if (!isMatch) return res.status(401).json({ message: 'Invalid credentials' });

        const token = jwt.sign({ id: user._id, role: user.role }, process.env.JWT_SECRET, { expiresIn: '24h' });
        
        res.json({
            token,
            user: {
                id: user._id,
                name: user.name,
                role: user.role,
                grade: user.grade,
                strand: user.strand,
                section: user.section,
                subjects: user.subjects,
                assignedSubject: user.assignedSubject,
                assignedTime: user.assignedTime
            }
        });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// Section Management (Admin/Teacher)
app.get('/api/sections', verifyToken, async (req, res) => {
    try {
        let query = {};
        if (req.userRole === 'TEACHER') query = { teacher: req.userId };
        
        const sections = await Section.find(query)
            .populate('teacher', 'name')
            .populate('students', 'name username');
        res.json(sections);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// Get all students in a section by matching User.section field (fallback for empty Section.students array)
app.get('/api/sections/students', verifyToken, async (req, res) => {
    try {
        const { sectionName } = req.query;
        if (!sectionName) return res.status(400).json({ message: 'sectionName is required' });
        const students = await User.find({ role: 'STUDENT', section: sectionName }, 'name username section');
        res.json(students);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

app.post('/api/sections', verifyToken, async (req, res) => {
    if (req.userRole !== 'ADMIN' && req.userRole !== 'TEACHER') {
        return res.status(403).json({ message: 'Forbidden' });
    }
    try {
        const section = await Section.create(req.body);
        res.status(201).json(section);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// --- ACADEMIC YEARS ---
app.get('/api/academic-years', async (req, res) => {
    try {
        const years = await AcademicYear.find().sort({ year: -1 });
        res.json(years);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/api/academic-years', async (req, res) => {
    try {
        const { year } = req.body;
        const newYear = new AcademicYear({ year });
        await newYear.save();
        res.status(201).json(newYear);
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

app.delete('/api/academic-years/:id', async (req, res) => {
    try {
        await AcademicYear.findByIdAndDelete(req.params.id);
        res.json({ message: 'Deleted successfully' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// --- ATTENDANCE SESSIONS ---
app.post('/api/attendance/start', verifyToken, async (req, res) => {
    const { subject, section, isEvent, lateThresholdMinutes, absentThresholdMinutes } = req.body;
    const teacherId = req.userId;
    try {
        await AttendanceSession.updateMany({ teacherId, isActive: true }, { isActive: false });
        
        const session = await AttendanceSession.create({
            teacherId,
            subject,
            section,
            isEvent,
            lateThresholdMinutes: lateThresholdMinutes || 5,
            absentThresholdMinutes: absentThresholdMinutes || 10
        });
        res.json(session);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

app.post('/api/attendance/mark', verifyToken, async (req, res) => {
    const { subject, section, studentName, timestamp } = req.body;
    let studentId = req.userId;
    let student;
    try {
        if (req.userRole === 'TEACHER' && studentName) {
            student = await User.findOne({ name: studentName, role: 'STUDENT' });
            if (!student) return res.status(404).json({ message: 'Student not found' });
            studentId = student._id;
        } else {
            student = await User.findById(studentId);
        }

        const session = await AttendanceSession.findOne({ subject, section, isActive: true });
        if (!session) return res.status(404).json({ message: 'No active session' });
        
        const attendanceTime = timestamp ? new Date(timestamp) : new Date();
        const diffMins = Math.floor((attendanceTime - session.startTime) / 60000);
        let status = 'present';
        if (diffMins >= session.absentThresholdMinutes) status = 'absent';
        else if (diffMins >= session.lateThresholdMinutes) status = 'late';
        
        const existingRecordIndex = session.records.findIndex(r => r.studentName === student.name);
        if (existingRecordIndex !== -1) {
            session.records[existingRecordIndex].status = status;
            session.records[existingRecordIndex].timestamp = attendanceTime;
        } else {
            session.records.push({ studentName: student.name, status, timestamp: attendanceTime });
        }
        await session.save();
        res.json({ status });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

app.get('/api/attendance/active', verifyToken, async (req, res) => {
    try {
        const session = await AttendanceSession.findOne({ 
            subject: req.query.subject, 
            section: req.query.section, 
            isActive: true 
        });
        res.json(session);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

app.post('/api/attendance/end', verifyToken, async (req, res) => {
    if (req.userRole !== 'TEACHER') return res.status(403).json({ message: 'Forbidden' });
    const { subject, section, records, reason } = req.body;
    try {
        const session = await AttendanceSession.findOne({ 
            subject, 
            section, 
            isActive: true,
            teacherId: req.userId
        });
        
        if (!session) return res.status(404).json({ message: 'No active session found' });
        
        session.isActive = false;
        session.endTime = new Date();
        if (reason) session.endReason = reason;
        
        // Sync the fully resolved records (including those marked absent)
        session.records = records.map(r => ({
            studentName: r.name || r.studentName,
            status: r.status,
            timestamp: r.timestamp ? new Date(r.timestamp) : new Date()
        }));
        
        await session.save();
        res.json({ message: 'Session ended successfully', session });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

app.get('/api/teacher/attendance-history', verifyToken, async (req, res) => {
    if (req.userRole !== 'TEACHER') return res.status(403).json({ message: 'Forbidden' });
    try {
        const { section, subject } = req.query;
        let query = { teacherId: req.userId, isActive: false };
        if (section) query.section = section;
        if (subject) query.subject = subject;
        
        const sessions = await AttendanceSession.find(query).sort({ startTime: -1 });
        res.json(sessions);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// --- CONCERN MANAGEMENT ---
app.get('/api/concerns', verifyToken, async (req, res) => {
    try {
        let query = {};
        if (req.userRole === 'STUDENT') query = { student: req.userId };
        // Teachers/Admins see all for now, or we can filter by teacher's sections later
        
        const concerns = await Concern.find(query)
            .populate('student', 'name username section')
            .sort({ createdAt: -1 });
        res.json(concerns);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

app.post('/api/concerns', verifyToken, async (req, res) => {
    if (req.userRole !== 'STUDENT') return res.status(403).json({ message: 'Only students can submit concerns' });
    try {
        const concern = await Concern.create({
            ...req.body,
            student: req.userId
        });
        
        // Also create the initial message in the chat thread
        const user = await User.findById(req.userId);
        await Message.create({
            threadId: concern._id,
            sender: req.userId,
            senderName: user.name,
            senderRole: user.role,
            body: req.body.message
        });

        res.status(201).json(concern);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

app.put('/api/concerns/:id', verifyToken, async (req, res) => {
    try {
        const updated = await Concern.findByIdAndUpdate(req.params.id, { 
            status: req.body.status,
            updatedAt: Date.now()
        }, { new: true });
        res.json(updated);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// --- MESSAGING ---
app.get('/api/messages/:threadId', verifyToken, async (req, res) => {
    try {
        const messages = await Message.find({ threadId: req.params.threadId }).sort({ timestamp: 1 });
        res.json(messages);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

app.post('/api/messages', verifyToken, async (req, res) => {
    try {
        const user = await User.findById(req.userId);
        const message = await Message.create({
            ...req.body,
            sender: req.userId,
            senderName: user.name,
            senderRole: user.role
        });

        // Emit to real-time clients
        io.to(message.threadId.toString()).emit('receive_message', message);

        res.status(201).json(message);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

app.post('/api/admin/bulk-users', verifyToken, async (req, res) => {
    if (req.userRole !== 'ADMIN') return res.status(403).json({ message: 'Forbidden' });
    try {
        const users = req.body; // Expecting an array
        if (!Array.isArray(users)) return res.status(400).json({ message: 'Data must be an array' });
        
        const results = await User.insertMany(users, { ordered: false });
        res.status(201).json({ count: results.length });
    } catch (err) {
        // insertMany with ordered:false will throw if some fail, but still insert others
        res.status(207).json({ 
            message: 'Partial success or error', 
            error: err.message,
            insertedCount: err.insertedDocs ? err.insertedDocs.length : 0
        });
    }
});

app.get('/api/teacher/analytics', verifyToken, async (req, res) => {
    if (req.userRole !== 'TEACHER') return res.status(403).json({ message: 'Forbidden' });
    try {
        const teacherId = new mongoose.Types.ObjectId(req.userId);
        
        // Fetch last 30 sessions to get a good sample
        const sessions = await AttendanceSession.find({ teacherId })
            .sort({ startTime: -1 })
            .limit(30);

        if (sessions.length === 0) {
            return res.json({
                weeklyAttendance: [
                    { day: 'Mon', present: 0, late: 0, absent: 0 },
                    { day: 'Tue', present: 0, late: 0, absent: 0 },
                    { day: 'Wed', present: 0, late: 0, absent: 0 },
                    { day: 'Thu', present: 0, late: 0, absent: 0 },
                    { day: 'Fri', present: 0, late: 0, absent: 0 },
                ],
                categoryDistribution: [
                    { name: 'On-Time', value: 0, color: '#4CAF50' },
                    { name: 'Late', value: 0, color: '#FF9800' },
                    { name: 'Absent', value: 0, color: '#F44336' },
                ]
            });
        }

        // 1. Calculate Category Distribution
        let totalPresent = 0;
        let totalLate = 0;
        let totalAbsent = 0;

        sessions.forEach(s => {
            s.records.forEach(r => {
                if (r.status === 'present') totalPresent++;
                else if (r.status === 'late') totalLate++;
                else if (r.status === 'absent') totalAbsent++;
            });
        });

        const total = totalPresent + totalLate + totalAbsent;
        const categoryDistribution = [
            { name: 'On-Time', value: total > 0 ? Math.round((totalPresent / total) * 100) : 0, color: '#4CAF50' },
            { name: 'Late', value: total > 0 ? Math.round((totalLate / total) * 100) : 0, color: '#FF9800' },
            { name: 'Absent', value: total > 0 ? Math.round((totalAbsent / total) * 100) : 0, color: '#F44336' },
        ];

        // 2. Weekly Attendance (Group by Day of Week)
        const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        const weeklyMap = { 'Mon': {present:0,late:0,absent:0}, 'Tue': {present:0,late:0,absent:0}, 'Wed': {present:0,late:0,absent:0}, 'Thu': {present:0,late:0,absent:0}, 'Fri': {present:0,late:0,absent:0} };

        sessions.forEach(s => {
            const dayName = days[new Date(s.startTime).getDay()];
            if (weeklyMap[dayName]) {
                s.records.forEach(r => {
                    if (r.status === 'present') weeklyMap[dayName].present++;
                    else if (r.status === 'late') weeklyMap[dayName].late++;
                    else if (r.status === 'absent') weeklyMap[dayName].absent++;
                });
            }
        });

        const weeklyAttendance = Object.keys(weeklyMap).map(day => ({
            day,
            ...weeklyMap[day]
        }));

        res.json({ weeklyAttendance, categoryDistribution });
    } catch (err) {
        console.error('Analytics Error:', err);
        res.status(500).json({ message: err.message });
    }
});

// User: Update own profile
app.put('/api/users/me', verifyToken, async (req, res) => {
    try {
        const { name } = req.body; // allow updating name for now
        const updated = await User.findByIdAndUpdate(
            req.userId, 
            { name }, 
            { new: true }
        );
        res.json(updated);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// Admin: Get all attendance sessions (System Logs)
app.get('/api/admin/logs', verifyToken, async (req, res) => {
    if (req.userRole !== 'ADMIN') return res.status(403).json({ message: 'Forbidden' });
    try {
        const sessions = await AttendanceSession.find().sort({ startTime: -1 }).limit(50);
        res.json(sessions);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// Admin: User Management
app.get('/api/admin/users', verifyToken, async (req, res) => {
    if (req.userRole !== 'ADMIN') return res.status(403).json({ message: 'Forbidden' });
    try {
        const users = await User.find({ role: { $ne: 'ADMIN' } });
        res.json(users);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

app.post('/api/admin/users', verifyToken, async (req, res) => {
    if (req.userRole !== 'ADMIN') return res.status(403).json({ message: 'Forbidden' });
    const { name, username, email, idNumber, password, role } = req.body;
    
    try {
        // 1. Create User in Firebase Auth first
        const userRecord = await admin.auth().createUser({
            email: email,
            password: password,
            displayName: name,
        });

        // 2. Create User in MongoDB
        const user = await User.create({
            name,
            username,
            email,
            idNumber,
            password, // Note: MongoDB middleware will hash this
            role,
            firebaseUid: userRecord.uid
        });

        res.status(201).json(user);
    } catch (err) {
        console.error('Admin Add User Error:', err);
        res.status(400).json({ message: err.message });
    }
});

app.put('/api/admin/users/:id', verifyToken, async (req, res) => {
    if (req.userRole !== 'ADMIN') return res.status(403).json({ message: 'Forbidden' });
    try {
        const { email, password, name } = req.body;
        const user = await User.findById(req.params.id);
        
        if (user && user.firebaseUid) {
            const updateParams = {};
            if (email) updateParams.email = email;
            if (password) updateParams.password = password;
            if (name) updateParams.displayName = name;

            if (Object.keys(updateParams).length > 0) {
                await admin.auth().updateUser(user.firebaseUid, updateParams);
            }
        }

        const updated = await User.findByIdAndUpdate(req.params.id, req.body, { new: true });
        res.json(updated);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

app.delete('/api/admin/users/:id', verifyToken, async (req, res) => {
    if (req.userRole !== 'ADMIN') return res.status(403).json({ message: 'Forbidden' });
    try {
        const user = await User.findById(req.params.id);
        if (user && user.firebaseUid) {
            try {
                await admin.auth().deleteUser(user.firebaseUid);
            } catch (firebaseErr) {
                console.error('Firebase Delete Error:', firebaseErr);
                // Continue even if Firebase delete fails (e.g. user already gone)
            }
        }
        await User.findByIdAndDelete(req.params.id);
        res.json({ message: 'User deleted from system and auth' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// Admin: Bulk Migrate Existing Users to Firebase
app.post('/api/admin/migrate-firebase', verifyToken, async (req, res) => {
    if (req.userRole !== 'ADMIN') return res.status(403).json({ message: 'Forbidden' });
    
    try {
        const usersToMigrate = await User.find({ firebaseUid: { $exists: false }, role: { $ne: 'ADMIN' } });
        let successCount = 0;
        let errorCount = 0;
        const results = [];

        for (const user of usersToMigrate) {
            try {
                // Ensure there's an email
                const email = user.email || `${user.username}@autodemy.com`;
                
                // Create in Firebase with a default password
                const userRecord = await admin.auth().createUser({
                    email: email,
                    password: 'password123', // Default password for migrated users
                    displayName: user.name,
                });

                // Update MongoDB
                user.firebaseUid = userRecord.uid;
                if (!user.email) user.email = email; // backfill email if missing
                await user.save();
                
                successCount++;
                results.push({ username: user.username, status: 'Success' });
            } catch (err) {
                console.error(`Migration error for ${user.username}:`, err.message);
                errorCount++;
                results.push({ username: user.username, status: 'Error', error: err.message });
            }
        }

        res.json({ 
            message: 'Migration complete', 
            total: usersToMigrate.length,
            success: successCount, 
            errors: errorCount,
            details: results
        });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});
// --- STUDENT DATA ENHANCEMENTS ---
app.get('/api/student/attendance', verifyToken, async (req, res) => {
    try {
        const { name, id } = req.query;
        let query = {};
        let studentName = name;

        if (id) {
            const student = await User.findById(id);
            if (student) {
                query["records.studentName"] = student.name;
                studentName = student.name;
            }
        } else if (name) {
            query["records.studentName"] = name;
        } else {
            return res.status(400).json({ message: 'Student ID or name is required' });
        }

        const sessions = await AttendanceSession.find(query).sort({ startTime: -1 });

        const history = sessions.map(s => {
            const record = s.records.find(r => r.studentName === studentName);
            return {
                subject: s.subject,
                section: s.section,
                date: s.startTime,
                status: record ? record.status : 'N/A',
                time: record ? record.timestamp : null
            };
        });

        res.json(history);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

app.get('/api/student/section-info', verifyToken, async (req, res) => {
    try {
        const user = await User.findById(req.userId);
        if (!user || !user.section) return res.json(null);

        // Find the section that matches the student's section and subject
        const section = await Section.findOne({ 
            sectionName: user.section,
            subject: user.assignedSubject || (user.subjects && user.subjects[0])
        }).populate('teacher', 'name');

        res.json(section);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// --- ADMIN: Granular Attendance History & Export ---
app.get('/api/admin/attendance-history', verifyToken, async (req, res) => {
    if (req.userRole !== 'ADMIN') return res.status(403).json({ message: 'Forbidden' });
    try {
        const { strand, grade, section, subject, academicYear } = req.query;
        let query = {};
        if (section) query.section = section;
        if (subject) query.subject = subject;

        let sessions = await AttendanceSession.find(query).sort({ startTime: -1 }).populate('teacher', 'name');

        if (strand || grade) {
            // This is a simplified filter. For production, consider denormalization or aggregation.
            const matchingSessions = [];
            for (let session of sessions) {
                const filteredRecords = [];
                for (let record of session.records) {
                    const student = await User.findById(record.studentId);
                    if (!student) continue;
                    if (strand && student.strand !== strand) continue;
                    if (grade && student.grade !== grade) continue;
                    filteredRecords.push(record);
                }
                if (filteredRecords.length > 0) {
                    const sessionObj = session.toObject();
                    sessionObj.records = filteredRecords;
                    matchingSessions.push(sessionObj);
                }
            }
            sessions = matchingSessions;
        }

        res.json(sessions);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// --- STUDENT: Concerns & Document Upload ---
app.post('/api/student/upload-document', verifyToken, upload.single('file'), async (req, res) => {
    try {
        if (!req.file) return res.status(400).json({ message: 'No file uploaded' });
        // Return full URL for convenience
        const fileUrl = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;
        res.json({ url: fileUrl, filename: req.file.filename });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

app.post('/api/student/submit-concern', verifyToken, async (req, res) => {
    try {
        const { subject, category, message, attachments, target } = req.body;
        const concern = await Concern.create({
            student: req.userId,
            subject,
            category,
            message,
            attachments,
            target: target || "System Administrator"
        });

        // Also create initial message for real-time chat
        const user = await User.findById(req.userId);
        await Message.create({
            threadId: concern._id,
            sender: req.userId,
            senderName: user.name,
            senderRole: user.role,
            body: message
        });

        res.status(201).json(concern);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

app.get('/api/student/concerns', verifyToken, async (req, res) => {
    try {
        const concerns = await Concern.find({ student: req.userId }).sort({ createdAt: -1 });
        res.json(concerns);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

app.get('/api/teacher/concerns', verifyToken, async (req, res) => {
    if (req.userRole !== 'TEACHER' && req.userRole !== 'ADMIN') return res.status(403).json({ message: 'Forbidden' });
    try {
        const user = await User.findById(req.userId);
        // Teachers see concerns where target matches their name
        const concerns = await Concern.find({ target: user.name }).populate('student', 'name username section').sort({ createdAt: -1 });
        res.json(concerns);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

app.get('/api/admin/student-analytics/:studentId', verifyToken, async (req, res) => {
    if (req.userRole !== 'ADMIN') return res.status(403).json({ message: 'Forbidden' });
    try {
        const studentId = new mongoose.Types.ObjectId(req.params.studentId);
        const sessions = await AttendanceSession.find({ "records.studentId": studentId });
        
        let present = 0, late = 0, absent = 0;
        sessions.forEach(s => {
            const record = s.records.find(r => r.studentId.equals(studentId));
            if (record) {
                if (record.status === 'present') present++;
                else if (record.status === 'late') late++;
                else if (record.status === 'absent') absent++;
            }
        });

        const total = present + late + absent;
        const presentPercent = total > 0 ? Math.round((present / total) * 100) + '%' : '0%';
        
        res.json({ presentPercent, lates: late, absents: absent });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

app.put('/api/admin/users/:userId/password', verifyToken, async (req, res) => {
    if (req.userRole !== 'ADMIN') return res.status(403).json({ message: 'Forbidden' });
    try {
        const { password } = req.body;
        if (!password) return res.status(400).json({ message: 'Password is required' });
        
        const user = await User.findById(req.params.userId);
        if (!user) return res.status(404).json({ message: 'User not found' });
        
        user.password = password; // Will be hashed by pre-save hook
        await user.save();
        
        res.json({ message: 'Password updated successfully' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});


// Announcement Routes
app.post('/api/announcements/publish', verifyToken, async (req, res) => {
    try {
        const announcement = await Announcement.create(req.body);
        res.status(201).json(announcement);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

app.get('/api/announcements', verifyToken, async (req, res) => {
    try {
        const { section } = req.query;
        // Filter: invited ALL, or specific section
        const announcements = await Announcement.find({
            $or: [
                { invitedSections: 'ALL' },
                { invitedSections: section },
                { invitedSections: { $size: 0 } }
            ]
        }).sort({ dateTime: -1 });
        res.json(announcements);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

app.delete('/api/announcements/:id', verifyToken, async (req, res) => {
    if (req.userRole !== 'ADMIN') return res.status(403).json({ message: 'Forbidden' });
    try {
        const deleted = await Announcement.findByIdAndDelete(req.params.id);
        if (!deleted) return res.status(404).json({ message: 'Announcement not found' });
        res.json({ message: 'Announcement deleted' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

server.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on http://0.0.0.0:${PORT}`);
});
