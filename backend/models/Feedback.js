const mongoose = require('mongoose');

const FeedbackSchema = new mongoose.Schema({
    residentId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    residentName: { type: String, required: true },
    houseNumber: { type: String, required: true },
    subject: { type: String, required: true },
    message: { type: String, required: true },
}, { timestamps: true });

module.exports = mongoose.model('Feedback', FeedbackSchema);
