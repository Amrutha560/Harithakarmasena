import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'complaints_screen.dart';

class ResidentDashboard extends StatefulWidget {
  const ResidentDashboard({super.key});

  @override
  _ResidentDashboardState createState() => _ResidentDashboardState();
}

class _ResidentDashboardState extends State<ResidentDashboard> with SingleTickerProviderStateMixin {
  final ApiService apiService = ApiService();
  Map<String, dynamic>? dashboardData;
  bool isLoading = true;
  int _selectedNavIndex = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchDashboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDashboard() async {
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

  void _payCollectionFee() async {
    setState(() => isLoading = true);
    final result = await apiService.payFromWallet();
    if (mounted) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Payment error'),
          backgroundColor: result['message']?.contains('successful') == true ? const Color(0xFF2E7D32) : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _fetchDashboard();
    }
  }

  void _addMoney() async {
    setState(() => isLoading = true);
    final result = await apiService.addWalletMoney(50);
    if (mounted) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('₹50 added to your wallet!'), backgroundColor: Color(0xFF1976D2), behavior: SnackBarBehavior.floating),
      );
      _fetchDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = dashboardData?['user']?['name'] ?? 'Resident';
    final walletBalance = dashboardData?['walletBalance'] ?? 0;
    final collectionStatus = dashboardData?['collectionStatus'] ?? 'Pending';

    const primaryColor = Color(0xFF2E7D32);
    const accentColor = Color(0xFF00C853);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      
      // ── Bottom Navigation ──────────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, -5))],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedNavIndex,
          onTap: (i) => setState(() => _selectedNavIndex = i),
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.black26,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'HOME'),
            BottomNavigationBarItem(icon: Icon(Icons.notifications_none_rounded), label: 'NOTIFICATIONS'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: 'PROFILE'),
          ],
        ),
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : SafeArea(
              child: Column(
                children: [
                  // 🔝 TOP SECTION ────────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('WELCOME BACK', style: TextStyle(color: Colors.black26, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      userName.toUpperCase(),
                                      style: const TextStyle(color: Color(0xFF1A1C1E), fontSize: 20, fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(width: 4),
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'logout') _logout();
                                      },
                                      icon: const Icon(Icons.more_vert_rounded, color: Colors.black26),
                                      offset: const Offset(0, 40),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'logout',
                                          child: Row(
                                            children: [
                                              Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                                              SizedBox(width: 12),
                                              Text('LOGOUT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.redAccent)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            _collectionStatusCircle(collectionStatus),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1B5E20), primaryColor],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(color: primaryColor.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8)),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('WALLET BALANCE', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                                  const SizedBox(height: 4),
                                  Text('₹$walletBalance', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                                ],
                              ),
                              GestureDetector(
                                onTap: _addMoney,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                                  child: const Text('ADD MONEY', style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.w900)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 📊 TABS SECTION ───────────────────────────────────────────
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFFF1F5E4),
                        ),
                        labelColor: primaryColor,
                        unselectedLabelColor: Colors.black26,
                        labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        tabs: const [
                          Tab(text: 'HOME'),
                          Tab(text: 'WALLET'),
                          Tab(text: 'ALERTS'),
                          Tab(text: 'ISSUES'),
                        ],
                        onTap: (index) {
                          if (index == 3) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ComplaintsScreen()));
                          }
                        },
                      ),
                    ),
                  ),

                  // 🧱 GRID FEATURES ───────────────────────────────────────────
                  Expanded(
                    child: GridView.count(
                      padding: const EdgeInsets.all(24),
                      crossAxisCount: 3,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        _gridItem('ALERTS', Icons.notifications_rounded, Colors.blue, () {}),
                        _gridItem('WALLET', Icons.account_balance_wallet_rounded, Colors.orange, () {}),
                        _gridItem('STATUS', Icons.track_changes_rounded, accentColor, () {}),
                        _gridItem('ISSUES', Icons.report_problem_rounded, Colors.redAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ComplaintsScreen()))),
                        _gridItem('HISTORY', Icons.history_edu_rounded, Colors.purple, () {}),
                        _gridItem('SCHEDULE', Icons.calendar_month_rounded, Colors.indigo, () {}),
                        _gridItem('USAGE', Icons.bar_chart_rounded, Colors.cyan, () {}),
                        _gridItem('PROFILE', Icons.account_circle_rounded, primaryColor, () {}),
                        _gridItem('PAY ₹50', Icons.check_circle_rounded, primaryColor, _payCollectionFee),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _collectionStatusCircle(String status) {
    Color color;
    switch (status) {
      case 'Collected': color = const Color(0xFF2E7D32); break;
      case 'Not Collected': color = Colors.orange; break;
      case 'Not Cooperative': color = Colors.redAccent; break;
      default: color = Colors.blueGrey.shade100;
    }
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                value: status == 'Collected' ? 1.0 : (status == 'Pending' ? 0.3 : 1.0),
                strokeWidth: 5,
                backgroundColor: const Color(0xFFF1F5F9),
                color: color,
              ),
            ),
            Icon(Icons.refresh_rounded, color: color, size: 20),
          ],
        ),
        const SizedBox(height: 8),
        Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _gridItem(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))),
          ],
        ),
      ),
    );
  }
}
