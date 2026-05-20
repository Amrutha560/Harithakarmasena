import 'dart:convert';
import '../utils/platform_utils.dart';import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

class ReportsScreen extends StatefulWidget {
  final bool embedded;

  const ReportsScreen({super.key, this.embedded = false});

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic> _stats = {};
  List<dynamic> _payments = [];
  List<dynamic> _assignments = [];
  List<dynamic> _routeCompletions = [];
  String _paymentStatusFilter = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final routeCompletions = await _apiService.getRouteCompletions();
    setState(() {
      _routeCompletions = routeCompletions;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
          )
        : SingleChildScrollView(
            padding: EdgeInsets.all(widget.embedded ? 32 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.embedded) ...[
                  const Text(
                    'Reports',
                    style: TextStyle(
                      color: Color(0xFF1A1C1E),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Staff route completion reports.',
                    style: TextStyle(color: Colors.black45, fontSize: 16),
                  ),
                  const SizedBox(height: 28),
                ],
                _buildRouteCompletionSection(),
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
          'Analytical Reports',
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

  Widget _buildSummarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'System Summary',
          style: TextStyle(
            color: Color(0xFF1A1C1E),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.25,
          children: [
            _buildSmallStatCard(
              'Residents',
              (_stats['totalResidents'] ?? 0).toString(),
              Icons.home_rounded,
              const Color(0xFF1976D2),
            ),
            _buildSmallStatCard(
              'Staff',
              (_stats['totalStaff'] ?? 0).toString(),
              Icons.badge_outlined,
              const Color(0xFF2E7D32),
            ),
            _buildSmallStatCard(
              'Complaints',
              (_stats['pendingComplaints'] ?? 0).toString(),
              Icons.feedback_outlined,
              const Color(0xFFE53935),
            ),
            _buildSmallStatCard(
              'Issues',
              (_stats['nonCooperativeHouses'] ?? 0).toString(),
              Icons.block_flipped,
              const Color(0xFF9E9E9E),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF1A1C1E),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
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
            'Distribution',
            style: TextStyle(
              color: Color(0xFF1A1C1E),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Operational Breakdown',
            style: TextStyle(color: Colors.black38, fontSize: 12),
          ),
          const SizedBox(height: 40),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 8,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    color: const Color(0xFF1976D2),
                    value: (_stats['totalResidents'] ?? 1).toDouble(),
                    title: '',
                    radius: 50,
                  ),
                  PieChartSectionData(
                    color: const Color(0xFF2E7D32),
                    value: (_stats['totalStaff'] ?? 0).toDouble(),
                    title: '',
                    radius: 50,
                  ),
                  PieChartSectionData(
                    color: const Color(0xFFE53935),
                    value: (_stats['pendingComplaints'] ?? 0).toDouble(),
                    title: '',
                    radius: 50,
                  ),
                  PieChartSectionData(
                    color: const Color(0xFF9E9E9E),
                    value: (_stats['nonCooperativeHouses'] ?? 0).toDouble(),
                    title: '',
                    radius: 50,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildLegendRow('Residents', const Color(0xFF1976D2)),
          _buildLegendRow('Staff', const Color(0xFF2E7D32)),
          _buildLegendRow('Complaints', const Color(0xFFE53935)),
          _buildLegendRow('Service Issues', const Color(0xFF9E9E9E)),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    return _reportPanel(
      title: 'Payment History',
      trailing: DropdownButton<String>(
        value: _paymentStatusFilter,
        underline: const SizedBox.shrink(),
        items: const [
          DropdownMenuItem(value: '', child: Text('All')),
          DropdownMenuItem(value: 'Paid', child: Text('Paid')),
          DropdownMenuItem(value: 'Due', child: Text('Due')),
          DropdownMenuItem(value: 'Pending', child: Text('Pending')),
        ],
        onChanged: (value) {
          setState(() {
            _paymentStatusFilter = value ?? '';
            _isLoading = true;
          });
          _fetchStats();
        },
      ),
      child: _payments.isEmpty
          ? const Text(
              'No payment records found.',
              style: TextStyle(color: Colors.black45),
            )
          : Column(
              children: _payments.take(12).map<Widget>((p) {
                return _compactRow(
                  Icons.payments_rounded,
                  p['residentName']?.toString() ?? 'Resident',
                  'House ${p['houseNumber'] ?? 'N/A'} | ${p['paymentMode'] ?? '-'} | Rs ${p['amount']} | ${p['month'] ?? '-'}',
                  p['paymentStatus'] ?? 'Pending',
                );
              }).toList(),
            ),
    );
  }

  Widget _buildAssignmentSection() {
    final due = _assignments.where((a) => a['paymentStatus'] == 'Due').length;
    final paid = _assignments
        .where((a) => '${a['paymentStatus']}'.startsWith('Paid'))
        .length;
    final collected = _assignments
        .where((a) => a['collectionStatus'] == 'Collected')
        .length;
    return _reportPanel(
      title: 'Resident Collection Status',
      trailing: Text(
        '$paid paid | $due due | $collected collected',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF2E7D32),
        ),
      ),
      child: _assignments.isEmpty
          ? const Text(
              'No scheduled resident records found.',
              style: TextStyle(color: Colors.black45),
            )
          : Column(
              children: _assignments.take(12).map<Widget>((a) {
                final house = a['house'] is Map
                    ? a['house']['houseNumber']
                    : a['houseNumber'];
                final resident = a['resident'];
                final name = resident is Map
                    ? '${resident['firstName'] ?? ''} ${resident['lastName'] ?? ''}'
                          .trim()
                    : (a['residentName'] ?? 'Resident').toString();
                return _compactRow(
                  Icons.home_work_outlined,
                  'House ${house ?? 'N/A'} - ${name.isEmpty ? 'Resident' : name}',
                  '${a['date']} | ${a['availabilityStatus']} | ${a['collectionStatus']} | ${a['paymentMode'] ?? '-'}',
                  a['paymentStatus'] ?? 'Pending',
                );
              }).toList(),
            ),
    );
  }

  Widget _buildRouteCompletionSection() {
    final completedReports = _routeCompletions
        .where((r) => r['routeStatus']?.toString() == 'Completed')
        .toList();
    final totalDone = completedReports.fold<int>(
      0,
      (sum, row) => sum + _totalValue(row, 'collectedHouses'),
    );
    final totalUnpaid = completedReports.fold<int>(
      0,
      (sum, row) => sum + _totalValue(row, 'unpaidHouses'),
    );

    return _reportPanel(
      title: 'Staff Route Completion Reports',
      trailing: Text(
        '$totalDone houses done | $totalUnpaid unpaid',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF2E7D32),
        ),
      ),
      child: completedReports.isEmpty
          ? const Text(
              'No completed route reports yet.',
              style: TextStyle(color: Colors.black45),
            )
          : Column(
              children: completedReports.take(10).map<Widget>((row) {
                final totals = row['totals'] is Map ? row['totals'] as Map : {};
                final unpaidResidents = row['unpaidResidents'] is List
                    ? row['unpaidResidents'] as List
                    : const [];
                final details = [
                  '${row['date'] ?? '-'}',
                  'Done ${totals['collectedHouses'] ?? 0}/${totals['totalHouses'] ?? 0}',
                  'Paid ${totals['paidHouses'] ?? 0}',
                  'Unpaid ${totals['unpaidHouses'] ?? 0}',
                ].join(' | ');
                return InkWell(
                  onTap: () => _showRouteReportDetails(
                    Map<String, dynamic>.from(row as Map),
                  ),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAF9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black.withOpacity(0.04)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _compactRow(
                                Icons.route_rounded,
                                row['routeName']?.toString() ?? 'Route',
                                '${row['ward'] ?? 'Ward'} | Completed by ${row['completedBy'] ?? 'Staff'}',
                                'Completed',
                              ),
                            ),
                            IconButton(
                              tooltip: 'Download report',
                              onPressed: () => _downloadRouteReport(
                                Map<String, dynamic>.from(row as Map),
                              ),
                              icon: const Icon(
                                Icons.download_rounded,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          details,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (unpaidResidents.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Unpaid residents',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...unpaidResidents.take(4).map((item) {
                            final resident = item is Map ? item : {};
                            return Text(
                              'House ${resident['houseNumber'] ?? 'N/A'} - ${resident['residentName'] ?? 'Resident'} (${resident['paymentStatus'] ?? 'Pending'})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            );
                          }),
                          if (unpaidResidents.length > 4)
                            Text(
                              '+${unpaidResidents.length - 4} more',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black38,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                        const SizedBox(height: 8),
                        const Text(
                          'Click to view all resident details',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  int _totalValue(dynamic row, String key) {
    if (row is! Map || row['totals'] is! Map) return 0;
    final value = row['totals'][key];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _showRouteReportDetails(Map<String, dynamic> report) {
    final residents = report['residents'] is List
        ? report['residents'] as List
        : const [];
    final totals = report['totals'] is Map ? report['totals'] as Map : {};

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report['routeName']?.toString() ?? 'Route Report',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${report['date'] ?? '-'} | ${report['ward'] ?? 'Ward'} | Completed by ${report['completedBy'] ?? 'Staff'}',
                            style: const TextStyle(
                              color: Colors.black45,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _downloadRouteReport(report),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Download CSV'),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _detailChip('Total', totals['totalHouses'] ?? 0),
                    _detailChip('Collected', totals['collectedHouses'] ?? 0),
                    _detailChip(
                      'Not collected',
                      totals['notCollectedHouses'] ?? 0,
                    ),
                    _detailChip('Paid', totals['paidHouses'] ?? 0),
                    _detailChip('Unpaid', totals['unpaidHouses'] ?? 0),
                  ],
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: residents.isEmpty
                      ? const Center(
                          child: Text(
                            'No resident details found for this report.',
                            style: TextStyle(color: Colors.black45),
                          ),
                        )
                      : ListView.separated(
                          itemCount: residents.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final resident = residents[index] is Map
                                ? residents[index] as Map
                                : {};
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAF9),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.black.withOpacity(0.05),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF2E7D32,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      resident['houseNumber']?.toString() ??
                                          '?',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF2E7D32),
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
                                          resident['residentName']
                                                  ?.toString() ??
                                              'Resident',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${resident['address'] ?? ''}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.black45,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [
                                            _miniStatus(
                                              'Availability',
                                              resident['availabilityStatus'],
                                            ),
                                            _miniStatus(
                                              'Collection',
                                              resident['collectionStatus'],
                                            ),
                                            _miniStatus(
                                              'Payment',
                                              resident['paymentStatus'],
                                            ),
                                            if ((resident['phoneNumber'] ?? '')
                                                .toString()
                                                .isNotEmpty)
                                              _miniStatus(
                                                'Phone',
                                                resident['phoneNumber'],
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailChip(String label, dynamic value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Color(0xFF2E7D32),
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _miniStatus(String label, dynamic value) {
    return Text(
      '$label: ${value ?? '-'}',
      style: const TextStyle(
        color: Colors.black54,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  void _downloadRouteReport(Map<String, dynamic> report) {
    final residents = report['residents'] is List
        ? report['residents'] as List
        : const [];
    final rows = <List<String>>[
      [
        'Route',
        'Date',
        'Ward',
        'Completed By',
        'House No',
        'Resident',
        'Phone',
        'Address',
        'Availability',
        'Collection',
        'Payment',
        'Payment Mode',
        'Amount',
      ],
      ...residents.map((item) {
        final resident = item is Map ? item : {};
        return [
          report['routeName']?.toString() ?? '',
          report['date']?.toString() ?? '',
          report['ward']?.toString() ?? '',
          report['completedBy']?.toString() ?? '',
          resident['houseNumber']?.toString() ?? '',
          resident['residentName']?.toString() ?? '',
          resident['phoneNumber']?.toString() ?? '',
          resident['address']?.toString() ?? '',
          resident['availabilityStatus']?.toString() ?? '',
          resident['collectionStatus']?.toString() ?? '',
          resident['paymentStatus']?.toString() ?? '',
          resident['paymentMode']?.toString() ?? '',
          resident['amount']?.toString() ?? '',
        ];
      }),
    ];
    final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
    final bytes = utf8.encode(csv);
    final filename =
        'route-report-${(report['date'] ?? 'date').toString()}-${(report['routeName'] ?? 'route').toString().replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '-')}.csv';
    downloadFile(bytes, filename, 'text/csv;charset=utf-8');
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  Widget _reportPanel({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1A1C1E),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _compactRow(
    IconData icon,
    String title,
    String subtitle,
    String status,
  ) {
    final isPaid =
        status == 'Success' || status == 'Paid' || status == 'Paid in Cash';
    final color = isPaid ? const Color(0xFF2E7D32) : Colors.orange;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.black45, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartBadge(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Icon(icon, size: 12, color: Color(0xFF1A1C1E)),
    );
  }

  Widget _buildLegendRow(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(color: Colors.black87, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
