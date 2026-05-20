const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const dotenv = require('dotenv');
const bcrypt = require('bcrypt');
const User = require('./models/User');

dotenv.config();

const app = express();

app.use(express.json());
app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization']
}));

const path = require('path');
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Request logging middleware
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
    next();
});

// Health check and root route
app.get('/', (req, res) => {
    res.send('Harithakarmasena Backend is running!');
});

app.get('/api/health', (req, res) => {
    res.json({ status: 'ok', time: new Date() });
});

// Routes
const authRoutes = require('./routes/auth');
const adminRoutes = require('./routes/admin');
const residentRoutes = require('./routes/resident');
const staffRoutes = require('./routes/staff');
const paymentRoutes = require('./routes/payment');

app.use('/api/auth', authRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/resident', residentRoutes);
app.use('/api/staff', staffRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/payment', paymentRoutes);

// Global Error Handler
app.use((err, req, res, next) => {
    console.error('SERVER ERROR:', err.stack);

    if (err.message === 'Only PDF files are allowed') {
        return res.status(400).json({ message: err.message });
    }

    if (err.name === 'MulterError') {
        return res.status(400).json({ message: err.message });
    }

    res.status(500).json({ 
        message: 'Internal Server Error', 
        error: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong' 
    });
});

const PORT = process.env.PORT || 3000;

const initializeAdmin = async () => {
    try {
        const adminExists = await User.findOne({ role: 'admin' });
        if (!adminExists) {
            const salt = await bcrypt.genSalt(10);
            const hashedPassword = await bcrypt.hash('admin123', salt);
            const admin = new User({
                firstName: 'System',
                lastName: 'Admin',
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
