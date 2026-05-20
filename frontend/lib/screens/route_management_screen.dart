import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/api_service.dart';
import 'manage_houses_screen.dart';

class RouteManagementScreen extends StatefulWidget {
  final dynamic ward;
  final bool embedded;
  final VoidCallback? onBack;

  const RouteManagementScreen({super.key, required this.ward, this.embedded = false, this.onBack});

  @override
  _RouteManagementScreenState createState() => _RouteManagementScreenState();
}

class _RouteManagementScreenState extends State<RouteManagementScreen> {
  final ApiService _apiService = ApiService();
  final _nameController = TextEditingController();
  dynamic _ward;
  List<dynamic> _routes = [];
  List<dynamic> _staff = [];
  bool _isLoading = true;
  List<String> _selectedDays = [];
  String? _selectedRouteId;
  String? _selectedStaffId;
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime _focusedDay = DateTime.now();
  RangeSelectionMode _rangeSelectionMode = RangeSelectionMode.toggledOn;
  final List<String> _daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    _ward = widget.ward;
    _fetchData();
  }

  Future<void> _fetchData() async {
    final routes = await _apiService.getRoutes(wardId: widget.ward['_id']);
    final staff = await _apiService.getStaff();
    final routeWard = routes.isNotEmpty && routes.first['ward'] is Map ? routes.first['ward'] : null;
    final wardData = routeWard ?? _ward ?? widget.ward;
    setState(() {
      _ward = wardData;
      _routes = routes;
      _staff = staff;
      _startDate = wardData is Map && wardData['startDate'] != null ? DateTime.tryParse(wardData['startDate'].toString()) : null;
      _endDate = wardData is Map && wardData['endDate'] != null ? DateTime.tryParse(wardData['endDate'].toString()) : null;
      _isLoading = false;
    });
  }

  void _addRoute() async {
    if (_selectedRouteId == null || _selectedStaffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select route and choose staff. Save ward duration separately if needed.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await _apiService.updateRoute(_selectedRouteId!, {
      'assignedStaff': _selectedStaffId,
      'collectionDays': _selectedDays,
    });
    _nameController.clear();
    setState(() {
      _selectedDays = [];
      _selectedRouteId = null;
      _selectedStaffId = null;
    });
    await _fetchData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Route saved and sent to staff.'),
        backgroundColor: Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveWardSchedule() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select the ward start and end date.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await _apiService.scheduleWardRange(widget.ward['_id'], _startDate!, _endDate!);
    await _fetchData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? 'Ward schedule saved.'),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _createRoute() async {
    final routeName = _nameController.text.trim();
    if (routeName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a route name.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final res = await _apiService.createRoute({
      'name': routeName,
      'ward': widget.ward['_id'],
      'description': '',
    });

    _nameController.clear();
    await _fetchData();
    if (!mounted) return;
    final createdRoute = res['route'];
    setState(() {
      _selectedRouteId = createdRoute is Map ? createdRoute['_id']?.toString() : null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Route created under this ward.'),
        backgroundColor: Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Route'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: editNameController,
                decoration: InputDecoration(
                  labelText: 'Route Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final newName = editNameController.text;
                if (newName.isNotEmpty) {
                  await _apiService.updateRoute(route['_id'], {
                    'name': newName,
                  });
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
      ),
    );
  }


  void _assignStaff(String routeId, String staffId) async {
    await _apiService.assignRouteToStaff(routeId, staffId);
    _fetchData();
  }

  Future<void> _autoAssignWardRoutes() async {
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.autoAssignWardRoutes(widget.ward['_id']);
      await _fetchData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Ward houses auto-assigned.'),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not auto-assign houses.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2E7D32);

    final content = _isLoading
        ? const Center(child: CircularProgressIndicator(color: primaryColor))
        : SingleChildScrollView(
            padding: EdgeInsets.all(widget.embedded ? 32 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.embedded) ...[
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1C1E)),
                        onPressed: widget.onBack,
                        tooltip: 'Back to wards',
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ward ${widget.ward['wardNumber']?.toString() ?? ''} Routes',
                        style: const TextStyle(color: Color(0xFF1A1C1E), fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.ward['name']?.toString() ?? 'Manage route plans and staff assignments.',
                    style: const TextStyle(color: Colors.black45, fontSize: 16),
                  ),
                  const SizedBox(height: 28),
                ],
                _buildAddForm(primaryColor),
                const SizedBox(height: 32),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Available Routes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                    OutlinedButton.icon(
                      onPressed: _autoAssignWardRoutes,
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                      label: const Text('Auto Assign Houses'),
                      style: OutlinedButton.styleFrom(foregroundColor: primaryColor),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  itemCount: _routes.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final route = _routes[index];
                    return _routeCard(route, primaryColor);
                  },
                ),
              ],
            ),
          );

    if (widget.embedded) {
      return Container(color: const Color(0xFFF8FAF9), child: content);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        title: Text('W${widget.ward['wardNumber']?.toString() ?? ''} Routes', style: const TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
      ),
      body: content,
    );
  }

  Widget _buildAddForm(Color primary) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black.withOpacity(0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Create Route', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black45)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Route name (e.g. Kidangoor road 1)',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _createRoute,
                icon: const Icon(Icons.add_road_rounded, size: 16, color: Colors.white),
                label: const Text(
                  'Create Route',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Route', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black45)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _routes.any((route) => route['_id']?.toString() == _selectedRouteId) ? _selectedRouteId : null,
            decoration: InputDecoration(
              hintText: _routes.isEmpty ? 'No routes created under this ward' : 'Select route under this ward',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: _routes
                .map(
                  (route) => DropdownMenuItem<String>(
                    value: route['_id']?.toString(),
                    child: Text(route['name']?.toString() ?? 'Unnamed Route'),
                  ),
                )
                .toList(),
            onChanged: _routes.isEmpty
                ? null
                : (value) {
                    final selectedRoute = _routes.firstWhere(
                      (route) => route['_id']?.toString() == value,
                      orElse: () => null,
                    );
                    setState(() {
                      _selectedRouteId = value;
                      final assignedStaff = selectedRoute is Map ? selectedRoute['assignedStaff'] : null;
                      _selectedStaffId = assignedStaff is Map
                          ? assignedStaff['_id']?.toString()
                          : assignedStaff?.toString();
                    });
                  },
          ),
          const SizedBox(height: 18),
          const Text('Assign Staff', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black45)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedStaffId,
            decoration: InputDecoration(
              hintText: 'Select staff to receive this route',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: _staff
                .map(
                  (s) => DropdownMenuItem<String>(
                    value: s['_id']?.toString(),
                    child: Text(
                      (s['name'] ?? '${s['firstName'] ?? ''} ${s['lastName'] ?? ''}').toString().trim(),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _selectedStaffId = value),
          ),
          const SizedBox(height: 24),
          const Text('Ward Work Duration Range', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E))),
          const SizedBox(height: 4),
          const Text('Admin sets this once for the whole ward. Staff will choose route visit dates inside this range.', style: TextStyle(fontSize: 12, color: Colors.black45)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAF9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
            ),
            child: TableCalendar(
              firstDay: DateTime(2020),
              lastDay: DateTime(2030),
              focusedDay: _focusedDay,
              rangeStartDay: _startDate,
              rangeEndDay: _endDate,
              rangeSelectionMode: _rangeSelectionMode,
              calendarFormat: CalendarFormat.month,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(fontWeight: FontWeight.bold),
              ),
              onRangeSelected: (start, end, focusedDay) {
                setState(() {
                  _startDate = start;
                  _endDate = end;
                  _focusedDay = focusedDay;
                });
              },
              calendarStyle: CalendarStyle(
                rangeHighlightColor: primary.withOpacity(0.2),
                rangeStartDecoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                rangeEndDecoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                todayDecoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle),
                todayTextStyle: TextStyle(color: primary, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_startDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.date_range, size: 16, color: Colors.black45),
                  const SizedBox(width: 8),
                  Text(
                    'Ward Range: ${DateFormat('dd MMM').format(_startDate!)} - ${_endDate != null ? DateFormat('dd MMM').format(_endDate!) : '...'}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: primary),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saveWardSchedule,
                  icon: Icon(Icons.event_available_rounded, size: 16, color: primary),
                  label: Text('Save Ward Dates', style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 46),
                    side: BorderSide(color: primary.withOpacity(0.45)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _addRoute,
                  icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                  label: const Text('Assign Route to Staff', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: primary, minimumSize: const Size(double.infinity, 46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ],
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
                    if (route['startDate'] != null && route['endDate'] != null)
                      Text(
                        'Duration: ${DateFormat('dd MMM').format(DateTime.parse(route['startDate']))} - ${DateFormat('dd MMM').format(DateTime.parse(route['endDate']))}',
                        style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                      ),
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

        ],
      ),
    );
  }
}
