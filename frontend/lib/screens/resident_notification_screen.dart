import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ResidentNotificationScreen extends StatefulWidget {
  const ResidentNotificationScreen({super.key});

  @override
  _ResidentNotificationScreenState createState() => _ResidentNotificationScreenState();
}

class _ResidentNotificationScreenState extends State<ResidentNotificationScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final notifications = await _apiService.getNotifications();
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _markAvailability(bool available) async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.respondToCollection(available ? 'Available' : 'Not Available');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(available ? 'Marked as Available' : 'Marked as Not Available'),
            backgroundColor: available ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
          )
        );
        // If not available, we show the payment options as requested in PRD
        if (!available) {
          _showPaymentSheet(false);
        } else {
          // If available, they might still want to pay now or pay staff by cash
          _showPaymentSheet(true);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPaymentSheet(bool isAvailable) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Collection Payment', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(isAvailable ? 'Since you are available, you can pay via Wallet or Cash.' : 'Please pay online as you are not available.', 
              style: const TextStyle(color: Colors.black45)),
            const SizedBox(height: 32),
            
            _paymentOption(Icons.account_balance_wallet_rounded, 'Pay via Wallet', 'Fast & Secure', Colors.orange, () {
               Navigator.pop(context);
               _processPayment('Wallet');
            }),
            const SizedBox(height: 16),
            if (isAvailable) ...[
               _paymentOption(Icons.money_rounded, 'Collected Cash', 'Hand over to staff', Colors.green, () {
                  Navigator.pop(context);
                  _processPayment('Cash');
               }),
               const SizedBox(height: 16),
            ],
            _paymentOption(Icons.qr_code_2_rounded, 'UPI Payment', 'Scan & Pay', Colors.blue, () {
               Navigator.pop(context);
               _processPayment('UPI');
            }),
            const SizedBox(height: 16),
            _paymentOption(Icons.credit_card_rounded, 'Card Payment', 'Visa / Mastercard', Colors.purple, () {
               Navigator.pop(context);
               _processPayment('Card');
            }),
            
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1C1E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('CANCEL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _processPayment(String method) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))),
    );
    
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context); // Close loading
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
          content: Text('Payment via $method successful!', textAlign: TextAlign.center),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))
          ],
        ),
      );
    });
  }

  Widget _paymentOption(IconData icon, String title, String sub, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(sub, style: const TextStyle(color: Colors.black38, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.black12, size: 14),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Notifications', style: TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : _notifications.isEmpty
              ? const Center(child: Text('No new notifications'))
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final n = _notifications[index];
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: n['type'] == 'CollectionAlert' ? const Color(0xFFE8F5E9) : 
                                   n['type'] == 'PaymentAlert' ? Colors.blue.withOpacity(0.1) : 
                                   Colors.orange.withOpacity(0.1),
                            shape: BoxShape.circle
                          ),
                          child: Icon(
                            n['type'] == 'CollectionAlert' ? Icons.eco_rounded : 
                            n['type'] == 'PaymentAlert' ? Icons.payment_rounded : 
                            Icons.notifications_active_rounded, 
                            color: n['type'] == 'CollectionAlert' ? Colors.green : 
                                   n['type'] == 'PaymentAlert' ? Colors.blue : 
                                   Colors.orange, 
                            size: 20
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          n['type'] == 'CollectionAlert' ? 'Waste Collection Alert' : 
                          n['type'] == 'PaymentAlert' ? 'Payment Notification' : 
                          'General Notification', 
                          style: const TextStyle(fontWeight: FontWeight.bold)
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(n['title'] ?? 'Notification', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(n['message'] ?? '', style: const TextStyle(color: Colors.black54, fontSize: 14)),
                    const SizedBox(height: 12),
                    if (n['createdAt'] != null)
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 12, color: Colors.black26),
                          const SizedBox(width: 4),
                          Text(
                            'Sent on ${n['createdAt'].toString().substring(0, 10)}', 
                            style: const TextStyle(color: Colors.black38, fontSize: 11)
                          ),
                        ],
                      ),
                    
                    if (n['type'] == 'CollectionAlert') ...[
                      const SizedBox(height: 32),
                      const Text('Will you be available?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _markAvailability(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Text('AVAILABLE', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _markAvailability(false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.orange,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: Colors.orange),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Text('NOT AVAILABLE', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
    );
  }
}
