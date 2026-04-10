import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CreateStaffScreen extends StatefulWidget {
  final Map<String, dynamic>? staffToEdit;
  const CreateStaffScreen({super.key, this.staffToEdit});

  @override
  _CreateStaffScreenState createState() => _CreateStaffScreenState();
}

class _CreateStaffScreenState extends State<CreateStaffScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _areaController = TextEditingController();
  final ApiService apiService = ApiService();
  bool _isLoading = false;
  bool _isAutoPassword = true;
  List<dynamic> _wards = [];
  List<dynamic> _routes = [];
  String? _selectedWardId;
  String? _selectedRouteId;

  @override
  void initState() {
    super.initState();
    _fetchWards();
    if (widget.staffToEdit != null) {
      _nameController.text = widget.staffToEdit!['name'] ?? '';
      _emailController.text = widget.staffToEdit!['email'] ?? '';
      _phoneController.text = widget.staffToEdit!['phoneNumber'] ?? '';
      _addressController.text = widget.staffToEdit!['address'] ?? '';
      _selectedWardId = widget.staffToEdit!['ward'];
      _selectedRouteId = widget.staffToEdit!['route'];
      _isAutoPassword = false;
      if (_selectedWardId != null) _fetchRoutes(_selectedWardId!);
    }
  }

  Future<void> _fetchWards() async {
    final wards = await apiService.getWards();
    setState(() => _wards = wards);
  }

  Future<void> _fetchRoutes(String wardId) async {
    final routes = await apiService.getRoutes(wardId: wardId);
    setState(() => _routes = routes);
  }

  void _submit() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
      _showMsg('Please fill name and email', Colors.orangeAccent);
      return;
    }

    setState(() => _isLoading = true);

    final payload = {
      'name': _nameController.text,
      'email': _emailController.text,
      'phoneNumber': _phoneController.text,
      'address': _addressController.text,
      'ward': _selectedWardId,
      'route': _selectedRouteId,
    };

    if (widget.staffToEdit != null) {
      final res = await apiService.updateUser(widget.staffToEdit!['_id'], payload);
      setState(() => _isLoading = false);
      if (res['message']?.contains('success') == true) {
        _showMsg('Staff updated successfully', const Color(0xFF00E676));
        Navigator.pop(context);
      } else {
        _showMsg(res['message'] ?? 'Update failed', Colors.redAccent);
      }
    } else {
      final result = await apiService.createStaff(
        _nameController.text,
        _emailController.text,
        _isAutoPassword ? "" : _passwordController.text,
        wardId: _selectedWardId,
        routeId: _selectedRouteId,
        phoneNumber: _phoneController.text,
        address: _addressController.text,
      );

      setState(() => _isLoading = false);

      if (result['message'] == 'Staff created successfully by Admin') {
        _showSuccessDialog(
          _nameController.text,
          _emailController.text,
          result['generatedPassword'] ?? _passwordController.text,
        );
      } else {
        _showMsg(result['message'] ?? 'Creation failed', Colors.redAccent);
      }
    }
  }

  void _showMsg(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  void _showSuccessDialog(String name, String username, String pass) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Center(child: Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 64)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Account Created!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 12),
            Text('Credentials for $name:', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 24),
            _credentialItem('USERNAME', username),
            const SizedBox(height: 12),
            _credentialItem('PASSWORD', pass),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: const Text('DONE', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _credentialItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F2), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isEdit = widget.staffToEdit != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isEdit ? 'Edit Staff' : 'Add Staff', 
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: Color(0xFF1A1C1E))),
                    const SizedBox(height: 4),
                    Text(isEdit ? 'Modify existing staff member info' : 'Manage your staff members', 
                        style: const TextStyle(fontSize: 14, color: Colors.black45)),
                  ],
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE65100),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('Go to Staff List'),
                ),
              ],
            ),
            const SizedBox(height: 40),
            // Form Container
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildInput('Staff Name', 'Enter staff name', _nameController)),
                      const SizedBox(width: 40),
                      Expanded(child: _buildInput('Phone Number', 'Enter phone number', _phoneController)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(child: _buildInput('Username (Email)', 'Enter email address', _emailController)),
                      const SizedBox(width: 40),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Ward Selection', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedWardId,
                                  isExpanded: true,
                                  hint: const Text('Select Ward', style: TextStyle(color: Colors.black26, fontSize: 13)),
                                  items: _wards.map((w) => DropdownMenuItem<String>(value: w['_id'], child: Text('Ward ${w['wardNumber']}'))).toList(),
                                  onChanged: (val) {
                                    setState(() => _selectedWardId = val);
                                    if (val != null) _fetchRoutes(val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Route Assignment', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedRouteId,
                                  isExpanded: true,
                                  hint: const Text('Select Route', style: TextStyle(color: Colors.black26, fontSize: 13)),
                                  items: _routes.map((r) => DropdownMenuItem<String>(value: r['_id'], child: Text(r['name']))).toList(),
                                  onChanged: (val) => setState(() => _selectedRouteId = val),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 40),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text('Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Select category', style: TextStyle(color: Colors.black26, fontSize: 13)),
                        Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const SizedBox(height: 32),
                  _buildInput('Description / Address', 'Enter official description', _addressController, maxLines: 4),
                  if (!isEdit) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Checkbox(
                          value: _isAutoPassword,
                          activeColor: const Color(0xFFE65100),
                          onChanged: (v) => setState(() => _isAutoPassword = v!),
                        ),
                        const Text('Auto-generate system password', style: TextStyle(fontSize: 13, color: Colors.black87)),
                      ],
                    ),
                    if (!_isAutoPassword) ...[
                      const SizedBox(height: 16),
                      _buildInput('Manual Password', 'Set a password', _passwordController, obscure: true),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Actions
            Row(
              children: [
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE65100),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(180, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(isEdit ? 'Update Staff' : 'Add Staff'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    _nameController.clear();
                    _emailController.clear();
                    _phoneController.clear();
                    _addressController.clear();
                    _areaController.clear();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF455A64),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(120, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, String hint, TextEditingController controller, {int maxLines = 1, bool obscure = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          maxLines: maxLines,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.black26, fontSize: 13),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE65100))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}
