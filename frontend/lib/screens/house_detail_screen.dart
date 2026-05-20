import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HouseDetailScreen extends StatefulWidget {
  final dynamic house;
  final dynamic route;

  const HouseDetailScreen({
    super.key,
    required this.house,
    required this.route,
  });

  @override
  State<HouseDetailScreen> createState() => _HouseDetailScreenState();
}

class _HouseDetailScreenState extends State<HouseDetailScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _hasProof = false;
  String _paymentStatus = 'Not Paid'; // 'Paid' or 'Not Paid'

  void _markCollection(String status) async {
    setState(() => _isLoading = true);
    if (status == 'Collected' && !_hasProof) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please upload a photo proof before marking as collected'),
        backgroundColor: Colors.orange,
      ));
      setState(() => _isLoading = false);
      return;
    }

    try {
      await _apiService.markCollection({
        'houseId': widget.house['_id'],
        'routeId': widget.route['_id'],
        'residentId': widget.house['resident'],
        'status': status,
        'scheduleId': widget.route['_id'],
        'paymentStatus': _paymentStatus,
        'proofImageUrl': _hasProof ? 'https://res.cloudinary.com/demo/image/upload/v1312461204/sample.jpg' : null,
      });

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Marked as: $status'),
          backgroundColor: status == 'Collected' ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to update status'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFF8FAFB);
    const primaryGreen = Color(0xFF1B5E20);
    const lightBlue = Color(0xFFE8F5FF);
    
    final houseName = widget.house['ownerName'] ?? 'Resident Home';
    final address = '${widget.house['houseNumber']}, ${widget.house['address']}';
    final wasteType = widget.house['wasteTypes'] != null ? (widget.house['wasteTypes'] as List).join(', ') : 'General Waste';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2E7D32)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Harithakarmasena',
          style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: const [
          Icon(Icons.eco_rounded, color: Color(0xFF2E7D32)),
          SizedBox(width: 24),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            // ─── TOP FEATURED CARD ───────────────────────────────────────
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [Colors.blue.shade300, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                image: DecorationImage(
                  image: const NetworkImage('https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=400&q=80'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.blue.withOpacity(0.3), BlendMode.srcOver),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFC5E1A5), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.home_rounded, size: 14, color: Color(0xFF33691E)),
                        SizedBox(width: 4),
                        Text('RESIDENT HOME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF33691E))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(houseName, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  Text('Priority Collection • $wasteType', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── STATUS INFO ROW ─────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 100,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: widget.house['residentResponse'] == 'Available' 
                          ? const Color(0xFFE8F5E9) 
                          : (widget.house['residentResponse'] == 'Not Available' ? const Color(0xFFFFEBEE) : lightBlue), 
                      borderRadius: BorderRadius.circular(24)
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('AVAILABILITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black38)),
                        const SizedBox(height: 4),
                        Text(
                          widget.house['residentResponse'] ?? 'Pending',
                          style: TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.w900, 
                            color: widget.house['residentResponse'] == 'Available' 
                                ? const Color(0xFF1B5E20) 
                                : (widget.house['residentResponse'] == 'Not Available' ? Colors.red : const Color(0xFF1A1C1E))
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(
                              widget.house['residentResponse'] == 'Available' 
                                  ? Icons.check_circle 
                                  : (widget.house['residentResponse'] == 'Not Available' ? Icons.cancel : Icons.info_outline),
                              size: 14,
                              color: widget.house['residentResponse'] == 'Available' 
                                  ? const Color(0xFF2E7D32) 
                                  : (widget.house['residentResponse'] == 'Not Available' ? Colors.red : Colors.orange),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.house['residentResponse'] == 'Available' 
                                  ? 'Confirmed via App' 
                                  : (widget.house['residentResponse'] == 'Not Available' ? 'Marked Unavailable' : 'Awaiting Response'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: widget.house['residentResponse'] == 'Available' 
                                    ? const Color(0xFF2E7D32) 
                                    : (widget.house['residentResponse'] == 'Not Available' ? Colors.red : Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    height: 100,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFCFD8DC).withOpacity(0.3), borderRadius: BorderRadius.circular(24)),
                    child: Column(
                      children: [
                        const Icon(Icons.access_time_filled, color: Color(0xFF0D47A1), size: 28),
                        const Spacer(),
                        const Text('ETA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black45)),
                        const Text('3 mins', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (widget.house['residentResponse'] == 'Not Available')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.orange),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'OUTSIDE COLLECTION REQUIRED: Resident is not home. ₹50 fee applies. Please collect from outside bin.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),



            // ─── VERIFICATION & PROOF ────────────────────────────────────
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Verification & Proof', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1A1C1E))),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () => setState(() => _hasProof = !_hasProof),
                    child: Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: _hasProof ? const Color(0xFFE8F5E9) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.withOpacity(0.1)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_rounded, size: 40, color: _hasProof ? Colors.green : Colors.black26),
                          const SizedBox(height: 12),
                          Text('Upload Photo Proof', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w900, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _sideActionCard(Icons.warning_rounded, 'Ensure bin lid is visible in shot', Colors.red.shade800),
                      const SizedBox(height: 10),
                      _sideActionCard(Icons.qr_code_scanner_rounded, 'Scan Bin Asset\nID Tag', Colors.blue.shade800),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ─── PAYMENT METHOD ──────────────────────────────────────────
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1A1C1E))),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: lightBlue, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        _payToggleItem('Paid', _paymentStatus == 'Paid', () => setState(() => _paymentStatus = 'Paid')),
                        _payToggleItem('Not Paid', _paymentStatus == 'Not Paid', () => setState(() => _paymentStatus = 'Not Paid')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Service Fee', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.bold)),
                        Text('\$12.50', style: TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w900, fontSize: 18)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // ─── FINAL ACTION BUTTONS ─────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _statusButton('Collected', Colors.green, Icons.check_circle_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _statusButton('Not Collected', Colors.orange, Icons.cancel_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statusButton('Not Cooperative', Colors.redAccent, Icons.do_not_disturb_on_rounded),
                ),
              ],
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(primaryGreen),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1A1C1E))),
        Icon(icon, color: Colors.black38, size: 20),
      ],
    );
  }

  Widget _sideActionCard(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _statusButton(String label, Color color, IconData icon) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : () => _markCollection(label),
      icon: _isLoading 
        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
        : Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        shadowColor: color.withOpacity(0.2),
      ),
    );
  }

  Widget _payToggleItem(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF2E7D32) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.black45, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(Color primary) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.gesture_rounded, 'ROUTES', true, primary),
          _navItem(Icons.calendar_today_rounded, 'SCHEDULE', false, primary),
          _navItem(Icons.person_outline_rounded, 'ACCOUNT', false, primary),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, Color primary) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFB9F6CA) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: active ? const Color(0xFF1B5E20) : Colors.black26),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: active ? const Color(0xFF1B5E20) : Colors.black26,
          ),
        ),
      ],
    );
  }
}
