const mongoose = require('mongoose');

const houseSchema = new mongoose.Schema({
    ownerName: { type: String, required: true },
    houseNumber: { type: String, required: true },
    address: { type: String, default: '' },
    phoneNumber: { type: String, default: '' },
    route: { type: mongoose.Schema.Types.ObjectId, ref: 'Route', required: true },
    ward: { type: mongoose.Schema.Types.ObjectId, ref: 'Ward' },
    wardNumber: { type: String },
    isActive: { type: Boolean, default: true },
    wasteTypes: { type: [String], default: ['General'] },
    collectionTime: { type: String, default: '09:00 AM - 11:00 AM' },
    resident: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
}, { timestamps: true });

module.exports = mongoose.model('House', houseSchema);
