const axios = require('axios');

const BASE_URL = 'http://localhost:5000/api';

async function run() {
    try {
        // 1. Login
        const loginRes = await axios.post(`${BASE_URL}/auth/admin/login`, {
            email: 'admin@system.com',
            password: 'admin123'
        });
        const token = loginRes.data.token;
        console.log('Logged in as Admin');

        // 2. Add Category - Plastic Waste
        const plasticRes = await axios.post(`${BASE_URL}/admin/categories`, {
            name: 'Plastic Waste',
            description: 'Recyclable plastics',
            icon: 'eco'
        }, { headers: { Authorization: `Bearer ${token}` } });
        console.log('Added category: Plastic Waste');

        // 3. Add Category - E-Waste
        const ewasteRes = await axios.post(`${BASE_URL}/admin/categories`, {
            name: 'E-Waste',
            description: 'Electronic waste',
            icon: 'memory'
        }, { headers: { Authorization: `Bearer ${token}` } });
        console.log('Added category: E-Waste');

        // 4. Create Schedule for April 2026, Ward 12
        const scheduleRes = await axios.post(`${BASE_URL}/admin/schedules`, {
            month: 4,
            year: 2026,
            wardNumber: '12',
            category: plasticRes.data._id,
            notes: 'Monthly plastic collection'
        }, { headers: { Authorization: `Bearer ${token}` } });
        console.log('Created schedule for April 2026, Ward 12');

        // 5. Create Staff - John Doe
        await axios.post(`${BASE_URL}/auth/staff/create`, {
            name: 'John Doe',
            email: 'john@staff.com',
            password: 'password123',
            wardNumber: '12',
            address: '123 Staff Street',
            phoneNumber: '9876543210'
        }, { headers: { Authorization: `Bearer ${token}` } });
        console.log('Created staff member: John Doe');

    } catch (error) {
        console.error('Error:', error.response ? error.response.data : error.message);
    }
}

run();
