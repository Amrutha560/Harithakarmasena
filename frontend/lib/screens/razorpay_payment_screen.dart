import 'package:flutter/material.dart';
import '../utils/platform_utils.dart';
import '../services/api_service.dart';
import 'payment_receipt_screen.dart';

class RazorpayPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> dashboardData;
  const RazorpayPaymentScreen({super.key, required this.dashboardData});

  @override
  _RazorpayPaymentScreenState createState() => _RazorpayPaymentScreenState();
}

class _RazorpayPaymentScreenState extends State<RazorpayPaymentScreen> {
  final ApiService _apiService = ApiService();
  bool _isProcessing = false;
  bool _hasCompletedPayment = false;

  @override
  void initState() {
    super.initState();
  }

  void _handlePaymentSuccess(Map<String, dynamic> response) async {
    setState(() => _isProcessing = true);
    print('[DEBUG] Payment Successful! Verifying with backend...');
    try {
      final verifyRes = await _apiService.verifyRazorpayPayment({
        'razorpay_order_id': response['razorpay_order_id'],
        'razorpay_payment_id': response['razorpay_payment_id'],
        'razorpay_signature': response['razorpay_signature'],
        'scheduleId': widget.dashboardData['scheduleId'] ?? '',
      });

      print('[DEBUG] Verification Response: $verifyRes');

      if (verifyRes['message'].contains('verified')) {
        _hasCompletedPayment = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Payment Verified! Schedule Updated.'),
              backgroundColor: Colors.green,
            ),
          );
          final paymentId = verifyRes['payment']?['_id']?.toString();
          if (paymentId != null && paymentId.isNotEmpty) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => PaymentReceiptScreen(paymentId: paymentId),
              ),
            );
          } else {
            Navigator.pop(context, true);
          }
        }
      }
    } catch (e) {
      print('[DEBUG] Verification Exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification Failed'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _markPaymentDue({
    bool returnToPrevious = false,
    bool showMessage = true,
  }) async {
    if (_hasCompletedPayment) return;
    final scheduleId = widget.dashboardData['scheduleId']?.toString() ?? '';
    final date =
        widget.dashboardData['selectedScheduleDate']?.toString() ??
        widget.dashboardData['staffVisitDate']?.toString() ??
        DateTime.now().toIso8601String().split('T')[0];

    if (scheduleId.isNotEmpty) {
      await _apiService.choosePaymentMode(
        assignmentId: scheduleId,
        date: date,
        mode: 'Due',
      );
    }

    if (!mounted) return;
    if (showMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment cancelled. Amount is marked as due.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    if (returnToPrevious) Navigator.pop(context, true);
  }

  Future<void> _payNow() async {
    final scheduleId = widget.dashboardData['scheduleId'];
    if (scheduleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active schedule found to pay for.')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    print('[DEBUG] Starting Razorpay Flow for Schedule: $scheduleId');

    try {
      // 1. Create Order on Backend
      final orderData = await _apiService.createRazorpayOrder(scheduleId);
      print('[DEBUG] Backend Order Data: $orderData');

      // 2. Open Razorpay Checkout
      final options = {
        'key': orderData['keyId'], // Use Key ID from backend
        'amount': orderData['amount'],
        'name': 'Harithakarmasena',
        'order_id': orderData['orderId'],
        'description': 'Outside Collection Fee',
        'currency': orderData['currency'],
        'timeout': 300,
        'remember_customer': false,
        'prefill': {
          'contact': widget.dashboardData['user']?['phoneNumber'] ?? '',
          'email': widget.dashboardData['user']?['email'] ?? '',
        },
        'theme': {'color': '#1B5E20'},
      };

      print('[DEBUG] Opening Razorpay Modal...');
      openRazorpayWeb(options, (Map<String, dynamic> response) {
        _handlePaymentSuccess({
          'razorpay_order_id': response['razorpay_order_id'],
          'razorpay_payment_id': response['razorpay_payment_id'],
          'razorpay_signature': response['razorpay_signature'],
        });
      }, () {
        if (mounted) {
          setState(() => _isProcessing = false);
          _markPaymentDue(showMessage: false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment not completed. Amount remains due.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });
    } catch (e) {
      print('[DEBUG] EXCEPTION in _payNow: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF1B5E20);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Secure Payment',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security_rounded, size: 80, color: primaryGreen),
              const SizedBox(height: 24),
              const Text(
                'Harithakarmasena',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryGreen,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Outside Collection Fee',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 40),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'TOTAL AMOUNT DUE',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '₹50.00',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _payNow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isProcessing
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Proceed to Pay Now',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing
                            ? null
                            : () async {
                                setState(() => _isProcessing = true);
                                try {
                                  await _markPaymentDue(returnToPrevious: true);
                                } finally {
                                  if (mounted)
                                    setState(() => _isProcessing = false);
                                }
                              },
                        icon: const Icon(
                          Icons.cancel_outlined,
                          color: Colors.redAccent,
                        ),
                        label: const Text(
                          'Cancel Payment',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  const Text(
                    'Secured by Razorpay',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
