import 'dart:convert';

import '../utils/platform_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';

class PaymentReceiptScreen extends StatefulWidget {
  final String paymentId;

  const PaymentReceiptScreen({super.key, required this.paymentId});

  @override
  State<PaymentReceiptScreen> createState() => _PaymentReceiptScreenState();
}

class _PaymentReceiptScreenState extends State<PaymentReceiptScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _receipt;
  bool _isLoading = true;

  static const _green = Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _fetchReceipt();
  }

  Future<void> _fetchReceipt() async {
    final receipt = await _apiService.getPaymentReceipt(widget.paymentId);
    if (!mounted) return;
    setState(() {
      _receipt = receipt;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Payment Receipt',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Download receipt',
            icon: const Icon(Icons.download_rounded, color: _green),
            onPressed: _receipt == null ? null : _downloadReceipt,
          ),
          IconButton(
            tooltip: 'Print receipt',
            icon: const Icon(Icons.print_rounded, color: _green),
            onPressed: _receipt == null
                ? null
                : () => printPage(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : _receipt == null || _receipt!.isEmpty
          ? const Center(child: Text('Receipt not found'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: _receiptCard(),
                ),
              ),
            ),
    );
  }

  Widget _receiptCard() {
    final receipt = _receipt!;
    final paidAt = DateTime.tryParse(receipt['paidAt']?.toString() ?? '');
    final amount = receipt['amount'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEAF0EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: _green,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receipt['organization']?.toString() ?? 'Harithakarmasena',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Receipt No: ${receipt['receiptNo'] ?? '-'}',
                      style: const TextStyle(
                        color: Colors.black45,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _statusPill(receipt['status']?.toString() ?? 'Paid'),
            ],
          ),
          const SizedBox(height: 26),
          Center(
            child: Column(
              children: [
                const Text(
                  'AMOUNT PAID',
                  style: TextStyle(
                    color: Colors.black38,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rs $amount.00',
                  style: const TextStyle(
                    color: _green,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const Divider(color: Color(0xFFEAF0EC)),
          const SizedBox(height: 12),
          _row('Resident', receipt['residentName']),
          _row('Phone', receipt['phoneNumber']),
          _row('House', receipt['houseNumber']),
          _row('Address', receipt['address']),
          _row('Route', receipt['routeName']),
          _row('Ward', receipt['wardNumber']),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFEAF0EC)),
          const SizedBox(height: 12),
          _row('Payment Month', receipt['month']),
          _row('Collection Date', _formatDate(receipt['collectionDate'])),
          _row(
            'Paid On',
            paidAt == null
                ? '-'
                : DateFormat('dd MMM yyyy, hh:mm a').format(paidAt),
          ),
          _row('Mode', receipt['mode']),
          _row('Transaction ID', receipt['transactionId']),
          _row('Collected By', receipt['collectedBy']),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _downloadReceipt,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text(
                    'Download',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _green,
                    side: const BorderSide(color: _green),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => printPage(),
                  icon: const Icon(Icons.print_rounded, color: Colors.white),
                  label: const Text(
                    'Print Receipt',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, dynamic value) {
    final text = value == null || value.toString().trim().isEmpty
        ? '-'
        : value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black45,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF1A1C1E),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: _green,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }

  String _formatDate(dynamic raw) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    return parsed == null ? '-' : DateFormat('dd MMM yyyy').format(parsed);
  }

  void _downloadReceipt() {
    final receipt = _receipt;
    if (receipt == null) return;

    final paidAt = DateTime.tryParse(receipt['paidAt']?.toString() ?? '');
    final lines = [
      receipt['organization']?.toString() ?? 'Harithakarmasena',
      'Payment Receipt',
      'Receipt No: ${receipt['receiptNo'] ?? '-'}',
      '',
      'Amount Paid: Rs ${receipt['amount'] ?? 0}.00',
      'Status: ${receipt['status'] ?? 'Paid'}',
      '',
      'Resident: ${_downloadValue(receipt['residentName'])}',
      'Phone: ${_downloadValue(receipt['phoneNumber'])}',
      'House: ${_downloadValue(receipt['houseNumber'])}',
      'Address: ${_downloadValue(receipt['address'])}',
      'Route: ${_downloadValue(receipt['routeName'])}',
      'Ward: ${_downloadValue(receipt['wardNumber'])}',
      '',
      'Payment Month: ${_downloadValue(receipt['month'])}',
      'Collection Date: ${_formatDate(receipt['collectionDate'])}',
      'Paid On: ${paidAt == null ? '-' : DateFormat('dd MMM yyyy, hh:mm a').format(paidAt)}',
      'Mode: ${_downloadValue(receipt['mode'])}',
      'Transaction ID: ${_downloadValue(receipt['transactionId'])}',
      'Collected By: ${_downloadValue(receipt['collectedBy'])}',
    ].join('\r\n');

    final bytes = utf8.encode(lines);
    final receiptNo = (receipt['receiptNo'] ?? 'receipt').toString().replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]+'),
      '-',
    );
    downloadFile(bytes, '$receiptNo.txt', 'text/plain;charset=utf-8');
  }

  String _downloadValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }
}
