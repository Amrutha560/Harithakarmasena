import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class RouteCalendarScreen extends StatefulWidget {
  final dynamic route;
  final bool isReadOnly;
  
  const RouteCalendarScreen({
    Key? key, 
    required this.route,
    this.isReadOnly = false,
  }) : super(key: key);

  @override
  _RouteCalendarScreenState createState() => _RouteCalendarScreenState();
}

class _RouteCalendarScreenState extends State<RouteCalendarScreen> {
  final ApiService _apiService = ApiService();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<dynamic> _houses = [];
  List<dynamic> _wasteCategories = [];
  bool _isLoading = false;

  Set<String> _selectedHouseIds = {};
  List<String> _scheduledDates = [];
  final Set<String> _selectedWasteTypes = {'Plastic'};
  String _selectedTimeSlot = '08:30 AM - 10:30 AM';
  
  final List<String> _timeSlots = [
    '08:30 AM - 10:30 AM',
    '10:00 AM - 12:00 PM',
    '12:30 PM - 02:30 PM',
    '02:00 PM - 04:00 PM',
    '04:30 PM - 06:30 PM'
  ];

  static const _bgColor = Color(0xFFF4F7FB);
  static const _primaryGreen = Color(0xFF2E7D32);
  static const _textDark = Color(0xFF1A1C1E);

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    final houses = await _apiService.getHousesInRoute(widget.route['_id']);
    final categories = await _apiService.getCategories();
    setState(() {
      _houses = houses;
      _wasteCategories = categories;
    });
    await _fetchAllSchedules();
    await _fetchScheduleForDate(_selectedDay!);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchAllSchedules() async {
    final schedules = await _apiService.getAllRouteSchedules(widget.route['_id']);
    _scheduledDates.clear();
    for (var s in schedules) {
      if (s['date'] != null) {
        final hasAssignments = s['assignments'] != null && (s['assignments'] as List).isNotEmpty;
        final hasCommon = s['commonTime'] != null || (s['commonWasteTypes'] != null && (s['commonWasteTypes'] as List).isNotEmpty);
        if (hasAssignments || hasCommon) {
          _scheduledDates.add(s['date']);
        }
      }
    }
  }

  Future<void> _fetchScheduleForDate(DateTime date) async {
    final dateString = DateFormat('yyyy-MM-dd').format(date);
    final schedule = await _apiService.getRouteSchedule(widget.route['_id'], dateString);
    
    _selectedHouseIds.clear();
    _selectedWasteTypes
      ..clear()
      ..add('Plastic');
    _selectedTimeSlot = '08:30 AM - 10:30 AM';

    if (schedule['commonTime'] != null) {
      _selectedTimeSlot = schedule['commonTime'];
    }
    if (schedule['commonWasteTypes'] != null && (schedule['commonWasteTypes'] as List).isNotEmpty) {
      _selectedWasteTypes
        ..clear()
        ..addAll((schedule['commonWasteTypes'] as List).map((item) => item.toString()));
      _selectedWasteTypes.add('Plastic');
    }

    if (schedule['assignments'] != null && schedule['assignments'].isNotEmpty) {
      for (var a in schedule['assignments']) {
        if (a['house'] != null) {
          final houseId = a['house']['_id'] ?? a['house'];
          _selectedHouseIds.add(houseId);
        }
      }
      // Fallback if common fields were missing
      if (schedule['commonTime'] == null) {
        _selectedTimeSlot = schedule['assignments'][0]['collectionTime'] ?? _selectedTimeSlot;
      }
      if (schedule['commonWasteTypes'] == null || (schedule['commonWasteTypes'] as List).isEmpty) {
        final firstA = schedule['assignments'][0];
        if (firstA['wasteTypes'] != null && (firstA['wasteTypes'] as List).isNotEmpty) {
          _selectedWasteTypes
            ..clear()
            ..addAll((firstA['wasteTypes'] as List).map((item) => item.toString()));
          _selectedWasteTypes.add('Plastic');
        }
      }
    } else {
      // If no assignments exist, pre-select all houses for easy saving
      for (var h in _houses) {
        _selectedHouseIds.add(h['_id']);
      }
    }
    setState(() {});
  }

