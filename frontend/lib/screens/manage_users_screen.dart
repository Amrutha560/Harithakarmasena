import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  _ManageUsersScreenState createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    final users = await _apiService.getUsers();
    setState(() {
      _users = users;
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
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1C1E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('User Management', style: TextStyle(color: Color(0xFF1A1C1E), fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'All Registered Users (${_users.length})',
                    style: const TextStyle(color: Color(0xFF1A1C1E), fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Track and manage roles and account status.',
                    style: TextStyle(color: Colors.black38, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        return _buildUserCard(user);
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    IconData roleIcon;
    Color roleColor;
    
    switch (user['role']) {
      case 'admin':
        roleIcon = Icons.admin_panel_settings_outlined;
        roleColor = const Color(0xFFE53935);
        break;
      case 'resident':
        roleIcon = Icons.home_outlined;
        roleColor = const Color(0xFF1976D2);
        break;
      case 'staff':
        roleIcon = Icons.badge_outlined;
        roleColor = const Color(0xFF2E7D32);
        break;
      default:
        roleIcon = Icons.person_outline;
        roleColor = Colors.black26;
    }

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
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(roleIcon, color: roleColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'],
                  style: const TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  user['email'],
                  style: const TextStyle(color: Colors.black38, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                (user['role'] as String).toUpperCase(),
                style: TextStyle(color: roleColor.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: user['isApproved'] == true ? const Color(0xFFE8F5E9) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  user['isApproved'] == true ? 'Active' : 'Pending',
                  style: TextStyle(
                    color: user['isApproved'] == true ? const Color(0xFF2E7D32) : Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
