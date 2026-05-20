import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class AdminResidentListScreen extends StatefulWidget {
  final bool embedded;

  const AdminResidentListScreen({super.key, this.embedded = false});

  @override
  State<AdminResidentListScreen> createState() => _AdminResidentListScreenState();
}

class _AdminResidentListScreenState extends State<AdminResidentListScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _residents = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchResidents();
  }

  Future<void> _fetchResidents() async {
    setState(() => _isLoading = true);
    final allUsers = await _apiService.getUsers();
    setState(() {
      _residents = allUsers.where((u) => u['role'] == 'resident').toList();
      _isLoading = false;
    });
  }

  Future<void> _deleteResident(String userId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Resident', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to permanently delete this resident account? This action cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      setState(() => _isLoading = true);
      try {
        await _apiService.deleteUser(userId);
        _fetchResidents();
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error deleting resident')));
      }
    }
  }

  Future<void> _approveResident(Map<String, dynamic> resident) async {
    final userId = resident['_id']?.toString() ?? '';
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.approveUser(userId); // Using the unified approve endpoint
      
      // Refresh residents to get updated status
      final allUsers = await _apiService.getUsers();
      final updatedResidents = allUsers.where((u) => u['role'] == 'resident').toList();
      
      setState(() {
        _residents = updatedResidents;
        _isLoading = false;
      });

      final setup = response['setup'] as Map<String, dynamic>?;
      final devCredentials = response['devCredentials'] as Map<String, dynamic>?;
      final whatsAppSent = setup?['whatsAppSent'] == true;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            whatsAppSent
                ? 'Resident approved and WhatsApp credentials sent'
                : 'Resident approved. WhatsApp not sent: ${setup?['whatsAppMessage'] ?? 'Twilio not ready'}',
          ),
          backgroundColor: whatsAppSent ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
        )
      );

      if (devCredentials != null) {
        _showCredentialsDialog(
          devCredentials['username']?.toString() ?? setup?['username']?.toString() ?? '',
          devCredentials['temporaryPassword']?.toString() ?? '',
          devCredentials['loginPageLink']?.toString() ?? setup?['loginPageLink']?.toString() ?? '',
          setup?['whatsAppMessage']?.toString() ?? '',
        );
      }

    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error approving resident'), backgroundColor: Colors.redAccent)
      );
    }
  }

  Future<void> _resendCredentials(Map<String, dynamic> resident) async {
    final userId = resident['_id']?.toString() ?? '';
    if (userId.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final response = await _apiService.resendResidentCredentials(userId);
      await _fetchResidents();

      final setup = response['setup'] as Map<String, dynamic>?;
      final devCredentials = response['devCredentials'] as Map<String, dynamic>?;
      final whatsAppSent = setup?['whatsAppSent'] == true;
      final whatsAppMessage = setup?['whatsAppMessage']?.toString() ?? response['message']?.toString() ?? '';

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(whatsAppSent ? 'WhatsApp credentials resent' : 'Credentials regenerated. WhatsApp not delivered: $whatsAppMessage'),
          backgroundColor: whatsAppSent ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (devCredentials != null) {
        _showCredentialsDialog(
          devCredentials['username']?.toString() ?? setup?['username']?.toString() ?? '',
          devCredentials['temporaryPassword']?.toString() ?? '',
          devCredentials['loginPageLink']?.toString() ?? setup?['loginPageLink']?.toString() ?? '',
          whatsAppMessage,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error resending credentials'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _sendCredentials(Map<String, dynamic> resident) async {
    if (resident['isApproved'] == false) {
      await _approveResident(resident);
      return;
    }

    await _resendCredentials(resident);
  }



  void _showCredentialsDialog(String username, String password, String loginLink, String whatsAppStatus) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.vpn_key_rounded, color: Colors.blue),
            SizedBox(width: 10),
            Text('Resident Credentials'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The following credentials were generated and sent to the resident WhatsApp when Twilio is ready:'),
            const SizedBox(height: 20),
            _credentialRow('Username', username),
            const SizedBox(height: 8),
            _credentialRow('Temporary Password', password),
            const SizedBox(height: 8),
            _credentialRow('Login Link', loginLink),
            if (whatsAppStatus.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('WhatsApp: $whatsAppStatus', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
            const SizedBox(height: 20),
            const Text('Note: The resident will be required to change this password on their first login.', style: TextStyle(fontSize: 12, color: Colors.black45)),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _credentialRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          SelectableText(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredResidents = _residents.where((r) {
      final firstName = (r['firstName'] ?? '').toString().toLowerCase();
      final lastName = (r['lastName'] ?? '').toString().toLowerCase();
      final fullName = '$firstName $lastName';
      final email = (r['email'] ?? '').toString().toLowerCase();
      final phone = (r['phoneNumber'] ?? '').toString().toLowerCase();
      final house = (r['houseNumber'] ?? '').toString().toLowerCase();
      return fullName.contains(_searchQuery.toLowerCase()) || 
             email.contains(_searchQuery.toLowerCase()) || 
             phone.contains(_searchQuery.toLowerCase()) ||
             house.contains(_searchQuery.toLowerCase());
    }).toList();

    final content = _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
        : Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: const InputDecoration(
                      hintText: 'Search residents by name, email, or house...',
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.black26),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: filteredResidents.isEmpty
                    ? const Center(child: Text('No residents found', style: TextStyle(color: Colors.black38)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: filteredResidents.length,
                        itemBuilder: (context, index) {
                          final resident = filteredResidents[index];
                          return _buildResidentCard(resident);
                        },
                      ),
              ),
            ],
          );

    if (widget.embedded) {
      return Container(
        color: const Color(0xFFF8FAF9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(32, 28, 32, 0),
              child: Text('Residents', style: TextStyle(color: Color(0xFF1A1C1E), fontSize: 32, fontWeight: FontWeight.bold)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(32, 8, 32, 0),
              child: Text('Review resident profiles, approvals, and route assignments.', style: TextStyle(color: Colors.black45, fontSize: 16)),
            ),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1C1E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Resident Details', 
          style: TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: content,
    );
  }

  Widget _buildResidentCard(Map<String, dynamic> resident) {
    final houseName = (resident['houseName'] ?? '').toString().trim();
    final address = (resident['address'] ?? '').toString().trim();
    final houseSubtitle = houseName.isNotEmpty
        ? houseName
        : (address.isNotEmpty ? address : 'House ${resident['houseNumber'] ?? 'N/A'}');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFE8F5E9),
                child: Text(
                  (resident['firstName'] ?? 'R')[0].toUpperCase(),
                  style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${resident['firstName'] ?? 'Unknown'} ${resident['lastName'] ?? ''}', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF1A1C1E))),
                    Text(houseSubtitle,
                      style: const TextStyle(color: Colors.black38, fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: resident['isApproved'] == false ? Colors.orange.withOpacity(0.1) : const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(resident['isApproved'] == false ? 'PENDING' : 'ACTIVE', 
                  style: TextStyle(color: resident['isApproved'] == false ? Colors.orange : Color(0xFF1976D2), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              if (resident['isApproved'] == false)
                IconButton(
                  icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 24),
                  onPressed: () => _approveResident(resident),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Approve Resident',
                ),
              IconButton(
                icon: const Icon(Icons.send_to_mobile_rounded, color: Color(0xFF2E7D32), size: 22),
                onPressed: () => _sendCredentials(resident),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: resident['isApproved'] == false
                    ? 'Approve and send WhatsApp credentials'
                    : 'Resend WhatsApp credentials',
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                onPressed: () => _deleteResident(resident['_id']?.toString() ?? ''),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          Row(
            children: [
              _detailItem(Icons.home_rounded, 'HOUSE NO', resident['houseNumber']?.toString() ?? 'N/A'),
              const SizedBox(width: 20),
              _detailItem(Icons.phone_rounded, 'PHONE', resident['phoneNumber']?.toString() ?? 'N/A'),
              const SizedBox(width: 20),
              _detailItem(Icons.location_on_rounded, 'ROUTE', resident['route'] != null ? (resident['route'] is Map ? resident['route']['name'] : 'Assigned') : 'NOT ASSIGNED', isAlert: resident['route'] == null),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _detailItem(Icons.location_city_rounded, 'WARD', '${resident['wardNumber'] ?? 'N/A'} - ${resident['wardName'] ?? ''}'),
              const SizedBox(width: 20),
              _detailItem(Icons.business_rounded, 'LSGI', '${resident['lsgiType'] ?? 'N/A'}\n${resident['lsgiName'] ?? ''}'),
              const SizedBox(width: 20),
              _detailItem(Icons.map_rounded, 'DISTRICT', resident['district']?.toString() ?? 'N/A'),
            ],
          ),
          if (resident['verificationDoc'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: InkWell(
                onTap: () async {
                  final String docPath = resident['verificationDoc'];
                  final String baseUrl = ApiService.baseUrl.replaceAll('/api', '');
                  final String url = '$baseUrl/$docPath'.replaceAll('\\', '/');
                  if (await canLaunchUrl(Uri.parse(url))) {
                    await launchUrl(Uri.parse(url));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open document')));
                  }
                },
                child: Row(
                  children: const [
                    Icon(Icons.description_outlined, size: 16, color: Color(0xFF2E7D32)),
                    SizedBox(width: 8),
                    Text('View Verification Document (PDF)', 
                      style: TextStyle(color: Color(0xFF2E7D32), fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailItem(IconData icon, String label, String value, {bool isAlert = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: Colors.black26),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 9, color: Colors.black38, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isAlert ? Colors.orange : Color(0xFF1A1C1E))),
        ],
      ),
    );
  }
}
