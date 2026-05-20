const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema({
    firstName: { type: String, required: true },
    lastName: { type: String },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    password: { type: String, required: true },
    verificationDoc: { type: String }, // Path to uploaded PDF
    role: {
        type: String,
        enum: ['admin', 'resident', 'staff'],
        required: true
    },
    isApproved: {
        type: Boolean,
        default: false // New residents need Admin approval
    },
    houseName: { type: String },
    houseNumber: { type: String },
    address: { type: String },
    phoneNumber: { type: String },
    district: { type: String },
    lsgiType: { type: String },
    lsgiName: { type: String },
    wardName: { type: String },
    wardNumber: { type: String },
    ward: { type: mongoose.Schema.Types.ObjectId, ref: 'Ward' },
    route: { type: mongoose.Schema.Types.ObjectId, ref: 'Route' },
    house: { type: mongoose.Schema.Types.ObjectId, ref: 'House' },
    walletBalance: { type: Number, default: 0 },
    isFirstLogin: { type: Boolean, default: true },
    passwordSetupToken: { type: String },
    passwordSetupExpires: { type: Date }
}, { 
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true }
});

UserSchema.virtual('name').get(function() {
    return `${this.firstName || ''} ${this.lastName || ''}`.trim();
});

module.exports = mongoose.model('User', UserSchema);
