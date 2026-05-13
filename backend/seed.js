require('dotenv').config();
const mongoose = require('mongoose');
const User = require('./models/User');

async function seedData() {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('Connected to MongoDB for seeding...');

        // Clear existing users (optional, remove if you want to keep them)
        // await User.deleteMany({ role: { $ne: 'ADMIN' } });

        // 1. Create Student 1
        const student1Exists = await User.findOne({ username: 'student1' });
        if (!student1Exists) {
            await User.create({
                name: 'Santos, Rizal',
                username: 'student1',
                password: 'password123',
                role: 'STUDENT',
                grade: '12',
                strand: 'STEM',
                section: 'STEM-A',
                assignedSubject: 'Physics',
                assignedTime: '08:00 AM - 09:30 AM'
            });
            console.log('Sample Student created: student1 / password123');
        }

        // 2. Create Student 2
        const student2Exists = await User.findOne({ username: 'student2' });
        if (!student2Exists) {
            await User.create({
                name: 'Reyes, Maria',
                username: 'student2',
                password: 'password123',
                role: 'STUDENT',
                grade: '12',
                strand: 'STEM',
                section: 'STEM-A',
                assignedSubject: 'Physics',
                assignedTime: '08:00 AM - 09:30 AM'
            });
            console.log('Sample Student created: student2 / password123');
        }

        // 3. Create Teacher
        const teacherExists = await User.findOne({ username: 'teacher1' });
        if (!teacherExists) {
            await User.create({
                name: 'Ma. Santos',
                username: 'teacher1',
                password: 'password123',
                role: 'TEACHER',
                subjects: ['Physics', 'Calculus']
            });
            console.log('Sample Teacher created: teacher1 / password123');
        }

        console.log('Seeding completed!');
        process.exit(0);
    } catch (err) {
        console.error('Seeding error:', err);
        process.exit(1);
    }
}

seedData();
