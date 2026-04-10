const mongoose = require('mongoose');

const ScheduleSchema = new mongoose.Schema({
    date: { type: Date, required: true },
    month: { type: Number, min: 1, max: 12 },   // 1-12 for monthly scheduling
    year: { type: Number },                       // e.g. 2025
    wardNumber: { type: String, required: true },
    category: { type: mongoose.Schema.Types.ObjectId, ref: 'WasteCategory', required: true },
    assignedStaff: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    notes: { type: String },
    status: { type: String, enum: ['Scheduled', 'In Progress', 'Completed'], default: 'Scheduled' }
}, { timestamps: true });

module.exports = mongoose.model('Schedule', ScheduleSchema);
