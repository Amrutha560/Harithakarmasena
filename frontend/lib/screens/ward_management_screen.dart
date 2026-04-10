import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'route_management_screen.dart';

class WardManagementScreen extends StatefulWidget {
  const WardManagementScreen({super.key});

  @override
  _WardManagementScreenState createState() => _WardManagementScreenState();
}

class _WardManagementScreenState extends State<WardManagementScreen> {
  final ApiService _apiService = ApiService();
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  List<dynamic> _wards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchWards();
  }

  Future<void> _fetchWards() async {
    final wards = await _apiService.getWards();
    setState(() {
      _wards = wards;
      _isLoading = false;
    });
  }

  void _addWard() async {
    if (_nameController.text.isEmpty || _numberController.text.isEmpty) return;
    await _apiService.createWard({
      'name': _nameController.text,
      'wardNumber': _numberController.text,
    });
    _nameController.clear();
    _numberController.clear();
    _fetchWards();
  }

  void _deleteWard(String id) async {
    final res = await _apiService.deleteWard(id);
    if (res['message']?.contains('success') == true) {
      _fetchWards();
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2E7D32);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        title: const Text('Manage Wards', style: TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildAddForm(primaryColor),
                  const SizedBox(height: 32),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _wards.length,
                      itemBuilder: (context, index) {
                        final ward = _wards[index];
                        return _wardCard(ward, primaryColor);
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAddForm(Color primary) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black.withOpacity(0.05))),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _inputField('Ward Name', _nameController)),
              const SizedBox(width: 16),
              Expanded(child: _inputField('Ward Number', _numberController)),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _addWard,
            style: ElevatedButton.styleFrom(backgroundColor: primary, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Add Ward', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _inputField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black45)),
        const SizedBox(height: 8),
        TextField(controller: controller, decoration: InputDecoration(hintText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
      ],
    );
  }

  Widget _wardCard(dynamic ward, Color primary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(ward['wardNumber'], style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ward['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
            onPressed: () => _deleteWard(ward['_id']),
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios_rounded, color: primary, size: 18),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RouteManagementScreen(ward: ward))),
          ),
        ],
      ),
    );
  }
}
