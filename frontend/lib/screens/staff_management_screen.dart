import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'create_staff_screen.dart';

class StaffManagementScreen extends StatefulWidget {
  final bool embedded;

  const StaffManagementScreen({super.key, this.embedded = false});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _staffList = [];
  List<dynamic> _routes = [];
  List<dynamic> _routeCompletions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStaff();
  }

  Future<void> _fetchStaff() async {
    setState(() => _isLoading = true);
    final staff = await _apiService.getStaff();
    final routes = await _apiService.getRoutes();
    final completions = await _apiService.getRouteCompletions();
    setState(() {
      _staffList = staff;
      _routes = routes;
      _routeCompletions = completions;
      _isLoading = false;
    });
  }

  Future<void> _deleteStaff(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Staff?'),
        content: const Text('Are you sure you want to remove this staff member? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      await _apiService.deleteUser(id);
      _fetchStaff();
    }
  }

  void _viewStaff(Map<String, dynamic> staff) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.person_pin_rounded, color: Color(0xFFE65100)),
            const SizedBox(width: 12),
            const Text('Staff Profile'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Name', staff['name']),
            _infoRow('Email', staff['email']),
            _infoRow('Phone', staff['phoneNumber'] ?? 'N/A'),
            _infoRow('Ward', 'Ward ${staff['wardNumber'] ?? 'N/A'}'),
            _infoRow('Address', staff['address'] ?? 'N/A'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: Colors.black54))),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  void _editStaff(Map<String, dynamic> staff) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateStaffScreen(staffToEdit: staff)),
    ).then((_) => _fetchStaff());
  }

  @override
  Widget build(BuildContext context) {
    final content = _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)))
        : SingleChildScrollView(
            padding: EdgeInsets.all(widget.embedded ? 32 : 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildToolbar(),
                const SizedBox(height: 24),
                _buildStaffTable(),
              ],
            ),
          );

    if (widget.embedded) {
      return Container(
        color: const Color(0xFFF4F7F6),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: content,
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Staff List', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E))),
            const SizedBox(height: 4),
            const Text('Manage your official staff members', style: TextStyle(color: Colors.black38, fontSize: 14)),
          ],
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateStaffScreen()))
                .then((_) => _fetchStaff());
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE65100),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: const Text('Add Staff', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        // Search
        Container(
          width: 300,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
          ),
          child: const Row(
            children: [
              Icon(Icons.search, color: Colors.black26, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search staff members...',
                    hintStyle: TextStyle(color: Colors.black26, fontSize: 13),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        _toolIcon(Icons.filter_list),
        const SizedBox(width: 8),
        _toolIcon(Icons.description_outlined, label: 'Excel'),
        const SizedBox(width: 8),
        _toolIcon(Icons.picture_as_pdf_outlined, label: 'PDF'),
      ],
    );
  }

  Widget _toolIcon(IconData icon, {String? label}) {
    return Container(
      height: 48,
      padding: EdgeInsets.symmetric(horizontal: label != null ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.black54, size: 18),
          if (label != null) ...[
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          ],
        ],
      ),
    );
  }

  Widget _buildStaffTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          _buildTableHeader(),
          if (_staffList.isEmpty)
            _emptyState()
          else
            ...List.generate(_staffList.length, (index) => _buildTableRow(_staffList[index])),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.05))),
      ),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('Staff', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 2, child: Text('Email/Login', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 2, child: Text('Phone', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 1, child: Text('Ward', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12))),
          SizedBox(width: 120, child: Text('Action', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> staff) {
    final assignedRoutes = _routesForStaff(staff);
    final completedRoutes = _completedRoutesForStaff(staff);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.05))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F2),
                        borderRadius: BorderRadius.circular(8),
                        image: (staff['profileImage'] != null)
                            ? DecorationImage(image: NetworkImage(staff['profileImage']), fit: BoxFit.cover)
                            : null,
                      ),
                      child: staff['profileImage'] == null 
                        ? const Icon(Icons.person, color: Color(0xFF2E7D32), size: 20)
                        : null,
                    ),
                    const SizedBox(width: 16),
                    Text(staff['name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),
              ),
              Expanded(flex: 2, child: Text(staff['email'], style: const TextStyle(color: Colors.black54, fontSize: 13))),
              Expanded(flex: 2, child: Text(staff['phoneNumber'] ?? 'N/A', style: const TextStyle(color: Colors.black54, fontSize: 13))),
              Expanded(flex: 1, child: Text('${staff['wardNumber'] ?? _wardNumber(staff)}', style: const TextStyle(color: Colors.black54, fontSize: 13))),
              SizedBox(
                width: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _actionIcon(Icons.visibility_outlined, Colors.black26, () => _viewStaff(staff)),
                    const SizedBox(width: 12),
                    _actionIcon(Icons.edit_outlined, Colors.black26, () => _editStaff(staff)),
                    const SizedBox(width: 12),
                    _actionIcon(Icons.delete_outline_rounded, const Color(0xFFEF4444), () => _deleteStaff(staff['_id'])),
                  ],
                ),
              ),
            ],
          ),
          if (assignedRoutes.isNotEmpty || completedRoutes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 60),
              child: _staffRouteSummary(assignedRoutes, completedRoutes),
            ),
          ],
        ],
      ),
    );
  }

  Widget _staffRouteSummary(List<Map<String, dynamic>> routes, List<Map<String, dynamic>> completions) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (routes.isNotEmpty) ...[
            const Text('Assigned routes', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black54)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: routes.map((route) {
                final status = route['routeStatus']?.toString() ?? 'Pending';
                final isCompleted = status == 'Completed';
                return _pill(
                  '${route['name'] ?? 'Route'} - $status',
                  isCompleted ? const Color(0xFF2E7D32) : Colors.orange,
                  Icons.route_rounded,
                );
              }).toList(),
            ),
          ],
          if (completions.isNotEmpty) ...[
            if (routes.isNotEmpty) const SizedBox(height: 10),
            const Text('Completed by staff', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black54)),
            const SizedBox(height: 6),
            ...completions.take(3).map((row) {
              final totals = row['totals'] is Map ? row['totals'] as Map : {};
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    const Icon(Icons.task_alt_rounded, color: Color(0xFF2E7D32), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${row['routeName'] ?? 'Route'} on ${row['date'] ?? '-'} - ${totals['collectedHouses'] ?? 0}/${totals['totalHouses'] ?? 0} houses done, ${totals['unpaidHouses'] ?? 0} unpaid',
                        style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (completions.length > 3)
              Text(
                '+${completions.length - 3} more completed route(s)',
                style: const TextStyle(fontSize: 12, color: Colors.black38, fontWeight: FontWeight.bold),
              ),
          ],
        ],
      ),
    );
  }

  Widget _pill(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _routesForStaff(Map<String, dynamic> staff) {
    final staffId = staff['_id']?.toString();
    final directRouteId = staff['route'] is Map ? staff['route']['_id']?.toString() : staff['route']?.toString();
    return _routes
        .whereType<Map>()
        .map((route) => Map<String, dynamic>.from(route))
        .where((route) {
          final assignedStaff = route['assignedStaff'];
          final assignedId = assignedStaff is Map ? assignedStaff['_id']?.toString() : assignedStaff?.toString();
          return assignedId == staffId || (directRouteId != null && route['_id']?.toString() == directRouteId);
        })
        .toList();
  }

  List<Map<String, dynamic>> _completedRoutesForStaff(Map<String, dynamic> staff) {
    final staffId = staff['_id']?.toString();
    final staffName = staff['name']?.toString();
    final staffEmail = staff['email']?.toString();
    return _routeCompletions
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) {
          if (row['routeStatus']?.toString() != 'Completed') return false;
          return row['completedById']?.toString() == staffId ||
              row['assignedStaffId']?.toString() == staffId ||
              row['completedBy']?.toString() == staffName ||
              row['completedBy']?.toString() == staffEmail ||
              row['assignedStaff']?.toString() == staffName ||
              row['assignedStaff']?.toString() == staffEmail;
        })
        .toList();
  }

  String _wardNumber(Map<String, dynamic> staff) {
    if (staff['ward'] is Map) {
      return staff['ward']['wardNumber']?.toString() ?? 'N/A';
    }
    return 'N/A';
  }

  Widget _actionIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: color, size: 18),
    );
  }

  Widget _emptyState() {
    return const Padding(
      padding: EdgeInsets.all(60.0),
      child: Center(child: Text('No staff members registered', style: TextStyle(color: Colors.black26, fontSize: 13))),
    );
  }
}
