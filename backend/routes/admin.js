const express = require('express');
const router = express.Router();
const User = require('../models/User');
const WasteCategory = require('../models/WasteCategory');
const Schedule = require('../models/Schedule');
const Complaint = require('../models/Complaint');
const Payment = require('../models/Payment');
const Ward = require('../models/Ward');
const Route = require('../models/Route');
const RouteSchedule = require('../models/RouteSchedule');
const House = require('../models/House');
const HouseAssignment = require('../models/HouseAssignment');
const MonthlyWastePlan = require('../models/MonthlyWastePlan');
const authMiddleware = require('../middleware/authMiddleware');
const { getLocalToday, parseLocalDate } = require('../utils/dateUtils');
const { buildPasswordSetupLink, createPasswordSetup } = require('../utils/passwordSetup');
const { sendResidentApprovalWhatsApp } = require('../utils/whatsapp');
const bcrypt = require('bcrypt');
const crypto = require('crypto');

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

const findPaidPaymentForSchedule = async ({ assignment, house, residentId, date }) => {
    const scheduleDate = parseLocalDate(date || getLocalToday());
    const monthStart = new Date(scheduleDate.getFullYear(), scheduleDate.getMonth(), 1);
    const nextMonth = new Date(scheduleDate.getFullYear(), scheduleDate.getMonth() + 1, 1);
    const monthKey = getMonthKey(date || scheduleDate);

    const paymentLinks = [];
    const assignmentId = assignment?._id || assignment;
    const houseId = house?._id || house || assignment?.house;
    const resolvedResidentId = residentId || assignment?.resident || house?.resident;

    if (assignmentId) paymentLinks.push({ assignment: assignmentId });
    if (houseId) paymentLinks.push({ house: houseId });
    if (resolvedResidentId) paymentLinks.push({ resident: resolvedResidentId });
    if (paymentLinks.length === 0) return null;

    return Payment.findOne({
        $and: [
            { $or: paymentLinks },
            { $or: [{ paymentStatus: 'Paid' }, { status: 'Success' }] },
            {
                $or: [
                    { month: monthKey },
                    { paymentDate: { $gte: monthStart, $lt: nextMonth } },
                    { createdAt: { $gte: monthStart, $lt: nextMonth } }
                ]
            }
        ]
    }).sort({ paymentDate: -1, createdAt: -1 });
};

const generateTemporaryPassword = (length = 10) => {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
    let password = '';
    for (let i = 0; i < length; i += 1) {
        password += alphabet[crypto.randomInt(0, alphabet.length)];
    }
    return password;
};

const displayUserName = (user, fallback = 'Staff') => {
    if (!user) return fallback;
    const fullName = `${user.firstName || ''} ${user.lastName || ''}`.trim();
    return user.name || fullName || user.email || fallback;
};

const toDateKey = (date) => {
    const d = new Date(date);
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
};

const parseDateOnlyAtUtcNoon = (value) => {
    if (!value) return null;
    if (value instanceof Date) return value;
    const raw = value.toString();
    const match = raw.match(/^(\d{4})-(\d{2})-(\d{2})/);
    if (match) {
        const [, year, month, day] = match;
        return new Date(Date.UTC(Number(year), Number(month) - 1, Number(day), 12, 0, 0, 0));
    }
    return new Date(value);
};

const getMonthKey = (dateValue = new Date()) => {
    const d = typeof dateValue === 'string' ? new Date(`${dateValue}T00:00:00`) : new Date(dateValue);
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    return `${year}-${month}`;
};

const getMonthDateRange = (month, year) => {
    const start = `${year}-${String(month).padStart(2, '0')}-01`;
    const lastDay = new Date(year, month, 0).getDate();
    const end = `${year}-${String(month).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`;
    return { start, end };
};

const datesBetween = (startDate, endDate) => {
    if (!startDate || !endDate) return [];
    const start = new Date(startDate);
    const end = new Date(endDate);
    start.setHours(0, 0, 0, 0);
    end.setHours(0, 0, 0, 0);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || start > end) return [];

    const dates = [];
    const cursor = new Date(start);
    while (cursor <= end && dates.length < 370) {
        dates.push(toDateKey(cursor));
        cursor.setDate(cursor.getDate() + 1);
    }
    return dates;
};

const syncRouteSchedulesForRange = async (routeId, startDate, endDate, assignedStaffId) => {
    const dateKeys = datesBetween(startDate, endDate);
    if (dateKeys.length === 0) return 0;

    await RouteSchedule.deleteMany({
        route: routeId,
        date: { $nin: dateKeys }
    });

    await HouseAssignment.deleteMany({
        route: routeId,
        date: { $nin: dateKeys }
    });

    const houses = await House.find({ route: routeId });
    const houseIds = houses.map(house => house._id);
    const defaultTime = '08:30 AM - 10:30 AM';
    const defaultWasteTypes = normalizeWasteTypes();

    await Route.findByIdAndUpdate(routeId, {
        routeStatus: 'Pending',
        $unset: { completedBy: '', completedAt: '' }
    });

    for (const date of dateKeys) {
        const scheduleAssignments = houses.map(house => ({
            house: house._id,
            collectionTime: house.collectionTime || defaultTime,
            wasteTypes: house.wasteTypes?.length ? house.wasteTypes : defaultWasteTypes
        }));

        await RouteSchedule.findOneAndUpdate(
            { route: routeId, date },
            {
                $set: {
                route: routeId,
                date,
                commonTime: defaultTime,
                commonWasteTypes: defaultWasteTypes,
                routeStatus: 'Pending',
                visitStatus: 'Pending',
                assignments: scheduleAssignments
                },
                $unset: {
                    visitedBy: '',
                    visitedAt: '',
                    completedBy: '',
                    completedAt: ''
                }
            },
            { upsert: true, new: true, setDefaultsOnInsert: true }
        );

        await HouseAssignment.deleteMany({
            route: routeId,
            date,
            house: { $nin: houseIds }
        });

        for (const house of houses) {
            let resident = house.resident ? await User.findById(house.resident) : null;
            if (!resident && house.houseNumber) {
                resident = await User.findOne({ role: 'resident', houseNumber: house.houseNumber });
            }

            await HouseAssignment.findOneAndUpdate(
                { route: routeId, house: house._id, date },
                {
                    route: routeId,
                    house: house._id,
                    houseNumber: house.houseNumber,
                    resident: resident?._id,
                    residentName: resident ? resident.name : house.ownerName,
                    address: house.address,
                    staff: assignedStaffId,
                    date,
                    time: house.collectionTime || defaultTime,
                    wasteType: (house.wasteTypes?.length ? house.wasteTypes : defaultWasteTypes).join(', '),
                    status: 'Scheduled'
                },
                { upsert: true, new: true, setDefaultsOnInsert: true }
            );
        }
    }

    return dateKeys.length;
};

const naturalNumber = (value) => {
    const match = (value || '').toString().match(/\d+/);
    return match ? Number(match[0]) : Number.MAX_SAFE_INTEGER;
};

const sortByNaturalNumber = (a, b, field) => {
    const aValue = a[field] || a.name || '';
    const bValue = b[field] || b.name || '';
    const numberDiff = naturalNumber(aValue) - naturalNumber(bValue);
    if (numberDiff !== 0) return numberDiff;
    return aValue.toString().localeCompare(bValue.toString(), undefined, { numeric: true });
};

