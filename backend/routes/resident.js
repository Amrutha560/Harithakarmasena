const express = require('express');
const router = express.Router();
const RouteSchedule = require('../models/RouteSchedule');
const HouseAssignment = require('../models/HouseAssignment');
const House = require('../models/House');
const authMiddleware = require('../middleware/authMiddleware');
const { getLocalToday } = require('../utils/dateUtils');
const User = require('../models/User');
const Complaint = require('../models/Complaint');
const Payment = require('../models/Payment');
const Schedule = require('../models/Schedule');
const MonthlyWastePlan = require('../models/MonthlyWastePlan');

const Notification = require('../models/Notification');

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

const displayUserName = (user, fallback = 'Assigned staff') => {
    if (!user) return fallback;
    const fullName = `${user.firstName || ''} ${user.lastName || ''}`.trim();
    return user.name || fullName || user.email || fallback;
};

const buildReceipt = (payment) => {
    const resident = payment.resident || {};
    const assignment = payment.assignment || {};
    const route = payment.route || assignment.route || {};
    const house = payment.house || assignment.house || {};
    const paidAt = payment.paymentDate || payment.createdAt;
    const residentName = resident.name ||
        `${resident.firstName || ''} ${resident.lastName || ''}`.trim() ||
        assignment.residentName ||
        'Resident';

    return {
        receiptNo: `HKS-${payment._id.toString().slice(-8).toUpperCase()}`,
        paymentId: payment._id,
        residentName,
        phoneNumber: resident.phoneNumber || null,
        houseNumber: house.houseNumber || assignment.houseNumber || resident.houseNumber || null,
        address: house.address || assignment.address || resident.address || null,
        routeName: route.name || 'Route pending',
        wardNumber: resident.wardNumber || route.ward?.wardNumber || null,
        amount: payment.amount,
        mode: payment.paymentMode || (payment.method === 'Razorpay' ? 'Online' : payment.method),
        status: payment.paymentStatus || (payment.status === 'Success' ? 'Paid' : payment.status),
        transactionId: payment.transactionId || null,
        month: payment.month || assignment.month || getMonthKey(paidAt),
        paidAt,
        collectionDate: assignment.date || null,
        collectedBy: payment.paymentCollectedBy?.name || payment.staff?.name || null,
        organization: 'Harithakarmasena'
    };
};

