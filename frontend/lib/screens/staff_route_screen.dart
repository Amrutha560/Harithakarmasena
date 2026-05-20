import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'staff_dashboard.dart';
import 'proof_of_collection_screen.dart';

class StaffRouteScreen extends StatefulWidget {
  final Map<String, dynamic> routeData;
  final String staffName;
  final String? selectedDate;

  const StaffRouteScreen({
    super.key,
    required this.routeData,
    required this.staffName,
    this.selectedDate,
  });

  @override
  State<StaffRouteScreen> createState() => _StaffRouteScreenState();
}

class _StaffRouteScreenState extends State<StaffRouteScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _houses = [];
  List<dynamic> _residents = [];
  Map<String, dynamic>? _schedule;
  final Set<String> _visitedDates = {};
  String? _activeVisitDate;
  bool _isLoading = true;
  bool _isCompleting = false;
  String _searchQuery = '';
  bool _showResidents = false;

  @override
  void initState() {
    super.initState();
    _activeVisitDate = widget.selectedDate;
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final routeId = widget.routeData['_id']?.toString() ?? '';
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final routeStart = widget.routeData['startDate'] == null
          ? null
          : DateTime.tryParse(widget.routeData['startDate'].toString());
      final routeEnd = widget.routeData['endDate'] == null
          ? null
          : DateTime.tryParse(widget.routeData['endDate'].toString());
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

      // Fetch ALL schedules and pick the best one (today first, else nearest)
      final allSchedules = await _apiService.getAllRouteSchedules(routeId);
      Map<String, dynamic>? bestSchedule;
      _visitedDates
        ..clear()
        ..addAll(
          allSchedules
              .where((s) => s['visitStatus']?.toString() == 'Visited')
              .map<String>((s) => s['date']?.toString() ?? '')
              .where((date) => date.isNotEmpty && isInsideCurrentRange(date)),
        );
      if (allSchedules.isNotEmpty) {
        dynamic best;
        if (_activeVisitDate != null && _activeVisitDate!.isNotEmpty) {
          best = allSchedules.firstWhere(
            (s) => s['date']?.toString() == _activeVisitDate,
            orElse: () => null,
          );
        }
        best ??= allSchedules.firstWhere(
          (s) => s['date']?.toString() == todayStr,
          orElse: () => allSchedules.reduce((a, b) {
            final aDate = a['date']?.toString() ?? '';
            final bDate = b['date']?.toString() ?? '';
            final aDiff = (aDate.compareTo(todayStr)).abs();
            final bDiff = (bDate.compareTo(todayStr)).abs();
            return aDiff <= bDiff ? a : b;
          }),
        );
        bestSchedule = best is Map
            ? Map<String, dynamic>.from(best as Map)
            : null;
      }

      List<dynamic> houses = [];
      if (bestSchedule != null && bestSchedule['assignments'] != null) {
        for (var a in bestSchedule['assignments']) {
          if (a['house'] != null && a['house'] is Map) {
            final h = Map<String, dynamic>.from(a['house'] as Map);
            h['assignmentId'] =
                a['assignmentId']?.toString() ?? h['assignmentId']?.toString();
            if (h['resident'] is Map) {
              h['residentId'] = h['resident']['_id']?.toString();
            } else {
              h['residentId'] = h['resident']?.toString();
            }
            h['assignedTime'] = a['collectionTime']?.toString();
            h['assignedWasteTypes'] = a['wasteTypes'];
            h['date'] = bestSchedule['date']?.toString();
            houses.add(h);
          }
        }
      }

      // Fallback: load houses from route if schedule has none
      if (houses.isEmpty) {
        final routeHouses = await _apiService.getHousesInRoute(routeId);
        houses = routeHouses;
      }

      // Fetch registered residents for this route
      List<dynamic> residents = [];
      try {
        final allResidents = await _apiService.getAssignedResidents();
        residents = allResidents
            .where((r) => r['route']?.toString() == routeId)
            .toList();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _schedule = bestSchedule;
          _houses = houses;
          _residents = residents;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markCollected(String houseId, List<dynamic>? wasteTypes) async {
    try {
      await _apiService.markCollection({
        'houseId': houseId,
        'routeId': widget.routeData['_id']?.toString() ?? '',
        'status': 'Collected',
        'wasteTypes': wasteTypes ?? [],
      });
      _fetchData();
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error updating status')));
    }
  }

  Future<void> _markHouseCollection(
    Map<String, dynamic> house,
    String status,
  ) async {
    try {
      await _apiService.markCollection({
        'assignmentId': house['assignmentId']?.toString(),
        'houseId': house['_id']?.toString() ?? '',
        'routeId': widget.routeData['_id']?.toString() ?? '',
        'date':
            _schedule?['date']?.toString() ??
            house['date']?.toString() ??
            DateTime.now().toIso8601String().split('T')[0],
        'status': status,
        'wasteTypes': house['assignedWasteTypes'] ?? [],
      });
      await _fetchData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'Collected'
                ? 'Marked as collected'
                : 'Marked as not collected',
          ),
          backgroundColor: status == 'Collected'
              ? const Color(0xFF2E7D32)
              : Colors.redAccent,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error updating collection status')),
      );
    }
  }

  Future<void> _skipUnit(String houseId) async {
    try {
      await _apiService.markCollection({
        'houseId': houseId,
        'routeId': widget.routeData['_id']?.toString() ?? '',
        'status': 'Not Collected',
      });
      _fetchData();
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error skipping unit')));
    }
  }

  Future<void> _markRouteVisited() async {
    try {
      final date =
          _schedule?['date']?.toString() ??
          DateTime.now().toIso8601String().split('T')[0];
      await _apiService.markRouteVisited(
        widget.routeData['_id']?.toString() ?? '',
        date,
      );
      _activeVisitDate = date;
      await _fetchData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Route marked as visited'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not mark route as visited')),
      );
    }
  }

  Future<void> _markVisitDateFromCalendar(DateTime day) async {
    try {
      final date = day.toIso8601String().split('T')[0];
      _activeVisitDate = date;
      final routeId = widget.routeData['_id']?.toString() ?? '';
      final wasVisited = _visitedDates.contains(date);
      if (wasVisited) {
        await _apiService.unmarkRouteVisited(routeId, date);
      } else {
        await _apiService.markRouteVisited(routeId, date);
      }
      await _fetchData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasVisited
                ? 'Staff visit date removed for ${DateFormat('dd MMM yyyy').format(day)}'
                : 'Staff visit date marked for ${DateFormat('dd MMM yyyy').format(day)}',
          ),
          backgroundColor: wasVisited
              ? Colors.blueGrey
              : const Color(0xFFC62828),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not mark staff visit date')),
      );
    }
  }

  Future<void> _selectVisitDateFromCalendar(DateTime day) async {
    final date = day.toIso8601String().split('T')[0];
    if (_activeVisitDate == date) return;
    _activeVisitDate = date;
    await _fetchData();
  }

  Future<void> _markCashPaid(Map<String, dynamic> house) async {
    try {
      await _apiService.recordPayment({
        'assignmentId': house['assignmentId']?.toString() ?? '',
        'houseId': house['_id']?.toString() ?? '',
        'residentId': house['residentId']?.toString() ?? '',
        'routeId': widget.routeData['_id']?.toString() ?? '',
        'amount': 50,
        'method': 'Cash',
        'date':
            _schedule?['date']?.toString() ??
            DateTime.now().toIso8601String().split('T')[0],
      });
      await _fetchData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment marked as paid in cash'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not mark cash payment')),
      );
    }
  }

  Future<void> _completeRoute() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    try {
      final date =
          _schedule?['date']?.toString() ??
          DateTime.now().toIso8601String().split('T')[0];
      final result = await _apiService.completeRoute(
        widget.routeData['_id']?.toString() ?? '',
        date,
      );
      await _fetchData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Route report sent to admin'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message.isEmpty ? 'Could not complete route' : message),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF2E7D32);
    final routeName = widget.routeData['name']?.toString() ?? 'Route';

    // Safe ward string — only if ward is a populated Map
    String wardLabel = '';
    if (widget.routeData['ward'] != null && widget.routeData['ward'] is Map) {
      final ward = widget.routeData['ward'] as Map;
      final num = ward['wardNumber']?.toString() ?? '';
      final name = ward['name']?.toString() ?? '';
      wardLabel = num.isNotEmpty ? 'Ward $num' : name;
    }

    // Schedule info — prefer commonTime, fall back to first assignment's collectionTime
    String scheduledTime = _schedule?['commonTime']?.toString() ?? '';
    if (scheduledTime.isEmpty && _houses.isNotEmpty) {
      scheduledTime = _houses.first['assignedTime']?.toString() ?? '';
    }
    if (scheduledTime.isEmpty) scheduledTime = 'Not scheduled';

    final scheduledDate = _schedule?['date']?.toString() ?? 'Today';

    // Waste types: admin's month plan should be shown before stale per-date schedule values.
    final routeMonthlyWasteTypes = widget.routeData['monthlyWasteTypes'];
    final rawWasteTypes =
        routeMonthlyWasteTypes is List && routeMonthlyWasteTypes.isNotEmpty
        ? routeMonthlyWasteTypes
        : _schedule?['commonWasteTypes'];
    String wasteLabel = '';
    if (rawWasteTypes is List && rawWasteTypes.isNotEmpty) {
      wasteLabel = _cleanWasteTypes(rawWasteTypes);
    }
    if (wasteLabel.isEmpty && _houses.isNotEmpty) {
      final firstWaste = _houses.first['assignedWasteTypes'];
      if (firstWaste is List && firstWaste.isNotEmpty) {
        wasteLabel = _cleanWasteTypes(firstWaste);
      }
    }
    if (wasteLabel.isEmpty) wasteLabel = 'Not specified';

    // Filtered houses
    final filteredHouses = _searchQuery.isEmpty
        ? _houses
        : _houses.where((h) {
            final name = (h['ownerName'] ?? '').toString().toLowerCase();
            final address = (h['address'] ?? '').toString().toLowerCase();
            final num = (h['houseNumber'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery) ||
                address.contains(_searchQuery) ||
                num.contains(_searchQuery);
          }).toList();

    final totalCount = _houses.length;
    final collectedCount = _houses
        .where((h) => h['collectionStatus']?.toString() == 'Collected')
        .length;
    final handledCount = _houses.where((h) {
      final collectionStatus = h['collectionStatus']?.toString() ?? 'Pending';
      final response = h['residentResponse']?.toString() ?? 'Pending';
      return collectionStatus == 'Collected' ||
          collectionStatus == 'Not Collected' ||
          response == 'Not Available';
    }).length;
    final visibleDateLabel = _schedule?['date'] != null
        ? DateFormat(
            'dd MMM yyyy',
          ).format(DateTime.parse(_schedule!['date'].toString()))
        : 'selected date';
    final isRouteCompleted =
        _schedule?['routeStatus']?.toString() == 'Completed';
    final canFinishRoute =
        totalCount > 0 && handledCount == totalCount && !isRouteCompleted;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          routeName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(color: primaryGreen),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_rounded, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // ── Green Info Header ─────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    color: primaryGreen,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routeName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (wardLabel.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                color: Colors.white70,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                wardLabel,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),
                        _buildAssignedCalendar(primaryGreen),
                      ],
                    ),
                  ),

                  // ── Search Bar ────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          const Icon(
                            Icons.search_rounded,
                            color: Colors.black38,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              onChanged: (v) => setState(
                                () => _searchQuery = v.toLowerCase(),
                              ),
                              style: const TextStyle(fontSize: 14),
                              decoration: const InputDecoration(
                                hintText: 'Search house or resident...',
                                hintStyle: TextStyle(
                                  color: Colors.black38,
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Registered Residents Toggle ──────────────────────────────
                  if (_residents.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: InkWell(
                        onTap: () =>
                            setState(() => _showResidents = !_showResidents),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.teal.withOpacity(0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.people_alt_rounded,
                                color: Colors.teal,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'REGISTERED RESIDENTS (${_residents.length})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.teal,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Icon(
                                _showResidents
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: Colors.teal,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // ── Residents List (Collapsible) ──────────────────────────────
                  if (_showResidents && _residents.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Column(
                        children: _residents.map<Widget>((res) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.teal.withOpacity(0.1),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    res['houseNumber']?.toString() ?? '?',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      color: Colors.teal,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${res['firstName'] ?? ''} ${res['lastName'] ?? ''}'
                                            .trim(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF1A1C1E),
                                        ),
                                      ),
                                      if (res['address'] != null)
                                        Text(
                                          res['address'],
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black54,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (res['phoneNumber'] != null)
                                  Text(
                                    res['phoneNumber'],
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.teal,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  // ── Header Label ──────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ADMIN ASSIGNED HOUSES',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.black45,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${filteredHouses.length} Houses',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Showing $visibleDateLabel',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── House List ─────────────────────────────────────────────────
                  if (filteredHouses.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isRouteCompleted
                              ? primaryGreen.withOpacity(0.1)
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isRouteCompleted
                                  ? Icons.verified_rounded
                                  : Icons.task_alt_rounded,
                              size: 18,
                              color: isRouteCompleted
                                  ? primaryGreen
                                  : Colors.black45,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                isRouteCompleted
                                    ? 'Route report sent to admin'
                                    : 'Complete all house visits to finish route ($handledCount/$totalCount)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: isRouteCompleted
                                      ? primaryGreen
                                      : Colors.black45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  filteredHouses.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 80),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.home_rounded,
                                size: 56,
                                color: Colors.black26,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No houses found.',
                                style: TextStyle(color: Colors.black45),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 156),
                          itemCount: filteredHouses.length,
                          itemBuilder: (context, index) =>
                              _buildHouseCard(filteredHouses[index]),
                        ),
                ],
              ),
            ),
      bottomNavigationBar: _isLoading
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 18,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isRouteCompleted
                                ? 'Report sent'
                                : 'Completed $handledCount/$totalCount visits',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1A1C1E),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isRouteCompleted
                                ? 'Admin can view this route in Reports'
                                : canFinishRoute
                                ? 'Ready to finish and send report'
                                : 'Finish after pending houses are handled',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: canFinishRoute ? _completeRoute : null,
                        icon: _isCompleting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                isRouteCompleted
                                    ? Icons.verified_rounded
                                    : Icons.send_rounded,
                                size: 18,
                              ),
                        label: Text(
                          isRouteCompleted
                              ? 'Completed'
                              : 'Finish & Send Report',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          disabledForegroundColor: Colors.black45,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
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

  Widget _greenChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedCalendar(Color primaryGreen) {
    final rawStart = widget.routeData['startDate'];
    final rawEnd = widget.routeData['endDate'];
    if (rawStart == null || rawEnd == null) {
      return const SizedBox.shrink();
    }

    DateTime start;
    DateTime end;
    try {
      start = DateTime.parse(rawStart.toString());
      end = DateTime.parse(rawEnd.toString());
    } catch (_) {
      return const SizedBox.shrink();
    }

    final firstOfMonth = DateTime(start.year, start.month, 1);
    final daysInMonth = DateTime(start.year, start.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday % 7;
    final rowCount = ((leadingBlanks + daysInMonth) / 7).ceil();
    final monthLabel = DateFormat('MMMM yyyy').format(firstOfMonth);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Staff assigned calendar - $monthLabel',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM').format(end)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Click a date to view houses for that date. Double-click to mark or remove the red staff visit date.',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
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
                          color: Colors.white70,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
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
                  final dateKey = day.toIso8601String().split('T')[0];
                  final showRed = inRange && _visitedDates.contains(dateKey);

                  return Expanded(
                    child: InkWell(
                      onTap: inRange
                          ? () => _selectVisitDateFromCalendar(day)
                          : null,
                      onDoubleTap: inRange
                          ? () => _markVisitDateFromCalendar(day)
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
                                    ? Colors.white.withOpacity(0.22)
                                    : Colors.transparent),
                          borderRadius: BorderRadius.circular(8),
                          border: showRed
                              ? Border.all(
                                  color: const Color(0xFFFF8A80),
                                  width: 1.5,
                                )
                              : (inRange
                                    ? Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                      )
                                    : null),
                        ),
                        child: Text(
                          '$dayNumber',
                          style: TextStyle(
                            color: showRed
                                ? const Color(0xFFC62828)
                                : (inRange ? Colors.white : Colors.white54),
                            fontWeight: inRange
                                ? FontWeight.w900
                                : FontWeight.w600,
                            fontSize: 11,
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

  Widget _buildHouseCard(dynamic house) {
    final response = house['residentResponse']?.toString() ?? 'Pending';
    final status = house['collectionStatus']?.toString() ?? 'Pending';
    final isNotAvailable = response == 'Not Available';
    final isCollected = status == 'Collected';
    final isNotCollected = status == 'Not Collected';
    final paymentStatus = house['paymentStatus']?.toString() ?? 'Pending';
    final paymentMode =
        house['paymentMode']?.toString() ??
        house['paymentMethod']?.toString() ??
        '';
    String availabilityDate = '';
    final rawAvailabilityDate = house['availabilityDate']?.toString();
    if (rawAvailabilityDate != null &&
        rawAvailabilityDate.isNotEmpty &&
        response != 'Pending') {
      availabilityDate = DateFormat(
        'dd MMM yyyy',
      ).format(DateTime.parse(rawAvailabilityDate));
    }

    final edgeColor = isNotAvailable
        ? const Color(0xFFC62828)
        : (isCollected ? const Color(0xFF2E7D32) : const Color(0xFF2E7D32));
    final numberBg = isNotAvailable
        ? const Color(0xFFFFCDD2)
        : const Color(0xFFB9F6CA);

    final houseNo = house['houseNumber']?.toString() ?? '?';
    final ownerName = house['ownerName']?.toString() ?? 'Resident';
    final address = house['address']?.toString() ?? '';
    final phone = house['phoneNumber']?.toString() ?? 'No phone';
    final digits = houseNo.replaceAll(RegExp(r'[^0-9]'), '');
    final displayNo = digits.isNotEmpty
        ? (digits.length > 2 ? digits.substring(0, 2) : digits)
        : '??';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            if (isCollected) return;
            if (isNotAvailable) {
              _skipUnit(house['_id']?.toString() ?? '');
              return;
            }
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProofOfCollectionScreen(
                  houseData: house,
                  routeId: widget.routeData['_id']?.toString() ?? '',
                ),
              ),
            );
            if (result == true) {
              _fetchData();
            }
          },
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Colored Edge
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: edgeColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        // Number Box
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: numberBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            displayNo,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ownerName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              if (address.isNotEmpty) ...[
                                const SizedBox(height: 1),
                                Text(
                                  address,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.phone_rounded,
                                    size: 11,
                                    color: Color(0xFF1565C0),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    phone,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1565C0),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Status pills
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _statusPill(response),
                                  if (availabilityDate.isNotEmpty)
                                    _datePill(availabilityDate),
                                  _paymentPill(paymentStatus, paymentMode),
                                ],
                              ),
                              if (!isCollected) ...[
                                const SizedBox(height: 9),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _collectionActionButton(
                                      label: 'Collected',
                                      icon: Icons.check_circle_rounded,
                                      color: const Color(0xFF2E7D32),
                                      filled: status == 'Collected',
                                      onPressed: () => _markHouseCollection(
                                        Map<String, dynamic>.from(house as Map),
                                        'Collected',
                                      ),
                                    ),
                                    _collectionActionButton(
                                      label: 'Not collected',
                                      icon: Icons.cancel_rounded,
                                      color: Colors.redAccent,
                                      filled: isNotCollected,
                                      onPressed: () => _markHouseCollection(
                                        Map<String, dynamic>.from(house as Map),
                                        'Not Collected',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Status Icon
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (paymentStatus != 'Paid' &&
                                paymentStatus != 'Paid in Cash')
                              IconButton(
                                tooltip: 'Paid in cash',
                                onPressed: () => _markCashPaid(
                                  Map<String, dynamic>.from(house as Map),
                                ),
                                icon: const Icon(
                                  Icons.payments_rounded,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            if (isCollected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF2E7D32),
                                size: 30,
                              )
                            else
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.black.withOpacity(0.1),
                                size: 16,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _paymentPill(String status, [String mode = '']) {
    Color bg = Colors.orange.withOpacity(0.1);
    Color text = Colors.orange[800]!;
    String label = 'Payment: $status';

    if (status.toLowerCase() == 'paid') {
      bg = const Color(0xFFE8F5E9);
      text = const Color(0xFF2E7D32);
      label = mode.isNotEmpty ? 'Paid ($mode)' : 'Paid';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _collectionActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool filled,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 34,
      child: filled
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 15),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 15),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withOpacity(0.45)),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
    );
  }

  Widget _datePill(String dateLabel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_today_rounded,
            size: 8,
            color: Color(0xFF1565C0),
          ),
          const SizedBox(width: 4),
          Text(
            dateLabel,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1565C0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String response) {
    Color bg, fg;
    String label;
    IconData icon;

    if (response == 'Not Available') {
      bg = const Color(0xFFFFEBEE);
      fg = const Color(0xFFC62828);
      label = 'NOT AVAILABLE';
      icon = Icons.cancel_outlined;
    } else if (response == 'Available') {
      bg = const Color(0xFFE8F5E9);
      fg = const Color(0xFF2E7D32);
      label = 'AVAILABLE';
      icon = Icons.circle;
    } else {
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFE65100);
      label = 'PENDING';
      icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 8, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
