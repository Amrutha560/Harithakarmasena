import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CollectionListScreen extends StatefulWidget {
  final String wardNumber;
  final String? scheduleId;

  const CollectionListScreen({super.key, required this.wardNumber, this.scheduleId});

  @override
  _CollectionListScreenState createState() => _CollectionListScreenState();
}

class _CollectionListScreenState extends State<CollectionListScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _residents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchResidents();
  }

  Future<void> _fetchResidents() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final data = await _apiService.getResidentsByWard(widget.wardNumber);
      if (mounted) {
        setState(() {
          _residents = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryGreen = const Color(0xFF00C853);
    final accentPurple = const Color(0xFF6200EA);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1C1E), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Ward ${widget.wardNumber} Tracking', style: const TextStyle(color: Color(0xFF1A1C1E), fontSize: 16, fontWeight: FontWeight.w900)),
        centerTitle: true,
        actions: [
          IconButton(onPressed: _fetchResidents, icon: Icon(Icons.refresh_rounded, color: primaryGreen)),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryGreen))
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _residents.length,
              itemBuilder: (context, index) {
                final r = _residents[index];
                final bool isPaid = r['hasPaid'] ?? false;
                final status = r['collectionStatus'] ?? 'Pending';
                
                return _neumorphicCard(r, isPaid, status, primaryGreen, accentPurple);
              },
            ),
    );
  }

  Widget _neumorphicCard(Map<String, dynamic> r, bool isPaid, String status, Color green, Color purple) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F2),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.white, offset: const Offset(-8, -8), blurRadius: 15),
          BoxShadow(color: Colors.black.withOpacity(0.08), offset: const Offset(8, 8), blurRadius: 15),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _userAvatar(r['name'], green, purple),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['name'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1A1C1E))),
                    const SizedBox(height: 2),
                    Text('House No: ${r['houseNumber'] ?? 'N/A'}', style: const TextStyle(fontSize: 11, color: Colors.black38, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              _statusBadge(status),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Monthly Service Fee (₹50)', style: TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w600)),
              _paymentLabel(isPaid, green),
            ],
          ),
          if (widget.scheduleId != null) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _actionBtn(
                    'COLLECTED', 
                    Icons.check_circle_outline, 
                    isPaid ? Colors.green : Colors.grey, 
                    () {
                      if (isPaid) {
                        _markStatus(r['_id'], 'Collected');
                      } else {
                        _showPaymentWarning(context);
                      }
                    }
                  )
                ),
                const SizedBox(width: 12),
                Expanded(child: _actionBtn('NOT HOME', Icons.cancel_outlined, Colors.orange, () => _markStatus(r['_id'], 'Not Collected'))),
                const SizedBox(width: 12),
                Expanded(child: _actionBtn('NON-COOP', Icons.report_problem_rounded, Colors.red, () => _markStatus(r['_id'], 'Not Cooperative'))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showPaymentWarning(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF0F4F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Payment Required', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.orange)),
        content: const Text('Waste collection is only permitted for residents who have paid their monthly ₹50 service fee. Please ask the resident to pay via their wallet or record a cash payment.', style: TextStyle(fontSize: 13, color: Colors.black54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _userAvatar(String name, Color green, Color purple) {
    return Container(
      height: 48, width: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [green, purple]),
        shape: BoxShape.circle,
      ),
      child: Center(child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18))),
    );
  }

  Widget _paymentLabel(bool isPaid, Color green) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPaid ? green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isPaid ? 'PAID VIA WALLET' : 'UNPAID',
        style: TextStyle(color: isPaid ? green : Colors.red, fontSize: 9, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status) {
      case 'Collected': color = const Color(0xFF00C853); break;
      case 'Not Collected': color = Colors.orange; break;
      case 'Not Cooperative': color = Colors.redAccent; break;
      default: color = Colors.blueGrey.shade100;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F2),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.white, offset: const Offset(-2, -2), blurRadius: 5),
            BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(2, 2), blurRadius: 5),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Future<void> _markStatus(String residentId, String status) async {
    setState(() => _isLoading = true);
    try {
      await _apiService.markCollection({
        'residentId': residentId,
        'scheduleId': widget.scheduleId,
        'status': status,
      });
      _fetchResidents();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
