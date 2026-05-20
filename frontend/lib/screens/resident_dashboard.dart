import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'complaints_screen.dart';
import 'resident_notification_screen.dart';
import 'collection_history_screen.dart';
import 'razorpay_payment_screen.dart';
import 'resident_schedule_screen.dart';

import 'resident_details_screen.dart';
import 'settings_screen.dart';
import 'change_password_screen.dart';
import 'support_screen.dart';
import 'about_us_screen.dart';

class ResidentDashboard extends StatefulWidget {
  const ResidentDashboard({super.key});

  @override
  _ResidentDashboardState createState() => _ResidentDashboardState();
}

class _ResidentDashboardState extends State<ResidentDashboard> {
  final ApiService apiService = ApiService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? dashboardData;
  bool isLoading = true;

  static const _primaryGreen = Color(0xFF1E6B3E);
  static const _accentGreen = Color(0xFF2E7D32);
  static const _bgColor = Color(0xFFF8FAF9);

  @override
  void initState() {
    super.initState();
    _redirectIfWrongRole();
    _fetchDashboard();
  }

  Future<void> _redirectIfWrongRole() async {
    final role = await apiService.getRole();
    if (!mounted || role == null || role == 'resident') return;

    if (role == 'staff') {
      Navigator.pushReplacementNamed(context, '/staff');
    } else if (role == 'admin') {
      Navigator.pushReplacementNamed(context, '/admin');
    }
  }