// ── Resident Dashboard ─────────────────────────────────────────────────────
router.get('/dashboard', authMiddleware(['resident']), async (req, res) => {
    try {
        const resident = await User.findById(req.user.id).select('-password')
            .populate('ward')
            .populate({
                path: 'route',
                populate: { path: 'ward' }
            });
        const resolvedWardNumber = resident.wardNumber ||
            resident.ward?.wardNumber ||
            resident.route?.ward?.wardNumber ||
            null;
        console.log(`Fetching dashboard for Resident: ${resident.name} (Route: ${resident.route ? resident.route.name : 'NONE'})`);

        // --- User Request: Fetch individual schedules from HouseAssignment ---
        const HouseAssignment = require('../models/HouseAssignment');
        const todayDateStr = getLocalToday();
        
        // Find the master house record first
        const House = require('../models/House');
        const cleanHouseNum = resident.houseNumber ? resident.houseNumber.toString().trim() : '';
        const myHouse = (resident.house ? await House.findById(resident.house) : null) || 
                       await House.findOne({ houseNumber: cleanHouseNum, ward: resident.ward });

        const mySchedules = await HouseAssignment.find({ 
            $or: [
                { houseNumber: cleanHouseNum }, // Primary match
                { resident: req.user.id },
                { house: myHouse ? myHouse._id : null }
            ],
            date: { $gte: todayDateStr } 
        }).populate('route').populate('staff', 'name firstName lastName email').sort({ date: 1 });

        // Latest payment status
        const lastPayment = await Payment.findOne({ resident: req.user.id }).sort({ createdAt: -1 });

        // Latest notifications
        const notifications = await Notification.find({ 
            $or: [
                { resident: req.user.id },
                { wardNumber: resolvedWardNumber }
            ]
        }).sort({ createdAt: -1 }).limit(10);

        // Daily Collection Status
        const CollectionLog = require('../models/CollectionLog');
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const collectionStatus = await CollectionLog.findOne({
            resident: req.user.id,
            createdAt: { $gte: today }
        }).sort({ createdAt: -1 });

        const RouteSchedule = require('../models/RouteSchedule');
        let assignedDate = null;
        let assignedTime = null;
        let assignedWasteTypes = [];
        let routeName = null;

        const isDateInsideRouteRange = (date, route) => {
            if (!date || !route || !route.startDate || !route.endDate) return true;
            const visitDate = new Date(date);
            const start = new Date(route.startDate);
            const end = new Date(route.endDate);
            if (Number.isNaN(visitDate.getTime()) || Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) return true;
            visitDate.setHours(0, 0, 0, 0);
            start.setHours(0, 0, 0, 0);
            end.setHours(0, 0, 0, 0);
            return visitDate >= start && visitDate <= end;
        };
        
        console.log(`[DEBUG] Dashboard Linking: user="${resident.email}", houseNumber="${cleanHouseNum}"`);
        if (myHouse) {
            console.log(`[DEBUG] Dashboard Match Found: houseId=${myHouse._id}`);
            if (!myHouse.resident) {
                // Auto-link the login account to the master house record
                myHouse.resident = resident._id;
                await myHouse.save();
            }
        } else {
            console.log(`[DEBUG] Dashboard Match FAILED for houseNumber="${cleanHouseNum}"`);
        }

        // 2. Query Schedule (using HouseAssignment model as used by staff)
        console.log(`[DEBUG] Dashboard Fetch: User=${resident.name}, House Number=${cleanHouseNum}`);
        
        // Build query: match by houseNumber OR by resident ID (whichever links exist)
        const assignmentQuery = { date: { $gte: todayDateStr } };
        const orConditions = [];
        if (cleanHouseNum) orConditions.push({ houseNumber: cleanHouseNum });
        orConditions.push({ resident: req.user.id });
        if (myHouse) orConditions.push({ house: myHouse._id });
        assignmentQuery.$or = orConditions;

        // Find the next upcoming assignment for this resident
        let houseAssignment = await HouseAssignment.findOne(assignmentQuery)
            .populate('route').populate('staff', 'name firstName lastName email').sort({ date: 1 });

        if (!houseAssignment && cleanHouseNum) {
            // Fallback: most recent past assignment so the UI doesn't go blank
            houseAssignment = await HouseAssignment.findOne({
                $or: orConditions
            }).populate('route').populate('staff', 'name firstName lastName email').sort({ date: -1 });
        }

        if (houseAssignment) {
            console.log(`[DEBUG] DASHBOARD MATCH SUCCESS: Date=${houseAssignment.date}, Time=${houseAssignment.time}, Waste=${houseAssignment.wasteType}`);
            assignedDate = houseAssignment.date;
            assignedTime = houseAssignment.time;
            assignedWasteTypes = await monthlyWasteTypesForDate(houseAssignment.date);
            routeName = houseAssignment.route ? houseAssignment.route.name : 'Unassigned Route';
        } else {
            console.log(`[DEBUG] DASHBOARD MATCH FAILED for House ${cleanHouseNum}. Using fallbacks.`);
            assignedWasteTypes = await monthlyWasteTypesForDate();
        }

        let staffVisitDate = null;
        let staffVisitRouteName = routeName || (resident.route ? resident.route.name : null);
        let staffVisitDates = [];
        let staffVisitAssignment = await HouseAssignment.findOne({
            $or: orConditions,
            visitStatus: 'Visited',
            date: { $gte: todayDateStr }
        }).populate('route').populate('staff', 'name firstName lastName email').sort({ date: 1 });

        if (staffVisitAssignment && isDateInsideRouteRange(staffVisitAssignment.date, staffVisitAssignment.route)) {
            staffVisitDate = staffVisitAssignment.date;
            staffVisitRouteName = staffVisitAssignment.route ? staffVisitAssignment.route.name : staffVisitRouteName;
        } else if (resident.route) {
            const staffVisitSchedule = await RouteSchedule.findOne({
                route: resident.route._id,
                visitStatus: 'Visited',
                date: { $gte: todayDateStr }
            }).populate('route').sort({ date: 1 });

            if (staffVisitSchedule && isDateInsideRouteRange(staffVisitSchedule.date, staffVisitSchedule.route)) {
                staffVisitDate = staffVisitSchedule.date;
                staffVisitRouteName = staffVisitSchedule.route ? staffVisitSchedule.route.name : staffVisitRouteName;
            }
        }

        const routeIdsForVisitLookup = new Set();
        if (resident.route?._id) routeIdsForVisitLookup.add(resident.route._id.toString());
        if (houseAssignment?.route?._id) routeIdsForVisitLookup.add(houseAssignment.route._id.toString());
        if (staffVisitAssignment?.route?._id) routeIdsForVisitLookup.add(staffVisitAssignment.route._id.toString());

        const visitedAssignments = await HouseAssignment.find({
            $or: orConditions,
            visitStatus: 'Visited'
        }).populate('route').populate('staff', 'name firstName lastName email').sort({ date: 1 });

        for (const assignment of visitedAssignments) {
            const assignmentRouteId = assignment.route?._id || assignment.route;
            const confirmedVisit = assignmentRouteId && assignment.date
                ? await RouteSchedule.findOne({
                    route: assignmentRouteId,
                    date: assignment.date,
                    visitStatus: 'Visited'
                }).lean()
                : null;

            if (confirmedVisit && assignment.date && isDateInsideRouteRange(assignment.date, assignment.route)) {
                staffVisitDates.push({
                    date: assignment.date,
                    routeName: assignment.route ? assignment.route.name : staffVisitRouteName,
                    staffName: displayUserName(assignment.staff),
                    wasteTypes: await monthlyWasteTypesForDate(assignment.date)
                });
            }
            if (assignment.route?._id) routeIdsForVisitLookup.add(assignment.route._id.toString());
        }

        if (routeIdsForVisitLookup.size > 0) {
            const visitedRouteSchedules = await RouteSchedule.find({
                route: { $in: [...routeIdsForVisitLookup] },
                visitStatus: 'Visited'
            }).populate('route').sort({ date: 1 });

            for (const schedule of visitedRouteSchedules) {
                if (schedule.date && isDateInsideRouteRange(schedule.date, schedule.route)) {
                    staffVisitDates.push({
                        date: schedule.date,
                        routeName: schedule.route ? schedule.route.name : staffVisitRouteName,
                        wasteTypes: await monthlyWasteTypesForDate(schedule.date)
                    });
                }
            }
        }

        const seenVisitDates = new Set();
        staffVisitDates = staffVisitDates.filter((visit) => {
            const key = `${visit.date}-${visit.routeName || ''}`;
            if (seenVisitDates.has(key)) return false;
            seenVisitDates.add(key);
            return true;
        });

        staffVisitDate = null;
        if (staffVisitDates.length > 0) {
            staffVisitDate = staffVisitDates[0].date;
            staffVisitRouteName = staffVisitDates[0].routeName || staffVisitRouteName;
        }

        const resolvedName = (resident.name && resident.name.toLowerCase() !== 'resident' && resident.name.trim() !== '') 
            ? resident.name 
            : (myHouse && myHouse.ownerName && myHouse.ownerName.toLowerCase() !== 'resident' ? myHouse.ownerName : (resident.phoneNumber || resident.email.split('@')[0] || 'Resident'));

        console.log(`[DEBUG] Dashboard resolvedName for ${resident.phoneNumber}: "${resolvedName}"`);
        
        const responseData = {
            user: resident,
            residentName: resolvedName,
            houseNumber: houseAssignment ? houseAssignment.houseNumber : cleanHouseNum,
            address: houseAssignment ? houseAssignment.address : resident.address,
            schedules: mySchedules,
            assignedDays: resident.route ? resident.route.collectionDays : [],
            lastPayment,
            notifications,
            collectionStatus: collectionStatus ? collectionStatus.status : 'Pending',
            residentResponse: collectionStatus ? collectionStatus.residentResponse : 'Pending',
            walletBalance: resident.walletBalance || 0,
            assignedDate,
            assignedTime,
            assignedWasteTypes,
            routeName: routeName || (resident.route ? resident.route.name : null),
            wardNumber: resolvedWardNumber,
            staffVisitDate,
            staffVisitDates,
            staffVisitRouteName,
            scheduleId: houseAssignment ? houseAssignment._id : null,
            paymentStatus: houseAssignment ? houseAssignment.paymentStatus || 'Pending' : 'No Data'
        };

        res.json(responseData);
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// ── Wallet Management ───────────────────────────────────────────────────────

router.put('/profile', authMiddleware(['resident']), async (req, res) => {
    try {
        const allowedFields = [
            'firstName',
            'lastName',
            'phoneNumber',
            'houseNumber',
            'address',
            'district',
            'lsgiType',
            'lsgiName'
        ];

        const update = {};
        for (const field of allowedFields) {
            if (req.body[field] !== undefined) {
                update[field] = req.body[field]?.toString().trim() || '';
            }
        }

        if (update.firstName !== undefined && update.firstName.length === 0) {
            return res.status(400).json({ message: 'First name is required' });
        }

        if (update.phoneNumber && !/^\d{10}$/.test(update.phoneNumber)) {
            return res.status(400).json({ message: 'Phone number must be 10 digits' });
        }

        if (update.houseNumber && !/^\d{1,3}$/.test(update.houseNumber)) {
            return res.status(400).json({ message: 'House number must be 1 to 3 digits' });
        }

        const resident = await User.findByIdAndUpdate(
            req.user.id,
            { $set: update },
            { new: true }
        ).select('-password').populate('ward').populate('route').populate('house');

        if (!resident) {
            return res.status(404).json({ message: 'Resident not found' });
        }

        const fullName = `${resident.firstName || ''} ${resident.lastName || ''}`.trim();
        if (resident.house?._id) {
            await House.findByIdAndUpdate(resident.house._id, {
                ownerName: fullName || 'Resident',
                houseNumber: resident.houseNumber,
                address: resident.address,
                phoneNumber: resident.phoneNumber
            });
        }

        await HouseAssignment.updateMany(
            { resident: resident._id },
            {
                $set: {
                    residentName: fullName || 'Resident',
                    houseNumber: resident.houseNumber,
                    address: resident.address
                }
            }
        );

        res.json({ message: 'Profile updated successfully', user: resident });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// Add money to wallet
router.post('/wallet/add', authMiddleware(['resident']), async (req, res) => {
    const { amount } = req.body;
    try {
        const user = await User.findByIdAndUpdate(req.user.id, { $inc: { walletBalance: amount } }, { new: true });
        res.json({ message: 'Wallet updated successfully', balance: user.walletBalance });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Pay ₹50 from wallet
router.post('/wallet/pay', authMiddleware(['resident']), async (req, res) => {
    const amount = 50;
    try {
        const user = await User.findById(req.user.id);
        if (user.walletBalance < amount) {
            return res.status(400).json({ message: 'Insufficient wallet balance. Please top up.' });
        }

        user.walletBalance -= amount;
        await user.save();

        const payment = new Payment({
            resident: req.user.id,
            amount,
            method: 'Wallet',
            status: 'Success'
        });
        await payment.save();

        // --- User Request: Sync paymentStatus to HouseAssignment ---
        const HouseAssignment = require('../models/HouseAssignment');
        const todayDateStr = getLocalToday();
        const cleanHouseNum = user.houseNumber ? user.houseNumber.toString().trim() : '';
        
        await HouseAssignment.findOneAndUpdate(
            { houseNumber: cleanHouseNum, date: { $gte: todayDateStr } },
            { paymentStatus: 'Paid' },
            { sort: { date: 1 } }
        );

        res.json({ message: 'Payment successful', balance: user.walletBalance, payment });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// ── Notifications ───────────────────────────────────────────────────────────

router.get('/notifications', authMiddleware(['resident']), async (req, res) => {
    try {
        const user = await User.findById(req.user.id).populate('ward').populate({
            path: 'route',
            populate: { path: 'ward' }
        });
        const resolvedWardNumber = user.wardNumber ||
            user.ward?.wardNumber ||
            user.route?.ward?.wardNumber ||
            null;
        const notifications = await Notification.find({ 
            $or: [
                { resident: req.user.id },
                { wardNumber: resolvedWardNumber }
            ]
        }).sort({ createdAt: -1 });
        res.json(notifications);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Respond to Collection Schedule
router.post('/collection-response', authMiddleware(['resident']), async (req, res) => {
    const { response, date } = req.body; // 'Available' or 'Not Available'
    try {
        if (!['Available', 'Not Available', 'Pending'].includes(response)) {
            return res.status(400).json({ message: 'Invalid availability response' });
        }

        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const CollectionLog = require('../models/CollectionLog');
        const resident = await User.findById(req.user.id).populate('route');
        
        const House = require('../models/House');
        const houseObj = await House.findOne({ resident: req.user.id }) || await House.findOne({ houseNumber: resident.houseNumber, wardNumber: resident.wardNumber });

        let collectionLog = await CollectionLog.findOne({
            resident: req.user.id,
            createdAt: { $gte: today }
        });

        if (collectionLog) {
            collectionLog.residentResponse = response;
            if (houseObj) collectionLog.house = houseObj._id;
            await collectionLog.save();
        } else {
            // Find assigned staff for this resident's route
            let assignedStaffId = req.user.id; // fallback
            if (resident.route && resident.route.assignedStaff) {
                assignedStaffId = resident.route.assignedStaff;
            }

            collectionLog = new CollectionLog({
                resident: req.user.id,
                house: houseObj?._id,
                route: resident.route?._id,
                staff: assignedStaffId,
                status: 'Pending',
                residentResponse: response
            });
            await collectionLog.save();
        }

        // --- User Request: Update HouseAssignment record ---
        const HouseAssignment = require('../models/HouseAssignment');
        const todayDateStr = date || getLocalToday();
        const cleanHouseNum = resident.houseNumber ? resident.houseNumber.toString().trim() : '';
        
        console.log(`[DEBUG] Updating Availability: House=${cleanHouseNum}, Date=${todayDateStr}, Status=${response}`);
        
        const assignmentUpdate = { 
            availabilityStatus: response,
            availabilityUpdatedAt: new Date(),
            resident: resident._id,
            residentName: resident.name
        };

        const assignmentMatch = {
            date: todayDateStr,
            $or: [
                { resident: resident._id },
                { houseNumber: cleanHouseNum },
            ]
        };
        if (resident.route?._id) {
            assignmentMatch.route = resident.route._id;
        }
        if (houseObj?._id) {
            assignmentMatch.$or.push({ house: houseObj._id });
        }

        const assignment = await HouseAssignment.findOneAndUpdate(
            assignmentMatch,
            assignmentUpdate,
            { new: true }
        );

        if (assignment && response !== 'Pending') {
            const paidStatuses = ['Paid', 'Paid in Cash'];
            if (!paidStatuses.includes(assignment.paymentStatus)) {
                assignment.paymentStatus = 'Due';
                await assignment.save();
            }

            await Payment.findOneAndUpdate(
                {
                    resident: resident._id,
                    assignment: assignment._id,
                    status: { $in: ['Due', 'Pending'] },
                },
                {
                    resident: resident._id,
                    route: assignment.route,
                    house: assignment.house,
                    assignment: assignment._id,
                    amount: 50,
                    method: 'Online',
                    status: 'Due',
                    paymentMode: 'Online',
                    paymentStatus: 'Due',
                    month: getMonthKey(assignment.date)
                },
                { upsert: true, new: true, setDefaultsOnInsert: true }
            );
        }

        res.json({ 
            message: 'Response recorded successfully', 
            log: collectionLog,
            assignment: assignment 
        });
    } catch (error) {
        console.error('Error recording response:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

router.post('/payment-choice', authMiddleware(['resident']), async (req, res) => {
    const { assignmentId, date, mode } = req.body;
    try {
        if (!['Cash', 'Due'].includes(mode)) {
            return res.status(400).json({ message: 'Only Cash or Due payment choices are supported here' });
        }

        const HouseAssignment = require('../models/HouseAssignment');
        const resident = await User.findById(req.user.id);
        const cleanHouseNum = resident.houseNumber ? resident.houseNumber.toString().trim() : '';
        const assignment = assignmentId
            ? await HouseAssignment.findOne({
                _id: assignmentId,
                $or: [
                    { resident: req.user.id },
                    { houseNumber: cleanHouseNum }
                ]
            })
            : await HouseAssignment.findOne({
                date: date || getLocalToday(),
                $or: [
                    { resident: req.user.id },
                    { houseNumber: cleanHouseNum }
                ]
            });

        if (!assignment) {
            return res.status(404).json({ message: 'Schedule record not found' });
        }

        if (!['Paid', 'Paid in Cash'].includes(assignment.paymentStatus)) {
            assignment.paymentStatus = mode === 'Due' ? 'Due' : 'Pending';
            assignment.paymentMode = mode === 'Due' ? 'Online' : 'Cash';
            assignment.paymentMethod = mode === 'Due' ? 'Online' : 'Cash';
            assignment.amount = 50;
            assignment.month = getMonthKey(assignment.date);
            await assignment.save();
        }

        const isDue = mode === 'Due';
        const payment = await Payment.findOneAndUpdate(
            { resident: req.user.id, assignment: assignment._id, paymentStatus: { $in: ['Pending', 'Due'] } },
            {
                resident: req.user.id,
                route: assignment.route,
                house: assignment.house,
                assignment: assignment._id,
                amount: 50,
                method: isDue ? 'Online' : 'Cash',
                status: isDue ? 'Due' : 'Pending',
                paymentMode: isDue ? 'Online' : 'Cash',
                paymentStatus: isDue ? 'Due' : 'Pending',
                month: getMonthKey(assignment.date)
            },
            { upsert: true, new: true, setDefaultsOnInsert: true }
        );

        res.json({
            message: isDue ? 'Payment marked due' : 'Cash payment marked pending',
            assignment,
            payment
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// Update Collection Feedback (Resident confirms if collected)
router.post('/collection-feedback', authMiddleware(['resident']), async (req, res) => {
    const { status } = req.body; // 'Collected', 'Not Collected', 'Not Cooperative'
    try {
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const CollectionLog = require('../models/CollectionLog');
        const log = await CollectionLog.findOne({
            resident: req.user.id,
            createdAt: { $gte: today }
        });

        if (!log) {
            return res.status(404).json({ message: 'No collection activity found for today' });
        }

        log.residentFeedbackStatus = status;
        await log.save();

        res.json({ message: 'Feedback recorded', log });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// View my Collection History
router.get('/my-collection-history', authMiddleware(['resident']), async (req, res) => {
    try {
        const CollectionLog = require('../models/CollectionLog');
        const logs = await CollectionLog.find({ resident: req.user.id })
            .sort({ createdAt: -1 })
            .populate('staff', 'name');
        res.json(logs);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// ── Complaints ─────────────────────────────────────────────────────────────

// File a Complaint
router.post('/complaints', authMiddleware(['resident']), async (req, res) => {
    const { description } = req.body;
    try {
        const resident = await User.findById(req.user.id);
        const complaint = new Complaint({
            resident: req.user.id,
            description,
            area: resident.area,
            status: 'Pending'
        });
        await complaint.save();

        // Notify Admins
        const admins = await User.find({ role: 'admin' });
        for (const admin of admins) {
            const adminNotif = new Notification({
                resident: admin._id, // Send to admin
                title: 'New Complaint Raised',
                message: `${resident.name} has filed a new grievance: "${description.substring(0, 50)}..."`,
                type: 'MaintenanceAlert'
            });
            await adminNotif.save();
        }

        res.status(201).json({ message: 'Complaint filed successfully', complaint });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// View my Complaints
router.get('/my-complaints', authMiddleware(['resident']), async (req, res) => {
    try {
        const complaints = await Complaint.find({ resident: req.user.id }).sort({ createdAt: -1 });
        res.json(complaints);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// ── Payments ───────────────────────────────────────────────────────────────

// View my Payment History
router.get('/my-payments', authMiddleware(['resident']), async (req, res) => {
    try {
        const payments = await Payment.find({ resident: req.user.id })
            .populate('assignment', 'date month')
            .sort({ createdAt: -1 });
        res.json(payments.map((payment) => ({
            _id: payment._id,
            month: payment.month || payment.assignment?.month || getMonthKey(payment.paymentDate || payment.createdAt),
            date: payment.paymentDate || payment.createdAt,
            amount: payment.amount,
            mode: payment.paymentMode || (payment.method === 'Razorpay' ? 'Online' : payment.method),
            status: payment.paymentStatus || (payment.status === 'Success' ? 'Paid' : payment.status),
            transactionId: payment.transactionId,
            canViewReceipt: (payment.paymentStatus || (payment.status === 'Success' ? 'Paid' : payment.status)) === 'Paid'
        })));
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

router.get('/payments/:id/receipt', authMiddleware(['resident']), async (req, res) => {
    try {
        const payment = await Payment.findOne({
            _id: req.params.id,
            resident: req.user.id,
            $or: [
                { paymentStatus: 'Paid' },
                { status: 'Success' }
            ]
        })
            .populate('resident', 'name firstName lastName phoneNumber houseNumber address wardNumber')
            .populate('staff', 'name')
            .populate('paymentCollectedBy', 'name')
            .populate({ path: 'route', select: 'name ward', populate: { path: 'ward', select: 'wardNumber name wardName' } })
            .populate('house', 'houseNumber address ownerName')
            .populate({
                path: 'assignment',
                select: 'date month houseNumber residentName address route house',
                populate: [
                    { path: 'route', select: 'name ward', populate: { path: 'ward', select: 'wardNumber name wardName' } },
                    { path: 'house', select: 'houseNumber address ownerName' }
                ]
            });

        if (!payment) {
            return res.status(404).json({ message: 'Receipt not found for this payment' });
        }

        res.json(buildReceipt(payment));
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

module.exports = router;


