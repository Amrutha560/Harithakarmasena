const express = require('express');
const router = express.Router();
const Razorpay = require('razorpay');
const crypto = require('crypto');
const authMiddleware = require('../middleware/authMiddleware');
const HouseAssignment = require('../models/HouseAssignment');
const User = require('../models/User');
const Payment = require('../models/Payment');

console.log('[BACKEND] Payment Routes Loaded');

const getMonthKey = (dateValue = new Date()) => {
    const d = typeof dateValue === 'string' ? new Date(`${dateValue}T00:00:00`) : new Date(dateValue);
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    return `${year}-${month}`;
};

const getMonthDateRange = (dateValue = new Date()) => {
    const d = typeof dateValue === 'string' ? new Date(`${dateValue}T00:00:00`) : new Date(dateValue);
    const year = d.getFullYear();
    const month = d.getMonth() + 1;
    const start = `${year}-${String(month).padStart(2, '0')}-01`;
    const lastDay = new Date(year, month, 0).getDate();
    const end = `${year}-${String(month).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`;
    return { start, end };
};

const razorpay = new Razorpay({
    key_id: process.env.RAZORPAY_KEY_ID,
    key_secret: process.env.RAZORPAY_KEY_SECRET,
});

// 1. Create Razorpay Order
router.post('/create-order', authMiddleware(['resident']), async (req, res) => {
    const { amount, scheduleId } = req.body; // scheduleId is the HouseAssignment _id

    try {
        const options = {
            amount: (amount || 50) * 100, // ₹50 in paise
            currency: 'INR',
            receipt: `receipt_${scheduleId || Date.now()}`,
        };

        const order = await razorpay.orders.create(options);
        
        // Return keyId along with order details as requested
        res.json({
            orderId: order.id,
            amount: order.amount,
            currency: order.currency,
            keyId: process.env.RAZORPAY_KEY_ID
        });
    } catch (error) {
        console.error('RAZORPAY ORDER ERROR DETAILS:', error);
        res.status(500).json({ 
            message: 'Could not create order', 
            error: error.message
        });
    }
});

// 2. Verify Payment and Update Schedule
router.post('/verify-payment', authMiddleware(['resident']), async (req, res) => {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature, scheduleId } = req.body;

    try {
        // Verify Signature
        const sign = razorpay_order_id + "|" + razorpay_payment_id;
        const expectedSign = crypto
            .createHmac("sha256", process.env.RAZORPAY_KEY_SECRET)
            .update(sign.toString())
            .digest("hex");

        if (razorpay_signature !== expectedSign) {
            return res.status(400).json({ message: "Invalid payment signature" });
        }

        // Payment is verified. The fee is monthly, so make it visible on every
        // staff visit card for the same resident/house in this month.
        const paymentDate = new Date();
        const month = getMonthKey(paymentDate);
        const { start, end } = getMonthDateRange(paymentDate);
        const assignment = await HouseAssignment.findByIdAndUpdate(
            scheduleId,
            { 
                paymentStatus: 'Paid',
                transactionId: razorpay_payment_id,
                amount: 50,
                paymentMethod: 'Online',
                paymentMode: 'Online',
                paymentDate,
                month,
                paidAt: paymentDate
            },
            { new: true }
        );

        if (!assignment) {
            return res.status(404).json({ message: "Schedule record not found" });
        }

        const payment = await Payment.findOneAndUpdate(
            { resident: req.user.id, assignment: assignment._id },
            {
                resident: req.user.id,
                route: assignment.route,
                house: assignment.house,
                assignment: assignment._id,
                amount: 50,
                method: 'Razorpay',
                status: 'Success',
                paymentMode: 'Online',
                paymentStatus: 'Paid',
                paymentDate,
                month,
                transactionId: razorpay_payment_id
            },
            { upsert: true, new: true, setDefaultsOnInsert: true }
        );

        await HouseAssignment.updateMany(
            {
                date: { $gte: start, $lte: end },
                $or: [
                    { resident: assignment.resident || req.user.id },
                    { house: assignment.house },
                    { houseNumber: assignment.houseNumber }
                ]
            },
            {
                $set: {
                    paymentStatus: 'Paid',
                    transactionId: razorpay_payment_id,
                    amount: 50,
                    paymentMethod: 'Online',
                    paymentMode: 'Online',
                    paymentDate,
                    month,
                    paidAt: paymentDate
                }
            }
        );

        res.json({ message: "Payment verified and schedule updated", assignment, payment });
    } catch (error) {
        console.error('Payment Verification Error:', error);
        res.status(500).json({ message: "Server error during verification" });
    }
});

module.exports = router;
