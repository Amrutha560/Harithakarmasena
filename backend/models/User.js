const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema({
    name: { type: String, required: true },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    password: { type: String, required: true },
    role: {
        type: String,
        enum: ['admin', 'resident', 'staff'],
        required: true
    },
    isApproved: {
        type: Boolean,
        default: true // Staff is created directly by Admin, so no approval needed
    },
    houseName: { type: String },
    houseNumber: { type: String },
    address: { type: String },
    phoneNumber: { type: String },
    wardNumber: { type: String },
    ward: { type: mongoose.Schema.Types.ObjectId, ref: 'Ward' },
    route: { type: mongoose.Schema.Types.ObjectId, ref: 'Route' },
    walletBalance: { type: Number, default: 0 }
}, { timestamps: true });

module.exports = mongoose.model('User', UserSchema);