const autoAssignWardHousesToRoutes = async (wardId) => {
    if (!wardId) return { updated: 0, routes: 0 };

    const routes = await Route.find({ ward: wardId }).sort({ createdAt: 1 });
    routes.sort((a, b) => sortByNaturalNumber(a, b, 'name'));
    if (routes.length === 0) return { updated: 0, routes: 0 };

    const houses = await House.find({ ward: wardId }).sort({ houseNumber: 1 });
    houses.sort((a, b) => sortByNaturalNumber(a, b, 'houseNumber'));

    const touchedRouteIds = new Set();
    const blockSize = 3;

    for (let index = 0; index < houses.length; index += 1) {
        const targetRoute = routes[Math.floor(index / blockSize) % routes.length];
        const house = houses[index];
        const previousRoute = house.route?.toString();

        if (previousRoute) touchedRouteIds.add(previousRoute);
        touchedRouteIds.add(targetRoute._id.toString());

        house.route = targetRoute._id;
        await house.save();

        if (house.resident) {
            await User.findByIdAndUpdate(house.resident, {
                route: targetRoute._id,
                ward: wardId,
                house: house._id,
                houseNumber: house.houseNumber,
                address: house.address,
                phoneNumber: house.phoneNumber || undefined,
                wardNumber: house.wardNumber
            });
        }
    }

    for (const routeId of touchedRouteIds) {
        const route = routes.find(r => r._id.toString() === routeId) || await Route.findById(routeId);
        if (route) {
            await syncRouteSchedulesForRange(route._id, route.startDate, route.endDate, route.assignedStaff);
        }
    }

    return { updated: houses.length, routes: routes.length };
};

const applyWardScheduleToRoutes = async (wardId, startDate, endDate) => {
    const ward = await Ward.findByIdAndUpdate(
        wardId,
        { startDate, endDate },
        { new: true }
    );
    if (!ward) return null;

    const routes = await Route.find({ ward: wardId });
    for (const route of routes) {
        route.startDate = startDate;
        route.endDate = endDate;
        route.routeStatus = 'Pending';
        route.completedBy = undefined;
        route.completedAt = undefined;
        await route.save();
        await syncRouteSchedulesForRange(route._id, startDate, endDate, route.assignedStaff);
    }

    return { ward, routesUpdated: routes.length };
};

// ── User Management ─────────────────────────────────────────────────────────

