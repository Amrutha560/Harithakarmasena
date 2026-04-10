const mongoose = require('mongoose');

const routeSchema = new mongoose.Schema({
    name: { type: String, required: true },
    ward: { type: mongoose.Schema.Types.ObjectId, ref: 'Ward', required: true },
    assignedStaff: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    collectionDays: { type: [String], default: [] },
    description: { type: String },
    createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Route', routeSchema);
