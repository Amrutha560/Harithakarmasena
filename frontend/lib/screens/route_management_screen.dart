import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'manage_houses_screen.dart';

class RouteManagementScreen extends StatefulWidget {
  final dynamic ward;
  const RouteManagementScreen({super.key, required this.ward});

  @override
  _RouteManagementScreenState createState() => _RouteManagementScreenState();
}

class _RouteManagementScreenState extends State<RouteManagementScreen> {
  final ApiService _apiService = ApiService();
  final _nameController = TextEditingController();
  List<dynamic> _routes = [];
  List<dynamic> _staff = [];
  bool _isLoading = true;
  List<String> _selectedDays = [];
  final List<String> _daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final routes = await _apiService.getRoutes(wardId: widget.ward['_id']);
    final staff = await _apiService.getStaff();
    setState(() {
      _routes = routes;
      _staff = staff;
      _isLoading = false;
    });
  }

  void _addRoute() async {
    if (_nameController.text.isEmpty) return;
    await _apiService.createRoute({
      'name': _nameController.text,
      'ward': widget.ward['_id'],
      'collectionDays': _selectedDays,
    });
    _nameController.clear();
    setState(() => _selectedDays = []);
    _fetchData();
  }

  void _deleteRoute(String id) async {
    final res = await _apiService.deleteRoute(id);
    if (res['message']?.contains('success') == true) {
      _fetchData();
    }
  }

  void _editRouteDialog(dynamic route) {
    final TextEditingController editNameController = TextEditingController(text: route['name']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Route'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: editNameController,
          decoration: InputDecoration(
            labelText: 'Route Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newName = editNameController.text;
              if (newName.isNotEmpty) {
                await _apiService.updateRoute(route['_id'], {'name': newName});
                if (mounted) {
                  Navigator.pop(ctx);
                  _fetchData();
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }


  void _assignStaff(String routeId, String staffId) async {
    await _apiService.assignRouteToStaff(routeId, staffId);
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2E7D32);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        title: Text('W${widget.ward['wardNumber']} Routes', style: const TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.bold)),
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
                  const Text('Available Routes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _routes.length,
                      itemBuilder: (context, index) {
                        final route = _routes[index];
                        return _routeCard(route, primaryColor);
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _inputField('Route Name (e.g. Area A)', _nameController),
          const SizedBox(height: 16),
          const Text('Collection Days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black45)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _daysOfWeek.map((day) {
                final isSelected = _selectedDays.contains(day);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(day.substring(0, 3)),
                    selected: isSelected,
                    selectedColor: primary.withOpacity(0.2),
                    checkmarkColor: primary,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedDays.add(day);
                        } else {
                          _selectedDays.remove(day);
                        }
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _addRoute,
            style: ElevatedButton.styleFrom(backgroundColor: primary, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Create Route', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  void _toggleDay(dynamic route, String day) async {
    List<dynamic> days = List.from(route['collectionDays'] ?? []);
    if (days.contains(day)) {
      days.remove(day);
    } else {
      days.add(day);
    }
    await _apiService.updateRoute(route['_id'], {'collectionDays': days});
    _fetchData();
  }

  Widget _routeCard(dynamic route, Color primary) {
    String? assignedName = route['assignedStaff']?['name'];
    List<dynamic> activeDays = route['collectionDays'] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.directions_rounded, color: primary, size: 20),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(route['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(assignedName != null ? 'Assigned to $assignedName' : 'Unassigned', style: const TextStyle(fontSize: 12, color: Colors.black38)),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                    onPressed: () => _editRouteDialog(route),
                    tooltip: 'Edit Route',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                    onPressed: () => _deleteRoute(route['_id']),
                    tooltip: 'Delete Route',
                  ),
                ],
              ),
              DropdownButton<String>(
                hint: const Text('Assign Staff', style: TextStyle(fontSize: 12)),
                items: _staff.map((s) => DropdownMenuItem<String>(value: s['_id'], child: Text(s['name']))).toList(),
                onChanged: (val) {
                  if (val != null) _assignStaff(route['_id'], val);
                },
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManageHousesScreen(route: route))).then((_) => _fetchData()),
                icon: Icon(Icons.home_work_outlined, size: 16, color: primary),
                label: Text('Houses', style: TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(height: 32),
          const Text('Scheduling', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black26)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _daysOfWeek.map((day) {
                final isSelected = activeDays.contains(day);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    padding: EdgeInsets.zero,
                    label: Text(day.substring(0, 3), style: const TextStyle(fontSize: 10)),
                    selected: isSelected,
                    selectedColor: primary.withOpacity(0.15),
                    checkmarkColor: primary,
                    onSelected: (_) => _toggleDay(route, day),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
