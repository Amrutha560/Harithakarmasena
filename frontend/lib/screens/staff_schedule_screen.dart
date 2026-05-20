import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'staff_routes_list_screen.dart';

class StaffScheduleScreen extends StatelessWidget {
  final List<dynamic> routes;
  final String staffName;
  final List<dynamic> monthlySchedules;

  const StaffScheduleScreen({
    super.key,
    required this.routes,
    required this.staffName,
    this.monthlySchedules = const [],
  });

  @override
  Widget build(BuildContext context) {
    final scheduledRoutes = routes.where((route) {
      if (route is! Map) return false;
      return route['startDate'] != null && route['endDate'] != null;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Schedule',
          style: TextStyle(
            color: Color(0xFF1A1C1E),
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: scheduledRoutes.isEmpty && monthlySchedules.isEmpty
          ? const Center(
              child: Text(
                'No admin schedule assigned yet.',
                style: TextStyle(
                  color: Colors.black45,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              itemCount:
                  scheduledRoutes.length + (monthlySchedules.isEmpty ? 0 : 1),
              itemBuilder: (context, index) {
                if (index == 0 && monthlySchedules.isNotEmpty) {
                  return _monthlyWasteCard();
                }
                final routeIndex = monthlySchedules.isEmpty ? index : index - 1;
                return _scheduleCard(context, scheduledRoutes[routeIndex]);
              },
            ),
    );
  }

  Widget _monthlyWasteCard() {
    final wasteTypes = _monthlyWasteTypes();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.recycling_rounded,
              color: Color(0xFF2E7D32),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This Month Waste Types',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1C1E),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  wasteTypes,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scheduleCard(BuildContext context, dynamic route) {
    final routeName = route is Map
        ? route['name']?.toString() ?? 'Route'
        : 'Route';
    final wardLabel = _routeWardLabel(route);
    final rangeLabel = route is Map
        ? _dateRangeLabel(route['startDate'], route['endDate'])
        : 'No date set';
    final wasteTypes = _routeWasteTypes(route);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: Color(0xFF2E7D32),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  routeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1C1E),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.map_rounded,
                      size: 15,
                      color: Colors.black45,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        wardLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.date_range_rounded,
                      size: 16,
                      color: Color(0xFF2E7D32),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Admin assigned: $rangeLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Open route',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StaffRoutesListScreen(
                    routes: [route],
                    staffName: staffName,
                  ),
                ),
              );
            },
            icon: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFF2E7D32),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  String _routeWardLabel(dynamic route) {
    if (route is! Map) return 'Ward';
    final ward = route['ward'];
    if (ward is Map) {
      final number = ward['wardNumber'] ?? ward['number'];
      final name = ward['wardName'] ?? ward['name'];
      if (number != null && name != null && name.toString().isNotEmpty) {
        return 'Ward $number - $name';
      }
      if (number != null) return 'Ward $number';
      if (name != null && name.toString().isNotEmpty) return name.toString();
    }
    return route['wardNumber'] == null ? 'Ward' : 'Ward ${route['wardNumber']}';
  }

  String _dateRangeLabel(dynamic startValue, dynamic endValue) {
    final start = _parseApiDate(startValue);
    final end = _parseApiDate(endValue);
    if (start == null || end == null) return 'No date set';
    final sameYear = start.year == end.year;
    final startFormat = DateFormat(sameYear ? 'd MMM' : 'd MMM yyyy');
    final endFormat = DateFormat('d MMM yyyy');
    return '${startFormat.format(start)} - ${endFormat.format(end)}';
  }

  DateTime? _parseApiDate(dynamic value) {
    if (value == null) return null;
    final raw = value.toString();
    final datePart = raw.contains('T') ? raw.split('T').first : raw;
    final parts = datePart.split('-');
    if (parts.length == 3) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year != null && month != null && day != null) {
        return DateTime(year, month, day);
      }
    }
    return DateTime.tryParse(raw);
  }

  String _monthlyWasteTypes() {
    final values = <String>['Plastic'];
    for (final schedule in monthlySchedules) {
      if (schedule is! Map) continue;
      final raw = schedule['wasteTypes'];
      if (raw is List) {
        for (final item in raw) {
          final value = item.toString().trim();
          final display = value.toLowerCase().contains('plastic')
              ? 'Plastic'
              : value;
          if (display.isNotEmpty &&
              !values.any(
                (existing) => existing.toLowerCase() == display.toLowerCase(),
              )) {
            values.add(display);
          }
        }
      } else {
        final category = schedule['category'];
        final name = category is Map
            ? category['name']?.toString().trim() ?? ''
            : '';
        if (name.toLowerCase().contains('plastic')) continue;
        if (name.isNotEmpty &&
            !values.any(
              (existing) => existing.toLowerCase() == name.toLowerCase(),
            )) {
          values.add(name);
        }
      }
    }
    return values.join(', ');
  }

  String _routeWasteTypes(dynamic route) {
    if (route is Map) {
      final raw = route['monthlyWasteTypes'];
      if (raw is List && raw.isNotEmpty) {
        final values = <String>[];
        for (final item in raw) {
          final value = item.toString().trim();
          if (value.isEmpty) continue;
          final display = value.toLowerCase().contains('plastic')
              ? 'Plastic'
              : value;
          if (!values.any(
            (existing) => existing.toLowerCase() == display.toLowerCase(),
          )) {
            values.add(display);
          }
        }
        if (values.isNotEmpty) return values.join(', ');
      }
    }
    return _monthlyWasteTypes();
  }
}
