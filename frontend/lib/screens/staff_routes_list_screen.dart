import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'staff_route_screen.dart';

class StaffRoutesListScreen extends StatefulWidget {
  final List<dynamic> routes;
  final String staffName;
  final String? selectedDay;

  const StaffRoutesListScreen({
    super.key,
    required this.routes,
    required this.staffName,
    this.selectedDay,
  });

  @override
  State<StaffRoutesListScreen> createState() => _StaffRoutesListScreenState();
}

class _StaffRoutesListScreenState extends State<StaffRoutesListScreen> {
  final ApiService _apiService = ApiService();
  final Map<String, dynamic> _schedulesPerRoute = {};
  final Map<String, Set<String>> _visitedDatesPerRoute = {};
  final Map<String, String> _selectedVisitDatePerRoute = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAllSchedules();
  }

  Future<void> _fetchAllSchedules() async {
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    await Future.wait(
      widget.routes.map((r) async {
        final routeId = r['_id']?.toString() ?? '';
        if (routeId.isEmpty) return;
        try {
          final allSchedules = await _apiService.getAllRouteSchedules(routeId);
          final routeStart = r['startDate'] == null
              ? null
              : DateTime.tryParse(r['startDate'].toString());
          final routeEnd = r['endDate'] == null
              ? null
              : DateTime.tryParse(r['endDate'].toString());
          bool isInsideCurrentRange(String date) {
            final parsed = DateTime.tryParse(date);
            if (parsed == null || routeStart == null || routeEnd == null)
              return true;
            final day = DateTime(parsed.year, parsed.month, parsed.day);
            final start = DateTime(
              routeStart.year,
              routeStart.month,
              routeStart.day,
            );
            final end = DateTime(routeEnd.year, routeEnd.month, routeEnd.day);
            return !day.isBefore(start) && !day.isAfter(end);
          }

          _visitedDatesPerRoute[routeId] = allSchedules
              .where((s) => s['visitStatus']?.toString() == 'Visited')
              .map<String>((s) => s['date']?.toString() ?? '')
              .where((date) => date.isNotEmpty && isInsideCurrentRange(date))
              .toSet();
          if (allSchedules.isNotEmpty) {
            // Prefer today's schedule, then nearest upcoming, then most recent past
            dynamic best = allSchedules.firstWhere(
              (s) => s['date']?.toString() == todayStr,
              orElse: () => allSchedules.reduce((a, b) {
                final aDate = a['date']?.toString() ?? '';
                final bDate = b['date']?.toString() ?? '';
                // Sort to pick nearest to today
                final aDiff = (aDate.compareTo(todayStr)).abs();
                final bDiff = (bDate.compareTo(todayStr)).abs();
                return aDiff <= bDiff ? a : b;
              }),
            );
            _schedulesPerRoute[routeId] = best;
            final visited = _visitedDatesPerRoute[routeId];
            if (visited != null && visited.isNotEmpty) {
              final sortedVisited = visited.toList()..sort();
              _selectedVisitDatePerRoute[routeId] = visited.contains(todayStr)
                  ? todayStr
                  : sortedVisited.firstWhere(
                      (date) => date.compareTo(todayStr) >= 0,
                      orElse: () => sortedVisited.last,
                    );
            }
          }
        } catch (_) {}
      }),
    );
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _markStaffVisitDate(dynamic route, DateTime day) async {
    final routeId = route['_id']?.toString() ?? '';
    if (routeId.isEmpty) return;

    final date = day.toIso8601String().split('T')[0];
    final alreadyMarked =
        _visitedDatesPerRoute[routeId]?.contains(date) == true ||
        _selectedVisitDatePerRoute[routeId] == date;
    try {
      final result = alreadyMarked
          ? await _apiService.unmarkRouteVisited(routeId, date)
          : await _apiService.markRouteVisited(routeId, date);
      if (result['message'] == null && result['error'] != null) {
        throw Exception(result['error']);
      }
      if (!mounted) return;
      setState(() {
        final visitedDates = _visitedDatesPerRoute.putIfAbsent(
          routeId,
          () => <String>{},
        );
        if (alreadyMarked) {
          visitedDates.remove(date);
          if (_selectedVisitDatePerRoute[routeId] == date) {
            _selectedVisitDatePerRoute.remove(routeId);
          }
        } else {
          _selectedVisitDatePerRoute[routeId] = date;
          visitedDates.add(date);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            alreadyMarked
                ? 'Visit date removed for ${DateFormat('dd MMM yyyy').format(day)}'
                : 'Visit date marked for ${DateFormat('dd MMM yyyy').format(day)}',
          ),
          backgroundColor: alreadyMarked
              ? Colors.orangeAccent
              : const Color(0xFFC62828),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            alreadyMarked
                ? 'Could not remove staff visit date'
                : 'Could not mark staff visit date',
          ),
        ),
      );
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Routes',
          style: TextStyle(
            color: Color(0xFF1A1C1E),
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: const [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF2E7D32),
              child: const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : widget.routes.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.route_rounded, size: 64, color: Colors.black26),
                  SizedBox(height: 16),
                  Text(
                    'No routes assigned yet.',
                    style: TextStyle(color: Colors.black45, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Contact your admin to get assigned.',
                    style: TextStyle(color: Colors.black38, fontSize: 13),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchAllSchedules,
              color: primaryGreen,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                itemCount: widget.routes.length,
                itemBuilder: (context, index) {
                  return _buildRouteCard(widget.routes[index], index);
                },
              ),
            ),
    );
  }

  Widget _buildRouteCard(dynamic route, int index) {
    final routeId = route['_id']?.toString() ?? '';
    final routeName = route['name']?.toString() ?? 'Route #${index + 1}';

    // Safe ward access — only if ward is a populated Map, not a bare ObjectId string
    String wardLabel = 'Ward';
    if (route['ward'] != null && route['ward'] is Map) {
      final ward = route['ward'] as Map;
      final wardNum = ward['wardNumber']?.toString() ?? '';
      final wardName = ward['name']?.toString() ?? '';
      wardLabel = wardNum.isNotEmpty
          ? 'Ward $wardNum'
          : (wardName.isNotEmpty ? wardName : 'Ward');
    }

    final schedule = _schedulesPerRoute[routeId];

    final hasSchedule = schedule != null;
    final wasteTypes = _wasteTypesForSchedule(schedule, route: route);
    final List<String> images = [
      'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1449844908441-8829872d2607?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?auto=format&fit=crop&w=800&q=80',
    ];
    final imgUrl = images[index % images.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Route Image
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: Image.network(
              imgUrl,
              height: 130,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          // Info Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route Name + Ward
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            routeName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              color: Color(0xFF1A1C1E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                color: Color(0xFF2E7D32),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                wardLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: hasSchedule
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        hasSchedule ? 'Scheduled' : 'No Schedule',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: hasSchedule
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFE65100),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                const SizedBox(height: 12),

                if (route['startDate'] != null && route['endDate'] != null) ...[
                  _buildRangeCalendar(route),
                  const SizedBox(height: 12),
                ],
                if (wasteTypes.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.recycling_rounded,
                        size: 16,
                        color: Color(0xFF2E7D32),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          wasteTypes,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Tap to view
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StaffRouteScreen(
                          routeData: route,
                          staffName: widget.staffName,
                          selectedDate: _selectedVisitDatePerRoute[routeId],
                        ),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View Route',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Color(0xFF2E7D32),
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _wasteTypesForSchedule(dynamic schedule, {dynamic route}) {
    if (route is Map) {
      final monthly = route['monthlyWasteTypes'];
      if (monthly is List && monthly.isNotEmpty) {
        return _cleanWasteTypes(monthly);
      }
    }
    if (schedule is Map) {
      final common = schedule['commonWasteTypes'];
      if (common is List && common.isNotEmpty) {
        return _cleanWasteTypes(common);
      }
      final assignments = schedule['assignments'];
      if (assignments is List &&
          assignments.isNotEmpty &&
          assignments.first is Map) {
        final firstWaste = (assignments.first as Map)['wasteTypes'];
        if (firstWaste is List && firstWaste.isNotEmpty) {
          return _cleanWasteTypes(firstWaste);
        }
      }
    }
    return 'Plastic';
  }

  String _cleanWasteTypes(List raw) {
    final values = <String>[];
    for (final item in raw) {
      final name = item.toString().trim();
      if (name.isEmpty) continue;
      final display = name.toLowerCase().contains('plastic') ? 'Plastic' : name;
      if (!values.any(
        (value) => value.toLowerCase() == display.toLowerCase(),
      )) {
        values.add(display);
      }
    }
    return values.join(', ');
  }

  Widget _buildRangeCalendar(dynamic route) {
    final routeId = route['_id']?.toString() ?? '';
    final start = DateTime.parse(route['startDate']);
    final end = DateTime.parse(route['endDate']);
    final firstOfMonth = DateTime(start.year, start.month, 1);
    final daysInMonth = DateTime(start.year, start.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday % 7;
    final totalCells = leadingBlanks + daysInMonth;
    final rowCount = (totalCells / 7).ceil();
    final monthLabel = DateFormat('MMMM yyyy').format(firstOfMonth);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2EEE5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                color: Color(0xFF2E7D32),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Admin assigned calendar - $monthLabel',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1C1E),
                  ),
                ),
              ),
              Text(
                '${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM').format(end)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: const [
              Icon(Icons.touch_app_rounded, size: 14, color: Color(0xFFC62828)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Double-click a green date to mark it red. Double-click the same red date to remove it.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.black45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.black38,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),
          ...List.generate(rowCount, (row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: List.generate(7, (col) {
                  final cellIndex = row * 7 + col;
                  final dayNumber = cellIndex - leadingBlanks + 1;
                  if (dayNumber < 1 || dayNumber > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 30));
                  }

                  final day = DateTime(start.year, start.month, dayNumber);
                  final inRange =
                      !day.isBefore(
                        DateTime(start.year, start.month, start.day),
                      ) &&
                      !day.isAfter(DateTime(end.year, end.month, end.day));
                  final isStart =
                      day.year == start.year &&
                      day.month == start.month &&
                      day.day == start.day;
                  final isEnd =
                      day.year == end.year &&
                      day.month == end.month &&
                      day.day == end.day;
                  final dateKey = day.toIso8601String().split('T')[0];
                  final isVisited =
                      _visitedDatesPerRoute[routeId]?.contains(dateKey) == true;
                  final isSelected =
                      _selectedVisitDatePerRoute[routeId] == dateKey;
                  final showRed = inRange && (isVisited || isSelected);

                  return Expanded(
                    child: InkWell(
                      onDoubleTap: inRange
                          ? () => _markStaffVisitDate(route, day)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 30,
                        alignment: Alignment.center,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: showRed
                              ? const Color(0xFFFFCDD2)
                              : (inRange
                                    ? const Color(0xFFDDEFE2)
                                    : Colors.transparent),
                          borderRadius: BorderRadius.circular(8),
                          border: showRed
                              ? Border.all(
                                  color: const Color(0xFFC62828),
                                  width: 1.5,
                                )
                              : ((isStart || isEnd)
                                    ? Border.all(
                                        color: const Color(0xFF2E7D32),
                                        width: 1.5,
                                      )
                                    : null),
                        ),
                        child: Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: inRange
                                ? FontWeight.w900
                                : FontWeight.w600,
                            color: showRed
                                ? const Color(0xFFC62828)
                                : (inRange
                                      ? const Color(0xFF2E7D32)
                                      : Colors.black54),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }
}