// View all users
router.get('/users', authMiddleware(['admin']), async (req, res) => {
    try {
        const users = await User.find()
            .select('-password -__v')
            .populate('ward')
            .populate('route');
        res.json(users);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// View all staff
router.get('/staff', authMiddleware(['admin']), async (req, res) => {
    try {
        const staff = await User.find({ role: 'staff' })
            .select('-password -__v')
            .populate('ward', 'name wardName wardNumber')
            .populate('route', 'name routeStatus startDate endDate');
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

router.get('/twilio/status', authMiddleware(['admin']), async (req, res) => {
    const hasSid = !!process.env.TWILIO_ACCOUNT_SID;
    const hasAuthToken = !!process.env.TWILIO_AUTH_TOKEN &&
        process.env.TWILIO_AUTH_TOKEN !== 'your_auth_token_here';
    const hasFrom = !!process.env.TWILIO_WHATSAPP_FROM;

    res.json({
        ready: hasSid && hasAuthToken && hasFrom,
        accountSidConfigured: hasSid,
        authTokenConfigured: hasAuthToken,
        whatsappFrom: process.env.TWILIO_WHATSAPP_FROM || null,
        residentApprovalContentSid: process.env.TWILIO_RESIDENT_APPROVAL_CONTENT_SID || null,
        mode: process.env.TWILIO_RESIDENT_APPROVAL_CONTENT_SID ? 'content-template' : 'free-form-sandbox'
    });
});

// Approve User (Staff or Resident)
router.put('/approve-user/:id', authMiddleware(['admin']), async (req, res) => {
    try {
        const user = await User.findById(req.params.id);
        if (!user) return res.status(404).json({ message: 'User not found' });

        user.isApproved = true;
        user.isFirstLogin = true;
        let houseIdentifier = user.houseName || user.houseNumber;
        if (!houseIdentifier) {
            houseIdentifier = user.phoneNumber || user.email;
        }

        // 📝 Simulate sending a message to the resident's mobile number
        let loginPageLink = process.env.FRONTEND_LOGIN_URL || 'http://127.0.0.1:8081/#/login';
        let temporaryPassword = null;
        let whatsAppResult = { sent: false, reason: 'WhatsApp credentials are only generated for resident approvals' };

        if (user.role === 'resident') {
            temporaryPassword = generateTemporaryPassword();
            const salt = await bcrypt.genSalt(10);
            user.password = await bcrypt.hash(temporaryPassword, salt);
            user.passwordSetupToken = undefined;
            user.passwordSetupExpires = undefined;
            await user.save();

            try {
                whatsAppResult = await sendResidentApprovalWhatsApp({
                    to: user.phoneNumber,
                    username: houseIdentifier,
                    temporaryPassword,
                    loginPageLink
                });
            } catch (whatsAppError) {
                console.error('[TWILIO] WhatsApp send failed:', whatsAppError.message);
                whatsAppResult = { sent: false, reason: whatsAppError.message };
            }
        } else {
            const setupToken = createPasswordSetup(user);
            loginPageLink = buildPasswordSetupLink(setupToken);
            await user.save();
        }

        if (user.role === 'resident') {
            const Notification = require('../models/Notification');
            await Notification.create({
                resident: user._id,
                title: 'Account Approved!',
                message: `Your account is active. Username: ${houseIdentifier}. Credentials were sent to your WhatsApp number. Please login and change your password.`,
                type: 'General'
            });
        }

        res.json({ 
            message: `${user.role.charAt(0).toUpperCase() + user.role.slice(1)} approved successfully`, 
            user,
            setup: {
                username: houseIdentifier,
                loginPageLink,
                temporaryPasswordSent: user.role === 'resident',
                whatsAppSent: whatsAppResult.sent,
                whatsAppMessage: whatsAppResult.sent ? 'Credentials sent via WhatsApp' : whatsAppResult.reason
            },
            ...(process.env.NODE_ENV === 'production' || !temporaryPassword ? {} : {
                devCredentials: {
                    username: houseIdentifier,
                    temporaryPassword,
                    loginPageLink
                }
            })
        });
    } catch (error) {
        console.error('Approval Error:', error);
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

// Get month-wise waste types. This setting applies to every ward for the selected month.
router.get('/monthly-waste-types', authMiddleware(['admin', 'staff', 'resident']), async (req, res) => {
    try {
        const now = new Date();
        const month = parseInt(req.query.month) || (now.getMonth() + 1);
        const year = parseInt(req.query.year) || now.getFullYear();
        const plan = await MonthlyWastePlan.findOne({ month, year }).lean();
        res.json({
            month,
            year,
            wasteTypes: normalizeWasteTypes(plan?.wasteTypes || [])
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// Save month-wise waste types and apply them to all route schedules in that month.
router.post('/monthly-waste-types', authMiddleware(['admin']), async (req, res) => {
    try {
        const now = new Date();
        const month = parseInt(req.body.month) || (now.getMonth() + 1);
        const year = parseInt(req.body.year) || now.getFullYear();
        const wasteTypes = normalizeWasteTypes(req.body.wasteTypes || []);
        const { start, end } = getMonthDateRange(month, year);

        const plan = await MonthlyWastePlan.findOneAndUpdate(
            { month, year },
            { $set: { month, year, wasteTypes } },
            { upsert: true, new: true, setDefaultsOnInsert: true }
        );

        const schedules = await RouteSchedule.find({ date: { $gte: start, $lte: end } });
        for (const schedule of schedules) {
            schedule.commonWasteTypes = wasteTypes;
            schedule.assignments = (schedule.assignments || []).map(assign => ({
                ...(assign.toObject?.() || assign),
                wasteTypes
            }));
            await schedule.save();
        }

        const houseAssignments = await HouseAssignment.updateMany(
            { date: { $gte: start, $lte: end } },
            { $set: { wasteType: wasteTypes.join(', ') } }
        );

        res.json({
            message: 'Monthly waste types saved for all wards',
            month,
            year,
            wasteTypes: plan.wasteTypes,
            updatedRouteSchedules: schedules.length,
            updatedHouseAssignments: houseAssignments.modifiedCount || 0
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// Create Schedule (monthly waste type scheduling)
router.post('/schedules', authMiddleware(['admin']), async (req, res) => {
    const { date, month, year, wardNumber, category, assignedStaff, notes, time, wasteTypes } = req.body;
    try {
        const scheduleDate = date ? new Date(date) : new Date();
        const schedMonth = month || (scheduleDate.getMonth() + 1);
        const schedYear = year || scheduleDate.getFullYear();
        const selectedCategory = category ? await WasteCategory.findById(category) : null;
        const normalizedWasteTypes = normalizeWasteTypes([
            ...(Array.isArray(wasteTypes) ? wasteTypes : []),
            selectedCategory?.name
        ]);

        const schedule = new Schedule({
            date: scheduleDate,
            month: schedMonth,
            year: schedYear,
            wardNumber,
            category,
            wasteTypes: normalizedWasteTypes,
            assignedStaff,
            notes,
            time
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
        res.json(schedules.map(schedule => ({
            ...schedule.toObject(),
            wasteTypes: normalizeWasteTypes(schedule.wasteTypes?.length ? schedule.wasteTypes : [schedule.category?.name])
        })));
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
        res.json(schedules.map(schedule => ({
            ...schedule.toObject(),
            wasteTypes: normalizeWasteTypes(schedule.wasteTypes?.length ? schedule.wasteTypes : [schedule.category?.name])
        })));
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
        const { ward, route, house, status, method } = req.query;
        const filter = {};
        if (route) filter.route = route;
        if (house) filter.house = house;
        const andFilters = [];
        if (status) {
            andFilters.push(status === 'Paid'
                ? { $or: [{ status: 'Success' }, { paymentStatus: 'Paid' }] }
                : { $or: [{ status }, { paymentStatus: status }] });
        }
        if (method) andFilters.push({ $or: [{ method }, { paymentMode: method }] });
        if (andFilters.length) filter.$and = andFilters;

        let payments = await Payment.find(filter)
            .populate('resident', 'firstName lastName email houseNumber wardNumber ward route')
            .populate('staff', 'name')
            .populate({ path: 'route', select: 'name ward', populate: { path: 'ward', select: 'wardName wardNumber' } })
            .populate('house', 'houseNumber ownerName')
            .populate('assignment')
            .sort({ createdAt: -1 });
        if (ward) {
            payments = payments.filter(p => {
                const residentWard = p.resident?.wardNumber?.toString();
                const populatedWard = p.resident?.ward?._id?.toString?.() || p.resident?.ward?.toString?.();
                return residentWard === ward.toString() || populatedWard === ward.toString();
            });
        }
        res.json(payments.map((payment) => ({
            _id: payment._id,
            houseNumber: payment.house?.houseNumber || payment.assignment?.houseNumber || payment.resident?.houseNumber,
            residentName: payment.resident
                ? `${payment.resident.firstName || ''} ${payment.resident.lastName || ''}`.trim()
                : 'Resident',
            routeName: payment.route?.name || 'Route pending',
            ward: payment.route?.ward
                ? `Ward ${payment.route.ward.wardNumber || ''} ${payment.route.ward.wardName || ''}`.trim()
                : payment.resident?.wardNumber ? `Ward ${payment.resident.wardNumber}` : 'Ward pending',
            date: payment.paymentDate || payment.createdAt,
            amount: payment.amount,
            paymentStatus: payment.paymentStatus || (payment.status === 'Success' ? 'Paid' : payment.status),
            paymentMode: payment.paymentMode || (payment.method === 'Razorpay' ? 'Online' : payment.method),
            month: payment.month || payment.assignment?.month || getMonthKey(payment.paymentDate || payment.createdAt),
            collectedBy: payment.staff?.name || null,
            raw: payment
        })));
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

router.post('/resend-resident-credentials/:id', authMiddleware(['admin']), async (req, res) => {
    try {
        const user = await User.findById(req.params.id);
        if (!user) return res.status(404).json({ message: 'User not found' });
        if (user.role !== 'resident') {
            return res.status(400).json({ message: 'Credentials can only be resent to residents' });
        }

        let username = user.houseName || user.houseNumber || user.phoneNumber || user.email;
        const temporaryPassword = generateTemporaryPassword();
        const salt = await bcrypt.genSalt(10);
        user.password = await bcrypt.hash(temporaryPassword, salt);
        user.isApproved = true;
        user.isFirstLogin = false;
        user.passwordSetupToken = undefined;
        user.passwordSetupExpires = undefined;
        await user.save();

        const loginPageLink = process.env.FRONTEND_LOGIN_URL || 'http://127.0.0.1:8081/#/login';
        let whatsAppResult;
        try {
            whatsAppResult = await sendResidentApprovalWhatsApp({
                to: user.phoneNumber,
                username,
                temporaryPassword,
                loginPageLink,
                forcePasswordChange: false
            });
        } catch (whatsAppError) {
            console.error('[TWILIO] WhatsApp resend failed:', whatsAppError.message);
            whatsAppResult = { sent: false, reason: whatsAppError.message };
        }

        res.json({
            message: whatsAppResult.sent
                ? 'Resident credentials resent via WhatsApp'
                : 'Resident credentials regenerated, but WhatsApp was not delivered',
            setup: {
                username,
                loginPageLink,
                temporaryPasswordSent: true,
                whatsAppSent: whatsAppResult.sent,
                whatsAppMessage: whatsAppResult.sent ? 'Credentials sent via WhatsApp' : whatsAppResult.reason,
                twilioMessageSid: whatsAppResult.sid || null
            },
            ...(process.env.NODE_ENV === 'production' ? {} : {
                devCredentials: {
                    username,
                    temporaryPassword,
                    loginPageLink
                }
            })
        });
    } catch (error) {
        console.error('Credential resend error:', error);
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

router.delete('/complaints/:id', authMiddleware(['admin']), async (req, res) => {
    try {
        const complaint = await Complaint.findByIdAndDelete(req.params.id);
        if (!complaint) return res.status(404).json({ message: 'Complaint not found' });
        res.json({ message: 'Complaint deleted successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

router.get('/reports/assignments', authMiddleware(['admin']), async (req, res) => {
    try {
        const { ward, route, house, paymentStatus, collectionStatus, date } = req.query;
        const filter = {};
        if (route) filter.route = route;
        if (house) filter.house = house;
        if (paymentStatus) filter.paymentStatus = paymentStatus;
        if (collectionStatus) filter.collectionStatus = collectionStatus;
        if (date) filter.date = date;

        let assignments = await HouseAssignment.find(filter)
            .populate('resident', 'firstName lastName email houseNumber wardNumber')
            .populate('route', 'name ward')
            .populate('house', 'houseNumber ownerName ward wardNumber')
            .populate('staff', 'firstName lastName email')
            .sort({ date: -1, createdAt: -1 });

        if (ward) {
            assignments = assignments.filter(a => {
                const wardId = a.route?.ward?.toString?.() || a.house?.ward?.toString?.();
                const wardNumber = a.house?.wardNumber?.toString?.() || a.resident?.wardNumber?.toString?.();
                return wardId === ward.toString() || wardNumber === ward.toString();
            });
        }

        res.json(assignments);
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// Collection History Report
router.get('/reports/collections', authMiddleware(['admin']), async (req, res) => {
    try {
        const CollectionLog = require('../models/CollectionLog');
        const logs = await CollectionLog.find()
            .populate('resident', 'name houseNumber wardNumber')
            .populate('staff', 'name')
            .populate({ path: 'route', select: 'name ward', populate: { path: 'ward', select: 'wardName wardNumber' } })
            .sort({ createdAt: -1 });
        res.json(logs.map((log) => ({
            _id: log._id,
            houseNumber: log.resident?.houseNumber,
            residentName: log.resident?.name || 'Unknown Resident',
            routeName: log.route?.name || 'Route pending',
            ward: log.route?.ward
                ? `Ward ${log.route.ward.wardNumber || ''} ${log.route.ward.wardName || ''}`.trim()
                : log.resident?.wardNumber ? `Ward ${log.resident.wardNumber}` : 'Ward pending',
            date: log.date || log.createdAt,
            time: log.time || '',
            wasteType: log.wasteType || 'General Waste',
            collectionStatus: log.status,
            paymentStatus: log.amountPaid > 0 ? 'Paid' : 'Pending',
            paymentMode: log.paymentMethod === 'None' ? '' : log.paymentMethod,
            month: log.month || getMonthKey(log.date || log.createdAt),
            proofPhotoUrl: log.proofPhotoUrl || log.proofImageUrl,
            staffName: log.staff?.name || 'Staff',
            raw: log
        })));
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
            { $match: { $or: [{ status: 'Success' }, { paymentStatus: 'Paid' }] } },
            { $group: { _id: null, total: { $sum: "$amount" } } }
        ]);

        const paymentReports = await Payment.aggregate([
            { $match: { $or: [{ status: 'Success' }, { paymentStatus: 'Paid' }] } },
            {
                $group: {
                    _id: { $ifNull: ['$paymentMode', '$method'] },
                    total: { $sum: '$amount' },
                    count: { $sum: 1 }
                }
            }
        ]);

        const routes = await Route.find()
            .populate('ward', 'wardName wardNumber')
            .populate('assignedStaff', 'name email')
            .sort({ updatedAt: -1 })
            .limit(12);

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
            totalRevenue: totalRevenue[0]?.total || 0,
            paymentReports,
            routeTracking: routes.map(route => ({
                routeName: route.name,
                ward: route.ward ? `Ward ${route.ward.wardNumber || ''} ${route.ward.wardName || ''}`.trim() : 'Ward pending',
                assignedStaff: route.assignedStaff?.name || route.assignedStaff?.email || 'Not assigned',
                routeStatus: route.routeStatus || 'Pending'
            }))
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

router.get('/route-completions', authMiddleware(['admin']), async (req, res) => {
    try {
        const schedules = await RouteSchedule.find({
            $or: [
                { visitStatus: 'Visited' },
                { routeStatus: 'Completed' }
            ]
        })
            .populate({
                path: 'route',
                select: 'name ward assignedStaff startDate endDate routeStatus',
                populate: [
                    { path: 'ward', select: 'wardName name wardNumber' },
                    { path: 'assignedStaff', select: 'name firstName lastName email' }
                ]
            })
            .populate('visitedBy', 'name firstName lastName email')
            .populate('completedBy', 'name firstName lastName email')
            .sort({ date: -1 });

        const buildResidentName = (assignment) => {
            if (assignment.resident) {
                const firstName = assignment.resident.firstName || '';
                const lastName = assignment.resident.lastName || '';
                const fullName = `${firstName} ${lastName}`.trim();
                if (fullName) return fullName;
                if (assignment.resident.email) return assignment.resident.email;
            }
            return assignment.residentName || 'Resident';
        };

        const reports = await Promise.all(schedules
            .filter(schedule => schedule.route)
            .map(async (schedule) => {
                const assignments = await HouseAssignment.find({
                    route: schedule.route._id,
                    date: schedule.date
                })
                    .populate('resident', 'firstName lastName email phoneNumber houseNumber')
                    .populate('house', 'houseNumber ownerName address phoneNumber')
                    .sort({ houseNumber: 1 })
                    .lean();

                const paidStatuses = ['Paid', 'Paid in Cash'];
                const totalHouses = assignments.length;
                const collectedHouses = assignments.filter((a) => a.collectionStatus === 'Collected').length;
                const notCollectedHouses = assignments.filter((a) => a.collectionStatus !== 'Collected').length;
                const paidHouses = assignments.filter((a) => paidStatuses.includes(a.paymentStatus)).length;
                const unpaidHouses = assignments.filter((a) => !paidStatuses.includes(a.paymentStatus)).length;
                const residents = assignments.map((a) => ({
                    assignmentId: a._id,
                    residentId: a.resident?._id || null,
                    residentName: buildResidentName(a),
                    phoneNumber: a.resident?.phoneNumber || a.house?.phoneNumber || '',
                    houseNumber: a.houseNumber || a.house?.houseNumber || 'N/A',
                    address: a.address || a.house?.address || '',
                    availabilityStatus: a.availabilityStatus || 'Pending',
                    collectionStatus: a.collectionStatus || 'Pending',
                    paymentStatus: a.paymentStatus || 'Pending',
                    paymentMode: a.paymentMode || a.paymentMethod || '',
                    amount: a.amount || 50,
                    collectedAt: a.collectedAt || null,
                    paidAt: a.paidAt || a.paymentDate || null
                }));
                const unpaidResidents = assignments
                    .filter((a) => !paidStatuses.includes(a.paymentStatus))
                    .map((a) => ({
                        assignmentId: a._id,
                        residentId: a.resident?._id || null,
                        residentName: buildResidentName(a),
                        phoneNumber: a.resident?.phoneNumber || a.house?.phoneNumber || '',
                        houseNumber: a.houseNumber || a.house?.houseNumber || 'N/A',
                        address: a.address || a.house?.address || '',
                        collectionStatus: a.collectionStatus || 'Pending',
                        paymentStatus: a.paymentStatus || 'Pending',
                        paymentMode: a.paymentMode || a.paymentMethod || ''
                    }));

                const ward = schedule.route.ward;
                const wardName = ward
                    ? `Ward ${ward.wardNumber || ''} ${ward.wardName || ward.name || ''}`.trim()
                    : 'Ward not set';
                const assignedStaff = schedule.route.assignedStaff;
                const visitedBy = schedule.visitedBy;
                const completedBy = schedule.completedBy;
                return {
                    _id: schedule._id,
                    date: schedule.date,
                    routeName: schedule.route.name,
                    routeId: schedule.route._id,
                    ward: wardName,
                    assignedStaffId: assignedStaff?._id || null,
                    assignedStaff: displayUserName(assignedStaff, 'Not assigned'),
                    selectedById: visitedBy?._id || null,
                    selectedBy: displayUserName(visitedBy, 'Not marked'),
                    completedById: completedBy?._id || null,
                    completedBy: displayUserName(completedBy, null),
                    visitStatus: schedule.visitStatus || 'Pending',
                    routeStatus: schedule.routeStatus || 'Pending',
                    visitedAt: schedule.visitedAt,
                    completedAt: schedule.completedAt,
                    adminStartDate: schedule.route.startDate,
                    adminEndDate: schedule.route.endDate,
                    totals: {
                        totalHouses,
                        collectedHouses,
                        notCollectedHouses,
                        paidHouses,
                        unpaidHouses
                    },
                    residents,
                    unpaidResidents
                };
            }));

        res.json(reports);
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// Get Unassigned Residents in a specific Ward
router.get('/residents/unassigned/:wardId', authMiddleware(['admin']), async (req, res) => {
    try {
        // Find residents in this ward who don't have a house record linked to them yet
        // We look for 'house: null' as the primary indicator of being unassigned to a physical location
        const unassigned = await User.find({ 
            role: 'resident', 
            ward: req.params.wardId,
            $or: [{ house: null }, { house: { $exists: false } }] 
        }).select('name email phoneNumber houseNumber');
        
        res.json(unassigned);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

router.post('/wards/:wardId/auto-assign-routes', authMiddleware(['admin']), async (req, res) => {
    try {
        const result = await autoAssignWardHousesToRoutes(req.params.wardId);
        res.json({
            message: `${result.updated} house(s) auto-assigned across ${result.routes} route(s), 3 houses per route.`,
            result
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
// Get Wards (Publicly accessible for registration)
router.get('/wards', async (req, res) => {
    try {
        const wards = await Ward.find().sort({ wardNumber: 1 });
        res.json(wards);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Set the ward-level work duration. All routes under this ward inherit this range.
router.put('/wards/:id/schedule', authMiddleware(['admin']), async (req, res) => {
    try {
        const { startDate, endDate } = req.body;
        if (!startDate || !endDate) {
            return res.status(400).json({ message: 'Start date and end date are required.' });
        }

        const start = parseDateOnlyAtUtcNoon(startDate);
        const end = parseDateOnlyAtUtcNoon(endDate);

        if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || start > end) {
            return res.status(400).json({ message: 'Select a valid ward work duration range.' });
        }

        const result = await applyWardScheduleToRoutes(req.params.id, start, end);
        if (!result) return res.status(404).json({ message: 'Ward not found' });

        res.json({
            message: `Ward schedule saved. ${result.routesUpdated} route(s) updated for staff selection.`,
            ward: result.ward,
            routesUpdated: result.routesUpdated
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
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
    const { name, ward, description, assignedStaff, collectionDays, startDate, endDate } = req.body;
    try {
        const wardDoc = await Ward.findById(ward);
        const effectiveStartDate = wardDoc?.startDate || startDate;
        const effectiveEndDate = wardDoc?.endDate || endDate;
        const route = new Route({
            name,
            ward,
            description,
            assignedStaff,
            collectionDays,
            startDate: effectiveStartDate,
            endDate: effectiveEndDate
        });
        await route.save();
        
        // If staff is assigned during creation, update user's routeRef
        if (assignedStaff) {
            await User.findByIdAndUpdate(assignedStaff, { route: route._id, ward: ward });
        }

        const autoAssign = await autoAssignWardHousesToRoutes(ward);
        const scheduledDays = await syncRouteSchedulesForRange(route._id, effectiveStartDate, effectiveEndDate, assignedStaff);

        const populated = await Route.findById(route._id).populate('ward').populate('assignedStaff', 'name email');
        res.status(201).json({ message: 'Route created, scheduled, and ward houses auto-assigned successfully', route: populated, scheduledDays, autoAssign });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// Get Routes
// Get Routes (Publicly accessible for registration)
router.get('/routes', async (req, res) => {
    const { ward } = req.query; // Optional filter by ward ID
    const filter = ward ? { ward } : {};
    try {
        const routes = await Route.find(filter).populate('ward').populate('assignedStaff', 'name email').lean();
        const monthPlans = await MonthlyWastePlan.find().lean();
        const planByMonth = new Map(
            monthPlans.map(plan => [`${plan.year}-${String(plan.month).padStart(2, '0')}`, normalizeWasteTypes(plan.wasteTypes)])
        );

        res.json(routes.map(route => {
            const routeDate = route.startDate || route.endDate;
            const routeMonthKey = routeDate ? getMonthKey(routeDate) : null;
            return {
                ...route,
                scheduleMonthKey: routeMonthKey,
                monthlyWasteTypes: routeMonthKey
                    ? (planByMonth.get(routeMonthKey) || normalizeWasteTypes())
                    : []
            };
        }));
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Delete Route
router.delete('/routes/:id', authMiddleware(['admin']), async (req, res) => {
    try {
        const route = await Route.findByIdAndDelete(req.params.id);
        if (!route) return res.status(404).json({ message: 'Route not found' });
        await RouteSchedule.deleteMany({ route: route._id });
        await HouseAssignment.deleteMany({ route: route._id });
        const autoAssign = await autoAssignWardHousesToRoutes(route.ward);
        res.json({ message: 'Route deleted successfully. Ward houses rebalanced.', autoAssign });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Update Route (Metadata & Schedule)
router.put('/routes/:id', authMiddleware(['admin']), async (req, res) => {
    const { name, description, collectionDays, startDate, endDate, assignedStaff } = req.body;
    try {
        const existingRoute = await Route.findById(req.params.id).populate('ward');
        if (!existingRoute) return res.status(404).json({ message: 'Route not found' });
        const wardStartDate = existingRoute.ward?.startDate;
        const wardEndDate = existingRoute.ward?.endDate;
        const update = {};
        if (name !== undefined) update.name = name;
        if (description !== undefined) update.description = description;
        if (collectionDays !== undefined) update.collectionDays = collectionDays;
        update.startDate = wardStartDate || startDate || existingRoute.startDate;
        update.endDate = wardEndDate || endDate || existingRoute.endDate;
        if (assignedStaff !== undefined) update.assignedStaff = assignedStaff;

        const route = await Route.findByIdAndUpdate(
            req.params.id, 
            update,
            { new: true }
        ).populate('ward').populate('assignedStaff', 'name email');
          
        if (assignedStaff) {
            await User.findByIdAndUpdate(assignedStaff, { route: route._id, ward: route.ward?._id || route.ward });
        }
        const scheduledDays = await syncRouteSchedulesForRange(route._id, route.startDate, route.endDate, route.assignedStaff?._id || route.assignedStaff);
        res.json({ message: 'Route updated and scheduled successfully', route, scheduledDays });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// Update Route Assignment
router.put('/routes/:id/assign', authMiddleware(['admin']), async (req, res) => {
    const { staffId } = req.body;
    try {
        const route = await Route.findById(req.params.id).populate('ward');
        if (!route) return res.status(404).json({ message: 'Route not found' });

        // Remove route from previous staff if exists
        if (route.assignedStaff) {
            await User.findByIdAndUpdate(route.assignedStaff, { $unset: { route: "" } });
        }

        // Assign to new staff
        route.assignedStaff = staffId;
        if (route.ward?.startDate && route.ward?.endDate) {
            route.startDate = route.ward.startDate;
            route.endDate = route.ward.endDate;
        }
        await route.save();

        if (staffId) {
            await User.findByIdAndUpdate(staffId, { route: route._id, ward: route.ward?._id || route.ward });
        }

        await syncRouteSchedulesForRange(route._id, route.startDate, route.endDate, staffId);
        const populated = await Route.findById(route._id).populate('ward').populate('assignedStaff', 'name email');
        res.json({ message: 'Route assigned successfully', route: populated });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// ── Route Schedules (New) ───────────────────────────────────────────────────

// Create or Update Route Schedule for a specific date
router.post('/routes/:id/schedules', authMiddleware(['admin']), async (req, res) => {
    const { date, assignments, commonTime, commonWasteTypes } = req.body;
    const routeId = req.params.id;
    try {
        const normalizedCommonWasteTypes = normalizeWasteTypes(commonWasteTypes);
        // --- IMPROVED LOGIC: Ensure ALL houses in the route get a record ---
        // If the Admin explicitly sent assignments, use them. 
        // Otherwise, fetch all houses in this route to ensure 100% coverage.
        let finalAssignments = assignments;
        if (!finalAssignments || finalAssignments.length === 0) {
            const allHousesInRoute = await House.find({ route: routeId });
            finalAssignments = allHousesInRoute.map(h => ({
                house: h._id,
                collectionTime: commonTime,
                wasteTypes: normalizedCommonWasteTypes
            }));
        } else {
            finalAssignments = finalAssignments.map(assign => ({
                ...assign,
                wasteTypes: normalizeWasteTypes(
                    assign.wasteTypes && assign.wasteTypes.length > 0
                        ? assign.wasteTypes
                        : normalizedCommonWasteTypes
                )
            }));
        }

        let schedule = await RouteSchedule.findOne({ route: routeId, date });
        if (schedule) {
            schedule.assignments = finalAssignments;
            schedule.commonTime = commonTime;
            schedule.commonWasteTypes = normalizedCommonWasteTypes;
            await schedule.save();
        } else {
            schedule = new RouteSchedule({ route: routeId, date, assignments: finalAssignments, commonTime, commonWasteTypes: normalizedCommonWasteTypes });
            await schedule.save();
        }

        // --- User Request: Sync to HouseAssignment for individual lookup ---
        const Route = require('../models/Route');
        const currentRoute = await Route.findById(routeId);
        const assignedStaffId = currentRoute?.assignedStaff;

        // Clear ALL future assignments for this route so rescheduling to a new date
        // properly replaces old upcoming schedules (not just the same date).
        const todayStr = getLocalToday();
        await HouseAssignment.deleteMany({ route: routeId, date: { $gte: todayStr } });

        console.log(`--- GLOBAL SYNC FOR ROUTE: ${routeId} ---`);
        console.log(`Date: ${date}, Syncing ${finalAssignments.length} individual house records...`);

        for (const assign of finalAssignments) {
            const houseDoc = await House.findById(assign.house);
            
            // --- CRITICAL FIX: Always re-verify resident by houseNumber to ensure correct dashboard linking ---
            let residentId = null;
            let resUser = null;
            if (houseDoc && houseDoc.houseNumber) {
                resUser = await User.findOne({ 
                    role: 'resident', 
                    houseNumber: houseDoc.houseNumber.toString().trim()
                });
                if (resUser) {
                    residentId = resUser._id;
                    // Also update the house master record for future consistency
                    if (!houseDoc.resident || houseDoc.resident.toString() !== residentId.toString()) {
                        houseDoc.resident = residentId;
                        await houseDoc.save();
                    }
                }
            }

            const houseAssignment = new HouseAssignment({
                route: routeId,
                house: assign.house,
                houseNumber: houseDoc?.houseNumber || 'Unknown',
                resident: residentId,
                residentName: resUser ? resUser.name : (houseDoc ? houseDoc.ownerName : 'Unknown'),
                address: houseDoc ? houseDoc.address : 'Unknown',
                staff: assignedStaffId,
                date: date,
                time: assign.collectionTime || commonTime,
                wasteType: (assign.wasteTypes && assign.wasteTypes.length > 0) ? assign.wasteTypes.join(', ') : normalizedCommonWasteTypes.join(', '),
                status: 'Scheduled',
                availabilityStatus: 'Pending',
                paymentStatus: 'Pending'
            });
            await houseAssignment.save();
            console.log(`[SYNC] Saved assignment for House ${houseAssignment.houseNumber} (Resident: ${residentId || 'NONE'})`);

            // Create Notification
            if (residentId) {
                const Notification = require('../models/Notification');
                await Notification.create({
                    resident: residentId,
                    title: 'New Collection Scheduled!',
                    message: `Admin has scheduled a ${houseAssignment.wasteType} collection for ${date} at ${houseAssignment.time}.`,
                    type: 'CollectionAlert'
                });
            }
        }
        
        // --- STAFF NOTIFICATION ---
        if (assignedStaffId) {
            try {
                const Notification = require('../models/Notification');
                await Notification.create({
                    resident: assignedStaffId, // Using 'resident' field as a general user pointer
                    title: 'New Route Assignment!',
                    message: `You have been assigned a collection for route "${currentRoute.name}" on ${date}. Start time: ${commonTime}.`,
                    type: 'General'
                });
                console.log(`[SYNC] Notification sent to Staff: ${assignedStaffId}`);
            } catch (staffNotifErr) {
                console.error('[NON-CRITICAL] Staff Notification Error:', staffNotifErr);
            }
        }

        console.log(`--- SYNC COMPLETE ---`);
        res.json(schedule);
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// Get Route Schedule for a specific date
router.get('/routes/:id/schedules/:date', authMiddleware(['admin', 'staff']), async (req, res) => {
    try {
        const routeId = req.params.id;
        const date = req.params.date;

        const schedule = await RouteSchedule.findOne({ route: routeId, date }).lean();
        
        // --- User Request: Fetch assignments from HouseAssignment table ---
        const HouseAssignment = require('../models/HouseAssignment');
        const assignments = await HouseAssignment.find({ route: routeId, date })
            .populate('house')
            .populate('resident')
            .lean();

        // Map assignments to the format expected by the frontend. Availability is
        // date-specific, so never copy a resident's response from another day.
        const mappedAssignments = await Promise.all(assignments.map(async (a) => {
            const house = a.house ? { ...a.house } : {};
            let paymentStatus = a.paymentStatus || 'Pending';
            let paymentMode = a.paymentMode;
            let paymentDate = a.paymentDate;
            const residentId = a.resident?._id || a.resident || house.resident;
            const paidPayment = await findPaidPaymentForSchedule({
                assignment: a,
                house,
                residentId,
                date
            });

            if (paidPayment) {
                paymentStatus = 'Paid';
                paymentMode = paidPayment.paymentMode || (paidPayment.method === 'Razorpay' ? 'Online' : paidPayment.method);
                paymentDate = paidPayment.paymentDate || paidPayment.createdAt;
                if (a.paymentStatus !== 'Paid') {
                    await HouseAssignment.findByIdAndUpdate(a._id, {
                        paymentStatus: 'Paid',
                        paymentMode,
                        paymentMethod: paymentMode,
                        paymentDate,
                        paidAt: paymentDate,
                        transactionId: paidPayment.transactionId,
                        amount: paidPayment.amount,
                        month: paidPayment.month || getMonthKey(date)
                    });
                }
            }

            let residentResponse = a.availabilityStatus || 'Pending';
            let availabilityDate = residentResponse !== 'Pending' ? a.date : null;
            if (residentResponse === 'Pending') {
                const latestAvailability = await HouseAssignment.findOne({
                    route: routeId,
                    availabilityStatus: { $in: ['Available', 'Not Available'] },
                    $or: [
                        ...(residentId ? [{ resident: residentId }] : []),
                        ...(a.house ? [{ house: a.house._id || a.house }] : []),
                        ...(a.houseNumber ? [{ houseNumber: a.houseNumber }] : [])
                    ]
                }).sort({ availabilityUpdatedAt: -1, updatedAt: -1 }).lean();

                if (latestAvailability) {
                    residentResponse = latestAvailability.availabilityStatus;
                    availabilityDate = latestAvailability.date;
                    paymentStatus = latestAvailability.paymentStatus || paymentStatus;
                    paymentMode = latestAvailability.paymentMode || paymentMode;
                    paymentDate = latestAvailability.paymentDate || paymentDate;
                }
            }

            return {
                assignmentId: a._id,
                house: {
                    ...house,
                    assignmentId: a._id,
                    residentResponse,
                    availabilityDate,
                    collectionStatus: a.collectionStatus,
                    paymentStatus,
                    paymentMode,
                    paymentDate,
                    month: a.month,
                    visitStatus: a.visitStatus
                },
                collectionTime: a.time,
                wasteTypes: normalizeWasteTypes(a.wasteType ? a.wasteType.split(', ') : [])
            };
        }));

        const commonTypes = normalizeWasteTypes(
            schedule?.commonWasteTypes?.length
                ? schedule.commonWasteTypes
                : (mappedAssignments[0]?.wasteTypes || [])
        );

        res.json({
            ...(schedule || {}),
            commonWasteTypes: commonTypes,
            assignments: mappedAssignments
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// Get all Route Schedules
router.get('/routes/:id/schedules', authMiddleware(['admin', 'staff']), async (req, res) => {
    try {
        const schedules = await RouteSchedule.find({ route: req.params.id })
            .populate('assignments.house')
            .lean();
            
        const CollectionLog = require('../models/CollectionLog');
        const User = require('../models/User');

        for (let schedule of schedules) {
            schedule.commonWasteTypes = normalizeWasteTypes(schedule.commonWasteTypes || []);
            const schedDate = parseLocalDate(schedule.date);
            const nextDay = new Date(schedDate);
            nextDay.setDate(nextDay.getDate() + 1);

            const visibleAssignments = [];
            for (let a of schedule.assignments) {
                if (a.house) {
                    const houseRouteId = a.house.route?.toString();
                    if (houseRouteId && houseRouteId !== req.params.id) {
                        continue;
                    }

                    if (a.house.resident) {
                        const linkedResident = await User.findById(a.house.resident).select('route');
                        const residentRouteId = linkedResident?.route?.toString();
                        if (residentRouteId && residentRouteId !== req.params.id) {
                            continue;
                        }
                    }

                    // Clone the house object to avoid status leakage if the same house 
                    // is referenced in multiple schedules in the loop.
                    let h = { ...a.house };
                    
                    let collectionStatus = 'Pending';
                    let residentResponse = 'Pending';
                    let availabilityDate = null;

                    // PRIMARY: Read availability from HouseAssignment
                    const haRecord = await HouseAssignment.findOne({
                        route: req.params.id,
                        date: schedule.date,
                        $or: [
                            { house: h._id },
                            { houseNumber: h.houseNumber }
                        ]
                    }).sort({ updatedAt: -1 });
                    if (haRecord) {
                        residentResponse = haRecord.availabilityStatus || 'Pending';
                        collectionStatus = haRecord.collectionStatus || 'Pending';
                        h.assignmentId = haRecord._id;
                        h.paymentStatus = haRecord.paymentStatus || 'Pending';
                        h.visitStatus = haRecord.visitStatus || 'Pending';
                        if (haRecord.availabilityStatus && haRecord.availabilityStatus !== 'Pending') {
                            availabilityDate = haRecord.date;
                        }
                        
                        // If a specific resident responded, show THEIR name and details
                        if (haRecord.residentName) h.ownerName = haRecord.residentName;
                        if (haRecord.resident) h.resident = haRecord.resident;
                    }

                    if (residentResponse === 'Pending') {
                        const latestAvailability = await HouseAssignment.findOne({
                            route: req.params.id,
                            availabilityStatus: { $in: ['Available', 'Not Available'] },
                            $or: [
                                ...(haRecord?.resident ? [{ resident: haRecord.resident }] : []),
                                ...(h.resident ? [{ resident: h.resident }] : []),
                                ...(h._id ? [{ house: h._id }] : []),
                                ...(h.houseNumber ? [{ houseNumber: h.houseNumber }] : [])
                            ]
                        }).sort({ availabilityUpdatedAt: -1, updatedAt: -1 });

                        if (latestAvailability) {
                            residentResponse = latestAvailability.availabilityStatus;
                            availabilityDate = latestAvailability.date;
                            h.paymentStatus = latestAvailability.paymentStatus || h.paymentStatus;
                            h.paymentMode = latestAvailability.paymentMode || h.paymentMode;
                            h.paymentDate = latestAvailability.paymentDate || h.paymentDate;
                            h.month = latestAvailability.month || h.month;
                        }
                    }

                    // SECONDARY: CollectionLog overrides status on the actual day
                    let resId = h.resident;
                    if (!resId) {
                        const resUser = await User.findOne({ 
                            role: 'resident', 
                            $or: [{ houseNumber: h.houseNumber }]
                        });
                        if (resUser) resId = resUser._id;
                    }

                    if (resId) {
                        const log = await CollectionLog.findOne({
                            $or: [{ house: h._id }, { resident: resId }],
                            createdAt: { $gte: schedDate, $lt: nextDay }
                        }).sort({ createdAt: -1 });

                        if (log) {
                            if (log.status && log.status !== 'Pending') collectionStatus = log.status;
                            if (residentResponse === 'Pending' && log.residentResponse && log.residentResponse !== 'Pending') {
                                residentResponse = log.residentResponse;
                            }
                            // Also update name if log has it (though haRecord is primary)
                            if (!haRecord && log.resident) {
                                const logRes = await User.findById(log.resident);
                                if (logRes) h.ownerName = logRes.name;
                            }
                        }
                    }

                    const paidPayment = await findPaidPaymentForSchedule({
                        assignment: haRecord,
                        house: h,
                        residentId: resId,
                        date: schedule.date
                    });

                    if (paidPayment) {
                        h.paymentStatus = 'Paid';
                        h.paymentMode = paidPayment.paymentMode || (paidPayment.method === 'Razorpay' ? 'Online' : paidPayment.method);
                        h.paymentDate = paidPayment.paymentDate || paidPayment.createdAt;
                        h.month = paidPayment.month || getMonthKey(schedule.date);

                        if (haRecord && haRecord.paymentStatus !== 'Paid') {
                            await HouseAssignment.findByIdAndUpdate(haRecord._id, {
                                paymentStatus: 'Paid',
                                paymentMode: h.paymentMode,
                                paymentMethod: h.paymentMode,
                                paymentDate: h.paymentDate,
                                paidAt: h.paymentDate,
                                transactionId: paidPayment.transactionId,
                                amount: paidPayment.amount,
                                month: h.month
                            });
                        }
                    }
                    
                    h.collectionStatus = collectionStatus;
                    h.residentResponse = residentResponse;
                    h.availabilityDate = availabilityDate;
                    h.paymentMode = h.paymentMode || haRecord?.paymentMode;
                    h.paymentDate = h.paymentDate || haRecord?.paymentDate;
                    h.month = h.month || haRecord?.month;
                    a.house = h; // Put the cloned and updated house back into the assignment
                }
                visibleAssignments.push(a);
            }
            schedule.assignments = visibleAssignments;
        }

        res.json(schedules);
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// Bulk Add Houses to Route
router.post('/routes/:id/houses', authMiddleware(['admin']), async (req, res) => {
    const { houses, preserveRoute = false } = req.body;
    const routeId = req.params.id;
    try {
        const route = await Route.findById(routeId).populate('ward');
        if (!route) return res.status(404).json({ message: 'Route not found' });

        const savedHouses = [];
        const routesToResync = new Set();
        for (const h of houses) {
            const housePayload = {
                ownerName: h.name || h.ownerName || 'Resident',
                houseNumber: h.houseNumber,
                address: h.address || '',
                phoneNumber: h.phoneNumber || '',
                route: routeId,
                ward: route.ward?._id || null,
                wardNumber: route.ward?.wardNumber || '',
                resident: h.resident || null,
                collectionTime: h.collectionTime || '09:00 AM - 11:00 AM',
                wasteTypes: h.wasteTypes ? [h.wasteTypes] : ['General'],
            };

            const existingFilter = h.resident
                ? { resident: h.resident }
                : { houseNumber: h.houseNumber, ward: route.ward?._id || null };

            const existingHouse = await House.findOne(existingFilter);
            if (existingHouse?.route) {
                routesToResync.add(existingHouse.route.toString());
            }

            const house = await House.findOneAndUpdate(
                existingFilter,
                { $set: housePayload },
                { upsert: true, new: true, setDefaultsOnInsert: true }
            );
            savedHouses.push(house);
            routesToResync.add(routeId.toString());
        }
        
        // Link existing residents to these new houses
        for (const house of savedHouses) {
            let resident = null;
            
            // If the frontend sent an explicit resident ID, use it
            if (house.resident) {
                resident = await User.findById(house.resident);
            } 
            
            // Fallback: search by houseNumber if no resident was linked yet
            if (!resident) {
                resident = await User.findOne({ 
                    role: 'resident', 
                    houseNumber: house.houseNumber, 
                    ward: house.ward 
                });
            }

            if (resident) {
                house.resident = resident._id;
                await house.save();
                
                // Update resident's route and ward
                resident.route = house.route;
                resident.ward = house.ward;
                resident.house = house._id;
                resident.houseNumber = house.houseNumber;
                resident.address = house.address || resident.address;
                resident.phoneNumber = house.phoneNumber || resident.phoneNumber;
                resident.wardNumber = house.wardNumber || resident.wardNumber;
                await resident.save();

                const duplicateHouses = await House.find({
                    resident: resident._id,
                    _id: { $ne: house._id }
                }).select('route');
                duplicateHouses.forEach((duplicateHouse) => {
                    if (duplicateHouse.route) {
                        routesToResync.add(duplicateHouse.route.toString());
                    }
                });
                if (duplicateHouses.length > 0) {
                    await House.deleteMany({
                        resident: resident._id,
                        _id: { $ne: house._id }
                    });
                }
            }
        }

        const autoAssign = preserveRoute
            ? { updated: savedHouses.length, routes: 1, preservedRoute: true }
            : await autoAssignWardHousesToRoutes(route.ward?._id || route.ward);
        if (preserveRoute) {
            for (const syncRouteId of routesToResync) {
                const routeToSync = syncRouteId === route._id.toString()
                    ? route
                    : await Route.findById(syncRouteId);
                if (routeToSync) {
                    await syncRouteSchedulesForRange(
                        routeToSync._id,
                        routeToSync.startDate,
                        routeToSync.endDate,
                        routeToSync.assignedStaff
                    );
                }
            }
        }
        res.status(201).json({ 
            message: preserveRoute
                ? `${savedHouses.length} house(s) saved under this route.`
                : `${savedHouses.length} house(s) saved. Ward houses auto-assigned across ${autoAssign.routes} route(s).`, 
            houses: savedHouses,
            autoAssign
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// View Houses in Route (Enhanced with today's status)
router.get('/routes/:id/houses', authMiddleware(['admin', 'staff']), async (req, res) => {
    try {
        const houses = await House.find({ route: req.params.id }).sort({ houseNumber: 1 });
        
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const tomorrow = new Date(today);
        tomorrow.setDate(tomorrow.getDate() + 1);

        const CollectionLog = require('../models/CollectionLog');

        const enhancedHousesRaw = await Promise.all(houses.map(async (h) => {
            if (h.resident) {
                const linkedResident = await User.findById(h.resident).select('route');
                const residentRouteId = linkedResident?.route?.toString();
                if (residentRouteId && residentRouteId !== req.params.id) {
                    return null;
                }
            }

            let status = 'Pending';
            let response = 'Pending';

            // Try to find the log by house ID or resident ID
            const logFilter = {
                $or: [
                    { house: h._id },
                ],
                createdAt: { $gte: today, $lt: tomorrow }
            };

            let resId = h.resident;
            if (!resId) {
                // Fallback: search for resident by phone or house number
                const resUser = await User.findOne({ 
                    role: 'resident', 
                    $or: [
                        { phoneNumber: h.phoneNumber },
                        { houseNumber: h.houseNumber, wardNumber: h.wardNumber }
                    ]
                });
                if (resUser) resId = resUser._id;
            }

            if (resId) {
                logFilter.$or.push({ resident: resId });
            }

            const log = await CollectionLog.findOne(logFilter).sort({ createdAt: -1 });

            if (log) {
                status = log.status;
                response = log.residentResponse;
            }

            return {
                ...h.toObject(),
                collectionStatus: status,
                residentResponse: response
            };
        }));

        res.json(enhancedHousesRaw.filter(Boolean));
    } catch (error) {
        console.error('Error fetching houses in route:', error);
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
