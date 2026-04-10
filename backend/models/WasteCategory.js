const mongoose = require('mongoose');

const WasteCategorySchema = new mongoose.Schema({
    name: { type: String, required: true, unique: true },
    description: { type: String },
    icon: { type: String } // Optional: icon name for UI
}, { timestamps: true });

module.exports = mongoose.model('WasteCategory', WasteCategorySchema);
