import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import 'payment_receipt_screen.dart';

class CollectionHistoryScreen extends StatefulWidget {
  const CollectionHistoryScreen({super.key});

  @override
  State<CollectionHistoryScreen> createState() => _CollectionHistoryScreenState();
}

class _CollectionHistoryScreenState extends State<CollectionHistoryScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _logs = [];
  List<dynamic> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final logs = await _apiService.getCollectionHistory();
      final payments = await _apiService.getMyPayments();
      if (mounted) {
        setState(() {
          _logs = logs;
          _payments = payments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF2E7D32);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1C1E), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Collection History', style: TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : (_logs.isEmpty && _payments.isEmpty)
              ? const Center(child: Text('No history found'))
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (_payments.isNotEmpty) _buildPaymentHistory(primaryGreen),
                    if (_payments.isNotEmpty) const SizedBox(height: 24),
                    if (_logs.isNotEmpty)
                      const Text('Collection History',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    if (_logs.isNotEmpty) const SizedBox(height: 12),
                    ..._logs.map((log) {
                    final date = DateTime.parse(log['createdAt']);
                    final status = log['status'] ?? 'Pending';
                    
                    Color statusColor;
                    if (status == 'Collected') {
                      statusColor = Colors.green;
                    } else if (status == 'Not Collected') {
                      statusColor = Colors.orange;
                    } else {
                      statusColor = Colors.redAccent;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(DateFormat('EEEE, d MMMM').format(date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(DateFormat('hh:mm a').format(date), style: const TextStyle(color: Colors.black38, fontSize: 12)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
                              ),
                            ],
                          ),
                          const Divider(height: 32, color: Color(0xFFF1F5F9)),
                          Row(
                            children: [
                              const Icon(Icons.person_rounded, size: 16, color: Colors.black26),
                              const SizedBox(width: 8),
                              Text('Staff: ${log['staff']?['name'] ?? 'Unknown'}', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                            ],
                          ),
                          if (log['proofImageUrl'] != null) ...[
                            const SizedBox(height: 16),
                            const Text('PROOF UPLOADED:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black26)),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?auto=format&fit=crop&w=400&q=80', // In real app, use log['proofImageUrl']
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  ],
                ),
    );
  }

  Widget _buildPaymentHistory(Color primaryGreen) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEAF0EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resident Payment History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 38,
              dataRowMinHeight: 42,
              dataRowMaxHeight: 48,
              columns: const [
                DataColumn(label: Text('Month')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('Mode')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Receipt')),
              ],
              rows: _payments.map<DataRow>((payment) {
                final rawDate = payment['date']?.toString();
                DateTime? parsed;
                if (rawDate != null && rawDate.isNotEmpty) {
                  parsed = DateTime.tryParse(rawDate);
                }
                final status = payment['status']?.toString() ?? 'Pending';
                final paid = status == 'Paid';
                return DataRow(cells: [
                  DataCell(Text(payment['month']?.toString() ?? '-')),
                  DataCell(Text(parsed == null ? '-' : DateFormat('dd MMM yyyy').format(parsed))),
                  DataCell(Text('Rs ${payment['amount'] ?? 0}')),
                  DataCell(Text(payment['mode']?.toString() ?? '-')),
                  DataCell(Text(
                    status,
                    style: TextStyle(
                      color: paid ? primaryGreen : Colors.orange[800],
                      fontWeight: FontWeight.w900,
                    ),
                  )),
                  DataCell(
                    paid
                        ? TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PaymentReceiptScreen(paymentId: payment['_id'].toString()),
                                ),
                              );
                            },
                            icon: const Icon(Icons.receipt_long_rounded, size: 16),
                            label: const Text('View'),
                          )
                        : const Text('-'),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
