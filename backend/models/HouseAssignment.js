const mongoose = require('mongoose');

const HouseAssignmentSchema = new mongoose.Schema({
    route: { type: mongoose.Schema.Types.ObjectId, ref: 'Route', required: true },
    house: { type: mongoose.Schema.Types.ObjectId, ref: 'House', required: true },
    houseNumber: { type: String, required: true }, // Added as requested for direct string lookup
    resident: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    residentName: { type: String }, // NEW: Added as requested
    address: { type: String },      // NEW: Added as requested
    staff: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    date: { type: String, required: true }, // Format: YYYY-MM-DD
    time: { type: String, required: true },
    wasteType: { type: String, required: true },
    status: { type: String, enum: ['Scheduled', 'Collected', 'Missed'], default: 'Scheduled' },
    
    // --- User Request: Availability and Payment tracking ---
    availabilityStatus: { type: String, enum: ['Available', 'Not Available', 'Pending'], default: 'Pending' },
    availabilityUpdatedAt: { type: Date },
    paymentStatus: { type: String, enum: ['Paid', 'Paid in Cash', 'Pending', 'Due', 'No Data'], default: 'Pending' },
    collectionStatus: { type: String, enum: ['Collected', 'Not Collected', 'Pending'], default: 'Pending' },
    visitStatus: { type: String, enum: ['Pending', 'Visited'], default: 'Pending' },
    visitedAt: { type: Date },
    transactionId: { type: String },
    amount: { type: Number },
    paymentMethod: { type: String },
    paymentMode: { type: String, enum: ['Online', 'Cash', 'Wallet', 'UPI'] },
    paymentDate: { type: Date },
    month: { type: String },
    paymentCollectedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    paidAt: { type: Date },
    proofPhotoUrl: { type: String },
    collectedAt: { type: Date }
}, { timestamps: true });

// Backward compatibility or alternate naming as requested by user
HouseAssignmentSchema.virtual('route_id').get(function() { return this.route; });
HouseAssignmentSchema.virtual('house_id').get(function() { return this.house; });
HouseAssignmentSchema.virtual('resident_id').get(function() { return this.resident; });
HouseAssignmentSchema.virtual('staff_id').get(function() { return this.staff; });
HouseAssignmentSchema.virtual('waste_type').get(function() { return this.wasteType; });

module.exports = mongoose.model('HouseAssignment', HouseAssignmentSchema);
