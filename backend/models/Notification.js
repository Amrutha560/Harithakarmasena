const mongoose = require('mongoose');

const NotificationSchema = new mongoose.Schema({
    resident: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }, // Specific resident or null for global
    wardNumber: { type: String }, // For ward-wide notifications
    title: { type: String, required: true },
    message: { type: String, required: true },
    type: { type: String, enum: ['CollectionAlert', 'PaymentAlert', 'General'], default: 'General' },
    isRead: { type: Boolean, default: false }
}, { timestamps: true });

module.exports = mongoose.model('Notification', NotificationSchema);
