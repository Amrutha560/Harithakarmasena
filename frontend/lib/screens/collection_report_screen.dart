import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class CollectionReportScreen extends StatefulWidget {
  const CollectionReportScreen({super.key});

  @override
  State<CollectionReportScreen> createState() => _CollectionReportScreenState();
}

class _CollectionReportScreenState extends State<CollectionReportScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    try {
      final logs = await _apiService.getCollectionReports();
      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF2E7D32);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Admin: Collection Reports', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: primaryGreen),
            onPressed: _fetchReports,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _statItem('Total Logs', _logs.length.toString()),
                      _statItem('Collected', _logs.where((l) => (l['collectionStatus'] ?? l['status']) == 'Collected').length.toString()),
                      _statItem('Issues', _logs.where((l) => (l['collectionStatus'] ?? l['status']) != 'Collected').length.toString()),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final date = DateTime.parse(log['date']?.toString() ?? log['createdAt']);
                      final status = log['collectionStatus'] ?? log['status'] ?? 'Pending';
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: status == 'Collected' ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                    child: Icon(
                                      status == 'Collected' ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                      color: status == 'Collected' ? Colors.green : Colors.red,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(log['residentName'] ?? log['resident']?['name'] ?? 'Unknown Resident', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        Text('House ${log['houseNumber'] ?? log['resident']?['houseNumber'] ?? 'N/A'} | ${log['ward'] ?? 'Ward pending'} | ${log['routeName'] ?? 'Route pending'}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(DateFormat('dd MMM').format(date), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text(DateFormat('hh:mm a').format(date), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  )
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _infoRow(Icons.person_outline_rounded, 'Staff: ${log['staffName'] ?? log['staff']?['name'] ?? 'N/A'}'),
                                  _infoRow(Icons.delete_outline_rounded, '${log['wasteType'] ?? 'General Waste'} | ${log['paymentStatus'] ?? 'Pending'} ${log['paymentMode'] ?? ''}'),
                                ],
                              ),
                              if (log['proofImageUrl'] != null) ...[
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?auto=format&fit=crop&w=400&q=80',
                                    height: 120,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _statItem(String title, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      ],
    );
  }
}