  Future<void> _fetchDashboard() async {
    setState(() => isLoading = true);
    try {
      final data = await apiService.getResidentDashboard();
      if (mounted) {
        setState(() {
          dashboardData = data;
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

  void _showAccountSheet() {
    final user = dashboardData?['user'] as Map<String, dynamic>? ?? {};
    final name =
        dashboardData?['residentName'] ??
        user['name'] ??
        '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    final residentName = (name.isEmpty || name == 'null') ? 'Resident' : name;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: _accentGreen.withOpacity(0.1),
                child: Text(
                  residentName[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: _accentGreen,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                residentName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                user['email']?.toString() ?? '',
                style: const TextStyle(color: Colors.black38),
              ),
              const SizedBox(height: 22),
              _profileRow('First name', user['firstName']),
              _profileRow('Last name', user['lastName']),
              _profileRow('Phone', user['phoneNumber']),
              _profileRow(
                'House number',
                user['houseNumber'] ?? dashboardData?['houseNumber'],
              ),
              _profileRow(
                'Address',
                user['address'] ?? dashboardData?['address'],
              ),
              _profileRow('District', user['district']),
              _profileRow('LSGI type', user['lsgiType']),
              _profileRow('LSGI name', user['lsgiName']),
              _profileRow(
                'Ward',
                user['wardName'] ??
                    'Ward ${dashboardData?['wardNumber'] ?? ''}',
              ),
              _profileRow('Route', dashboardData?['routeName']),
              _profileRow(
                'Approval status',
                user['isApproved'] == true ? 'Approved' : 'Pending',
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditProfileDialog();
                      },
                      icon: const Icon(Icons.edit_rounded, color: Colors.white),
                      label: const Text(
                        'Edit Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentGreen,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                      label: const Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileRow(String label, dynamic value) {
    final text = value?.toString().trim() ?? '';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6EFE8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black45,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text.isEmpty ? 'Not provided' : text,
              style: const TextStyle(
                color: Color(0xFF1A1C1E),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    final user = dashboardData?['user'] as Map<String, dynamic>? ?? {};
    final firstName = TextEditingController(
      text: user['firstName']?.toString() ?? '',
    );
    final lastName = TextEditingController(
      text: user['lastName']?.toString() ?? '',
    );
    final phone = TextEditingController(
      text: user['phoneNumber']?.toString() ?? '',
    );
    final houseNumber = TextEditingController(
      text:
          user['houseNumber']?.toString() ??
          dashboardData?['houseNumber']?.toString() ??
          '',
    );
    final address = TextEditingController(
      text:
          user['address']?.toString() ??
          dashboardData?['address']?.toString() ??
          '',
    );
    final district = TextEditingController(
      text: user['district']?.toString() ?? '',
    );
    final lsgiType = TextEditingController(
      text: user['lsgiType']?.toString() ?? '',
    );
    final lsgiName = TextEditingController(
      text: user['lsgiName']?.toString() ?? '',
    );
    bool saving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Edit Profile',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _editField(firstName, 'First name'),
                  _editField(lastName, 'Last name'),
                  _editField(phone, 'Phone number'),
                  _editField(houseNumber, 'House number'),
                  _editField(address, 'Address', maxLines: 2),
                  _editField(district, 'District'),
                  _editField(lsgiType, 'LSGI type'),
                  _editField(lsgiName, 'LSGI name'),
                  const Text(
                    'Ward and route are managed by admin and cannot be changed here.',
                    style: TextStyle(
                      color: Colors.black45,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      final result = await apiService.updateResidentProfile({
                        'firstName': firstName.text,
                        'lastName': lastName.text,
                        'phoneNumber': phone.text,
                        'houseNumber': houseNumber.text,
                        'address': address.text,
                        'district': district.text,
                        'lsgiType': lsgiType.text,
                        'lsgiName': lsgiName.text,
                      });
                      if (!mounted) return;
                      setDialogState(() => saving = false);
                      if (result['message']?.toString().toLowerCase().contains(
                            'success',
                          ) ==
                          true) {
                        Navigator.pop(context);
                        await _fetchDashboard();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile updated'),
                            backgroundColor: _accentGreen,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              result['message']?.toString() ??
                                  'Could not update profile',
                            ),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: _accentGreen),
              child: Text(
                saving ? 'Saving...' : 'Save',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF7FAF8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _bgColor,
      drawer: _buildDrawer(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _accentGreen))
          : _buildBody(),
    );
  }

  Widget _buildDrawer() {
    final name =
        dashboardData?['residentName'] ??
        dashboardData?['user']?['name'] ??
        '${dashboardData?['user']?['firstName'] ?? ''} ${dashboardData?['user']?['lastName'] ?? ''}'
            .trim();
    final residentName = (name.isEmpty || name == 'null') ? 'Resident' : name;
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: _primaryGreen),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                residentName[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _primaryGreen,
                ),
              ),
            ),
            accountName: Text(
              residentName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(dashboardData?['user']?['email'] ?? ''),
          ),
          _drawerItem(Icons.home_rounded, 'Home', () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ResidentDetailsScreen()),
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

  Widget _buildBody() {
    final name =
        dashboardData?['residentName'] ??
        dashboardData?['user']?['name'] ??
        '${dashboardData?['user']?['firstName'] ?? ''} ${dashboardData?['user']?['lastName'] ?? ''}'
            .trim();

    // Explicitly handle 'Resident' as a generic fallback
    final residentName = (name.isEmpty || name == 'null' || name == 'Resident')
        ? (dashboardData?['user']?['phoneNumber'] ?? 'Resident')
        : name;
    final paymentStatus = dashboardData?['paymentStatus'] ?? 'Pending';
    final staffAssignedDatesLabel = _formatStaffAssignedDates();
    final wasteTypes =
        (dashboardData?['assignedWasteTypes'] as List<dynamic>? ?? [])
            .where((item) => item != null && item.toString().trim().isNotEmpty)
            .join(', ');

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _fetchDashboard,
        color: _accentGreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 20, 24, 40),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryGreen, _accentGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.menu_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: () =>
                              _scaffoldKey.currentState?.openDrawer(),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.notifications_none_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const ResidentNotificationScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello,',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            residentName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            dashboardData?['houseNumber'] != null
                                ? 'House ${dashboardData?['houseNumber']}'
                                : 'Resident Dashboard',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.76),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 760;
                            final assignedCards = [
                              _buildStatCard(
                                Icons.calendar_today_rounded,
                                'Staff Assigned Dates',
                                staffAssignedDatesLabel,
                                _accentGreen,
                              ),
                              _buildStatCard(
                                Icons.route_rounded,
                                'Route',
                                dashboardData?['routeName'] ?? 'Route pending',
                                const Color(0xFF0277BD),
                              ),
                            ];

                            if (!isWide) {
                              return Column(
                                children: [
                                  assignedCards[0],
                                  const SizedBox(height: 14),
                                  assignedCards[1],
                                ],
                              );
                            }

                            return GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 3.1,
                              children: assignedCards,
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        _buildSchedulePanel(
                          paymentStatus: paymentStatus,
                          wasteTypes: wasteTypes.isEmpty
                              ? 'No waste type assigned'
                              : wasteTypes,
                          routeName:
                              dashboardData?['routeName'] ?? 'Route pending',
                          address:
                              dashboardData?['address'] ?? 'Address pending',
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          "Our Services",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1C1E),
                          ),
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 760;
                            return GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: isWide ? 3 : 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: isWide ? 2.45 : 1.35,
                              children: [
                                _buildGridItem(
                                  Icons.calendar_month_rounded,
                                  "Schedules",
                                  "View pickup date and time",
                                  Colors.green,
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ResidentScheduleScreen(),
                                      ),
                                    );
                                  },
                                ),
                                _buildGridItem(
                                  Icons.report_problem_rounded,
                                  "Complaints",
                                  "Report a collection issue",
                                  Colors.orange,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ComplaintsScreen(),
                                    ),
                                  ),
                                ),
                                _buildGridItem(
                                  Icons.payments_rounded,
                                  "Payments",
                                  "Pay service charges",
                                  Colors.purple,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => RazorpayPaymentScreen(
                                        dashboardData: dashboardData ?? {},
                                      ),
                                    ),
                                  ),
                                ),
                                _buildGridItem(
                                  Icons.history_rounded,
                                  "History",
                                  "Check past collections",
                                  Colors.blue,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const CollectionHistoryScreen(),
                                    ),
                                  ),
                                ),
                                _buildGridItem(
                                  Icons.person_rounded,
                                  "Account",
                                  "Profile and logout",
                                  Colors.teal,
                                  _showAccountSheet,
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDashboardDate(dynamic value) {
    try {
      final date = DateTime.parse(value.toString());
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return value.toString();
    }
  }

  String _formatStaffAssignedDates() {
    final rawVisitDates =
        dashboardData?['staffVisitDates'] as List<dynamic>? ?? [];
    final dates = <DateTime>[];

    for (final item in rawVisitDates) {
      final rawDate = item is Map ? item['date'] : item;
      if (rawDate == null || rawDate.toString().isEmpty) continue;
      try {
        dates.add(DateTime.parse(rawDate.toString()));
      } catch (_) {}
    }

    final singleDate = rawVisitDates.isEmpty
        ? (dashboardData?['staffVisitDate'] ?? dashboardData?['assignedDate'])
        : null;
    if (singleDate != null && singleDate.toString().isNotEmpty) {
      try {
        final parsed = DateTime.parse(singleDate.toString());
        if (!dates.any(
          (date) =>
              date.year == parsed.year &&
              date.month == parsed.month &&
              date.day == parsed.day,
        )) {
          dates.add(parsed);
        }
      } catch (_) {}
    }

    if (dates.isEmpty) return 'Pending';
    dates.sort((a, b) => a.compareTo(b));

    final groupedByMonth = <String, List<int>>{};
    for (final date in dates) {
      final key = '${_shortMonthName(date.month)} ${date.year}';
      groupedByMonth.putIfAbsent(key, () => []).add(date.day);
    }

    return groupedByMonth.entries
        .map((entry) {
          final days = entry.value.toSet().toList()..sort();
          return '${days.join(', ')} ${entry.key}';
        })
        .join(' | ');
  }

  String _shortMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  Widget _buildStatCard(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: 142),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAF0EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1C1E),
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black45,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulePanel({
    required String paymentStatus,
    required String wasteTypes,
    required String routeName,
    required String address,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEAF0EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: _accentGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.recycling_rounded, color: _accentGreen),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Collection Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1C1E),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: paymentStatus == 'Paid'
                      ? _accentGreen.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  paymentStatus,
                  style: TextStyle(
                    color: paymentStatus == 'Paid'
                        ? _accentGreen
                        : Colors.orange[800],
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _overviewChip(Icons.delete_outline_rounded, wasteTypes),
              _overviewChip(Icons.route_rounded, routeName),
              _overviewChip(Icons.home_work_outlined, address),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStaffVisitCalendar() {
    final rawVisitDate = dashboardData?['staffVisitDate'];
    final rawVisitDates =
        dashboardData?['staffVisitDates'] as List<dynamic>? ?? [];
    final routeName =
        dashboardData?['staffVisitRouteName'] ??
        dashboardData?['routeName'] ??
        'Assigned route';
    final visitDates = <DateTime>[];
    for (final item in rawVisitDates) {
      final rawDate = item is Map ? item['date'] : item;
      if (rawDate == null || rawDate.toString().isEmpty) continue;
      try {
        visitDates.add(DateTime.parse(rawDate.toString()));
      } catch (_) {}
    }
    DateTime? visitDate;
    if (rawVisitDate != null && rawVisitDate.toString().isNotEmpty) {
      try {
        visitDate = DateTime.parse(rawVisitDate.toString());
        if (!visitDates.any(
          (date) =>
              date.year == visitDate!.year &&
              date.month == visitDate.month &&
              date.day == visitDate.day,
        )) {
          visitDates.add(visitDate);
        }
      } catch (_) {}
    }

    visitDates.sort((a, b) => a.compareTo(b));
    final baseDate = visitDates.isNotEmpty ? visitDates.first : DateTime.now();
    final visitDateKeys = visitDates
        .map((date) => '${date.year}-${date.month}-${date.day}')
        .toSet();
    final firstOfMonth = DateTime(baseDate.year, baseDate.month, 1);
    final daysInMonth = DateTime(baseDate.year, baseDate.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday % 7;
    final rowCount = ((leadingBlanks + daysInMonth) / 7).ceil();
    final monthLabel = '${_monthName(baseDate.month)} ${baseDate.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEAF0EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: Color(0xFFC62828),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Staff Assigned Calendar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1C1E),
                      ),
                    ),
                    Text(
                      visitDate == null
                          ? 'Staff visit date not marked yet'
                          : '$routeName - ${visitDates.length} date${visitDates.length == 1 ? '' : 's'} marked',
                      style: const TextStyle(
                        color: Colors.black45,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            monthLabel,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1C1E),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.black38,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          ...List.generate(rowCount, (row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: List.generate(7, (col) {
                  final cellIndex = row * 7 + col;
                  final dayNumber = cellIndex - leadingBlanks + 1;
                  if (dayNumber < 1 || dayNumber > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 34));
                  }
                  final isVisitDate =
                      visitDate != null &&
                      visitDateKeys.contains(
                        '${baseDate.year}-${baseDate.month}-$dayNumber',
                      );

                  return Expanded(
                    child: Container(
                      height: 34,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isVisitDate
                            ? const Color(0xFFFFCDD2)
                            : const Color(0xFFF8FAF9),
                        borderRadius: BorderRadius.circular(10),
                        border: isVisitDate
                            ? Border.all(
                                color: const Color(0xFFC62828),
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: Text(
                        '$dayNumber',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: isVisitDate
                              ? const Color(0xFFC62828)
                              : Colors.black54,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  Widget _overviewChip(IconData icon, String text) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 340),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: _accentGreen),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF333D36),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(
    IconData icon,
    String label,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEAF0EC)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1C1E),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black45, height: 1.25),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
