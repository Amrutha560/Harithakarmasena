import 'dart:html' as html;
import 'dart:js' as js;

void downloadFile(List<int> bytes, String filename, String mimeType) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

void printPage() {
  js.context.callMethod('print');
}

void openRazorpayWeb(Map<String, dynamic> options, Function(Map<String, dynamic>) onSuccess, Function onDismiss) {
  options['handler'] = js.JsFunction.withThis((_, dynamic response) {
    final paymentResponse = js.JsObject.fromBrowserObject(response);
    onSuccess({
      'razorpay_order_id': paymentResponse['razorpay_order_id'],
      'razorpay_payment_id': paymentResponse['razorpay_payment_id'],
      'razorpay_signature': paymentResponse['razorpay_signature'],
    });
  });
  options['modal'] = {
    'ondismiss': js.JsFunction.withThis((_) {
      onDismiss();
    }),
  };
  final razorpayConstructor = js.context['Razorpay'];
  if (razorpayConstructor == null) {
    throw 'Razorpay checkout script is not loaded';
  }
  final razorpay = js.JsObject(razorpayConstructor, [
    js.JsObject.jsify(options),
  ]);
  razorpay.callMethod('open');
}
