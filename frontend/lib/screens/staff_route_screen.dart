import 'package:flutter/material.dart';
import '../services/api_service.dart';

class StaffRouteScreen extends StatefulWidget {
  final Map<String, dynamic> routeData; // The full populated route object
  final String staffName;

  const StaffRouteScreen({
    super.key,
    required this.routeData,
    required this.staffName,
  });

  @override
  State<StaffRouteScreen> createState() => _StaffRouteScreenState();
}

class _StaffRouteScreenState extends State<StaffRouteScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _houses = [];
  bool _isLoading = true;

  static const List<String> _weekDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    final List<dynamic> days = widget.routeData['collectionDays'] ?? [];
    final String today = _weekDays[DateTime.now().weekday - 1];
    _fetchHouses(days.contains(today));
  }

  Future<void> _fetchHouses(bool isScheduledToday) async {
    if (!isScheduledToday) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (mounted) setState(() => _isLoading = true);
    try {
      final routeId = widget.routeData['_id'];
      final houses = await _apiService.getHousesInRoute(routeId);
      if (mounted) setState(() { _houses = houses; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteHouse(String houseId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete House'),
        content: const Text('Are you sure you want to remove this house from the route?'),
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
      _fetchHouses(true); // reload list
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
    const primaryGreen = Color(0xFF00C853);
    const bgColor = Color(0xFFF0F4F2);

    final routeName = widget.routeData['name'] ?? 'My Route';
    final List<dynamic> collectionDays = widget.routeData['collectionDays'] ?? [];
    final String today = _weekDays[DateTime.now().weekday - 1];
    final bool isScheduledToday = collectionDays.contains(today);

    // Find next scheduled day
    String nextDay = '';
    if (!isScheduledToday && collectionDays.isNotEmpty) {
      final todayIdx = _weekDays.indexOf(today);
      for (int i = 1; i <= 7; i++) {
        final candidate = _weekDays[(todayIdx + i) % 7];
        if (collectionDays.contains(candidate)) {
          nextDay = candidate;
          break;
        }
      }
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1C1E), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('My Route', style: TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.w900, fontSize: 16)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ─── Route Info Header Card ──────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryGreen,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: primaryGreen.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.map_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(routeName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
                      const SizedBox(height: 4),
                      Text('Staff: ${widget.staffName}', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            isScheduledToday ? Icons.check_circle_rounded : Icons.schedule_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isScheduledToday ? 'Collection day today ($today)' : 'Not scheduled today ($today)',
                            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Collection Days ────────────────────────────────────────────────
          if (collectionDays.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, color: Color(0xFF00C853), size: 18),
                    const SizedBox(width: 10),
                    const Text('Schedule: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        children: collectionDays.map((day) {
                          final isToday = day == today;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isToday ? primaryGreen.withOpacity(0.15) : Colors.grey.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: isToday ? Border.all(color: primaryGreen, width: 1) : null,
                            ),
                            child: Text(
                              day.toString().substring(0, 3),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isToday ? primaryGreen : Colors.black45,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ─── Houses Section ─────────────────────────────────────────────────
          if (!isScheduledToday) ...[  
            // OFF-DAY: show informational card
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.event_busy_rounded, color: Colors.orange, size: 40),
                    const SizedBox(height: 12),
                    const Text(
                      'No Collection Today',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.orange),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Today is $today. Your route is not scheduled for collection today.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black45, fontSize: 13),
                    ),
                    if (nextDay.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Next collection: $nextDay',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 13),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ] else ...[
            // COLLECTION DAY: show house list
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Houses (${_houses.length})',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1A1C1E)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00C853)),
                    onPressed: () => _fetchHouses(true),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: primaryGreen))
                  : _houses.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.home_work_outlined, size: 64, color: Colors.black12),
                              const SizedBox(height: 16),
                              const Text('No houses assigned to this route yet.', style: TextStyle(color: Colors.black38, fontSize: 14)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: _houses.length,
                          itemBuilder: (context, index) {
                            final h = _houses[index];
                            return _houseCard(h, index, primaryGreen);
                          },
                        ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _houseCard(dynamic h, int index, Color green) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(color: green, fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  h['ownerName'] ?? h['name'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1A1C1E)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.tag_rounded, size: 12, color: Colors.black38),
                    const SizedBox(width: 3),
                    Text('House No: ${h['houseNumber'] ?? 'N/A'}', style: const TextStyle(fontSize: 12, color: Colors.black45)),
                  ],
                ),
                if ((h['address'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: Colors.black38),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          h['address'] ?? '',
                          style: const TextStyle(fontSize: 11, color: Colors.black38),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if ((h['phoneNumber'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 12, color: Colors.black38),
                      const SizedBox(width: 3),
                      Text(h['phoneNumber'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.black38)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
            onPressed: () => _deleteHouse(h['_id']),
            tooltip: 'Remove House',
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.08),
              padding: const EdgeInsets.all(10),
            ),
          ),
        ],
      ),
    );
  }
}
