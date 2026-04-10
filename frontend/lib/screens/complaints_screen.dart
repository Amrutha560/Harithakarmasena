import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  _ComplaintsScreenState createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _complaintController = TextEditingController();
  List<dynamic> _complaints = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchComplaints();
  }

  Future<void> _fetchComplaints() async {
    setState(() => _isLoading = true);
    final data = await _apiService.getMyComplaints();
    if (mounted) {
      setState(() {
        _complaints = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _submitComplaint() async {
    if (_complaintController.text.trim().isEmpty) return;
    
    setState(() => _isLoading = true);
    final result = await _apiService.fileComplaint(_complaintController.text);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Complaint submitted'),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _complaintController.clear();
      _tabController.animateTo(1); // Switch to "My Complaints" tab
      _fetchComplaints();
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF2E7D32);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1C1E), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Complaints', style: TextStyle(color: Color(0xFF1A1C1E), fontSize: 18, fontWeight: FontWeight.w900)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryGreen,
          unselectedLabelColor: Colors.black26,
          indicatorColor: primaryGreen,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          tabs: const [
            Tab(text: 'NEW COMPLAINT'),
            Tab(text: 'MY ISSUES'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewComplaintForm(primaryGreen),
          _buildComplaintsList(primaryGreen),
        ],
      ),
    );
  }

  Widget _buildNewComplaintForm(Color primaryGreen) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Describe your issue',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 1.5),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAF9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: TextField(
              controller: _complaintController,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Type your grievance here (e.g., Waste not collected, Payment issue...)',
                hintStyle: TextStyle(color: Colors.black26, fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(24),
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitComplaint,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('SUBMIT COMPLAINT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 24),
          _infoCard('Important', 'Our team typically resolves complaints within 24-48 working hours. You can track status in "My Issues" tab.'),
        ],
      ),
    );
  }

  Widget _buildComplaintsList(Color primaryGreen) {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: primaryGreen));
    if (_complaints.isEmpty) return _emptyState('No complaints filed yet');

    return RefreshIndicator(
      onRefresh: _fetchComplaints,
      color: primaryGreen,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _complaints.length,
        itemBuilder: (context, index) {
          final c = _complaints[index];
          final status = c['status'] ?? 'Pending';
          
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 15, offset: const Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statusBadge(status),
                    Text(
                      _formatDate(c['createdAt']),
                      style: const TextStyle(fontSize: 10, color: Colors.black26, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  c['description'] ?? 'No description',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1A1C1E), fontWeight: FontWeight.w600, height: 1.5),
                ),
                if (c['remarks'] != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F2), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('OFFICIAL REMARKS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: primaryGreen)),
                        const SizedBox(height: 4),
                        Text(c['remarks'], style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status) {
      case 'Resolved': color = const Color(0xFF2E7D32); break;
      case 'In Progress': color = Colors.orange; break;
      default: color = Colors.blueAccent;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _infoCard(String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.orange)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 11, color: Colors.black54, height: 1.4)),
        ],
      ),
    );
  }

  Widget _emptyState(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.black12),
          const SizedBox(height: 16),
          Text(text, style: const TextStyle(color: Colors.black26, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '--';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '--';
    return '${date.day}/${date.month}/${date.year}';
  }
}
