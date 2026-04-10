const mongoose = require('mongoose');

const ComplaintSchema = new mongoose.Schema({
    resident: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    description: { type: String, required: true },
    wardNumber: { type: String }, // Can be auto-filled from resident profile
    status: {
        type: String,
        enum: ['Pending', 'In Progress', 'Resolved'],
        default: 'Pending'
    },
    remarks: { type: String } // For admin/staff responses
}, { timestamps: true });

module.exports = mongoose.model('Complaint', ComplaintSchema);
