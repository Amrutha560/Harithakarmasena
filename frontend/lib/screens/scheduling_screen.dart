import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SchedulingScreen extends StatefulWidget {
  final bool embedded;

  const SchedulingScreen({super.key, this.embedded = false});

  @override
  State<SchedulingScreen> createState() => _SchedulingScreenState();
}

class _SchedulingScreenState extends State<SchedulingScreen> {
  final ApiService _apiService = ApiService();
  final _categoryNameController = TextEditingController();
  final _areaController = TextEditingController();

  List<dynamic> _categories = [];
  List<dynamic> _routeSchedules = [];
  List<dynamic> _routeCompletions = [];
  bool _isLoading = true;
  bool _isSavingWasteTypes = false;
  final Set<String> _selectedCategories = {};
  DateTime _selectedDate = DateTime.now();
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  final bool _isMonthlyPlan = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final cats = await _apiService.getCategories();
    final routes = await _apiService.getRoutes();
    final completions = await _apiService.getRouteCompletions();
    final monthlyPlan = await _apiService.getMonthlyWasteTypes(
      month: _selectedMonth,
      year: _selectedYear,
    );
    routes.sort((a, b) {
      final aDate = a['startDate']?.toString() ?? '';
      final bDate = b['startDate']?.toString() ?? '';
      return bDate.compareTo(aDate);
    });
    setState(() {
      _categories = cats;
      _applyMonthlyPlanSelection(monthlyPlan);
      _routeSchedules = routes.where((route) {
        final ward = route['ward'];
        final hasWard =
            ward is Map &&
            (ward['_id']?.toString().isNotEmpty == true ||
                ward['wardNumber']?.toString().isNotEmpty == true);
        if (!hasWard) return false;
        return route['startDate'] != null ||
            route['endDate'] != null ||
            route['assignedStaff'] != null;
      }).toList();
      _routeCompletions = completions;
      _isLoading = false;
    });
  }

  Future<void> _addCategory() async {
    if (_categoryNameController.text.isEmpty) return;
    final category = await _apiService.createCategory(
      _categoryNameController.text,
      'Waste collection',
    );
    _categoryNameController.clear();
    if (!mounted) return;
    if (category['_id'] != null) {
      setState(() {
        _categories.add(category);
        _selectedCategories.add(category['_id'].toString());
      });
    } else {
      _fetchData();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Waste type added. Click Save Month to apply it.'),
        backgroundColor: Color(0xFF00E676),
      ),
    );
  }

  final List<String> _months = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];

  @override
  Widget build(BuildContext context) {
    final content = _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
          )
        : SingleChildScrollView(
            padding: EdgeInsets.all(widget.embedded ? 32.0 : 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.embedded) ...[
                  const Text(
                    'Scheduling',
                    style: TextStyle(
                      color: Color(0xFF1A1C1E),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Scheduled route assignments sent to staff.',
                    style: TextStyle(color: Colors.black45, fontSize: 16),
                  ),
                  const SizedBox(height: 28),
                ],
                _buildSectionTitle('Waste Types'),
                const SizedBox(height: 16),
                _buildWasteTypePanel(),
                const SizedBox(height: 28),
                _buildSectionTitle('Route Schedule List'),
                const SizedBox(height: 16),
                _buildRouteScheduleList(),
              ],
            ),
          );

    if (widget.embedded) {
      return Container(color: const Color(0xFFF8FAF9), child: content);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1C1E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scheduling & Categories',
          style: TextStyle(
            color: Color(0xFF1A1C1E),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: content,
    );
  }

  Widget _buildRouteScheduleList() {
    if (_routeSchedules.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: const Center(
          child: Text(
            'No route schedules found. Create one from Wards & Routes.',
            style: TextStyle(color: Colors.black38),
          ),
        ),
      );
    }

    final groupedSchedules = <String, List<Map<String, dynamic>>>{};
    final wardLabels = <String, String>{};

    for (final item in _routeSchedules) {
      final route = Map<String, dynamic>.from(item as Map);
      final ward = route['ward'] is Map ? route['ward'] as Map : {};
      if (_wardLabel(ward) == 'Ward not set') continue;
      final wardId =
          ward['_id']?.toString() ??
          route['ward']?.toString() ??
          'unassigned-ward';
      groupedSchedules.putIfAbsent(wardId, () => []).add(route);
      wardLabels[wardId] = _wardLabel(ward);
    }

    final wardIds = groupedSchedules.keys.toList()
      ..sort(
        (a, b) => _wardSortValue(
          wardLabels[a],
        ).compareTo(_wardSortValue(wardLabels[b])),
      );

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: wardIds.length,
      separatorBuilder: (_, __) => const SizedBox(height: 22),
      itemBuilder: (context, index) {
        final wardId = wardIds[index];
        final routes = groupedSchedules[wardId]!;
        final scheduledCount = routes.where((route) {
          return route['startDate'] != null && route['endDate'] != null;
        }).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.map_outlined,
                    color: Color(0xFF2E7D32),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      wardLabels[wardId] ?? 'Ward not set',
                      style: const TextStyle(
                        color: Color(0xFF1A1C1E),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '$scheduledCount/${routes.length} scheduled',
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ...routes.map(_buildRouteScheduleCard),
          ],
        );
      },
    );
  }

  Widget _buildWasteTypePanel() {
    final categories = _categories
        .whereType<Map>()
        .map((category) => Map<String, dynamic>.from(category))
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.recycling_rounded,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly waste types',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Choose the month, then select the waste types for all wards.',
                      style: TextStyle(color: Colors.black45, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedMonth,
                  decoration: _compactSelectDecoration('Month'),
                  items: List.generate(
                    12,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text(_months[index]),
                    ),
                  ),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedMonth = value);
                    _loadMonthlyWastePlan();
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 130,
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedYear,
                  decoration: _compactSelectDecoration('Year'),
                  items: _yearOptions()
                      .map(
                        (year) => DropdownMenuItem(
                          value: year,
                          child: Text(year.toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedYear = value);
                    _loadMonthlyWastePlan();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _wasteTypeChip('Plastic', true),
              ...categories
                  .where((category) => !_isPlasticCategory(category))
                  .map(
                    (category) => _wasteTypeChip(
                      category['name']?.toString() ?? 'Waste',
                      false,
                      categoryId: category['_id']?.toString(),
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _categoryNameController,
                  style: const TextStyle(color: Color(0xFF1A1C1E)),
                  decoration: InputDecoration(
                    hintText: 'Add extra waste type, e.g. E-waste',
                    hintStyle: const TextStyle(
                      color: Colors.black26,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAF9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _addCategory,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: const Text(
                  'Add',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSavingWasteTypes ? null : _saveMonthlyWasteTypes,
              icon: _isSavingWasteTypes
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.calendar_month_rounded,
                      color: Colors.white,
                    ),
              label: Text(
                _isSavingWasteTypes
                    ? 'Saving...'
                    : 'Save ${_months[_selectedMonth - 1]} $_selectedYear for all wards',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wasteTypeChip(String label, bool required, {String? categoryId}) {
    final selected =
        required ||
        (categoryId != null && _selectedCategories.contains(categoryId));
    return Container(
      margin: EdgeInsets.zero,
      child: FilterChip(
        selected: selected,
        showCheckmark: !required,
        onSelected: required || categoryId == null
            ? null
            : (value) {
                setState(() {
                  if (value) {
                    _selectedCategories.add(categoryId);
                  } else {
                    _selectedCategories.remove(categoryId);
                  }
                });
              },
        avatar: Icon(
          required ? Icons.lock_rounded : Icons.recycling_rounded,
          size: 15,
        ),
        label: Text(required ? '$label (must)' : label),
        labelStyle: TextStyle(
          color: selected ? const Color(0xFF2E7D32) : const Color(0xFF526057),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
        selectedColor: const Color(0xFFE8F5E9),
        backgroundColor: const Color(0xFFF1F5F2),
        side: BorderSide(
          color: selected
              ? const Color(0xFF2E7D32)
              : Colors.black.withOpacity(0.06),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }

  Widget _buildRouteScheduleCard(Map<String, dynamic> route) {
    final ward = route['ward'] is Map ? route['ward'] as Map : {};
    final staff = route['assignedStaff'] is Map
        ? route['assignedStaff'] as Map
        : {};
    final routeName = route['name']?.toString() ?? 'Unnamed route';
    final wardLabel = _wardLabel(ward);
    final staffName = staff['name']?.toString().isNotEmpty == true
        ? staff['name'].toString()
        : staff['email']?.toString() ?? 'Not assigned';
    final startDate = _formatDate(route['startDate']);
    final endDate = _formatDate(route['endDate']);
    final isScheduled = route['startDate'] != null && route['endDate'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.route_rounded, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  routeName,
                  style: const TextStyle(
                    color: Color(0xFF1A1C1E),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    if (wardLabel != 'Ward not set')
                      _metaChip(Icons.map_outlined, wardLabel),
                    _metaChip(Icons.person_outline_rounded, staffName),
                    _metaChip(
                      Icons.event_available_outlined,
                      '$startDate - $endDate',
                    ),
                    _metaChip(
                      Icons.recycling_rounded,
                      _wasteTypesForRoute(route),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isScheduled
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isScheduled ? 'Scheduled' : 'Draft',
              style: TextStyle(
                color: isScheduled
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFE65100),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCompletionList() {
    if (_routeCompletions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: const Text(
          'No staff visit dates marked yet.',
          style: TextStyle(color: Colors.black38),
          textAlign: TextAlign.center,
        ),
      );
    }

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in _routeCompletions) {
      final row = Map<String, dynamic>.from(item as Map);
      final rawWard = row['ward']?.toString().trim() ?? '';
      final key = rawWard.isEmpty || rawWard == 'Ward not set' ? '' : rawWard;
      grouped.putIfAbsent(key, () => []).add(row);
    }

    final wards = grouped.keys.toList()
      ..sort((a, b) {
        if (a.isEmpty) return 1;
        if (b.isEmpty) return -1;
        return _wardSortValue(a).compareTo(_wardSortValue(b));
      });

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: wards.length,
      separatorBuilder: (_, __) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        final ward = wards[index];
        final rows = grouped[ward]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ward.isNotEmpty) ...[
              Text(
                ward,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(height: 8),
            ],
            ...rows.map(_buildCompletionCard),
          ],
        );
      },
    );
  }

  Widget _buildCompletionCard(Map<String, dynamic> row) {
    final status = row['routeStatus']?.toString() ?? 'Pending';
    final isCompleted = status == 'Completed';
    final color = isCompleted ? const Color(0xFF2E7D32) : Colors.orange[800]!;
    final bg = isCompleted ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0);
    final date = _formatDate(row['date']);
    final routeName = row['routeName']?.toString() ?? 'Route';
    final assignedStaff = row['assignedStaff']?.toString() ?? 'Not assigned';
    final selectedBy = row['selectedBy']?.toString() ?? 'Staff';
    final completedBy = row['completedBy']?.toString();
    final adminRange =
        '${_formatDate(row['adminStartDate'])} - ${_formatDate(row['adminEndDate'])}';
    final totals = row['totals'] is Map ? row['totals'] as Map : {};
    final totalHouses = totals['totalHouses'] ?? 0;
    final collectedHouses = totals['collectedHouses'] ?? 0;
    final notCollectedHouses = totals['notCollectedHouses'] ?? 0;
    final paidHouses = totals['paidHouses'] ?? 0;
    final unpaidHouses = totals['unpaidHouses'] ?? 0;
    final unpaidResidents = row['unpaidResidents'] is List
        ? row['unpaidResidents'] as List
        : const [];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCompleted
                      ? Icons.task_alt_rounded
                      : Icons.event_available_rounded,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routeName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 12,
                      runSpacing: 5,
                      children: [
                        _metaChip(Icons.calendar_today_outlined, date),
                        _metaChip(
                          Icons.person_outline_rounded,
                          'Assigned: $assignedStaff',
                        ),
                        _metaChip(
                          Icons.how_to_reg_outlined,
                          'Marked by: $selectedBy',
                        ),
                        if (completedBy != null && completedBy.isNotEmpty)
                          _metaChip(
                            Icons.verified_outlined,
                            'Completed by: $completedBy',
                          ),
                        _metaChip(
                          Icons.date_range_outlined,
                          'Admin range: $adminRange',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  isCompleted ? 'Completed' : 'In Progress',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (totalHouses != 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _countChip(
                  'Houses',
                  '$totalHouses',
                  Icons.home_work_outlined,
                  const Color(0xFF1976D2),
                ),
                _countChip(
                  'Done',
                  '$collectedHouses',
                  Icons.check_circle_outline,
                  const Color(0xFF2E7D32),
                ),
                _countChip(
                  'Not done',
                  '$notCollectedHouses',
                  Icons.cancel_outlined,
                  Colors.redAccent,
                ),
                _countChip(
                  'Paid',
                  '$paidHouses',
                  Icons.payments_outlined,
                  const Color(0xFF2E7D32),
                ),
                _countChip(
                  'Unpaid',
                  '$unpaidHouses',
                  Icons.money_off_rounded,
                  Colors.orange,
                ),
              ],
            ),
          ],
          if (unpaidResidents.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Residents not done payment',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1C1E),
              ),
            ),
            const SizedBox(height: 6),
            ...unpaidResidents.take(5).map((item) {
              final resident = item is Map ? item : {};
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  'House ${resident['houseNumber'] ?? 'N/A'} - ${resident['residentName'] ?? 'Resident'} (${resident['paymentStatus'] ?? 'Pending'})',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }),
            if (unpaidResidents.length > 5)
              Text(
                '+${unpaidResidents.length - 5} more unpaid resident(s)',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black38,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _countChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.black38),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(color: Colors.black45, fontSize: 12)),
      ],
    );
  }

  InputDecoration _compactSelectDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black45, fontSize: 12),
      filled: true,
      fillColor: const Color(0xFFF8FAF9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2E7D32)),
      ),
    );
  }

  List<int> _yearOptions() {
    final currentYear = DateTime.now().year;
    return List.generate(7, (index) => currentYear - 2 + index);
  }

  Future<void> _loadMonthlyWastePlan() async {
    final plan = await _apiService.getMonthlyWasteTypes(
      month: _selectedMonth,
      year: _selectedYear,
    );
    if (!mounted) return;
    setState(() => _applyMonthlyPlanSelection(plan));
  }

  void _applyMonthlyPlanSelection(Map<String, dynamic> plan) {
    final planTypes =
        (plan['wasteTypes'] is List ? plan['wasteTypes'] as List : const [])
            .map((item) => item.toString().trim().toLowerCase())
            .where((item) => item.isNotEmpty)
            .toSet();

    _selectedCategories.clear();
    for (final category in _categories) {
      if (category is! Map) continue;
      final id = category['_id']?.toString() ?? '';
      final name = category['name']?.toString().trim().toLowerCase() ?? '';
      if (id.isEmpty) continue;
      if (_isPlasticCategory(category) || planTypes.contains(name)) {
        _selectedCategories.add(id);
      }
    }
  }

  List<String> _selectedWasteTypeNames() {
    final values = <String>['Plastic'];
    for (final category in _categories) {
      if (category is! Map) continue;
      final id = category['_id']?.toString() ?? '';
      final name = category['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      if (_isPlasticCategory(category)) continue;
      if (_isPlasticCategory(category) || _selectedCategories.contains(id)) {
        if (!values.any((item) => item.toLowerCase() == name.toLowerCase())) {
          values.add(name);
        }
      }
    }
    return values;
  }

  Future<void> _saveMonthlyWasteTypes() async {
    setState(() => _isSavingWasteTypes = true);
    try {
      final result = await _apiService.saveMonthlyWasteTypes(
        month: _selectedMonth,
        year: _selectedYear,
        wasteTypes: _selectedWasteTypeNames(),
      );
      if (!mounted) return;
      final routeCount = result['updatedRouteSchedules'] ?? 0;
      final houseCount = result['updatedHouseAssignments'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved for ${_months[_selectedMonth - 1]} $_selectedYear. Updated $routeCount route schedules and $houseCount houses.',
          ),
          backgroundColor: const Color(0xFF00A651),
        ),
      );
      _fetchData();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save monthly waste types'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingWasteTypes = false);
    }
  }

  String _wardLabel(Map ward) {
    final number = ward['wardNumber']?.toString() ?? '';
    final name = ward['name']?.toString() ?? '';
    if (number.isNotEmpty && name.isNotEmpty) return 'Ward $number - $name';
    if (number.isNotEmpty) return 'Ward $number';
    if (name.isNotEmpty) return name;
    return 'Ward not set';
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return 'Not set';
    final date = DateTime.tryParse(raw.toString());
    if (date == null) return raw.toString();
    return '${date.day.toString().padLeft(2, '0')} ${_months[date.month - 1].substring(0, 3)} ${date.year}';
  }

  String _currentWasteTypesLabel() {
    return _selectedWasteTypeNames().join(', ');
  }

  String _wasteTypesForRoute(Map<String, dynamic> route) {
    final raw = route['monthlyWasteTypes'];
    if (raw is List && raw.isNotEmpty) {
      final values = <String>[];
      for (final item in raw) {
        final name = item.toString().trim();
        if (name.isEmpty) continue;
        final displayName = name.toLowerCase().contains('plastic')
            ? 'Plastic'
            : name;
        if (!values.any(
          (value) => value.toLowerCase() == displayName.toLowerCase(),
        )) {
          values.add(displayName);
        }
      }
      if (values.isNotEmpty) return values.join(', ');
    }

    final hasRouteMonth =
        route['startDate'] != null || route['endDate'] != null;
    return hasRouteMonth ? 'Plastic' : 'Set route month first';
  }

  int _wardSortValue(String? wardLabel) {
    final match = RegExp(r'Ward\s+(\d+)').firstMatch(wardLabel ?? '');
    return int.tryParse(match?.group(1) ?? '') ?? 9999;
  }

  Widget _buildSchedulesList() {
    return FutureBuilder<List<dynamic>>(
      future: _apiService.getMonthlySchedules(
        month: _isMonthlyPlan ? _selectedMonth : null,
        year: _isMonthlyPlan ? _selectedYear : null,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
          );
        final schedules = snapshot.data!;
        if (schedules.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
            ),
            child: const Center(
              child: Text(
                'No schedules found for this period',
                style: TextStyle(color: Colors.black26),
              ),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: schedules.length,
          itemBuilder: (context, index) {
            final s = schedules[index];
            final wasteTypes = _wasteTypesForSchedule(s);
            final date = s['date'] != null
                ? DateTime.tryParse(s['date'])
                : null;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.event_note_outlined,
                      color: Color(0xFF2E7D32),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wasteTypes,
                          style: const TextStyle(
                            color: Color(0xFF1A1C1E),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Ward ${s['wardNumber']?.toString() ?? ''}',
                          style: const TextStyle(
                            color: Colors.black38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    date != null
                        ? '${date.day} ${_months[date.month - 1].substring(0, 3)}'
                        : 'Monthly',
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2E7D32),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildAddCategoryRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _categoryNameController,
            style: const TextStyle(color: Color(0xFF1A1C1E)),
            decoration: InputDecoration(
              hintText: 'New Category (e.g. Plastic)',
              hintStyle: const TextStyle(color: Colors.black26, fontSize: 14),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _addCategory,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryList() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: _categories.isEmpty
          ? const Center(
              child: Text(
                'No categories found',
                style: TextStyle(color: Colors.black26),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _categories.length,
              separatorBuilder: (context, index) =>
                  const Divider(color: Colors.black12),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.category_outlined,
                    color: Color(0xFF2E7D32),
                    size: 18,
                  ),
                  title: Text(
                    cat['name'],
                    style: const TextStyle(
                      color: Color(0xFF1A1C1E),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildScheduleForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Waste Types',
            style: TextStyle(
              color: Color(0xFF1A1C1E),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((category) {
              final id = category['_id']?.toString() ?? '';
              final name = category['name']?.toString() ?? 'Waste';
              final isPlastic = _isPlasticCategory(category);
              final selected = isPlastic || _selectedCategories.contains(id);
              return FilterChip(
                label: Text(isPlastic ? '$name (must)' : name),
                selected: selected,
                onSelected: (value) {
                  setState(() {
                    if (value || isPlastic) {
                      _selectedCategories.add(id);
                    } else {
                      _selectedCategories.remove(id);
                    }
                  });
                },
                selectedColor: const Color(0xFFE8F5E9),
                checkmarkColor: const Color(0xFF2E7D32),
                labelStyle: TextStyle(
                  color: selected ? const Color(0xFF2E7D32) : Colors.black54,
                  fontWeight: FontWeight.w800,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _areaController,
            style: const TextStyle(color: Color(0xFF1A1C1E)),
            decoration: _formInputDecoration(
              'Ward Number',
              Icons.location_on_outlined,
            ),
          ),
          const SizedBox(height: 20),

          if (_isMonthlyPlan) ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedMonth,
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Color(0xFF1A1C1E)),
                    decoration: _formInputDecoration(
                      'Month',
                      Icons.calendar_month,
                    ),
                    items: List.generate(
                      12,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text(_months[index]),
                      ),
                    ),
                    onChanged: (v) => setState(() => _selectedMonth = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedYear,
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Color(0xFF1A1C1E)),
                    decoration: _formInputDecoration('Year', Icons.numbers),
                    items: [2024, 2025, 2026]
                        .map(
                          (y) => DropdownMenuItem(
                            value: y,
                            child: Text(y.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedYear = v!),
                  ),
                ),
              ],
            ),
          ] else ...[
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Color(0xFF2E7D32),
                        onPrimary: Colors.white,
                        surface: Colors.white,
                        onSurface: Color(0xFF1A1C1E),
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              child: InputDecorator(
                decoration: _formInputDecoration(
                  'Select Date',
                  Icons.calendar_today_outlined,
                ),
                child: Text(
                  "${_selectedDate.toLocal()}".split(' ')[0],
                  style: const TextStyle(
                    color: Color(0xFF1A1C1E),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _saveSchedule,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text(
              'PUBLISH SCHEDULE',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSchedule() async {
    final selectedIds = _normalizedSelectedCategoryIds();
    if (selectedIds.isEmpty || _areaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select waste type and ward'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final selectedNames = selectedIds
        .map(
          (id) => _categories.firstWhere(
            (cat) => cat['_id']?.toString() == id,
            orElse: () => null,
          ),
        )
        .where((cat) => cat != null)
        .map((cat) => cat['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();

    for (final categoryId in selectedIds) {
      final payload = {
        'date': _selectedDate.toIso8601String(),
        'month': _isMonthlyPlan ? _selectedMonth : _selectedDate.month,
        'year': _isMonthlyPlan ? _selectedYear : _selectedDate.year,
        'wardNumber': _areaController.text,
        'category': categoryId,
        'wasteTypes': selectedNames,
      };
      await _apiService.createSchedule(payload);
    }
    setState(() {
      _areaController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Schedule published successfully'),
        backgroundColor: Color(0xFF00E676),
      ),
    );
  }

  bool _isPlasticCategory(dynamic category) {
    final name = category is Map
        ? category['name']?.toString().toLowerCase() ?? ''
        : '';
    return name == 'plastic' || name.contains('plastic');
  }

  List<String> _normalizedSelectedCategoryIds() {
    final ids = <String>{..._selectedCategories};
    ids.addAll(
      _categories
          .where((cat) => _isPlasticCategory(cat))
          .map((cat) => cat['_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty),
    );
    return ids.toList();
  }

  String _wasteTypesForSchedule(dynamic schedule) {
    if (schedule is Map) {
      final rawTypes = schedule['wasteTypes'];
      if (rawTypes is List && rawTypes.isNotEmpty) {
        return rawTypes
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .join(', ');
      }
      return schedule['category']?['name']?.toString() ?? 'Plastic';
    }
    return 'Plastic';
  }

  InputDecoration _formInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black38, fontSize: 13),
      prefixIcon: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAF9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1),
      ),
    );
  }
}
