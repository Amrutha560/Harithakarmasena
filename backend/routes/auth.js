const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Ward = require('../models/Ward');
const authMiddleware = require('../middleware/authMiddleware');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const nodemailer = require('nodemailer');
const { buildPasswordSetupLink, createPasswordSetup, hashSetupToken } = require('../utils/passwordSetup');

const sendStaffCredentialsEmail = async ({ to, name, username, password }) => {
    if (!process.env.EMAIL_USER || !process.env.EMAIL_PASS) {
        console.log(`
            --- STAFF CREDENTIAL EMAIL (NOT SENT: EMAIL_USER/EMAIL_PASS missing) ---
            To: ${to}
            Message: Hello ${name}, your staff account has been created.
            Username: ${username}
            Temporary Password: ${password}
            Please login and change this password immediately.
            -----------------------------------------------------------------------
        `);
        return { sent: false, reason: 'Email sender is not configured' };
    }

    const transporter = nodemailer.createTransport({
        service: 'gmail',
        auth: {
            user: process.env.EMAIL_USER,
            pass: process.env.EMAIL_PASS,
        },
    });

    try {
        await transporter.sendMail({
            from: `"Harithakarma Sena" <${process.env.EMAIL_USER}>`,
            to,
            subject: 'Harithakarma Sena Staff Account',
            text: `Hello ${name},

Your staff account has been created.

Username: ${username}
Temporary Password: ${password}

Please login and change this password immediately.`,
        });
    } catch (error) {
        console.error('[EMAIL] Staff credential email failed:', error.message);
        return { sent: false, reason: error.message || 'Email delivery failed' };
    }

    return { sent: true };
};

// Multer storage configuration
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        const uploadPath = 'uploads/verification_docs/';
        if (!fs.existsSync(uploadPath)) {
            fs.mkdirSync(uploadPath, { recursive: true });
        }
        cb(null, uploadPath);
    },
    filename: (req, file, cb) => {
        cb(null, `${Date.now()}-${file.originalname}`);
    }
});

const upload = multer({
    storage,
    fileFilter: (req, file, cb) => {
        const isPdfMime = file.mimetype === 'application/pdf';
        const isPdfName = file.originalname.toLowerCase().endsWith('.pdf');
        if (isPdfMime || isPdfName) {
            cb(null, true);
        } else {
            cb(new Error('Only PDF files are allowed'), false);
        }
    },
    limits: { fileSize: 5 * 1024 * 1024 } // 5MB limit
});

const generateToken = (user) => {
    return jwt.sign({ id: user._id, role: user.role }, process.env.JWT_SECRET, {
        expiresIn: '1d',
    });
};

const passwordMatches = async (plainPassword, storedPassword) => {
    try {
        if (storedPassword && storedPassword.startsWith('$2')) {
            return bcrypt.compare(plainPassword, storedPassword);
        }
        return plainPassword === storedPassword;
    } catch (bcryptErr) {
        console.error('[AUTH] Password compare error:', bcryptErr);
        return plainPassword === storedPassword;
    }
};

const isLocalDemoPassword = (plainPassword) =>
    process.env.NODE_ENV !== 'production' && plainPassword === 'resident123';

const escapeRegExp = (value = '') =>
    value.toString().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const buildLoginQuery = (role, identifier) => {
    const cleanIdentifier = identifier.trim();
    const escaped = escapeRegExp(cleanIdentifier);
    if (role === 'admin') {
        return {
            role,
            email: { $regex: `^${escaped}$`, $options: 'i' }
        };
    }

    const dummyEmail = cleanIdentifier.includes('@')
        ? cleanIdentifier.toLowerCase()
        : `${cleanIdentifier.toLowerCase()}@resident.com`;
    const query = {
        role,
        $or: [
            { email: { $regex: `^${escapeRegExp(dummyEmail)}$`, $options: 'i' } },
            { phoneNumber: cleanIdentifier },
            { firstName: { $regex: `^${escaped}$`, $options: 'i' } },
            { lastName: { $regex: `^${escaped}$`, $options: 'i' } }
        ]
    };

    if (role === 'resident') {
        query.$or.push(
            { houseNumber: cleanIdentifier },
            { houseName: { $regex: `^${escaped}$`, $options: 'i' } }
        );
        if (cleanIdentifier.includes('/')) {
            const [hName, hNum] = cleanIdentifier.split('/');
            query.$or.push({
                $and: [
                    { houseName: { $regex: `^${escapeRegExp(hName.trim())}$`, $options: 'i' } },
                    { houseNumber: hNum.trim() }
                ]
            });
        }
    }

    return query;
};

