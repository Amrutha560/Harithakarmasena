import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HouseDetailScreen extends StatefulWidget {
  final dynamic house;
  final dynamic route;

  const HouseDetailScreen({
    super.key,
    required this.house,
    required this.route,
  });

  @override
  State<HouseDetailScreen> createState() => _HouseDetailScreenState();
}

class _HouseDetailScreenState extends State<HouseDetailScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  void _markCollection(String status) async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.markCollection({
        'houseId': widget.house['_id'],
        'routeId': widget.route['_id'],
        'status': status,
        'scheduleId': widget.route['_id'], // Mocking schedule since we use routes directly now.
      });

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Marked as: $status'),
          backgroundColor: status == 'Collected' ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context, true); // Pop back with refresh signal
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to update status'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF00C853);
    final String owner = widget.house['ownerName'] ?? widget.house['name'] ?? 'Unknown Owner';
    final String houseNo = widget.house['houseNumber'] ?? 'N/A';
    final String address = widget.house['address'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F4F2),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1C1E), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('House Details', style: TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.w900, fontSize: 16)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: primaryGreen.withOpacity(0.1),
                          child: const Icon(Icons.home_work_rounded, color: primaryGreen, size: 36),
                        ),
                        const SizedBox(height: 16),
                        Text(owner, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFF1A1C1E))),
                        const SizedBox(height: 8),
                        Text('House No: $houseNo', style: const TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_rounded, color: Colors.black26, size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: Text(address, style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.5))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Update Collection Status', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1A1C1E))),
                  ),
                  const SizedBox(height: 16),
                  _buildStatusButton('Collected', Icons.check_circle_rounded, primaryGreen),
                  const SizedBox(height: 12),
                  _buildStatusButton('Not Collected', Icons.cancel_rounded, Colors.orange),
                  const SizedBox(height: 12),
                  _buildStatusButton('Not Cooperative', Icons.do_not_disturb_alt_rounded, Colors.redAccent),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusButton(String title, IconData icon, Color color) {
    return InkWell(
      onTap: () => _markCollection(title),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color))),
            const Icon(Icons.chevron_right_rounded, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}
