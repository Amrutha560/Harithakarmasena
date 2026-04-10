const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Ward = require('../models/Ward');
const authMiddleware = require('../middleware/authMiddleware');

const generateToken = (user) => {
    return jwt.sign({ id: user._id, role: user.role }, process.env.JWT_SECRET, {
        expiresIn: '1d',
    });
};

// Admin Login
router.post('/admin/login', async (req, res) => {
    const { email, password } = req.body;

    try {
        const admin = await User.findOne({ email, role: 'admin' });
        if (!admin) return res.status(401).json({ message: 'Invalid credentials' });

        const isMatch = await bcrypt.compare(password, admin.password);
        if (!isMatch) return res.status(401).json({ message: 'Invalid credentials' });

        res.json({
            message: 'Admin logged in',
            token: generateToken(admin),
            user: { id: admin._id, name: admin.name, email: admin.email, role: admin.role }
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Resident Registration
router.post('/resident/register', async (req, res) => {
    const { name, email, password, houseName, houseNumber, address, phoneNumber, wardNumber } = req.body;

    try {
        const existingUser = await User.findOne({ email });
        if (existingUser) return res.status(400).json({ message: 'User already exists' });

        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);

        const resident = new User({
            name,
            email,
            password: hashedPassword,
            role: 'resident',
            houseName,
            houseNumber,
            address,
            phoneNumber,
            wardNumber
        });

        await resident.save();

        res.status(201).json({
            message: 'Resident registered successfully',
            token: generateToken(resident),
            user: { id: resident._id, name, email, role: 'resident' }
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Resident Login
router.post('/resident/login', async (req, res) => {
    const { email, password } = req.body;
    const identifier = email.trim();
    const dummyEmail = identifier.includes('@') ? identifier.toLowerCase() : `${identifier.toLowerCase()}@resident.com`;

    try {
        const resident = await User.findOne({
            $or: [
                { email: dummyEmail },
                { phoneNumber: identifier },
                { name: identifier }
            ],
            role: 'resident'
        });
        if (!resident) return res.status(401).json({ message: 'Invalid credentials' });

        const isMatch = await bcrypt.compare(password, resident.password);
        if (!isMatch) return res.status(401).json({ message: 'Invalid credentials' });

        res.json({
            message: 'Resident logged in',
            token: generateToken(resident),
            user: { id: resident._id, name: resident.name, email: resident.email, role: resident.role }
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Create Staff (Admin Only)
router.post('/staff/create', authMiddleware(['admin']), async (req, res) => {
    let { name, email, password, houseName, houseNumber, address, phoneNumber, wardNumber, wardId, routeId } = req.body;

    // Auto-generate password if not provided
    let generatedPassword = null;
    if (!password || password.trim() === '') {
        // Generate a random 8-character alphanumeric password
        generatedPassword = Math.random().toString(36).slice(-8);
        password = generatedPassword;
    }

    try {
        const existingStaff = await User.findOne({ email });
        if (existingStaff) return res.status(400).json({ message: 'User already exists' });

        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);

        // Map wardId/routeId to ward/route for schema consistency
        const wardObj = wardId ? await Ward.findById(wardId) : null;
        const actualWardNumber = wardNumber || wardObj?.wardNumber;

        const staff = new User({
            name,
            email,
            password: hashedPassword,
            role: 'staff',
            houseName,
            houseNumber,
            address,
            phoneNumber,
            wardNumber: actualWardNumber,
            ward: wardId,
            route: routeId,
            isApproved: true
        });

        await staff.save();

        res.status(201).json({ 
            message: 'Staff created successfully by Admin',
            generatedPassword, // Return so frontend can show it
            user: { name, email, role: 'staff' }
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Staff Login
router.post('/staff/login', async (req, res) => {
    const { email, password } = req.body; // 'email' here is the username input from frontend

    try {
        // Try finding by email or name (as username)
        const staff = await User.findOne({
            $or: [{ email: email }, { name: email }],
            role: 'staff'
        });

        if (!staff) return res.status(401).json({ message: 'Invalid credentials' });

        const isMatch = await bcrypt.compare(password, staff.password);
        if (!isMatch) return res.status(401).json({ message: 'Invalid credentials' });

        res.json({
            message: 'Staff logged in',
            token: generateToken(staff),
            user: { id: staff._id, name: staff.name, email: staff.email, role: staff.role }
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

module.exports = router;
