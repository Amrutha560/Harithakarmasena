import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'razorpay_payment_screen.dart';

class ResidentScheduleScreen extends StatefulWidget {
  const ResidentScheduleScreen({super.key});

  @override
  State<ResidentScheduleScreen> createState() => _ResidentScheduleScreenState();
}

class _ResidentScheduleScreenState extends State<ResidentScheduleScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  String? _submittingDate;

  static const _accentGreen = Color(0xFF2E7D32);
  static const _red = Color(0xFFC62828);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getResidentDashboard();
      if (mounted) {
        setState(() {
          _dashboardData = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAvailability(String date, String choice) async {
    setState(() => _submittingDate = date);
    try {
      final response = await _apiService.respondToCollection(
        choice,
        date: date,
      );
      final latestDashboard = await _apiService.getResidentDashboard();
      if (!mounted) return;
      setState(() {
        _dashboardData = latestDashboard;
        _submittingDate = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            choice == 'Available'
                ? 'Marked available for $date'
                : choice == 'Not Available'
                ? 'Marked not available for $date'
                : 'Cleared availability for $date',
          ),
          backgroundColor: choice == 'Available'
              ? _accentGreen
              : choice == 'Not Available'
              ? Colors.orange[800]
              : Colors.blueGrey,
          behavior: SnackBarBehavior.floating,
        ),
      );

      final assignment = response['assignment'];
      final selectedVisit = _visitForDate(date, latestDashboard);
      final paymentData = Map<String, dynamic>.from(latestDashboard);
      paymentData['selectedScheduleDate'] = date;
      paymentData['selectedAvailability'] = choice;
      paymentData['selectedWasteTypes'] = _wasteTypesForVisit(
        selectedVisit ?? const {},
      );
      paymentData['selectedStaffName'] = _staffNameForVisit(selectedVisit);
      if (assignment is Map && assignment['_id'] != null) {
        paymentData['scheduleId'] = assignment['_id'].toString();
      }

      if (choice == 'Not Available') {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RazorpayPaymentScreen(dashboardData: paymentData),
          ),
        );
        _fetchData();
      } else if (choice == 'Available') {
        _showAvailablePaymentChoice(paymentData);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _submittingDate = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update availability'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAvailablePaymentChoice(Map<String, dynamic> paymentData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Required',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'You can pay online now, or give cash to the staff during collection. Until then it stays marked as due.',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.payments_rounded, color: Colors.white),
                label: const Text(
                  'Pay Online Now',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          RazorpayPaymentScreen(dashboardData: paymentData),
                    ),
                  );
                  _fetchData();
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.money_rounded, color: _accentGreen),
                label: const Text(
                  'Pay in Cash',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _accentGreen,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: _accentGreen),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  final assignmentId =
                      paymentData['scheduleId']?.toString() ?? '';
                  if (assignmentId.isNotEmpty) {
                    await _apiService.choosePaymentMode(
                      assignmentId: assignmentId,
                      date:
                          paymentData['selectedScheduleDate']?.toString() ??
                          paymentData['staffVisitDate']?.toString() ??
                          DateTime.now().toIso8601String().split('T')[0],
                      mode: 'Cash',
                    );
                    await _fetchData();
                  }
                  if (!mounted) return;
                  _showCashPaymentConfirmation(paymentData);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _staffVisitDates {
    final visits = _dashboardData?['staffVisitDates'] as List<dynamic>? ?? [];
    return visits
        .whereType<Map>()
        .map((visit) => Map<String, dynamic>.from(visit))
        .where((visit) => visit['date'] != null)
        .toList()
      ..sort((a, b) => a['date'].toString().compareTo(b['date'].toString()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Staff Schedule',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accentGreen))
          : RefreshIndicator(
              onRefresh: _fetchData,
              color: _accentGreen,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 18),
                        if (_staffVisitDates.isEmpty)
                          _emptyState()
                        else
                          ..._staffVisitDates.map(_scheduleCard),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final routeName =
        _dashboardData?['routeName']?.toString() ?? 'Route pending';
    final wardNumber = _dashboardData?['wardNumber']?.toString() ?? 'Not set';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAF0EC)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.calendar_month_rounded, color: _red),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Staff Assigned Dates',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '$routeName - Ward $wardNumber',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Click a choice to mark your availability.',
                  style: TextStyle(
                    color: Colors.black38,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(
        child: Text(
          'No staff visit dates marked yet.',
          style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _scheduleCard(Map<String, dynamic> visit) {
    final date = visit['date'].toString();
    final routeName =
        visit['routeName']?.toString() ??
        _dashboardData?['routeName']?.toString() ??
        'Assigned route';
    final wardNumber = _dashboardData?['wardNumber']?.toString() ?? 'Not set';
    final status = _statusForDate(date);
    final isSubmitting = _submittingDate == date;
    final wasteTypes = _wasteTypesForVisit(visit);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAF0EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCDD2),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: _red, width: 1.4),
                ),
                child: Text(
                  DateTime.tryParse(date)?.day.toString() ?? date,
                  style: const TextStyle(
                    color: _red,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(date),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _meta(Icons.route_rounded, routeName),
                    const SizedBox(height: 6),
                    _meta(Icons.map_outlined, 'Ward $wardNumber'),
                    const SizedBox(height: 6),
                    _meta(Icons.recycling_rounded, wasteTypes),
                    const SizedBox(height: 10),
                    _statusPill(status),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isSubmitting)
            const Center(child: CircularProgressIndicator(color: _accentGreen))
          else
            Row(
              children: [
                Expanded(
                  child: _availabilityButton(
                    date,
                    'Available',
                    Icons.check_circle_rounded,
                    _accentGreen,
                    status == 'Available',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _availabilityButton(
                    date,
                    'Not Available',
                    Icons.cancel_rounded,
                    Colors.redAccent,
                    status == 'Not Available',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _availabilityButton(
    String date,
    String label,
    IconData icon,
    Color color,
    bool selected,
  ) {
    return InkWell(
      onTap: () {
        _markAvailability(date, selected ? 'Pending' : label);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(selected ? 1 : 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: Colors.black38),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black45,
              fontWeight: FontWeight.w700,
              height: 1.18,
            ),
          ),
        ),
      ],
    );
  }

  void _showCashPaymentConfirmation(Map<String, dynamic> paymentData) {
    final date =
        paymentData['selectedScheduleDate']?.toString() ??
        paymentData['staffVisitDate']?.toString() ??
        '';
    final formattedDate = date.isEmpty ? 'Not set' : _formatDate(date);
    final staff =
        paymentData['selectedStaffName']?.toString() ?? 'Assigned staff';
    final wasteType =
        paymentData['selectedWasteTypes']?.toString() ?? 'Plastic';
    final availability =
        paymentData['selectedAvailability']?.toString() ?? 'Available';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Cash Payment Selected',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogInfoRow(Icons.calendar_month_rounded, 'Date', formattedDate),
            _dialogInfoRow(Icons.person_rounded, 'Staff', staff),
            _dialogInfoRow(Icons.recycling_rounded, 'Waste Type', wasteType),
            _dialogInfoRow(
              Icons.check_circle_rounded,
              'Availability',
              availability,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/resident',
                (route) => false,
              );
            },
            child: const Text(
              'Close',
              style: TextStyle(
                color: _accentGreen,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dialogInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _accentGreen, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF1A1C1E),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _visitForDate(
    String date,
    Map<String, dynamic> dashboardData,
  ) {
    final visits = dashboardData['staffVisitDates'] as List<dynamic>? ?? [];
    for (final visit in visits) {
      if (visit is Map && visit['date']?.toString() == date) {
        return Map<String, dynamic>.from(visit);
      }
    }
    return null;
  }

  String _staffNameForVisit(Map<String, dynamic>? visit) {
    final name = visit?['staffName']?.toString().trim() ?? '';
    return name.isEmpty ? 'Assigned staff' : name;
  }

  String _wasteTypesForVisit(Map<String, dynamic> visit) {
    final raw = visit['wasteTypes'];
    if (raw is List && raw.isNotEmpty) {
      final values = raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
      if (values.isNotEmpty) return values.join(', ');
    }
    final assigned = _dashboardData?['assignedWasteTypes'];
    if (assigned is List && assigned.isNotEmpty) {
      final values = assigned
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
      if (values.isNotEmpty) return values.join(', ');
    }
    return 'Plastic';
  }

  Widget _statusPill(String status) {
    final isAvailable = status == 'Available';
    final isNotAvailable = status == 'Not Available';
    final color = isAvailable
        ? _accentGreen
        : isNotAvailable
        ? Colors.redAccent
        : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  String _statusForDate(String date) {
    final schedules = _dashboardData?['schedules'] as List<dynamic>? ?? [];
    for (final item in schedules) {
      if (item is Map && item['date']?.toString() == date) {
        return item['availabilityStatus']?.toString() ?? 'Pending';
      }
    }
    return 'Pending';
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('EEEE, MMM d, yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}
