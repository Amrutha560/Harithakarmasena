const mongoose = require('mongoose');

const ScheduleSchema = new mongoose.Schema({
    date: { type: Date, required: true },
    month: { type: Number, min: 1, max: 12 },   // 1-12 for monthly scheduling
    year: { type: Number },                       // e.g. 2025
    wardNumber: { type: String, required: true },
    category: { type: mongoose.Schema.Types.ObjectId, ref: 'WasteCategory', required: true },
    wasteTypes: { type: [String], default: ['Plastic'] },
    assignedStaff: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    notes: { type: String },
    time: { type: String, default: '09:00 AM - 11:00 AM' },
    status: { type: String, enum: ['Scheduled', 'In Progress', 'Completed'], default: 'Scheduled' }
}, { timestamps: true });

module.exports = mongoose.model('Schedule', ScheduleSchema);
