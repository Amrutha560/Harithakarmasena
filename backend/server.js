const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const dotenv = require('dotenv');
const bcrypt = require('bcrypt');
const User = require('./models/User');

dotenv.config();

const app = express();

app.use(express.json());
app.use(cors());

// Request logging middleware
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
    next();
});

// Health check and root route
app.get('/', (req, res) => {
    res.send('Harithakarmasena Backend is running!');
});

// Routes
const authRoutes = require('./routes/auth');
const adminRoutes = require('./routes/admin');
const residentRoutes = require('./routes/resident');
const staffRoutes = require('./routes/staff');

app.use('/api/auth', authRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/resident', residentRoutes);
app.use('/api/staff', staffRoutes);

// Catch-all 404 for debugging
app.use((req, res) => {
    console.log(`404 - Not Found: ${req.method} ${req.url}`);
    res.status(404).json({ message: `Route ${req.method} ${req.url} not found on this server.` });
});

const PORT = process.env.PORT || 5000;

const initializeAdmin = async () => {
    try {
        const adminExists = await User.findOne({ role: 'admin' });
        if (!adminExists) {
            const salt = await bcrypt.genSalt(10);
            const hashedPassword = await bcrypt.hash('admin123', salt);
            const admin = new User({
                name: 'System Admin',
                email: 'admin@system.com',
                password: hashedPassword,
                role: 'admin'
            });
            await admin.save();
            console.log('Default admin created: admin@system.com / admin123');
        }
    } catch (error) {
        console.error('Error creating default admin', error);
    }
};

mongoose.connect(process.env.MONGO_URI).then(() => {
    console.log('MongoDB connected');
    initializeAdmin();
    app.listen(PORT, () => {
        console.log(`Server is running on port ${PORT}`);
    });
}).catch(err => {
    console.error('MongoDB connection error:', err);
});
