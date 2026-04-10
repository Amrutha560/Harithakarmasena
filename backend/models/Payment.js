const mongoose = require('mongoose');

const PaymentSchema = new mongoose.Schema({
    resident: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    staff: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }, // Who collected it
    amount: { type: Number, required: true },
    method: { type: String, enum: ['Cash', 'UPI', 'Wallet'], required: true },
    status: { type: String, enum: ['Success', 'Pending'], default: 'Success' },
    transactionId: { type: String } // For UPI
}, { timestamps: true });

module.exports = mongoose.model('Payment', PaymentSchema);
