const mongoose = require('mongoose');

const CollectionLogSchema = new mongoose.Schema({
    resident: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    house: { type: mongoose.Schema.Types.ObjectId, ref: 'House' },
    staff: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    route: { type: mongoose.Schema.Types.ObjectId, ref: 'Route' },
    schedule: { type: mongoose.Schema.Types.ObjectId, ref: 'Schedule' },
    status: {
        type: String,
        enum: ['Collected', 'Pending', 'Not Collected', 'Not Cooperative'],
        default: 'Pending'
    },
    weight: { type: Number },
    amountPaid: { type: Number, default: 0 },
    paymentMethod: { type: String, enum: ['Cash', 'Wallet', 'None'], default: 'None' },
    proofImageUrl: { type: String }, // base64 or path
    proofPhotoUrl: { type: String },
    date: { type: String },
    time: { type: String },
    month: { type: String },
    residentResponse: { type: String, enum: ['Available', 'Not Available', 'Pending'], default: 'Pending' },
    residentFeedbackStatus: { type: String, enum: ['Collected', 'Not Collected', 'Not Cooperative', 'Pending'], default: 'Pending' },
    wasteType: { type: String },
    notes: { type: String }
}, { timestamps: true });

module.exports = mongoose.model('CollectionLog', CollectionLogSchema);
