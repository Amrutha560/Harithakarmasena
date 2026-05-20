const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const User = require('../models/User');
const Schedule = require('../models/Schedule');
const CollectionLog = require('../models/CollectionLog');
const Payment = require('../models/Payment');
const Complaint = require('../models/Complaint');
const Route = require('../models/Route');
const RouteSchedule = require('../models/RouteSchedule');
const Ward = require('../models/Ward');
const HouseAssignment = require('../models/HouseAssignment');
const House = require('../models/House');
const MonthlyWastePlan = require('../models/MonthlyWastePlan');
const mongoose = require('mongoose');
const { getLocalToday } = require('../utils/dateUtils');

const REQUIRED_MONTHLY_WASTE_TYPE = 'Plastic';

const normalizeWasteTypes = (types = []) => {
    const list = Array.isArray(types) ? types : [types];
    const cleaned = list
        .flatMap(type => type?.toString().split(',') || [])
        .map(type => type.trim())
        .filter(Boolean)
        .map(type => type.toLowerCase().includes('plastic') ? REQUIRED_MONTHLY_WASTE_TYPE : type);
    const hasPlastic = cleaned.some(type => type.toLowerCase() === REQUIRED_MONTHLY_WASTE_TYPE.toLowerCase());
    const withRequired = hasPlastic ? cleaned : [REQUIRED_MONTHLY_WASTE_TYPE, ...cleaned];
    return [...new Map(withRequired.map(type => [type.toLowerCase(), type])).values()];
};

const getMonthKey = (dateValue = new Date()) => {
    const d = typeof dateValue === 'string' ? new Date(`${dateValue}T00:00:00`) : new Date(dateValue);
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    return `${year}-${month}`;
};

const monthlyWasteTypesForDate = async (dateValue = new Date()) => {
    const date = typeof dateValue === 'string' ? new Date(`${dateValue}T00:00:00`) : new Date(dateValue);
    const month = date.getMonth() + 1;
    const year = date.getFullYear();
    const plan = await MonthlyWastePlan.findOne({ month, year }).lean();
    return normalizeWasteTypes(plan?.wasteTypes || []);
};

const findManageableRouteForStaff = async (routeId, staffId) => {
    const staff = await User.findById(staffId).select('ward wardNumber');
    const route = await Route.findById(routeId).populate('ward');
    if (!route || !staff) return null;

    const directlyAssigned =
        route.assignedStaff?.toString() === staffId.toString();
    const sameWard =
        (staff.ward && route.ward?._id?.toString() === staff.ward.toString()) ||
        (staff.wardNumber &&
            route.ward?.wardNumber?.toString() === staff.wardNumber.toString());

    return directlyAssigned || sameWard ? route : null;
};

