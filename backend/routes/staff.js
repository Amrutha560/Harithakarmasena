const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const User = require('../models/User');
const Schedule = require('../models/Schedule');
const CollectionLog = require('../models/CollectionLog');
const Payment = require('../models/Payment');
const Complaint = require('../models/Complaint');

// ── Staff Dashboard Info ───────────────────────────────────────────────────
router.get('/dashboard', authMiddleware(['staff']), async (req, res) => {
    try {
        const staff = await User.findById(req.user.id).select('-password').populate('ward').populate('route');

        const now = new Date();
        const currentMonth = now.getMonth() + 1;
        const currentYear = now.getFullYear();

        // Monthly schedules for this staff's ward (or route)
        const monthlySchedules = await Schedule.find({
            wardNumber: staff.wardNumber,
            month: currentMonth,
            year: currentYear
        }).populate('category').sort({ date: 1 });

        // Today's schedules
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const tomorrow = new Date(today);
        tomorrow.setDate(tomorrow.getDate() + 1);

        const todaySchedules = await Schedule.find({
            wardNumber: staff.wardNumber,
            date: { $gte: today, $lt: tomorrow }
        }).populate('category');

        const mongoose = require('mongoose');
        const staffRoutes = await mongoose.model('Route').find({ assignedStaff: req.user.id });

        res.json({
            user: staff,
            routes: staffRoutes,
            schedules: todaySchedules,
            monthlySchedules: monthlySchedules,
            currentMonth,
            currentYear
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// ── Daily Operations ────────────────────────────────────────────────────────

// View residents in a specific ward or assigned route (for today's collection)
router.get('/residents/:wardNumber', authMiddleware(['staff']), async (req, res) => {
    try {
        const staff = await User.findById(req.user.id);
        
        let query = { role: 'resident' };
        if (staff.route) {
            query.route = staff.route;
        } else {
            query.wardNumber = req.params.wardNumber;
        }

        const residents = await User.find(query).select('-password');
        
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const enhancedResidents = await Promise.all(residents.map(async (r) => {
            // Check if resident paid today
            const paidToday = await Payment.findOne({ 
                resident: r._id, 
                createdAt: { $gte: today } 
            });
            // Check current collection status for today
            const collectionLog = await CollectionLog.findOne({
                resident: r._id,
                createdAt: { $gte: today }
            });

            return {
                ...r.toObject(),
                hasPaid: !!paidToday,
                collectionStatus: collectionLog ? collectionLog.status : 'Pending'
            };
        }));

        res.json(enhancedResidents);
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// Mark Collection Status
router.post('/mark-collection', authMiddleware(['staff']), async (req, res) => {
    const { residentId, scheduleId, status, weight, notes } = req.body;
    try {
        const log = new CollectionLog({
            resident: residentId,
            staff: req.user.id,
            schedule: scheduleId,
            status,
            weight,
            notes
        });
        await log.save();

        // ── Refund Logic (Staff Issue) ────────────────
        if (status === 'Not Collected') {
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            
            // Check if user paid today via wallet
            const payment = await Payment.findOne({ 
                resident: residentId, 
                createdAt: { $gte: today },
                status: 'Success',
                method: 'Wallet'
            });

            if (payment) {
                // Refund to wallet
                await User.findByIdAndUpdate(residentId, { $inc: { walletBalance: 50 } });
                
                // Update payment status
                payment.status = 'Refunded';
                await payment.save();

                // Notify User
                const Notification = require('../models/Notification');
                await new Notification({
                    resident: residentId,
                    title: 'Refund Processed',
                    message: `₹50 refunded to your wallet as collection was Not Completed by our staff.`,
                    type: 'RefundAlert'
                }).save();
            }
        }
        // ───────────────────────────────

        res.status(201).json({ message: 'Collection status updated', log });
    } catch (error) {
        console.error('Error marking collection:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// ── Payment Verification ────────────────────────────────────────────────────

// Record Payment (Cash or UPI)
router.post('/record-payment', authMiddleware(['staff']), async (req, res) => {
    const { residentId, amount, method, transactionId } = req.body;
    try {
        const payment = new Payment({
            resident: residentId,
            staff: req.user.id,
            amount,
            method,
            transactionId,
            status: 'Success'
        });
        await payment.save();
        res.status(201).json({ message: 'Payment recorded successfully', payment });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// View Resident Payment History (Local)
router.get('/resident-payments/:residentId', authMiddleware(['staff']), async (req, res) => {
    try {
        const payments = await Payment.find({ resident: req.params.residentId }).sort({ createdAt: -1 });
        res.json(payments);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

const Notification = require('../models/Notification');

// ── Communication ───────────────────────────────────────────────────────────

// Send notification to a ward
router.post('/notify-ward', authMiddleware(['staff']), async (req, res) => {
    const { message, wardNumber } = req.body;
    try {
        const notif = new Notification({
            wardNumber,
            title: 'Collection Alert',
            message: message || `Waste collection is starting in Ward ${wardNumber}. Please keep your waste outside.`,
            type: 'CollectionAlert'
        });
        await notif.save();
        res.json({ message: 'Residents notified successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// View complaints in staff's ward
router.get('/complaints', authMiddleware(['staff']), async (req, res) => {
    try {
        const staff = await User.findById(req.user.id);
        const complaints = await Complaint.find({ wardNumber: staff.wardNumber }).populate('resident', 'name address');
        res.json(complaints);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// View daily collection report
router.get('/daily-report', authMiddleware(['staff']), async (req, res) => {
    try {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const tomorrow = new Date(today);
        tomorrow.setDate(tomorrow.getDate() + 1);

        const staff = await User.findById(req.user.id);

        const logs = await CollectionLog.find({ 
            staff: req.user.id,
            createdAt: { $gte: today, $lt: tomorrow }
        }).populate('resident', 'name houseNumber wardNumber');

        const totalCollected = logs.filter(l => l.status === 'Collected').length;
        const totalNotCollected = logs.filter(l => l.status === 'Not Collected').length;
        const totalNotCooperative = logs.filter(l => l.status === 'Not Cooperative').length;

        const payments = await Payment.find({
            staff: req.user.id,
            createdAt: { $gte: today, $lt: tomorrow }
        });

        const totalAmount = payments.reduce((sum, p) => sum + p.amount, 0);

        res.json({
            date: today,
            logs,
            stats: {
                totalHouses: logs.length,
                totalCollected,
                totalNotCollected,
                totalNotCooperative,
                totalRevenue: totalAmount
            }
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

module.exports = router;
