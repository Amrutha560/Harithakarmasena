const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const User = require('../models/User');
const Complaint = require('../models/Complaint');
const Payment = require('../models/Payment');
const Schedule = require('../models/Schedule');

const Notification = require('../models/Notification');

// ── Resident Dashboard ─────────────────────────────────────────────────────
router.get('/dashboard', authMiddleware(['resident']), async (req, res) => {
    try {
        const resident = await User.findById(req.user.id).select('-password');

        // Find current schedules for the resident's ward
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const mySchedules = await Schedule.find({ wardNumber: resident.wardNumber, date: { $gte: today } }).populate('category');

        // Latest payment status
        const lastPayment = await Payment.findOne({ resident: req.user.id }).sort({ createdAt: -1 });

        // Latest notifications
        const notifications = await Notification.find({ 
            $or: [
                { resident: req.user.id },
                { wardNumber: resident.wardNumber }
            ]
        }).sort({ createdAt: -1 }).limit(10);

        // Daily Collection Status
        const CollectionLog = require('../models/CollectionLog');
        const collectionStatus = await CollectionLog.findOne({
            resident: req.user.id,
            createdAt: { $gte: today }
        }).sort({ createdAt: -1 });

        res.json({
            user: resident,
            schedules: mySchedules,
            lastPayment,
            notifications,
            collectionStatus: collectionStatus ? collectionStatus.status : 'Pending',
            walletBalance: resident.walletBalance || 0
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// ── Wallet Management ───────────────────────────────────────────────────────

// Add money to wallet
router.post('/wallet/add', authMiddleware(['resident']), async (req, res) => {
    const { amount } = req.body;
    try {
        const user = await User.findByIdAndUpdate(req.user.id, { $inc: { walletBalance: amount } }, { new: true });
        res.json({ message: 'Wallet updated successfully', balance: user.walletBalance });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Pay ₹50 from wallet
router.post('/wallet/pay', authMiddleware(['resident']), async (req, res) => {
    const amount = 50;
    try {
        const user = await User.findById(req.user.id);
        if (user.walletBalance < amount) {
            return res.status(400).json({ message: 'Insufficient wallet balance. Please top up.' });
        }

        user.walletBalance -= amount;
        await user.save();

        const payment = new Payment({
            resident: req.user.id,
            amount,
            method: 'Wallet',
            status: 'Success'
        });
        await payment.save();

        // Create success notification
        const notif = new Notification({
            resident: req.user.id,
            title: 'Payment Successful',
            message: `₹${amount} deducted for waste collection service.`,
            type: 'PaymentAlert'
        });
        await notif.save();

        res.json({ message: 'Payment successful', balance: user.walletBalance, payment });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// ── Notifications ───────────────────────────────────────────────────────────

router.get('/notifications', authMiddleware(['resident']), async (req, res) => {
    try {
        const user = await User.findById(req.user.id);
        const notifications = await Notification.find({ 
            $or: [
                { resident: req.user.id },
                { wardNumber: user.wardNumber }
            ]
        }).sort({ createdAt: -1 });
        res.json(notifications);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// ── Complaints ─────────────────────────────────────────────────────────────

// File a Complaint
router.post('/complaints', authMiddleware(['resident']), async (req, res) => {
    const { description } = req.body;
    try {
        const resident = await User.findById(req.user.id);
        const complaint = new Complaint({
            resident: req.user.id,
            description,
            area: resident.area,
            status: 'Pending'
        });
        await complaint.save();

        // Notify Admins
        const admins = await User.find({ role: 'admin' });
        for (const admin of admins) {
            const adminNotif = new Notification({
                resident: admin._id, // Send to admin
                title: 'New Complaint Raised',
                message: `${resident.name} has filed a new grievance: "${description.substring(0, 50)}..."`,
                type: 'MaintenanceAlert'
            });
            await adminNotif.save();
        }

        res.status(201).json({ message: 'Complaint filed successfully', complaint });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// View my Complaints
router.get('/my-complaints', authMiddleware(['resident']), async (req, res) => {
    try {
        const complaints = await Complaint.find({ resident: req.user.id }).sort({ createdAt: -1 });
        res.json(complaints);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// ── Payments ───────────────────────────────────────────────────────────────

// View my Payment History
router.get('/my-payments', authMiddleware(['resident']), async (req, res) => {
    try {
        const payments = await Payment.find({ resident: req.user.id }).sort({ createdAt: -1 });
        res.json(payments);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

module.exports = router;
