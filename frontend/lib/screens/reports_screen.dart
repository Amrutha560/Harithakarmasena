import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final stats = await _apiService.getAdminStats();
    setState(() {
      _stats = stats;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1C1E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Analytical Reports', style: TextStyle(color: Color(0xFF1A1C1E), fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummarySection(),
                  const SizedBox(height: 32),
                  _buildChartSection(),
                  const SizedBox(height: 32),
                  _buildRevenueCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('System Summary', style: TextStyle(color: Color(0xFF1A1C1E), fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.25,
          children: [
            _buildSmallStatCard('Residents', (_stats['totalResidents'] ?? 0).toString(), Icons.home_rounded, const Color(0xFF1976D2)),
            _buildSmallStatCard('Staff', (_stats['totalStaff'] ?? 0).toString(), Icons.badge_outlined, const Color(0xFF2E7D32)),
            _buildSmallStatCard('Complaints', (_stats['pendingComplaints'] ?? 0).toString(), Icons.feedback_outlined, const Color(0xFFE53935)),
            _buildSmallStatCard('Issues', (_stats['nonCooperativeHouses'] ?? 0).toString(), Icons.block_flipped, const Color(0xFF9E9E9E)),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(color: Color(0xFF1A1C1E), fontSize: 20, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Distribution', style: TextStyle(color: Color(0xFF1A1C1E), fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Operational Breakdown', style: TextStyle(color: Colors.black38, fontSize: 12)),
          const SizedBox(height: 40),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 8,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    color: const Color(0xFF1976D2),
                    value: (_stats['totalResidents'] ?? 1).toDouble(),
                    title: '',
                    radius: 50,
                  ),
                  PieChartSectionData(
                    color: const Color(0xFF2E7D32),
                    value: (_stats['totalStaff'] ?? 0).toDouble(),
                    title: '',
                    radius: 50,
                  ),
                  PieChartSectionData(
                    color: const Color(0xFFE53935),
                    value: (_stats['pendingComplaints'] ?? 0).toDouble(),
                    title: '',
                    radius: 50,
                  ),
                  PieChartSectionData(
                    color: const Color(0xFF9E9E9E),
                    value: (_stats['nonCooperativeHouses'] ?? 0).toDouble(),
                    title: '',
                    radius: 50,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildLegendRow('Residents', const Color(0xFF1976D2)),
          _buildLegendRow('Staff', const Color(0xFF2E7D32)),
          _buildLegendRow('Complaints', const Color(0xFFE53935)),
          _buildLegendRow('Service Issues', const Color(0xFF9E9E9E)),
        ],
      ),
    );
  }

  Widget _buildChartBadge(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: Icon(icon, size: 12, color: Color(0xFF1A1C1E)),
    );
  }

  Widget _buildLegendRow(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.black87, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildRevenueCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE8F5E9).withOpacity(0.5),
            Colors.white,
          ],
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF2E7D32), size: 32),
          const SizedBox(height: 24),
          const Text('Total Collected Revenue', style: TextStyle(color: Colors.black54, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            '₹${_stats['totalRevenue'] ?? 0}',
            style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 42, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(30)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sync, color: Color(0xFF2E7D32), size: 14),
                SizedBox(width: 8),
                Text('Real-time updates', style: TextStyle(color: Color(0xFF2E7D32), fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