  void _saveSchedule() async {
    final dateString = DateFormat('yyyy-MM-dd').format(_selectedDay!);
    final selectedWasteTypes = _normalizedSelectedWasteTypes();
    final assignmentsToSave = _selectedHouseIds.map((houseId) => {
      'house': houseId,
      'collectionTime': _selectedTimeSlot,
      'wasteTypes': selectedWasteTypes,
    }).toList();

    setState(() => _isLoading = true);
    await _apiService.saveRouteSchedule(
      widget.route['_id'], 
      dateString, 
      assignmentsToSave,
      commonTime: _selectedTimeSlot,
      commonWasteTypes: selectedWasteTypes,
    );
    await _fetchAllSchedules();
    setState(() => _isLoading = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Success: Schedule for $dateString saved for ${_selectedHouseIds.length} households.'),
        backgroundColor: _primaryGreen,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _toggleHouse(String id) {
    setState(() {
      if (_selectedHouseIds.contains(id)) {
        _selectedHouseIds.remove(id);
      } else {
        _selectedHouseIds.add(id);
      }
    });
  }

  void _selectAllHouses() {
    setState(() {
      if (_selectedHouseIds.length == _houses.length) {
        _selectedHouseIds.clear(); // deselect all
      } else {
        _selectedHouseIds.addAll(_houses.map((h) => h['_id'].toString()));
      }
    });
  }

  List<String> _normalizedSelectedWasteTypes() {
    final values = <String>['Plastic'];
    for (final type in _selectedWasteTypes) {
      final clean = type.trim();
      if (clean.isEmpty) continue;
      if (!values.any((item) => item.toLowerCase() == clean.toLowerCase())) {
        values.add(clean);
      }
    }
    return values;
  }

  Widget _buildWasteTypeCard(String title, String subtitle, IconData icon, Color iconColor) {
    final isPlastic = title.toLowerCase() == 'plastic' || title.toLowerCase().contains('plastic');
    bool selected = isPlastic || _selectedWasteTypes.any((type) => type.toLowerCase() == title.toLowerCase());
    return InkWell(
      onTap: () {
        setState(() {
          if (selected && !isPlastic) {
            _selectedWasteTypes.removeWhere((type) => type.toLowerCase() == title.toLowerCase());
          } else {
            _selectedWasteTypes.add(title);
          }
          _selectedWasteTypes.add('Plastic');
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? iconColor.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: selected ? Border.all(color: iconColor.withOpacity(0.3), width: 1.5) : Border.all(color: Colors.transparent),
          boxShadow: [
             if (!selected) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
          ]
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, color: selected ? iconColor : Colors.black26),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: selected ? iconColor : Colors.black54)),
                ]
              )
            ),
            Icon(icon, color: selected ? iconColor : Colors.black26),
          ]
        )
      )
    );
  }

  List<Widget> _getWasteTypeCards() {
    if (_wasteCategories.isEmpty) {
      return [
        _buildWasteTypeCard('Plastic', 'Mandatory monthly collection', Icons.recycling_rounded, Colors.blue),
        const SizedBox(height: 8),
        _buildWasteTypeCard('General Waste', 'Standard landfill collection', Icons.delete_outline, _primaryGreen),
        const SizedBox(height: 8),
        _buildWasteTypeCard('Hazardous', 'Chemicals & E-waste', Icons.warning_amber_rounded, Colors.redAccent),
      ];
    } else {
      return _wasteCategories.map((c) {
        String name = c['name'];
        IconData icon = Icons.delete_outline;
        Color color = _primaryGreen;
        if (name.toLowerCase().contains('recycl')) { icon = Icons.recycling_rounded; color = Colors.blue; }
        else if (name.toLowerCase().contains('hazard')) { icon = Icons.warning_amber_rounded; color = Colors.redAccent; }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8), 
          child: _buildWasteTypeCard(name, c['description'] ?? 'Collection type', icon, color)
        );
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading && _houses.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _primaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header Section ──────────────────────────────────────────
                  const Text('Fleet Management > Schedules', style: TextStyle(fontSize: 10, color: Colors.black45)),
                  const SizedBox(height: 8),
                  Text('Route: ${widget.route['name']}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _textDark, height: 1.1)),
                  const SizedBox(height: 8),
                  const Text('Surgical precision logistics operations', style: TextStyle(fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: _primaryGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: _primaryGreen, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        const Text('Active Monitoring', style: TextStyle(color: _primaryGreen, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      ],
                    )
                  ),
                  const SizedBox(height: 28),

                  // ── Fleet Calendar Card ─────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white, 
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Fleet Calendar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _textDark)),
                        const SizedBox(height: 8),
                        TableCalendar(
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          calendarFormat: _calendarFormat,
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            titleTextStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            leftChevronIcon: Icon(Icons.chevron_left, size: 20),
                            rightChevronIcon: Icon(Icons.chevron_right, size: 20),
                          ),
                          daysOfWeekStyle: const DaysOfWeekStyle(
                            weekdayStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black38),
                            weekendStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black38),
                          ),
                          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                          onDaySelected: (selectedDay, focusedDay) async {
                            if (!isSameDay(_selectedDay, selectedDay)) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                                _isLoading = true;
                              });
                              await _fetchScheduleForDate(selectedDay);
                              setState(() => _isLoading = false);
                            }
                          },
                          calendarBuilders: CalendarBuilders(
                            defaultBuilder: (context, day, focusedDay) {
                              final dateStr = DateFormat('yyyy-MM-dd').format(day);
                              if (_scheduledDates.contains(dateStr)) {
                                return Container(
                                  margin: const EdgeInsets.all(4),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _primaryGreen.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${day.day}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                );
                              }
                              return null;
                            },
                          ),
                          calendarStyle: CalendarStyle(
                            selectedDecoration: const BoxDecoration(color: _primaryGreen, shape: BoxShape.rectangle, borderRadius: BorderRadius.all(Radius.circular(8))),
                            // Remove any special decoration for today
                            todayDecoration: const BoxDecoration(shape: BoxShape.rectangle),
                            todayTextStyle: const TextStyle(color: Colors.black87),
                            defaultDecoration: const BoxDecoration(shape: BoxShape.rectangle, borderRadius: BorderRadius.all(Radius.circular(8))),
                            weekendDecoration: const BoxDecoration(shape: BoxShape.rectangle, borderRadius: BorderRadius.all(Radius.circular(8))),
                            outsideDaysVisible: false,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                           padding: const EdgeInsets.all(16),
                           decoration: BoxDecoration(color: const Color(0xFFF9FAFC), borderRadius: BorderRadius.circular(12)),
                           child: const Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text('MULTI-SELECT TIP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                               SizedBox(height: 6),
                               Text('Click dates to toggle availability for this route. Selected dates will share the configuration defined below.', style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4))
                             ]
                           )
                        )
                      ]
                    )
                  ),
                  const SizedBox(height: 24),

                  // ── Configuration Section ───────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white, 
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Row(
                           children: [
                             Container(
                               padding: const EdgeInsets.all(10),
                               decoration: BoxDecoration(color: _primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                               child: const Icon(Icons.calendar_month_rounded, color: _primaryGreen, size: 24),
                             ),
                             const SizedBox(width: 16),
                             Expanded(
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text('Configuration for ${DateFormat('MMM d').format(_selectedDay!)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.redAccent)),
                                   const SizedBox(height: 2),
                                   Text('Defining collection parameters for ${widget.route['name']}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                 ]
                               ),
                             )
                           ]
                         ),
                         const SizedBox(height: 32),
                         
                         // ASSIGN HOUSES
                         Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Text('ASSIGN HOUSES (${_houses.length} TOTAL)', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black54, letterSpacing: 0.5)),
                             TextButton(
                               onPressed: _selectAllHouses, 
                               style: TextButton.styleFrom(minimumSize: Size.zero, padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                               child: Text(_selectedHouseIds.length == _houses.length ? 'Deselect All' : 'Select All in District', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue[700]))
                             ),
                           ]
                         ),
                         const SizedBox(height: 12),
                         Column(
                           children: _houses.map((h) {
                              bool selected = _selectedHouseIds.contains(h['_id']);
                              final ownerName = h['ownerName'] ?? 'Resident';
                              final address = h['address'] ?? 'No Address Details';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: selected ? Colors.yellow.shade100 : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected ? _primaryGreen.withOpacity(0.3) : Colors.black.withOpacity(0.05),
                                    width: 1.5
                                  ),
                                ),
                                child: CheckboxListTile(
                                  value: selected,
                                  onChanged: widget.isReadOnly ? null : (_) => _toggleHouse(h['_id']),
                                  activeColor: _primaryGreen,
                                  checkColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  title: Text(
                                    'House No: ${h['houseNumber']} • $ownerName',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: selected ? Colors.black87 : Colors.black87,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      address,
                                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                                    ),
                                  ),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                           }).toList(),
                         ),
                         const SizedBox(height: 32),
                         
                         // WASTE TYPE SELECTION
                         const Text('WASTE TYPE SELECTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black54, letterSpacing: 0.5)),
                         const SizedBox(height: 16),
                         ..._getWasteTypeCards(),
                         
                         const SizedBox(height: 32),
                         
                         // SET COLLECTION TIME
                         const Text('SET COLLECTION TIME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black54, letterSpacing: 0.5)),
                         const SizedBox(height: 16),
                         Wrap(
                           spacing: 12, runSpacing: 12,
                           children: _timeSlots.map((ts) {
                             bool selected = _selectedTimeSlot == ts;
                             return InkWell(
                               onTap: widget.isReadOnly ? null : () => setState(() => _selectedTimeSlot = ts),
                               borderRadius: BorderRadius.circular(12),
                               child: Container(
                                 width: (MediaQuery.of(context).size.width - 48 - 48 - 12) / 2, // calculate for 2 columns with padding
                                 padding: const EdgeInsets.symmetric(vertical: 14),
                                 decoration: BoxDecoration(
                                   color: selected ? _primaryGreen : const Color(0xFFF0F4F8),
                                   borderRadius: BorderRadius.circular(10),
                                   border: selected ? null : Border.all(color: Colors.blue.withOpacity(0.08))
                                 ),
                                 child: Center(
                                   child: Text(ts, style: TextStyle(
                                     fontSize: 11, 
                                     fontWeight: FontWeight.w700, 
                                     color: selected ? Colors.white : Colors.black87
                                   ))
                                 )
                               )
                             );
                           }).toList()
                         ),
                         const SizedBox(height: 20),
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                           decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(8)),
                           child: const Row(
                             children: [
                               Icon(Icons.access_time_filled_rounded, size: 16, color: Colors.black87),
                               SizedBox(width: 10),
                               Text('Estimated route duration: 4h 15m', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
                             ]
                           )
                         ),
                         
                         const SizedBox(height: 32),
                         
                         // Save Button
                         if (!widget.isReadOnly)
                           _isLoading 
                              ? const Center(child: CircularProgressIndicator(color: _primaryGreen))
                              : ElevatedButton(
                                  onPressed: _saveSchedule,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primaryGreen, 
                                    minimumSize: const Size(double.infinity, 56), 
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 0,
                                  ),
                                  child: const Text('Save Schedule', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                                )
                       ]
                    )
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
