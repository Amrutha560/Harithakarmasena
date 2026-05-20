const mongoose = require('mongoose');

const routeScheduleSchema = new mongoose.Schema({
    route: { type: mongoose.Schema.Types.ObjectId, ref: 'Route', required: true },
    date: { type: String, required: true }, // Format: YYYY-MM-DD
    commonTime: { type: String },
    commonWasteTypes: { type: [String] },
    visitStatus: { type: String, enum: ['Pending', 'Visited'], default: 'Pending' },
    routeStatus: { type: String, enum: ['Pending', 'In Progress', 'Completed'], default: 'Pending' },
    visitedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    visitedAt: { type: Date },
    completedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    completedAt: { type: Date },
    assignments: [{
        house: { type: mongoose.Schema.Types.ObjectId, ref: 'House' },
        wasteTypes: [String],
        collectionTime: String
    }],
}, { timestamps: true });

module.exports = mongoose.model('RouteSchedule', routeScheduleSchema);
