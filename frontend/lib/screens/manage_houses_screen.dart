import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ManageHousesScreen extends StatefulWidget {
  final dynamic route;
  const ManageHousesScreen({super.key, required this.route});

  @override
  _ManageHousesScreenState createState() => _ManageHousesScreenState();
}

class _ManageHousesScreenState extends State<ManageHousesScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _existingHouses = [];
  List<Map<String, String>> _newHouses = [];
  bool _isLoading = true;

  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchHouses();
  }

  Future<void> _fetchHouses() async {
    final houses = await _apiService.getHousesInRoute(widget.route['_id']);
    setState(() {
      _existingHouses = houses;
      _isLoading = false;
    });
  }

  void _addHouseToTemp() {
    if (_nameController.text.isEmpty || _numberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill Name and House Number')));
      return;
    }
    setState(() {
      _newHouses.add({
        'name': _nameController.text,
        'houseNumber': _numberController.text,
        'phoneNumber': _phoneController.text,
        'address': _addressController.text,
      });
      _nameController.clear();
      _numberController.clear();
      _phoneController.clear();
      _addressController.clear();
    });
  }

  void _saveAllHouses() async {
    if (_newHouses.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.addHousesToRoute(widget.route['_id'], List<Map<String, dynamic>>.from(_newHouses));
      final message = res['message'] ?? '';
      final isSuccess = message.isNotEmpty && !message.toLowerCase().contains('error') && res['houses'] != null;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message.isNotEmpty ? message : (isSuccess ? 'Houses saved!' : 'Save failed. Try again.')),
          backgroundColor: isSuccess ? Colors.green : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));

        if (isSuccess) {
          setState(() => _newHouses.clear());
        }
        // Always refresh the list and stop loading
        await _fetchHouses();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to save houses. Please try again.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _deleteHouse(String houseId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete House'),
        content: const Text('Are you sure you want to permanently remove this house?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    final success = await _apiService.deleteHouse(houseId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('House deleted successfully'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
      _fetchHouses();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to delete house'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2E7D32);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        title: Text('${widget.route['name']} - Houses', style: const TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Side: Add Form
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFormCard(primary),
                          const SizedBox(height: 24),
                          if (_newHouses.isNotEmpty) _buildTempList(primary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                  // Right Side: Existing Houses
                  Expanded(
                    flex: 3,
                    child: _buildExistingList(primary),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFormCard(Color primary) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black.withOpacity(0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New Household Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 20),
          _input('Resident Name', _nameController, Icons.person_outline),
          const SizedBox(height: 12),
          _input('House Number', _numberController, Icons.numbers),
          const SizedBox(height: 12),
          _input('Phone Number', _phoneController, Icons.phone_outlined),
          const SizedBox(height: 12),
          _input('Detailed Address', _addressController, Icons.map_outlined),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _addHouseToTemp,
            style: ElevatedButton.styleFrom(backgroundColor: primary, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Add to Queue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTempList(Color primary) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.withOpacity(0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('In Queue (${_newHouses.length})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              TextButton(onPressed: _saveAllHouses, child: const Text('Save All Now', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          const Divider(),
          ..._newHouses.map((h) => ListTile(
            title: Text(h['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('House No: ${h['houseNumber']}'),
            trailing: IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.red), onPressed: () => setState(() => _newHouses.remove(h))),
          )),
        ],
      ),
    );
  }

  Widget _buildExistingList(Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Current Route Houses (${_existingHouses.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: _existingHouses.isEmpty 
              ? const Center(child: Text('No houses assigned yet', style: TextStyle(color: Colors.black26)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _existingHouses.length,
                  itemBuilder: (context, index) {
                    final h = _existingHouses[index];
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: primary.withOpacity(0.1), child: Icon(Icons.home_outlined, color: primary, size: 20)),
                      title: Text(h['ownerName'] ?? h['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('ID: ${h['houseNumber']} | ${h['address']}', style: const TextStyle(fontSize: 11)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        onPressed: () => _deleteHouse(h['_id']),
                        tooltip: 'Remove House',
                      ),
                    );
                  },
                ),
          ),
        ),
      ],
    );
  }

  Widget _input(String label, TextEditingController ctrl, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
