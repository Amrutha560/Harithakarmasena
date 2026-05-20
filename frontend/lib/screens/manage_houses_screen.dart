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
  List<dynamic> _residents = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _selectedResidentId;
  final _houseNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchHouses();
  }

  Future<void> _fetchHouses() async {
    final houses = await _apiService.getHousesInRoute(widget.route['_id']);
    final users = await _apiService.getUsers();
    setState(() {
      _existingHouses = houses;
      _residents = users.where((u) => u['role'] == 'resident').toList();
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _houseNumberController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _selectResident(String? residentId) {
    final resident = _residents.firstWhere(
      (r) => r['_id']?.toString() == residentId,
      orElse: () => null,
    );
    setState(() {
      _selectedResidentId = residentId;
      if (resident != null) {
        _houseNumberController.text = resident['houseNumber']?.toString() ?? '';
        _addressController.text = resident['address']?.toString() ?? '';
        _phoneController.text = resident['phoneNumber']?.toString() ?? '';
      }
    });
  }

  Future<void> _linkResidentToRoute() async {
    if (_selectedResidentId == null ||
        _houseNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a resident and enter a house number.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final resident = _residents.firstWhere(
      (r) => r['_id']?.toString() == _selectedResidentId,
    );
    final name = '${resident['firstName'] ?? ''} ${resident['lastName'] ?? ''}'
        .trim();

    setState(() => _isSaving = true);
    try {
      await _apiService.addHousesToRoute(widget.route['_id'], [
        {
          'resident': _selectedResidentId,
          'ownerName': name.isEmpty ? 'Resident' : name,
          'name': name.isEmpty ? 'Resident' : name,
          'houseNumber': _houseNumberController.text.trim(),
          'address': _addressController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
        },
      ], preserveRoute: true);

      _selectedResidentId = null;
      _houseNumberController.clear();
      _addressController.clear();
      _phoneController.clear();
      await _fetchHouses();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('House saved under this route.'),
          backgroundColor: Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteHouse(String houseId) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete House'),
            content: const Text(
              'Are you sure you want to permanently remove this house?',
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    final success = await _apiService.deleteHouse(houseId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('House deleted successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _fetchHouses();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete house'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2E7D32);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        title: Text(
          '${widget.route['name']} - Household Management',
          style: const TextStyle(
            color: Color(0xFF1A1C1E),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildLinkResidentForm(primary),
                  const SizedBox(height: 20),
                  Expanded(child: _buildExistingList(primary)),
                ],
              ),
            ),
    );
  }

  Widget _buildLinkResidentForm(Color primary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Resident House and Auto Assign Route',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _selectedResidentId,
            decoration: InputDecoration(
              labelText: 'Registered resident',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            items: _residents.map((resident) {
              final name =
                  '${resident['firstName'] ?? ''} ${resident['lastName'] ?? ''}'
                      .trim();
              final phone = resident['phoneNumber']?.toString() ?? '';
              return DropdownMenuItem<String>(
                value: resident['_id']?.toString(),
                child: Text(
                  '${name.isEmpty ? resident['email'] : name}${phone.isEmpty ? '' : ' - $phone'}',
                ),
              );
            }).toList(),
            onChanged: _selectResident,
          ),
          const SizedBox(height: 12),
          if (_selectedResidentId != null) ...[
            _buildSelectedResidentDetails(),
            const SizedBox(height: 14),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _linkResidentToRoute,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: Colors.white,
                    ),
              label: Text(
                _isSaving ? 'Saving...' : 'Save House Details',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(backgroundColor: primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedResidentDetails() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E8E1)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        children: [
          _readOnlyInfo('House number', _houseNumberController.text),
          _readOnlyInfo('Phone', _phoneController.text),
          _readOnlyInfo('Address', _addressController.text),
        ],
      ),
    );
  }

  Widget _readOnlyInfo(String label, String value) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 520),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
          Flexible(
            child: Text(
              value.isEmpty ? 'Not provided' : value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingList(Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Current Route Households (${_existingHouses.length})',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                ),
              ],
            ),
            child: _existingHouses.isEmpty
                ? const Center(
                    child: Text(
                      'No households registered on this route yet',
                      style: TextStyle(color: Colors.black26),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _existingHouses.length,
                    itemBuilder: (context, index) {
                      final h = _existingHouses[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: primary.withOpacity(0.1),
                          child: Icon(
                            Icons.home_outlined,
                            color: primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          h['ownerName'] ?? h['name'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'House Number: ${h['houseNumber']} | ${h['address']}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                            size: 20,
                          ),
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
}