// ── Staff Dashboard Info ───────────────────────────────────────────────────
router.get('/dashboard', authMiddleware(['staff']), async (req, res) => {
    try {
        const staff = await User.findById(req.user.id).select('-password').populate('ward').populate('route');

        const now = new Date();
        const currentMonth = now.getMonth() + 1;
        const currentYear = now.getFullYear();
        const currentMonthlyWasteTypes = await monthlyWasteTypesForDate(now);

        // Monthly schedules for this staff's ward (or route)
        const monthlySchedulesRaw = await Schedule.find({
            wardNumber: staff.wardNumber,
            month: currentMonth,
            year: currentYear
        }).populate('category').sort({ date: 1 });
        let monthlySchedules = monthlySchedulesRaw.map(schedule => ({
            ...schedule.toObject(),
            wasteTypes: normalizeWasteTypes(schedule.wasteTypes?.length ? schedule.wasteTypes : [schedule.category?.name])
        }));
        if (monthlySchedules.length === 0) {
            monthlySchedules = [{
                month: currentMonth,
                year: currentYear,
                wasteTypes: currentMonthlyWasteTypes
            }];
        }

        // Today's schedules
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const tomorrow = new Date(today);
        tomorrow.setDate(tomorrow.getDate() + 1);

        const todaySchedules = await Schedule.find({
            wardNumber: staff.wardNumber,
            date: { $gte: today, $lt: tomorrow }
        }).populate('category');

        const todayStr = getLocalToday();

        // 1) Routes directly assigned to this staff member
        const directRoutes = await Route.find({ assignedStaff: req.user.id }).populate('ward').lean();
        const directRouteIds = directRoutes.map(r => r._id.toString());

        // 2) Routes scheduled for today in the staff's ward
        const todaySchedules2 = await RouteSchedule.find({ date: todayStr }).populate({
            path: 'route',
            populate: { path: 'ward' }
        });
        const scheduledRoutesForToday = todaySchedules2
            .map(s => s.route)
            .filter(r => r && r.ward && staff.ward && r.ward._id.toString() === staff.ward._id.toString() && !directRouteIds.includes(r._id.toString()));

        // Merge both lists (deduplicated)
        const allRoutesRaw = [...directRoutes, ...scheduledRoutesForToday];
        const monthPlanCache = new Map();
        const allRoutes = [];
        for (const route of allRoutesRaw) {
            const routeDate = route.startDate || route.endDate || now;
            const monthKey = getMonthKey(routeDate);
            if (!monthPlanCache.has(monthKey)) {
                monthPlanCache.set(monthKey, await monthlyWasteTypesForDate(routeDate));
            }
            allRoutes.push({
                ...(route.toObject?.() || route),
                scheduleMonthKey: monthKey,
                monthlyWasteTypes: monthPlanCache.get(monthKey)
            });
        }

        const HouseAssignment = require('../models/HouseAssignment');
        const houseAssignments = await HouseAssignment.find({
            route: { $in: allRoutes.map(r => r._id) },
            date: todayStr
        }).populate('house').populate('resident');

        res.json({
            user: staff,
            routes: allRoutes,
            schedules: todaySchedules,
            monthlySchedules: monthlySchedules,
            monthlyWasteTypes: currentMonthlyWasteTypes,
            houseAssignments, // Added for individual house status
            currentMonth,
            currentYear
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// ── Daily Operations ────────────────────────────────────────────────────────

// View residents in a specific ward or assigned route (for today's collection)
router.get('/residents/:wardNumber', authMiddleware(['staff']), async (req, res) => {
    try {
        const staff = await User.findById(req.user.id);
        
        let query = { role: 'resident' };
        if (staff.route) {
            query.route = staff.route;
        } else {
            query.wardNumber = req.params.wardNumber;
        }

        const residents = await User.find(query).select('-password');
        
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const enhancedResidents = await Promise.all(residents.map(async (r) => {
            // Check if resident paid today
            const paidToday = await Payment.findOne({ 
                resident: r._id, 
                createdAt: { $gte: today } 
            });
            // Check current collection status for today
            const collectionLog = await CollectionLog.findOne({
                resident: r._id,
                createdAt: { $gte: today }
            });

            return {
                ...r.toObject(),
                hasPaid: !!paidToday,
                collectionStatus: collectionLog ? collectionLog.status : 'Pending',
                residentResponse: collectionLog ? collectionLog.residentResponse : 'Pending'
            };
        }));

        res.json(enhancedResidents);
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// View all registered residents under staff's assigned routes
router.get('/assigned-residents', authMiddleware(['staff']), async (req, res) => {
    try {
        const staff = await User.findById(req.user.id);
        const routes = await Route.find({ assignedStaff: req.user.id });
        const routeIds = routes.map(r => r._id);

        const residents = await User.find({ 
            role: 'resident',
            route: { $in: routeIds }
        }).select('firstName lastName houseNumber address phoneNumber route');

        res.json(residents);
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// Mark Collection Status
router.post('/mark-collection', authMiddleware(['staff']), async (req, res) => {
    const { residentId, houseId, assignmentId, routeId, status, weight, notes, proofImageUrl, amountPaid, paymentMethod, date } = req.body;
    try {
        const scheduleDate = date || getLocalToday();
        const normalizedStatus = status === 'Skipped' ? 'Not Collected' : status;
        let assignment = null;

        if (assignmentId) {
            assignment = await HouseAssignment.findById(assignmentId);
        }
        if (!assignment && houseId) {
            assignment = await HouseAssignment.findOne({ house: houseId, route: routeId, date: scheduleDate });
        }

        const House = require('../models/House');
        const house = houseId ? await House.findById(houseId) : null;
        const resolvedResidentId = residentId || assignment?.resident || house?.resident || null;

        const collectedAt = normalizedStatus === 'Collected' ? new Date() : null;
        const log = new CollectionLog({
            resident: resolvedResidentId,
            house: assignment?.house || houseId,
            route: routeId,
            staff: req.user.id,
            status: normalizedStatus,
            weight,
            notes,
            proofImageUrl,
            proofPhotoUrl: proofImageUrl,
            amountPaid,
            paymentMethod,
            date: scheduleDate,
            time: assignment?.time,
            month: getMonthKey(scheduleDate),
            wasteType: assignment?.wasteType
        });
        await log.save();

        // Also update HouseAssignment (Schedule) record
        if (assignment) {
            assignment.collectionStatus = normalizedStatus;
            assignment.proofPhotoUrl = proofImageUrl;
            if (collectedAt) assignment.collectedAt = collectedAt;
            assignment.staff = req.user.id;
            assignment.visitStatus = 'Visited';
            assignment.visitedAt = new Date();
            if (resolvedResidentId && !assignment.resident) assignment.resident = resolvedResidentId;
            await assignment.save();
        } else if (houseId) {
            await HouseAssignment.findOneAndUpdate(
                { house: houseId, route: routeId, date: scheduleDate },
                {
                    collectionStatus: normalizedStatus,
                    proofPhotoUrl: proofImageUrl,
                    ...(collectedAt ? { collectedAt } : {}),
                    staff: req.user.id,
                    visitStatus: 'Visited',
                    visitedAt: new Date()
                }
            );
        }

        // ── Refund Logic (Staff Issue) ────────────────
        if (normalizedStatus === 'Not Collected' && resolvedResidentId) {
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            
            // Check if user paid today via wallet
            const payment = await Payment.findOne({ 
                resident: resolvedResidentId, 
                createdAt: { $gte: today },
                status: 'Success',
                method: 'Wallet'
            });

            if (payment) {
                // Refund to wallet
                await User.findByIdAndUpdate(resolvedResidentId, { $inc: { walletBalance: 50 } });
                
                // Update payment status
                payment.status = 'Refunded';
                await payment.save();

                // Notify User
                const Notification = require('../models/Notification');
                await new Notification({
                    resident: resolvedResidentId,
                    title: 'Refund Processed',
                    message: `₹50 refunded to your wallet as collection was Not Completed by our staff.`,
                    type: 'RefundAlert'
                }).save();
            }
        }
        // ───────────────────────────────

        res.status(201).json({ message: 'Collection status updated', log });
    } catch (error) {
        console.error('Error marking collection:', error);
        res.status(500).json({ message: 'Server error' });
    }
});


router.post('/routes/:routeId/visit', authMiddleware(['staff']), async (req, res) => {
    const { date } = req.body;
    const routeId = req.params.routeId;
    const visitDate = date || getLocalToday();
    try {
        const route = await findManageableRouteForStaff(routeId, req.user.id);
        if (!route) return res.status(403).json({ message: 'Route is not assigned to this staff member or ward' });

        if (route.startDate && route.endDate) {
            const startKey = route.startDate.toISOString().split('T')[0];
            const endKey = route.endDate.toISOString().split('T')[0];
            if (visitDate < startKey || visitDate > endKey) {
                return res.status(400).json({ message: 'Visit date must be inside the admin assigned date range' });
            }
        }

        const schedule = await RouteSchedule.findOneAndUpdate(
            { route: routeId, date: visitDate },
            { visitStatus: 'Visited', routeStatus: 'In Progress', visitedBy: req.user.id, visitedAt: new Date() },
            { new: true, upsert: true, setDefaultsOnInsert: true }
        );

        route.routeStatus = 'In Progress';
        await route.save();

        await HouseAssignment.updateMany(
            { route: routeId, date: visitDate },
            { visitStatus: 'Visited', staff: req.user.id, visitedAt: new Date() }
        );

        const Notification = require('../models/Notification');
        const displayDate = new Date(`${visitDate}T00:00:00`).toLocaleDateString('en-IN', {
            day: '2-digit',
            month: 'short',
            year: 'numeric'
        });
        const message = `Staff will visit ${route.name} on ${displayDate} for waste collection.`;
        const wardNumber = route.ward?.wardNumber?.toString();
        if (wardNumber) {
            await Notification.findOneAndUpdate(
                {
                    wardNumber,
                    title: 'Staff Visit Date Marked',
                    message
                },
                {
                    wardNumber,
                    title: 'Staff Visit Date Marked',
                    message,
                    type: 'CollectionAlert',
                    isRead: false
                },
                { upsert: true, new: true, setDefaultsOnInsert: true }
            );
        }

        const residentIds = new Set();
        const routeResidents = await User.find({ role: 'resident', route: routeId }).select('_id');
        routeResidents.forEach((resident) => residentIds.add(resident._id.toString()));

        const routeHouses = await House.find({ route: routeId }).select('resident');
        routeHouses.forEach((house) => {
            if (house.resident) residentIds.add(house.resident.toString());
        });

        const routeAssignments = await HouseAssignment.find({ route: routeId, date: visitDate }).select('resident');
        routeAssignments.forEach((assignment) => {
            if (assignment.resident) residentIds.add(assignment.resident.toString());
        });

        await Promise.all([...residentIds].map((residentId) => Notification.findOneAndUpdate(
            {
                resident: residentId,
                title: 'Staff Visit Date Marked',
                message
            },
            {
                resident: residentId,
                title: 'Staff Visit Date Marked',
                message,
                type: 'CollectionAlert',
                isRead: false
            },
            { upsert: true, new: true, setDefaultsOnInsert: true }
        )));

        res.json({ message: 'Route marked as visited and residents notified', schedule });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

router.post('/routes/:routeId/unvisit', authMiddleware(['staff']), async (req, res) => {
    const { date } = req.body;
    const routeId = req.params.routeId;
    const visitDate = date || getLocalToday();
    try {
        const route = await findManageableRouteForStaff(routeId, req.user.id);
        if (!route) return res.status(403).json({ message: 'Route is not assigned to this staff member or ward' });

        const completedSchedule = await RouteSchedule.findOne({
            route: routeId,
            date: visitDate,
            routeStatus: 'Completed'
        });
        if (completedSchedule) {
            return res.status(400).json({ message: 'Completed visit dates cannot be removed' });
        }

        const schedule = await RouteSchedule.findOneAndUpdate(
            { route: routeId, date: visitDate },
            {
                $set: {
                    visitStatus: 'Pending',
                    routeStatus: 'Pending'
                },
                $unset: { visitedBy: '', visitedAt: '' }
            },
            { new: true }
        );

        await HouseAssignment.updateMany(
            { route: routeId, date: visitDate },
            {
                $set: { visitStatus: 'Pending' },
                $unset: { staff: '', visitedAt: '' }
            }
        );

        const remainingVisited = await RouteSchedule.exists({
            route: routeId,
            visitStatus: 'Visited'
        });
        if (!remainingVisited) {
            route.routeStatus = 'Pending';
            await route.save();
        }

        const Notification = require('../models/Notification');
        const displayDate = new Date(`${visitDate}T00:00:00`).toLocaleDateString('en-IN', {
            day: '2-digit',
            month: 'short',
            year: 'numeric'
        });
        const message = `Staff will visit ${route.name} on ${displayDate} for waste collection.`;
        await Notification.deleteMany({
            title: 'Staff Visit Date Marked',
            message
        });

        res.json({ message: 'Route visit date removed', schedule });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});


// Notify Resident about schedule
router.post('/notify-resident', authMiddleware(['staff']), async (req, res) => {
    const { houseId, date, time, wasteType } = req.body;
    try {
        const house = await require('../models/House').findById(houseId).populate('resident');
        if (!house || !house.resident) {
            return res.status(404).json({ message: 'House or resident not found' });
        }
        
        const Notification = require('../models/Notification');
        await new Notification({
            resident: house.resident._id,
            title: 'Collection Scheduled',
            message: `Your solid waste collection is scheduled on ${date} at ${time}. Waste types: ${wasteType}. Please let us know if you are available.`,
            type: 'CollectionAlert'
        }).save();

        res.json({ message: 'Notification sent to resident' });
    } catch (error) {
        console.error('Error sending notification:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// ── Payment Verification ────────────────────────────────────────────────────

// Record Payment (Cash or UPI)
router.post('/record-payment', authMiddleware(['staff']), async (req, res) => {
    const { residentId, amount, method, transactionId, assignmentId, houseId, routeId, date } = req.body;
    try {
        let assignment = null;
        if (assignmentId) {
            assignment = await HouseAssignment.findById(assignmentId);
        }
        if (!assignment && houseId && routeId) {
            assignment = await HouseAssignment.findOne({ house: houseId, route: routeId, date: date || getLocalToday() });
        }

        const resolvedResidentId = residentId || assignment?.resident;
        if (!resolvedResidentId) {
            return res.status(400).json({ message: 'Resident not found for this payment' });
        }

        const paidAt = new Date();
        const mode = method === 'Cash' || !method ? 'Cash' : 'Online';
        const payment = new Payment({
            resident: resolvedResidentId,
            staff: req.user.id,
            route: routeId || assignment?.route,
            house: houseId || assignment?.house,
            assignment: assignment?._id,
            amount: amount || 50,
            method: method || 'Cash',
            transactionId,
            status: 'Success',
            paymentMode: mode,
            paymentStatus: 'Paid',
            paymentCollectedBy: req.user.id,
            paymentDate: paidAt,
            month: getMonthKey(date || paidAt)
        });
        await payment.save();

        if (assignment) {
            assignment.paymentStatus = 'Paid';
            assignment.paymentMethod = method || 'Cash';
            assignment.paymentMode = mode;
            assignment.amount = amount || 50;
            assignment.paymentCollectedBy = req.user.id;
            assignment.paymentDate = paidAt;
            assignment.month = getMonthKey(date || paidAt);
            assignment.paidAt = paidAt;
            await assignment.save();
        }

        res.status(201).json({ message: 'Payment recorded successfully', payment });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// View Resident Payment History (Local)
router.get('/resident-payments/:residentId', authMiddleware(['staff']), async (req, res) => {
    try {
        const payments = await Payment.find({ resident: req.params.residentId }).sort({ createdAt: -1 });
        res.json(payments);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

router.post('/routes/:routeId/complete', authMiddleware(['staff']), async (req, res) => {
    const routeId = req.params.routeId;
    const completeDate = req.body.date || getLocalToday();
    try {
        const route = await findManageableRouteForStaff(routeId, req.user.id);
        if (!route) return res.status(403).json({ message: 'Route is not assigned to this staff member or ward' });

        const assignments = await HouseAssignment.find({ route: routeId, date: completeDate });
        const total = assignments.length;
        const collected = assignments.filter(a => a.collectionStatus === 'Collected').length;
        const handled = assignments.filter(a =>
            ['Collected', 'Not Collected'].includes(a.collectionStatus) ||
            a.availabilityStatus === 'Not Available'
        ).length;
        const notCollected = Math.max(total - collected, 0);
        if (total > 0 && handled < total) {
            return res.status(400).json({
                message: `Handle all houses before completing this route (${handled}/${total} handled).`,
                total,
                collected,
                handled,
                notCollected
            });
        }
        const paidStatuses = ['Paid', 'Paid in Cash'];
        const paid = assignments.filter(a => paidStatuses.includes(a.paymentStatus)).length;
        const unpaid = Math.max(total - paid, 0);

        await RouteSchedule.findOneAndUpdate(
            { route: routeId, date: completeDate },
            {
                routeStatus: 'Completed',
                visitStatus: 'Visited',
                visitedBy: req.user.id,
                visitedAt: new Date(),
                completedBy: req.user.id,
                completedAt: new Date()
            },
            { new: true, upsert: true, setDefaultsOnInsert: true }
        );

        route.routeStatus = 'Completed';
        route.completedBy = req.user.id;
        route.completedAt = new Date();
        await route.save();

        const admins = await User.find({ role: 'admin' }).select('_id');
        const routeLabel = route.name || 'Route';
        const reportMessage = `${routeLabel} finished on ${completeDate}. Collected ${collected}/${total} houses. Paid: ${paid}, Due: ${unpaid}.`;
        await Promise.all(admins.map(admin => Notification.findOneAndUpdate(
            {
                resident: admin._id,
                title: 'Route Completion Report',
                message: reportMessage
            },
            {
                resident: admin._id,
                title: 'Route Completion Report',
                message: reportMessage,
                type: 'General',
                isRead: false
            },
            { upsert: true, new: true, setDefaultsOnInsert: true }
        )));

        res.json({
            message: 'Route finished and report sent to admin',
            total,
            collected,
            handled,
            notCollected,
            paid,
            unpaid
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

const Notification = require('../models/Notification');

// ── Communication ───────────────────────────────────────────────────────────

// Send notification to a ward
router.post('/notify-ward', authMiddleware(['staff']), async (req, res) => {
    const { message, wardNumber } = req.body;
    try {
        const notif = new Notification({
            wardNumber,
            title: 'Collection Alert',
            message: message || `Waste collection is starting in Ward ${wardNumber}. Please keep your waste outside.`,
            type: 'CollectionAlert'
        });
        await notif.save();
        res.json({ message: 'Residents notified successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// View complaints in staff's ward
router.get('/complaints', authMiddleware(['staff']), async (req, res) => {
    try {
        const staff = await User.findById(req.user.id);
        const complaints = await Complaint.find({ wardNumber: staff.wardNumber }).populate('resident', 'name address');
        res.json(complaints);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// View daily collection report
router.get('/daily-report', authMiddleware(['staff']), async (req, res) => {
    try {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const tomorrow = new Date(today);
        tomorrow.setDate(tomorrow.getDate() + 1);

        const staff = await User.findById(req.user.id);

        const logs = await CollectionLog.find({ 
            staff: req.user.id,
            createdAt: { $gte: today, $lt: tomorrow }
        }).populate('resident', 'name houseNumber wardNumber');

        const totalCollected = logs.filter(l => l.status === 'Collected').length;
        const totalNotCollected = logs.filter(l => l.status === 'Not Collected').length;
        const totalNotCooperative = logs.filter(l => l.status === 'Not Cooperative').length;

        const payments = await Payment.find({
            staff: req.user.id,
            createdAt: { $gte: today, $lt: tomorrow }
        });

        const totalAmount = payments.reduce((sum, p) => sum + p.amount, 0);

        res.json({
            date: today,
            logs,
            stats: {
                totalHouses: logs.length,
                totalCollected,
                totalNotCollected,
                totalNotCooperative,
                totalRevenue: totalAmount
            }
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

module.exports = router;
