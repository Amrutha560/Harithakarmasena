const mongoose = require('mongoose');

const wardSchema = new mongoose.Schema({
    name: { type: String, required: true },
    wardNumber: { type: String, required: true, unique: true },
    description: { type: String },
    createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Ward', wardSchema);