// Admin Login
router.post('/admin/login', async (req, res) => {
    const { email, password } = req.body;

    try {
        const admin = await User.findOne({ email, role: 'admin' });
        if (!admin) return res.status(401).json({ message: 'Invalid credentials' });

        let isMatch = false;
        if (admin.password && admin.password.startsWith('$2')) {
            isMatch = await bcrypt.compare(password, admin.password);
        } else {
            isMatch = password === admin.password;
        }
        if (!isMatch) return res.status(401).json({ message: 'Invalid credentials' });

        res.json({
            message: 'Admin logged in',
            token: generateToken(admin),
            user: { 
                id: admin._id, 
                firstName: admin.firstName, 
                lastName: admin.lastName, 
                email: admin.email, 
                role: admin.role 
            }
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Resident Registration
router.post('/resident/register', upload.single('verificationDoc'), async (req, res) => {
    console.log('[DEBUG] Registration Request Body:', req.body);
    console.log('[DEBUG] Uploaded File:', req.file);

    const { 
        firstName, lastName, email, address, 
        phoneNumber, houseNumber, ward, route, district, lsgiType, lsgiName, wardName 
    } = req.body;
    const wardId = ward;
    const routeId = route;
    const phone = phoneNumber ? phoneNumber.toString().trim() : '';
    const cleanHouseNumber = houseNumber ? houseNumber.toString().trim() : '';
    const normalizedIncomingEmail = email ? email.toString().trim().toLowerCase() : '';
    const residentEmail = !normalizedIncomingEmail || normalizedIncomingEmail.endsWith('@resident.local')
        ? `house_${cleanHouseNumber.replace(/[^a-zA-Z0-9]/g, '').toLowerCase()}_${(wardId || 'ward').toString().replace(/[^a-zA-Z0-9]/g, '').toLowerCase()}@resident.local`
        : normalizedIncomingEmail;

    const verificationDoc = req.file ? req.file.path : null;

    try {
        const wordCount = (value) => value ? value.toString().trim().split(/\s+/).filter(Boolean).length : 0;
        if (wordCount(firstName) > 10) {
            return res.status(400).json({ message: 'First name must be maximum 10 words' });
        }
        if (wordCount(lastName) > 10) {
            return res.status(400).json({ message: 'Last name must be maximum 10 words' });
        }

        if (!/^\d{1,3}$/.test(cleanHouseNumber)) {
            return res.status(400).json({ message: 'House number must be 1 to 3 digits, e.g. 1, 18 or 133' });
        }

        const uniqueChecks = [{ email: residentEmail }];
        if (!process.env.TWILIO_RESIDENT_TEST_TO && phone) {
            uniqueChecks.push({ phoneNumber: phone });
        }
        if (cleanHouseNumber && wardId) {
            uniqueChecks.push({ houseNumber: cleanHouseNumber, ward: wardId });
        }

        const existingUser = await User.findOne({ $or: uniqueChecks });
        if (existingUser) {
            const field = existingUser.email === residentEmail
                ? 'House/email'
                : (existingUser.houseNumber === cleanHouseNumber ? 'House number' : 'Phone number');
            return res.status(400).json({ message: `${field} already registered` });
        }

        // Generate a random password since user sets it upon approval
        const generatedPassword = Math.random().toString(36).slice(-8);
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(generatedPassword, salt);

        const Ward = require('../models/Ward');
        const Route = require('../models/Route');
        const House = require('../models/House');
        const Notification = require('../models/Notification');

        const wardObj = wardId ? await Ward.findById(wardId) : null;
        const routeObj = routeId ? await Route.findById(routeId) : null;

        const residentData = {
            firstName,
            lastName,
            email: residentEmail,
            password: hashedPassword,
            role: 'resident',
            houseName: address ? address.split(',')[0].trim() : '',
            houseNumber: cleanHouseNumber,
            address,
            phoneNumber: phone,
            district,
            lsgiType,
            lsgiName,
            wardName: wardName || (wardObj ? wardObj.name : ''),
            wardNumber: wardObj ? wardObj.wardNumber : '',
            verificationDoc,
            isApproved: false 
        };

        if (wardId && wardId !== 'null') residentData.ward = wardId;
        if (routeId && routeId !== 'null') residentData.route = routeId;

        const resident = new User(residentData);
        await resident.save();

        // --- SMART LINKING & AUTO-HOUSE CREATION ---
        // Removed because houseNumber is no longer collected during registration

        // --- ADMIN NOTIFICATION ---
        const systemAdmin = await User.findOne({ role: 'admin' });
        if (systemAdmin) {
            try {
                await Notification.create({
                    resident: resident._id, 
                    title: 'New Resident Approval Needed',
                    message: `${firstName} ${lastName} has registered. Route: "${routeObj?.name || 'N/A'}", Ward: ${wardObj?.wardNumber || 'N/A'}. Please review and approve.`,
                    type: 'General'
                });
            } catch (notifErr) {
                console.error('[NON-CRITICAL] Notification Error:', notifErr);
            }
        }

        res.status(201).json({
            message: 'Resident registered successfully. Pending Admin approval.',
            user: { 
                id: resident._id, 
                firstName, 
                lastName, 
                email, 
                role: 'resident', 
                isApproved: false 
            }
        });
    } catch (error) {
        console.error('Registration Error:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Resident Login
router.post('/resident/login', async (req, res) => {
    const { email, password } = req.body;
    const identifier = email.trim();
    const dummyEmail = identifier.includes('@') ? identifier.toLowerCase() : `${identifier.toLowerCase()}@resident.com`;

    try {
        // Check if identifier is in houseName/houseNumber format
        let query = {
            $or: [
                { email: { $regex: `^${dummyEmail}$`, $options: 'i' } },
                { phoneNumber: identifier },
                { firstName: { $regex: `^${identifier}$`, $options: 'i' } },
                { lastName: { $regex: `^${identifier}$`, $options: 'i' } },
                { houseNumber: identifier },
                { houseName: { $regex: `^${identifier}$`, $options: 'i' } }
            ],
            role: 'resident'
        };

        if (identifier.includes('/')) {
            const [hName, hNum] = identifier.split('/');
            query.$or.push({
                $and: [
                    { houseName: { $regex: `^${hName.trim()}$`, $options: 'i' } },
                    { houseNumber: hNum.trim() }
                ]
            });
        }

        const candidates = await User.find(query);
        if (candidates.length === 0) return res.status(401).json({ message: 'Invalid credentials' });

        let resident = null;
        for (const candidate of candidates) {
            if (await passwordMatches(password, candidate.password)) {
                resident = candidate;
                break;
            }
        }

        if (!resident && isLocalDemoPassword(password)) {
            resident =
                candidates.find((candidate) => candidate.isApproved) ||
                candidates[0];
        }

        if (!resident) {
            return res.status(401).json({
                message: candidates.length > 1
                    ? 'Invalid credentials. If residents share a phone number, login with house number or name.'
                    : 'Invalid credentials'
            });
        }

        // Check Admin Approval
        if (!resident.isApproved) {
            return res.status(403).json({ message: 'Your account is pending admin approval. Please try again later.' });
        }

        // --- User Request: Link to master house record on login ---
        const House = require('../models/House');
        const cleanLoginHouseNum = resident.houseNumber ? resident.houseNumber.toString().trim() : '';
        let masterHouse = await House.findOne({ 
            houseNumber: cleanLoginHouseNum,
            $or: [{ ward: resident.ward }, { wardNumber: resident.wardNumber }]
        });
        
        if (!masterHouse && cleanLoginHouseNum) {
            // Last resort fallback
            const possibleHouses = await House.find({ houseNumber: cleanLoginHouseNum });
            if (possibleHouses.length === 1) {
                masterHouse = possibleHouses[0];
            }
        }
        
        if (masterHouse) {
            resident.house = masterHouse._id;
            
            // Sync name if current name is generic
            if (masterHouse.ownerName && (!resident.firstName || resident.firstName.toLowerCase() === 'resident')) {
                const nameParts = masterHouse.ownerName.trim().split(' ');
                resident.firstName = nameParts[0] || 'Resident';
                resident.lastName = nameParts.slice(1).join(' ') || '';
            }
            
            await resident.save();
            
            if (!masterHouse.resident) {
                masterHouse.resident = resident._id;
                await masterHouse.save();
            }
        }

        res.json({
            message: 'Resident logged in',
            token: generateToken(resident),
            user: { 
                id: resident._id, 
                firstName: resident.firstName, 
                lastName: resident.lastName, 
                email: resident.email, 
                role: resident.role,
                houseId: masterHouse ? masterHouse._id : null,
                houseNumber: resident.houseNumber,
                isFirstLogin: resident.isFirstLogin,
                mustChangePassword: resident.isFirstLogin
            }
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Create Staff (Admin Only)
router.post('/staff/create', authMiddleware(['admin']), async (req, res) => {
    let { name, email, houseName, houseNumber, address, phoneNumber, wardNumber, wardId, routeId } = req.body;

    try {
        const existingStaff = await User.findOne({ $or: [{ email }, { phoneNumber }] });
        if (existingStaff) {
            const field = existingStaff.email === email ? 'Email' : 'Phone number';
            return res.status(400).json({ message: `${field} already registered` });
        }

        const temporaryPassword = Math.random().toString(36).slice(-8);
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(temporaryPassword, salt);

        // Map wardId/routeId to ward/route for schema consistency
        const wardObj = wardId ? await Ward.findById(wardId) : null;
        const actualWardNumber = wardNumber || wardObj?.wardNumber;

        const staff = new User({
            firstName: name.split(' ')[0] || name,
            lastName: name.split(' ').slice(1).join(' ') || '',
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
            isApproved: true,
            isFirstLogin: false
        });

        await staff.save();

        // 📝 Simulate sending a message to the staff's mobile number
        if (false && phoneNumber) {
            const message = `
                --- PASSWORD SETUP NOTIFICATION (STAFF) ---
                To: ${phoneNumber}
                Message: Hello ${name}, you have been added as a Staff member!
                Username: ${email}
                Set your password here: ${setupLink}
                This link expires in 24 hours.
                -------------------------------
            `;
            console.log(message);
        }

        const emailResult = await sendStaffCredentialsEmail({
            to: email,
            name,
            username: email,
            password: temporaryPassword
        });

        // Also create an in-app notification for the staff member
        try {
            const Notification = require('../models/Notification');
            await Notification.create({
                resident: staff._id, // Using 'resident' field to store the user ID
                title: 'Account Created!',
                message: `Your staff account is ready. Credentials have been sent to ${email}. Please login and change your password.`,
                type: 'General'
            });
        } catch (notifErr) {
            console.error('[NON-CRITICAL] Staff Notification Error:', notifErr);
        }

        res.status(201).json({ 
            message: 'Staff created successfully by Admin',
            emailSentTo: email,
            emailSent: emailResult.sent,
            emailMessage: emailResult.sent ? 'Credentials sent to staff email' : emailResult.reason,
            user: { firstName: staff.firstName, lastName: staff.lastName, email, role: 'staff' }
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Staff Login
router.post('/staff/login', async (req, res) => {
    const { email, password } = req.body; // 'email' here is the username input from frontend
    console.log(`[AUTH] Staff login attempt for: ${email}`);

    try {
        // Try finding by email, name, or phone number - Case Insensitive
        const staff = await User.findOne({
            $or: [
                { email: { $regex: `^${email}$`, $options: 'i' } }, 
                { phoneNumber: email },
                { firstName: { $regex: `^${email}$`, $options: 'i' } },
                { lastName: { $regex: `^${email}$`, $options: 'i' } }
            ],
            role: 'staff'
        });

        if (!staff) {
            console.log(`[AUTH] Staff not found for identifier: ${email}`);
            return res.status(401).json({ message: 'Invalid credentials' });
        }

        let isMatch = false;
        try {
            if (staff.password && staff.password.startsWith('$2')) {
                isMatch = await bcrypt.compare(password, staff.password);
            } else {
                isMatch = (password === staff.password);
            }
        } catch (bcryptErr) {
            console.error('[AUTH] Bcrypt error in staff login:', bcryptErr);
            isMatch = (password === staff.password);
        }

        if (!isMatch) {
            console.log(`[AUTH] Password mismatch for staff: ${email}`);
            return res.status(401).json({ message: 'Invalid credentials' });
        }

        res.json({
            message: 'Staff logged in',
            token: generateToken(staff),
            user: { 
                id: staff._id, 
                firstName: staff.firstName, 
                lastName: staff.lastName, 
                email: staff.email, 
                role: staff.role,
                isFirstLogin: staff.isFirstLogin
            }
        });
    } catch (error) {
        console.error('[AUTH] Staff login error:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Public one-time password setup
router.post('/set-password', async (req, res) => {
    const { token, newPassword } = req.body;

    if (!token || !newPassword || newPassword.length < 6) {
        return res.status(400).json({ message: 'Valid token and a password of at least 6 characters are required' });
    }

    try {
        const user = await User.findOne({
            passwordSetupToken: hashSetupToken(token),
            passwordSetupExpires: { $gt: new Date() }
        });

        if (!user) {
            return res.status(400).json({ message: 'This password setup link is invalid or expired' });
        }

        const salt = await bcrypt.genSalt(10);
        user.password = await bcrypt.hash(newPassword, salt);
        user.passwordSetupToken = undefined;
        user.passwordSetupExpires = undefined;
        user.isFirstLogin = false;
        user.isApproved = true;
        await user.save();

        res.json({ message: 'Password set successfully. Please login with your new password.' });
    } catch (error) {
        console.error('[AUTH] Set password error:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

router.post('/forgot-password', async (req, res) => {
    const { role, identifier, newPassword } = req.body;
    try {
        if (!['admin', 'staff', 'resident'].includes(role)) {
            return res.status(400).json({ message: 'Please choose a valid account type' });
        }
        if (!identifier || !newPassword || newPassword.length < 6) {
            return res.status(400).json({ message: 'Enter your username and a password of at least 6 characters' });
        }

        const users = await User.find(buildLoginQuery(role, identifier));
        const approvedUsers = role === 'resident'
            ? users.filter((user) => user.isApproved)
            : users;
        if (approvedUsers.length === 0) {
            return res.status(404).json({ message: 'Account not found' });
        }
        if (approvedUsers.length > 1 && role === 'resident') {
            return res.status(400).json({ message: 'Multiple residents found. Use house number or exact name.' });
        }

        const user = approvedUsers[0];
        const salt = await bcrypt.genSalt(10);
        user.password = await bcrypt.hash(newPassword, salt);
        user.isFirstLogin = false;
        user.passwordSetupToken = undefined;
        user.passwordSetupExpires = undefined;
        await user.save();

        res.json({ message: 'Password reset successfully. Please login with the new password.' });
    } catch (error) {
        console.error('[AUTH] Forgot password error:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// ── User Account Actions ────────────────────────────────────────────────────

// Universal Change Password
router.post('/change-password', authMiddleware(['admin', 'resident', 'staff']), async (req, res) => {
    const { oldPassword, newPassword } = req.body;

    try {
        const user = await User.findById(req.user.id);
        if (!user) return res.status(404).json({ message: 'User not found' });

        // Verify old password
        let isMatch = false;
        if (user.password && user.password.startsWith('$2')) {
            isMatch = await bcrypt.compare(oldPassword, user.password);
        } else {
            isMatch = (oldPassword === user.password);
        }

        if (!isMatch) {
            return res.status(400).json({ message: 'Incorrect old password' });
        }

        // Hash and save new password
        const salt = await bcrypt.genSalt(10);
        user.password = await bcrypt.hash(newPassword, salt);
        user.isFirstLogin = false; // Set to false after password change
        await user.save();

        res.json({ message: 'Password updated successfully. Please login again.' });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Universal Feedback submission
router.post('/feedback', authMiddleware(['admin', 'resident', 'staff']), async (req, res) => {
    const { subject, message } = req.body;
    const Feedback = require('../models/Feedback');

    try {
        const user = await User.findById(req.user.id);
        const feedback = new Feedback({
            residentId: req.user.id,
            residentName: `${user.firstName} ${user.lastName || ''}`.trim(),
            houseNumber: user.houseNumber || 'N/A',
            subject,
            message
        });
        await feedback.save();
        res.status(201).json({ message: 'Feedback submitted successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Get all feedback (Admin Only)
router.get('/all-feedback', authMiddleware(['admin']), async (req, res) => {
    const Feedback = require('../models/Feedback');
    try {
        const feedback = await Feedback.find().sort({ createdAt: -1 });
        res.json(feedback);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

module.exports = router;

