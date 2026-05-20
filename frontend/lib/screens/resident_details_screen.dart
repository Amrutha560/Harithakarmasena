import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class ResidentDetailsScreen extends StatefulWidget {
  const ResidentDetailsScreen({super.key});

  @override
  State<ResidentDetailsScreen> createState() => _ResidentDetailsScreenState();
}

class _ResidentDetailsScreenState extends State<ResidentDetailsScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getResidentDashboard();
      setState(() {
        _data = res;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _respond(String choice) async {
    setState(() => _submitting = true);
    try {
      await _apiService.respondToCollection(choice);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Marked as $choice'), backgroundColor: Colors.green));
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error updating status'), backgroundColor: Colors.redAccent));
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Resident Profile', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 32),
                  _buildInfoCard(),
                  const SizedBox(height: 40),
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    final rawName = _data?['residentName'] ?? 
                 _data?['user']?['name'] ?? 
                 '${_data?['user']?['firstName'] ?? ''} ${_data?['user']?['lastName'] ?? ''}'.trim();
    final name = (rawName.isEmpty || rawName == 'null') ? 'Resident' : rawName;
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: const Color(0xFFE8F5E9),
          child: Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
        ),
        const SizedBox(height: 16),
        Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(_data?['user']?['email'] ?? '', style: const TextStyle(color: Colors.black38)),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          // House number removed per user request
          _infoTile(Icons.location_on_rounded, 'ADDRESS', _data?['address'] ?? 'N/A'),
          const Divider(height: 32),
          _infoTile(Icons.map_rounded, 'WARD', _data?['wardNumber']?.toString() ?? 'N/A'),
          const Divider(height: 32),
          _infoTile(Icons.directions_rounded, 'ROUTE', _data?['routeName'] ?? 'N/A'),
        ],
      ),
    );
  }



  Widget _buildActionButtons() {
    final response = _data?['residentResponse'] ?? 'Pending';
    return Row(
      children: [
        Expanded(
          child: _btn('Available', Colors.green, response == 'Available', () => _respond('Available')),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _btn('Not Available', Colors.redAccent, response == 'Not Available', () => _respond('Not Available')),
        ),
      ],
    );
  }

  Widget _btn(String label, Color color, bool isSelected, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: _submitting ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : Colors.white,
        foregroundColor: isSelected ? Colors.white : color,
        elevation: isSelected ? 4 : 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withOpacity(0.3))),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.black26),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.black38, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }
}


