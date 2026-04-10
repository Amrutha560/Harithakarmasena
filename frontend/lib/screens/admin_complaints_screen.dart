import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminComplaintsScreen extends StatefulWidget {
  const AdminComplaintsScreen({super.key});

  @override
  _AdminComplaintsScreenState createState() => _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends State<AdminComplaintsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _complaints = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchComplaints();
  }

  Future<void> _fetchComplaints() async {
    setState(() => _isLoading = true);
    final data = await _apiService.getAllComplaints();
    setState(() {
      _complaints = data;
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
        title: const Text('Resident Complaints', style: TextStyle(color: Color(0xFF1A1C1E), fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Recent Issues (${_complaints.length})',
                    style: const TextStyle(color: Color(0xFF1A1C1E), fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Review and resolve service-related feedback.',
                    style: TextStyle(color: Colors.black38, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: _complaints.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            itemCount: _complaints.length,
                            itemBuilder: (context, index) {
                              final c = _complaints[index];
                              return _buildComplaintCard(c);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black.withOpacity(0.05)),
            ),
            child: Icon(Icons.mark_chat_read_outlined, color: Colors.black.withOpacity(0.05), size: 64),
          ),
          const SizedBox(height: 24),
          const Text(
            'All Resolved!',
            style: TextStyle(color: Color(0xFF1A1C1E), fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'There are no pending complaints to display.',
            style: TextStyle(color: Colors.black38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintCard(Map<String, dynamic> c) {
    Color statusColor;
    switch (c['status']) {
      case 'Pending':
        statusColor = Colors.orange;
        break;
      case 'In Progress':
        statusColor = Colors.blue;
        break;
      case 'Resolved':
        statusColor = const Color(0xFF2E7D32);
        break;
      default:
        statusColor = Colors.black38;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: const Color(0xFF2E7D32),
          collapsedIconColor: Colors.black26,
          dense: true,
          title: Text(
            c['resident']?['name'] ?? 'Unknown Resident',
            style: const TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                '${c['status']} • Area: ${c['area'] ?? 'N/A'}',
                style: const TextStyle(color: Colors.black38, fontSize: 11),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Colors.black12),
                  const SizedBox(height: 8),
                  const Text('RESIDENT DETAILS', style: TextStyle(color: Colors.black26, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  _detailRow(Icons.person, 'Name', c['resident']?['name'] ?? 'N/A'),
                  _detailRow(Icons.home, 'House No.', c['resident']?['houseNumber'] ?? 'N/A'),
                  _detailRow(Icons.phone, 'Phone', c['resident']?['phoneNumber'] ?? 'N/A'),
                  _detailRow(Icons.map, 'Ward', c['resident']?['wardNumber'] ?? 'N/A'),
                  const SizedBox(height: 12),
                  const Text('ISSUE DESCRIPTION', style: TextStyle(color: Colors.black26, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Text(
                    c['description'] ?? 'No description provided.',
                    style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: _statusButton('RESOLVE CASE', const Color(0xFF2E7D32), () => _updateStatus(c['_id'], 'Resolved')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF2E7D32).withOpacity(0.5)),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _statusButton(String label, Color color, VoidCallback onPressed) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.1),
          foregroundColor: color,
          elevation: 0,
          side: BorderSide(color: color.withOpacity(0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Future<void> _updateStatus(String id, String status) async {
    final TextEditingController remarksController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${status == 'Resolved' ? 'Resolve' : 'Record Review'}', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add official remarks for the resident:', style: TextStyle(color: Colors.black45, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: remarksController,
              maxLines: 3,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Enter status updates or instructions...',
                filled: true,
                fillColor: const Color(0xFFF8FAF9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: Colors.black26))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              await _apiService.updateComplaint(id, status, remarksController.text);
              _fetchComplaints();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Complaint $status successfully'), backgroundColor: const Color(0xFF2E7D32)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), elevation: 0),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
