const express = require('express');
const router = express.Router();
const User = require('../models/User');
const WasteCategory = require('../models/WasteCategory');
const Schedule = require('../models/Schedule');
const Complaint = require('../models/Complaint');
const Payment = require('../models/Payment');
const Ward = require('../models/Ward');
const Route = require('../models/Route');
const House = require('../models/House');
const authMiddleware = require('../middleware/authMiddleware');

// ── User Management ─────────────────────────────────────────────────────────

// View all users
router.get('/users', authMiddleware(['admin']), async (req, res) => {
    try {
        const users = await User.find().select('-password -__v');
        res.json(users);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// View all staff
router.get('/staff', authMiddleware(['admin']), async (req, res) => {
    try {
        const staff = await User.find({ role: 'staff' }).select('-password -__v');
        res.json(staff);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// View Pending Staff (Deprecated logic, left empty array to prevent frontend crash if still calling)
router.get('/pending-staff', authMiddleware(['admin']), async (req, res) => {
    try {
        res.json([]);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Approve Staff member
router.put('/approve-staff/:id', authMiddleware(['admin']), async (req, res) => {
    try {
        const user = await User.findByIdAndUpdate(req.params.id, { isApproved: true }, { new: true });
        if (!user) return res.status(404).json({ message: 'User not found' });
        res.json({ message: 'Staff member approved successfully', user });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Delete a user
router.delete('/user/:id', authMiddleware(['admin']), async (req, res) => {
    try {
        await User.findByIdAndDelete(req.params.id);
        res.json({ message: 'User deleted successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Update a user
router.put('/user/:id', authMiddleware(['admin']), async (req, res) => {
    try {
        if (req.body.ward) {
            const wardObj = await Ward.findById(req.body.ward);
            if (wardObj && !req.body.wardNumber) {
                req.body.wardNumber = wardObj.wardNumber;
            }
        }
        const user = await User.findByIdAndUpdate(req.params.id, req.body, { new: true });
        if (!user) return res.status(404).json({ message: 'User not found' });
        res.json({ message: 'User updated successfully', user });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// ── Waste Categories ────────────────────────────────────────────────────────

// Add Category
router.post('/categories', authMiddleware(['admin']), async (req, res) => {
    const { name, description, icon } = req.body;
    try {
        const category = new WasteCategory({ name, description, icon });
        await category.save();
        res.status(201).json(category);
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// Get Categories
router.get('/categories', authMiddleware(['admin', 'resident', 'staff']), async (req, res) => {
    try {
        const categories = await WasteCategory.find();
        res.json(categories);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// ── Scheduling ──────────────────────────────────────────────────────────────

// Create Schedule (monthly waste type scheduling)
router.post('/schedules', authMiddleware(['admin']), async (req, res) => {
    const { date, month, year, wardNumber, category, assignedStaff, notes } = req.body;
    try {
        const scheduleDate = date ? new Date(date) : new Date();
        const schedMonth = month || (scheduleDate.getMonth() + 1);
        const schedYear = year || scheduleDate.getFullYear();

        const schedule = new Schedule({
            date: scheduleDate,
            month: schedMonth,
            year: schedYear,
            wardNumber,
            category,
            assignedStaff,
            notes
        });
        await schedule.save();
        const populated = await schedule.populate('category');
        res.status(201).json(populated);
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// View All Schedules
router.get('/schedules', authMiddleware(['admin', 'staff']), async (req, res) => {
    try {
        const schedules = await Schedule.find()
            .populate('category')
            .populate('assignedStaff', 'name email wardNumber')
            .sort({ date: -1 });
        res.json(schedules);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Get monthly schedules (for staff/admin to view this month's plan)
router.get('/schedules/monthly', authMiddleware(['admin', 'staff']), async (req, res) => {
    try {
        const now = new Date();
        const month = parseInt(req.query.month) || (now.getMonth() + 1);
        const year = parseInt(req.query.year) || now.getFullYear();
        const wardNumber = req.query.ward; // optional ward filter

        const filter = { month, year };
        if (wardNumber) filter.wardNumber = wardNumber;

        const schedules = await Schedule.find(filter)
            .populate('category')
            .populate('assignedStaff', 'name wardNumber')
            .sort({ date: 1 });
        res.json(schedules);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// ── Feedback Loop ───────────────────────────────────────────────────────────

// View all Complaints
router.get('/complaints', authMiddleware(['admin']), async (req, res) => {
    try {
        const complaints = await Complaint.find().populate('resident', 'name email houseName houseNumber address phoneNumber wardNumber');
        res.json(complaints);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Update Complaint Status
router.put('/complaints/:id', authMiddleware(['admin', 'staff']), async (req, res) => {
    const { status, remarks } = req.body;
    try {
        const complaint = await Complaint.findByIdAndUpdate(req.params.id, { status, remarks }, { new: true }).populate('resident');
        
        // Notify resident of the action taken
        if (complaint) {
            const resNotif = new Notification({
                resident: complaint.resident._id,
                title: `Complaint Update: ${status}`,
                message: `Status: ${status}. Admin Remarks: ${remarks || 'Reviewing issue.'}`,
                type: 'ServiceAlert'
            });
            await resNotif.save();
        }

        res.json(complaint);
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// ── Reporting ───────────────────────────────────────────────────────────────

// Payment History Report
router.get('/reports/payments', authMiddleware(['admin']), async (req, res) => {
    try {
        const payments = await Payment.find()
            .populate('resident', 'name wardNumber')
            .populate('staff', 'name')
            .sort({ createdAt: -1 });
        res.json(payments);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Basic Stats
router.get('/reports/stats', authMiddleware(['admin']), async (req, res) => {
    try {
        const totalUsers = await User.countDocuments();
        const totalResidents = await User.countDocuments({ role: 'resident' });
        const totalStaff = await User.countDocuments({ role: 'staff' });
        const pendingComplaints = await Complaint.countDocuments({ status: 'Pending' });
        const totalWards = await Ward.countDocuments();
        const totalRoutes = await Route.countDocuments();

        const totalRevenue = await Payment.aggregate([
            { $group: { _id: null, total: { $sum: "$amount" } } }
        ]);

        const CollectionLog = require('../models/CollectionLog');
        const nonCooperativeHouses = await CollectionLog.countDocuments({ status: 'Not Cooperative' });

        res.json({
            totalUsers,
            totalResidents,
            totalStaff,
            totalWards,
            totalRoutes,
            pendingComplaints,
            nonCooperativeHouses,
            totalRevenue: totalRevenue[0]?.total || 0
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// ── Ward & Route Management ─────────────────────────────────────────────────

// Add Ward
router.post('/wards', authMiddleware(['admin']), async (req, res) => {
    const { name, wardNumber, description } = req.body;
    try {
        const ward = new Ward({ name, wardNumber, description });
        await ward.save();
        res.status(201).json({ message: 'Ward created successfully', ward });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// Get Wards
router.get('/wards', authMiddleware(['admin', 'staff', 'resident']), async (req, res) => {
    try {
        const wards = await Ward.find().sort({ wardNumber: 1 });
        res.json(wards);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Delete Ward
router.delete('/wards/:id', authMiddleware(['admin']), async (req, res) => {
    try {
        const ward = await Ward.findByIdAndDelete(req.params.id);
        if (!ward) return res.status(404).json({ message: 'Ward not found' });
        res.json({ message: 'Ward deleted successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Add Route
router.post('/routes', authMiddleware(['admin']), async (req, res) => {
    const { name, ward, description, assignedStaff, collectionDays } = req.body;
    try {
        const route = new Route({ name, ward, description, assignedStaff, collectionDays });
        await route.save();
        
        // If staff is assigned during creation, update user's routeRef
        if (assignedStaff) {
            await User.findByIdAndUpdate(assignedStaff, { route: route._id, ward: ward });
        }

        const populated = await Route.findById(route._id).populate('ward').populate('assignedStaff', 'name email');
        res.status(201).json({ message: 'Route created successfully', route: populated });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// Get Routes
router.get('/routes', authMiddleware(['admin', 'staff', 'resident']), async (req, res) => {
    const { ward } = req.query; // Optional filter by ward ID
    const filter = ward ? { ward } : {};
    try {
        const routes = await Route.find(filter).populate('ward').populate('assignedStaff', 'name email');
        res.json(routes);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Delete Route
router.delete('/routes/:id', authMiddleware(['admin']), async (req, res) => {
    try {
        const route = await Route.findByIdAndDelete(req.params.id);
        if (!route) return res.status(404).json({ message: 'Route not found' });
        res.json({ message: 'Route deleted successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Update Route (Metadata & Schedule)
router.put('/routes/:id', authMiddleware(['admin']), async (req, res) => {
    const { name, description, collectionDays } = req.body;
    try {
        const route = await Route.findByIdAndUpdate(
            req.params.id, 
            { name, description, collectionDays },
            { new: true }
        ).populate('ward').populate('assignedStaff', 'name email');
        
        if (!route) return res.status(404).json({ message: 'Route not found' });
        res.json({ message: 'Route updated successfully', route });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// Update Route Assignment
router.put('/routes/:id/assign', authMiddleware(['admin']), async (req, res) => {
    const { staffId } = req.body;
    try {
        const route = await Route.findById(req.params.id);
        if (!route) return res.status(404).json({ message: 'Route not found' });

        // Remove route from previous staff if exists
        if (route.assignedStaff) {
            await User.findByIdAndUpdate(route.assignedStaff, { $unset: { route: "" } });
        }

        // Assign to new staff
        route.assignedStaff = staffId;
        await route.save();

        if (staffId) {
            await User.findByIdAndUpdate(staffId, { route: route._id, ward: route.ward });
        }

        const populated = await Route.findById(route._id).populate('ward').populate('assignedStaff', 'name email');
        res.json({ message: 'Route assigned successfully', route: populated });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// Bulk Add Houses to Route
router.post('/routes/:id/houses', authMiddleware(['admin']), async (req, res) => {
    const { houses } = req.body;
    const routeId = req.params.id;
    try {
        const route = await Route.findById(routeId).populate('ward');
        if (!route) return res.status(404).json({ message: 'Route not found' });

        const preparedHouses = houses.map(h => ({
            ownerName: h.name || h.ownerName,
            houseNumber: h.houseNumber,
            address: h.address || '',
            phoneNumber: h.phoneNumber || '',
            route: routeId,
            ward: route.ward?._id || null,
            wardNumber: route.ward?.wardNumber || '',
        }));

        const created = await House.insertMany(preparedHouses);
        res.status(201).json({ message: `${created.length} houses added to ${route.name}`, houses: created });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// View Houses in Route
router.get('/routes/:id/houses', authMiddleware(['admin', 'staff']), async (req, res) => {
    try {
        const houses = await House.find({ route: req.params.id }).sort({ houseNumber: 1 });
        res.json(houses);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Delete House
router.delete('/houses/:id', authMiddleware(['admin', 'staff']), async (req, res) => {
    try {
        await House.findByIdAndDelete(req.params.id);
        res.json({ message: 'House deleted successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

module.exports = router;
