const mongoose = require('mongoose');
const User = require('./models/User');
const WasteCategory = require('./models/WasteCategory');
const Schedule = require('./models/Schedule');
const bcrypt = require('bcrypt');
const dotenv = require('dotenv');

dotenv.config();

const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/harithakarmasena';

async function addOrUpdateData() {
    try {
        await mongoose.connect(MONGO_URI);
        console.log('Connected to MongoDB');

        // 1. Add Waste Categories
        let plastic = await WasteCategory.findOne({ name: 'Plastic Waste' });
        if (!plastic) {
            plastic = new WasteCategory({
                name: 'Plastic Waste',
                description: 'Bottles, containers, and other recyclable plastics',
                icon: 'eco'
            });
            await plastic.save();
            console.log('Added category: Plastic Waste');
        } else {
            console.log('Category already exists: Plastic Waste');
        }

        let ewaste = await WasteCategory.findOne({ name: 'E-Waste' });
        if (!ewaste) {
            ewaste = new WasteCategory({
                name: 'E-Waste',
                description: 'Old electronics, batteries, and cables',
                icon: 'memory'
            });
            await ewaste.save();
            console.log('Added category: E-Waste');
        } else {
            console.log('Category already exists: E-Waste');
        }

        // 2. Add Staff Member (John Doe)
        let staff = await User.findOne({ email: 'john@staff.com' });
        if (!staff) {
            const salt = await bcrypt.genSalt(10);
            const hashedPassword = await bcrypt.hash('password123', salt);
            staff = new User({
                name: 'John Doe',
                email: 'john@staff.com',
                password: hashedPassword,
                role: 'staff',
                address: '123 Staff Street',
                phoneNumber: '9876543210',
                wardNumber: '12',
                isApproved: true
            });
            await staff.save();
            console.log('Created staff member: John Doe');
        } else {
            console.log('Staff already exists: John Doe');
        }

        // 3. Create Schedule for April 2026, Ward 12
        const aprilDate = new Date(2026, 3, 1); // 0-indexed month: April is index 3
        const scheduleExists = await Schedule.findOne({ month: 4, year: 2026, wardNumber: '12', category: plastic._id });
        if (!scheduleExists) {
            const schedule = new Schedule({
                date: aprilDate,
                month: 4,
                year: 2026,
                wardNumber: '12',
                category: plastic._id,
                assignedStaff: staff._id,
                notes: 'Monthly plastic collection for Ward 12'
            });
            await schedule.save();
            console.log('Created schedule for April 2026, Ward 12');
        } else {
            console.log('Schedule already exists for April 2026, Ward 12');
        }

        process.exit(0);
    } catch (error) {
        console.error('Error adding data:', error);
        process.exit(1);
    }
}

addOrUpdateData();
