const mongoose = require('mongoose');

const MonthlyWastePlanSchema = new mongoose.Schema({
    month: { type: Number, required: true, min: 1, max: 12 },
    year: { type: Number, required: true },
    wasteTypes: { type: [String], default: ['Plastic'] }
}, { timestamps: true });

MonthlyWastePlanSchema.index({ month: 1, year: 1 }, { unique: true });

module.exports = mongoose.model('MonthlyWastePlan', MonthlyWastePlanSchema);
