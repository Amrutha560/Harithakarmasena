import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'staff_routes_list_screen.dart';
import 'staff_schedule_screen.dart';
import 'staff_profile_screen.dart';
import 'settings_screen.dart';
import 'change_password_screen.dart';
import 'support_screen.dart';
import 'about_us_screen.dart';

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  _StaffDashboardState createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  final ApiService apiService = ApiService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? dashboardData;
  Map<String, dynamic>? reportStats;
  List<dynamic> assignedResidents = [];
  bool isLoading = true;
  int _selectedNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _redirectIfWrongRole();
    _fetchDashboard();
  }

  Future<void> _redirectIfWrongRole() async {
    final role = await apiService.getRole();
    if (!mounted || role == null || role == 'staff') return;

    if (role == 'resident') {
      Navigator.pushReplacementNamed(context, '/resident');
    } else if (role == 'admin') {
      Navigator.pushReplacementNamed(context, '/admin');
    }
  }

  Future<void> _fetchDashboard() async {
    try {
      final results = await Future.wait([
        apiService.getStaffDashboard(),
        apiService.getDailyReport(),
      ]);
      final data = results[0];
      final report = results[1];
      final residents = await apiService.getAssignedResidents();
      if (mounted) {
        setState(() {
          dashboardData = data;
          reportStats = report['stats'];
          assignedResidents = residents;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _logout() async {
    await apiService.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00C853)),
        ),
      );
    }

    final staffName = dashboardData?['user']?['name'] ?? 'Staff Member';
    final staffWard = dashboardData?['user']?['wardNumber'] ?? '5';

    const primaryGreen = Color(0xFF00C853);
    const accentPurple = Color(0xFF6200EA);

    final routesList = dashboardData?['routes'] as List<dynamic>? ?? [];
    final monthlySchedules = dashboardData?['monthlySchedules'] as List<dynamic>? ?? [];
    int routeCount = routesList.length;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryGreen.withOpacity(0.05),
              accentPurple.withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 🔝 TOP NEUMORPHIC HEADER ───────────────────────────────────────
              _buildHeader(staffName, staffWard, primaryGreen, accentPurple),

              // 📊 SUMMARY STRIP ───────────────────────────────────────────────
              _buildSummaryStrip(primaryGreen, accentPurple),

              // 📅 CALENDAR STRIP REMOVED
              // _buildWeeklyCalendar(primaryGreen, routesList, staffName),

              // 🧱 NEUMORPHIC GRID ─────────────────────────────────────────────
              Expanded(
                child: GridView.count(
                  padding: const EdgeInsets.all(24),
                  crossAxisCount: 2,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  children: [
                    _neumorphicItem(
                      'MY ROUTES\n($routeCount)',
                      Icons.map_rounded,
                      primaryGreen,
                      () {
                        if (routesList.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StaffRoutesListScreen(
                                routes: routesList,
                                staffName: staffName,
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'No route assigned yet. Contact admin.',
                              ),
                              backgroundColor: Colors.orangeAccent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                    _scheduleItem(routesList, staffName, accentPurple, monthlySchedules),
                    _neumorphicItem(
                      'REPORTS',
                      Icons.bar_chart_rounded,
                      Colors.indigo,
                      () => _showReportDialog(context, primaryGreen),
                    ),
                    _neumorphicItem(
                      'RESIDENTS\n(${assignedResidents.length})',
                      Icons.people_alt_rounded,
                      Colors.teal,
                      () => _showResidentsDialog(context, primaryGreen),
                    ),
                    _neumorphicItem(
                      'COMPLAINTS',
                      Icons.bug_report_rounded,
                      Colors.redAccent,
                      () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(primaryGreen),
    );
  }

  Widget _buildDrawer() {
    final name = dashboardData?['user']?['name'] ?? 'Staff Member';
    const primaryGreen = Color(0xFF00C853);

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: primaryGreen),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryGreen,
                ),
              ),
            ),
            accountName: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(dashboardData?['user']?['email'] ?? ''),
          ),
          _drawerItem(Icons.home_rounded, 'Home', () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StaffProfileScreen()),
            );
          }),
          _drawerItem(Icons.settings_rounded, 'Settings', () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          }),
          _drawerItem(Icons.lock_reset_rounded, 'Change Password', () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            );
          }),
          _drawerItem(Icons.help_outline_rounded, 'Help & Support', () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupportScreen()),
            );
          }),
          _drawerItem(Icons.info_outline_rounded, 'About Us', () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutUsScreen()),
            );
          }),
          const Spacer(),
          const Divider(),
          _drawerItem(
            Icons.logout_rounded,
            'Logout',
            _logout,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _drawerItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.black87),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color ?? Colors.black87,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildHeader(String name, String ward, Color green, Color purple) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F2),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.white,
            offset: const Offset(-8, -8),
            blurRadius: 15,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(8, 8),
            blurRadius: 15,
          ),
        ],
      ),
      child: Row(
        children: [
          _iconButton(
            Icons.menu_rounded,
            green,
            () => _scaffoldKey.currentState?.openDrawer(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2E7D32),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          _iconButton(Icons.logout_rounded, Colors.redAccent, _logout),
        ],
      ),
    );
  }

  Widget _buildSummaryStrip(Color green, Color purple) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _miniSummary(
              'Houses',
              '${reportStats?['totalHouses'] ?? 0}',
              green,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _miniSummary(
              'Collected',
              '${reportStats?['totalCollected'] ?? 0}',
              purple,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _miniSummary(
              'Issues',
              '${reportStats?['totalNotCooperative'] ?? 0}',
              Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniSummary(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F2),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.white,
            offset: const Offset(-4, -4),
            blurRadius: 10,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(4, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: Colors.black26,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _neumorphicItem(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F2),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.white,
              offset: const Offset(-8, -8),
              blurRadius: 15,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(8, 8),
              blurRadius: 15,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1C1E),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scheduleItem(List<dynamic> routes, String staffName, Color color, List<dynamic> monthlySchedules) {
    return InkWell(
      onTap: () {
        if (routes.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StaffScheduleScreen(
                routes: routes,
                staffName: staffName,
                monthlySchedules: monthlySchedules,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No schedule assigned yet.'),
              backgroundColor: Colors.orangeAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F2),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.white,
              offset: const Offset(-8, -8),
              blurRadius: 15,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(8, 8),
              blurRadius: 15,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_rounded, color: color, size: 32),
            const SizedBox(height: 12),
            const Text(
              'SCHEDULE',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1C1E),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F2),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.white,
              offset: const Offset(-4, -4),
              blurRadius: 10,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(4, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildBottomNav(Color primary) {
    return Container(
      height: 70,
      margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F2),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.white,
            offset: const Offset(-8, -8),
            blurRadius: 15,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(8, 8),
            blurRadius: 15,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navIcon(Icons.dashboard_rounded, 0, primary),
          _navIcon(Icons.notifications_active_rounded, 1, primary),
          _navIcon(Icons.person_rounded, 2, primary),
        ],
      ),
    );
  }

  Widget _navIcon(IconData icon, int index, Color primary) {
    bool isSelected = _selectedNavIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedNavIndex = index),
      child: Icon(icon, color: isSelected ? primary : Colors.black26, size: 24),
    );
  }

  void _showNotifyDialog(BuildContext context, Color primary) {
    final dateController = TextEditingController(text: 'Tomorrow');
    final timeController = TextEditingController(text: '09:00 AM');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF0F4F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        title: const Text(
          'Send Alert',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _neumorphicField('Date', dateController),
            const SizedBox(height: 16),
            _neumorphicField('Time', timeController),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              apiService.notifyWard(
                (dashboardData?['user']?['wardNumber'] ?? '').toString(),
                message:
                    'Collection at ${dateController.text} ${timeController.text}',
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('SEND', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _neumorphicField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.black26,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4F2),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.white,
                offset: const Offset(-2, -2),
                blurRadius: 5,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(2, 2),
                blurRadius: 5,
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
      ],
    );
  }

  void _showReportDialog(BuildContext context, Color primary) async {
    final report = await apiService.getDailyReport();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF0F4F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        title: const Text(
          'Daily Summary',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _reportRow('Total Houses', '${report['stats']['totalHouses']}'),
            _reportRow('Collected', '${report['stats']['totalCollected']}'),
            _reportRow('Issues', '${report['stats']['totalNotCooperative']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _reportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black45,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyCalendar(
    Color primary,
    List<dynamic> routes,
    String staffName,
  ) {
    const List<String> weekDays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final int currentWeekday = DateTime.now().weekday; // 1 = Monday, 7 = Sunday

    return Container(
      height: 90,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, index) {
          final String dayName = weekDays[index];
          final bool isToday = (index + 1) == currentWeekday;

          // Check if any route is assigned for this day
          final bool hasRoute = routes.any(
            (r) => (r['collectionDays'] ?? []).contains(dayName),
          );

          return GestureDetector(
            onTap: () {
              if (hasRoute) {
                // If they click a marked day, navigate
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StaffRoutesListScreen(
                      routes: routes,
                      staffName: staffName,
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('No routes assigned for $dayName.'),
                    backgroundColor: Colors.orangeAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Container(
              width: 60,
              margin: const EdgeInsets.only(right: 12, bottom: 8, top: 4),
              decoration: BoxDecoration(
                color: isToday ? Colors.white : const Color(0xFFF0F4F2),
                borderRadius: BorderRadius.circular(16),
                border: isToday
                    ? Border.all(color: primary.withOpacity(0.3), width: 1.5)
                    : Border.all(color: Colors.transparent),
                boxShadow: isToday
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          offset: const Offset(4, 4),
                          blurRadius: 10,
                        ),
                        const BoxShadow(
                          color: Colors.white,
                          offset: Offset(-4, -4),
                          blurRadius: 10,
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayName.substring(0, 3).toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isToday ? primary : Colors.black38,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: hasRoute ? primary : Colors.black12,
                      shape: BoxShape.circle,
                      boxShadow: hasRoute && isToday
                          ? [
                              BoxShadow(
                                color: primary.withOpacity(0.4),
                                blurRadius: 6,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showResidentsDialog(BuildContext context, Color primary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF0F4F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        title: const Text(
          'Registered Residents',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: assignedResidents.isEmpty
              ? const Center(
                  child: Text('No residents assigned to your routes.'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: assignedResidents.length,
                  itemBuilder: (context, index) {
                    final res = assignedResidents[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'H.No: ${res['houseNumber'] ?? 'N/A'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                          Text(
                            '${res['firstName'] ?? ''} ${res['lastName'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            res['address'] ?? 'No address',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }
}
