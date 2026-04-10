const mongoose = require('mongoose');

const CollectionLogSchema = new mongoose.Schema({
    resident: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    staff: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    schedule: { type: mongoose.Schema.Types.ObjectId, ref: 'Schedule', required: true },
    status: {
        type: String,
        enum: ['Collected', 'Pending', 'Not Available', 'Not Cooperative'],
        default: 'Pending'
    },
    weight: { type: Number }, // Optional kg
    notes: { type: String }
}, { timestamps: true });

module.exports = mongoose.model('CollectionLog', CollectionLogSchema);
