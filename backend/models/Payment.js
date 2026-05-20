const mongoose = require('mongoose');

const PaymentSchema = new mongoose.Schema({
    resident: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    staff: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }, // Who collected it
    route: { type: mongoose.Schema.Types.ObjectId, ref: 'Route' },
    house: { type: mongoose.Schema.Types.ObjectId, ref: 'House' },
    assignment: { type: mongoose.Schema.Types.ObjectId, ref: 'HouseAssignment' },
    amount: { type: Number, required: true },
    method: { type: String, enum: ['Cash', 'UPI', 'Wallet', 'Online', 'Razorpay'], required: true },
    status: { type: String, enum: ['Success', 'Pending', 'Due', 'Refunded'], default: 'Success' },
    paymentMode: { type: String, enum: ['Online', 'Cash', 'Wallet', 'UPI'] },
    paymentStatus: { type: String, enum: ['Paid', 'Pending', 'Due', 'Refunded'], default: 'Paid' },
    paymentDate: { type: Date },
    month: { type: String },
    paymentCollectedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    transactionId: { type: String } // For UPI/Razorpay
}, { timestamps: true });

module.exports = mongoose.model('Payment', PaymentSchema);
