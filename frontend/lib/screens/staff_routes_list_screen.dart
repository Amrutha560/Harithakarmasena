import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'house_detail_screen.dart';

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
  final Map<String, List<dynamic>> _housesPerRoute = {};
  bool _isLoading = true;

  static const List<String> _weekDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _fetchAllHouses();
  }

  Future<void> _fetchAllHouses() async {
    for (var r in widget.routes) {
      final routeId = r['_id'];
      try {
        final houses = await _apiService.getHousesInRoute(routeId);
        _housesPerRoute[routeId] = houses;
      } catch (e) {
        _housesPerRoute[routeId] = [];
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF00C853);
    const bgColor = Color(0xFFF0F4F2);
    final String today = _weekDays[DateTime.now().weekday - 1];

    final List<String> displayDays = widget.selectedDay != null 
        ? [widget.selectedDay!] 
        : _weekDays;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1C1E), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.selectedDay != null ? '${widget.selectedDay} - Tasks' : 'Weekly Task Plan', style: const TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.w900, fontSize: 16)),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: primaryGreen))
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: displayDays.length,
            itemBuilder: (context, index) {
              final day = displayDays[index];
              final isToday = day == today;
              
              // Find routes assigned for this specific day
              final routesForDay = widget.routes.where((r) {
                final List<dynamic> days = r['collectionDays'] ?? [];
                return days.contains(day);
              }).toList();

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: isToday ? Border.all(color: primaryGreen, width: 2) : Border.all(color: Colors.black.withOpacity(0.05)),
                  boxShadow: [
                    BoxShadow(color: isToday ? primaryGreen.withOpacity(0.1) : Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      collapsedBackgroundColor: isToday ? primaryGreen.withOpacity(0.05) : Colors.white,
                      backgroundColor: isToday ? primaryGreen.withOpacity(0.02) : Colors.white,
                      initiallyExpanded: isToday,
                      title: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isToday ? primaryGreen : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.calendar_today_rounded, color: isToday ? Colors.white : Colors.black38, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  day,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: isToday ? primaryGreen : const Color(0xFF1A1C1E),
                                  ),
                                ),
                                if (routesForDay.isNotEmpty)
                                  ...routesForDay.map((r) => Text(
                                    r['name'] ?? '',
                                    style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.bold),
                                  )),
                              ],
                            ),
                          ),
                          if (routesForDay.isEmpty)
                            const Text('Rest Day', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold))
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('${routesForDay.length} Route(s)', style: const TextStyle(color: primaryGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      children: _buildExpansionContent(routesForDay, primaryGreen),
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }

  List<Widget> _buildExpansionContent(List<dynamic> routesForDay, Color primary) {
    if (routesForDay.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.only(bottom: 24),
          child: Text('No routes assigned for this day.', style: TextStyle(color: Colors.black38, fontSize: 13)),
        )
      ];
    }

    List<Widget> content = [];
    for (var r in routesForDay) {
      final houses = _housesPerRoute[r['_id']] ?? [];
      
      content.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.02),
            border: Border(top: BorderSide(color: Colors.black.withOpacity(0.05))),
          ),
          child: Text(
            '${r['name']} - ${houses.length} Houses',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13),
          ),
        ),
      );

      if (houses.isEmpty) {
        content.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text('No houses in this route yet.', style: TextStyle(color: Colors.black38, fontSize: 13)),
        ));
      } else {
        for (int i = 0; i < houses.length; i++) {
          final h = houses[i];
          content.add(
            InkWell(
              onTap: () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => HouseDetailScreen(house: h, route: r)));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: primary.withOpacity(0.1),
                      child: Text('${i + 1}', style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(h['ownerName'] ?? h['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                          const SizedBox(height: 2),
                          Text('House No: ${h['houseNumber']} | ${h['address']}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.black26, size: 24),
                  ],
                ),
              ),
            ),
          );
        }
      }
    }
    return content;
  }
}
