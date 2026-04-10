import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import 'create_staff_screen.dart';
import 'ward_management_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final ApiService apiService = ApiService();
  List<dynamic> staffMembers = [];
  Map<String, dynamic> stats = {};
  bool isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  void _fetchDashboardData() async {
    final fetchedStaff = await apiService.getStaff();
    final fetchedStats = await apiService.getAdminStats();
    setState(() {
      staffMembers = fetchedStaff;
      stats = fetchedStats;
      isLoading = false;
    });
  }

  void _logout() async {
    await apiService.logout();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9), // Light background
      body: Row(
        children: [
          // Sidebar
          _buildSidebar(),
          // Main Content
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Overview',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1C1E), // Dark text
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Real-time waste management monitoring',
                          style: TextStyle(color: Colors.black45, fontSize: 16),
                        ),
                        const SizedBox(height: 40),
                        // Stats Grid
                        _buildStatsGrid(),
                        const SizedBox(height: 40),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Revenue Chart Card
                            Expanded(flex: 3, child: _buildRevenueChartCard()),
                            const SizedBox(width: 32),
                            // Staff List Section
                            Expanded(flex: 2, child: _buildRecentStaffList()),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final List<Map<String, dynamic>> menuItems = [
      {'icon': Icons.grid_view_rounded, 'label': 'Dashboard'},
      {'icon': Icons.people_outline, 'label': 'Residents'},
      {'icon': Icons.business_outlined, 'label': 'Staff', 'isParent': true},
      {'icon': Icons.map_outlined, 'label': 'Wards & Routes'},
      {'icon': Icons.calendar_month_outlined, 'label': 'Scheduling'},
      {'icon': Icons.report_problem_outlined, 'label': 'Complaints'},
      {'icon': Icons.bar_chart_rounded, 'label': 'Reports'},
    ];

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.black.withOpacity(0.05))),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                  child: const Icon(Icons.eco, color: Color(0xFF2E7D32), size: 24),
                ),
                const SizedBox(width: 16),
                const Text('Harithakarma', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E), letterSpacing: 0.5)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                bool isSelected = _selectedIndex == index;

                if (item['isParent'] == true) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        leading: Icon(item['icon'], color: isSelected ? const Color(0xFF2E7D32) : Colors.black38),
                        title: Text(item['label'], style: TextStyle(color: isSelected ? Colors.black : Colors.black38, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.only(left: 48),
                            title: const Text('Staff List', style: TextStyle(fontSize: 13, color: Colors.black54)),
                            onTap: () {
                              setState(() => _selectedIndex = index);
                              Navigator.pushNamed(context, '/admin/staff');
                            },
                          ),
                          ListTile(
                            contentPadding: const EdgeInsets.only(left: 48),
                            title: const Text('Add Staff', style: TextStyle(fontSize: 13, color: Colors.black54)),
                            onTap: () {
                              setState(() => _selectedIndex = index);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateStaffScreen())).then((_) => _fetchDashboardData());
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: ListTile(
                    onTap: () {
                      setState(() => _selectedIndex = index);
                      if (index == 1) Navigator.pushNamed(context, '/admin/users');
                      if (index == 3) Navigator.push(context, MaterialPageRoute(builder: (_) => const WardManagementScreen()));
                      if (index == 4) Navigator.pushNamed(context, '/admin/scheduling');
                      if (index == 5) Navigator.pushNamed(context, '/admin/complaints');
                      if (index == 6) Navigator.pushNamed(context, '/admin/reports');
                    },
                    leading: Icon(item['icon'], color: isSelected ? const Color(0xFF2E7D32) : Colors.black38),
                    title: Text(item['label'], style: TextStyle(color: isSelected ? Colors.black : Colors.black38, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: isSelected ? const Color(0xFFE8F5E9) : Colors.transparent,
                  ),
                );
              },
            ),
          ),
          const Divider(color: Colors.black12, indent: 24, endIndent: 24),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ListTile(
              onTap: _logout,
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const TextField(
                style: TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Search data, residents or staff...',
                  hintStyle: TextStyle(color: Colors.black26),
                  prefixIcon: Icon(Icons.search, color: Colors.black26),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 32),
          _topBarIcon(Icons.notifications_none_rounded),
          const SizedBox(width: 16),
          _topBarIcon(Icons.settings_outlined),
          const SizedBox(width: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7F6),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.person, color: Color(0xFF2E7D32), size: 18),
                ),
                SizedBox(width: 12),
                Text(
                  'Super Admin',
                  style: TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.bold, fontSize: 13),
                ),
                SizedBox(width: 8),
                Icon(Icons.keyboard_arrow_down, color: Colors.black26, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBarIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.black54, size: 20),
    );
  }

  Widget _buildStatsGrid() {
    final List<Map<String, dynamic>> metricItems = [
      {'label': 'Residents', 'value': stats['totalResidents']?.toString() ?? '0', 'trend': '+12%', 'icon': Icons.people_alt_outlined},
      {'label': 'Staff', 'value': stats['totalStaff']?.toString() ?? '0', 'trend': 'Active', 'icon': Icons.badge_outlined},
      {'label': 'Revenue', 'value': '₹${stats['totalRevenue']?.toString() ?? '0'}', 'trend': '+8%', 'icon': Icons.account_balance_wallet_outlined},
      {'label': 'Complaints', 'value': stats['pendingComplaints']?.toString() ?? '0', 'trend': 'Pending', 'icon': Icons.error_outline_rounded},
      {'label': 'System Users', 'value': stats['totalUsers']?.toString() ?? '0', 'trend': 'Online', 'icon': Icons.hub_outlined},
    ];

    return Row(
      children: metricItems.map((item) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item['icon'], color: const Color(0xFF2E7D32), size: 20),
              ),
              const SizedBox(height: 20),
              Text(
                item['value'],
                style: const TextStyle(color: Color(0xFF1A1C1E), fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item['label'], style: const TextStyle(color: Colors.black45, fontSize: 13)),
                  Text(
                    item['trend'],
                    style: TextStyle(
                      color: item['trend'].startsWith('+') ? const Color(0xFF2E7D32) : Colors.black38,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildRevenueChartCard() {
    return Container(
      height: 420,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Collection Analytics',
                    style: TextStyle(color: Color(0xFF1A1C1E), fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text('Weekly performance metrics', style: TextStyle(color: Colors.black38, fontSize: 13)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Text('This Week', style: TextStyle(color: Colors.black54, fontSize: 12)),
                    SizedBox(width: 8),
                    Icon(Icons.keyboard_arrow_down, color: Colors.black26, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => const FlLine(color: Colors.black12, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(days[value.toInt()], style: const TextStyle(color: Colors.black38, fontSize: 11)),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(value.toInt().toString(), style: const TextStyle(color: Colors.black38, fontSize: 11));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 180),
                      FlSpot(1, 240),
                      FlSpot(2, 210),
                      FlSpot(3, 300),
                      FlSpot(4, 280),
                      FlSpot(5, 350),
                      FlSpot(6, 310),
                    ],
                    isCurved: true,
                    color: const Color(0xFF2E7D32),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF2E7D32).withOpacity(0.1),
                          const Color(0xFF2E7D32).withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentStaffList() {
    return Container(
      height: 420,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top Staff',
                style: TextStyle(color: Color(0xFF1A1C1E), fontSize: 20, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CreateStaffScreen()))
                      .then((value) => _fetchDashboardData());
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
                : ListView.builder(
                    itemCount: staffMembers.length > 5 ? 5 : staffMembers.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: Row(
                          children: [
                            Container(
                              height: 48,
                              width: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F7F6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.person_outline, color: Color(0xFF2E7D32)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    staffMembers[index]['name'],
                                    style: const TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    staffMembers[index]['email'],
                                    style: const TextStyle(color: Colors.black26, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Active',
                                style: TextStyle(color: Color(0xFF2E7D32), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pushNamed(context, '/admin/staff'),
              child: const Text('View All Staff', style: TextStyle(color: Color(0xFF2E7D32), fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
