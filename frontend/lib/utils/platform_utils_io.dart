import 'package:razorpay_flutter/razorpay_flutter.dart';

void downloadFile(List<int> bytes, String filename, String mimeType) {
  print('Download file not fully implemented for mobile in this stub. Please use a package like path_provider or open_file for mobile.');
}

void printPage() {
  print('Print not implemented for mobile.');
}

void openRazorpayWeb(Map<String, dynamic> options, Function(Map<String, dynamic>) onSuccess, Function onDismiss) {
  final razorpay = Razorpay();
  
  razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
    onSuccess({
      'razorpay_order_id': response.orderId,
      'razorpay_payment_id': response.paymentId,
      'razorpay_signature': response.signature,
    });
    razorpay.clear();
  });
  
  razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
    onDismiss();
    razorpay.clear();
  });
  
  razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse response) {
    razorpay.clear();
  });
  
  razorpay.open(options);
}
