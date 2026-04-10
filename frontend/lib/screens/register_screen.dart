import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _houseNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _wardController = TextEditingController();
  final _passwordController = TextEditingController();
  final ApiService apiService = ApiService();
  bool _isLoading = false;
  List<dynamic> _wards = [];
  List<dynamic> _routes = [];
  String? _selectedWardId;
  String? _selectedRouteId;

  @override
  void initState() {
    super.initState();
    _fetchWards();
  }

  Future<void> _fetchWards() async {
    final wards = await apiService.getWards();
    setState(() => _wards = wards);
  }

  Future<void> _fetchRoutes(String wardId) async {
    final routes = await apiService.getRoutes(wardId: wardId);
    setState(() {
      _routes = routes;
      _selectedRouteId = null;
    });
  }

  void _register() async {
    if (_nameController.text.isEmpty ||
        _usernameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _selectedWardId == null ||
        _selectedRouteId == null) {
      _showMsg('Please fill all mandatory fields', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String identifier = _usernameController.text.trim().toLowerCase();
      final emailValue = identifier.contains('@') ? identifier : '$identifier@resident.com';
      
      final result = await apiService.residentRegister(
        _nameController.text,
        emailValue,
        _passwordController.text,
        houseNumber: _houseNumberController.text,
        address: _addressController.text,
        phone: _phoneController.text,
        wardId: _selectedWardId,
        routeId: _selectedRouteId,
      ).timeout(const Duration(seconds: 10));

      if (result['token'] != null || result['message'] == 'Resident registered successfully') {
        if (!mounted) return;
        _showMsg('Registration successful! Please login.', Colors.green);
        Navigator.pop(context);
      } else {
        _showMsg(result['message'] ?? 'Registration Failed', Colors.redAccent);
      }
    } catch (e) {
      _showMsg('Connection error. Server may be down.', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMsg(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _houseNumberController.dispose();
    _addressController.dispose();
    _wardController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5E5E5), // Light grey background
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Header Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Resident Registration",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Icon(
                          Icons.code, // </> equivalent
                          color: Colors.black38,
                          size: 20,
                        ),
                      ],
                    ),
                  ),

                  // Main Card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1B8A44), // Darker Emerald Green
                          Color(0xFF6EDC44), // Lime Green
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Leaf Icon Circle
                        Container(
                          height: 70,
                          width: 70,
                          decoration: const BoxDecoration(
                            color: Color(0xFF00FF55), // Bright Neon Green
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.eco,
                            color: Colors.black87,
                            size: 35,
                          ),
                        ),
                        
                        const SizedBox(height: 15),

                        // Title
                        const Text(
                          "Harithakarma Sena",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 5),

                        const Text(
                          "RESIDENT REGISTRATION",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: Colors.white70,
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Full Name Field
                        _buildLabel("Resident Full Name"),
                        _buildTextField(
                          controller: _nameController,
                          hint: "Enter your full name",
                          icon: Icons.person_outline_rounded,
                        ),

                        const SizedBox(height: 15),

                        // Username Field (actually the email)
                        _buildLabel("Username"),
                        _buildTextField(
                          controller: _usernameController,
                          hint: "Create a login username",
                          icon: Icons.alternate_email_rounded,
                        ),

                        const SizedBox(height: 15),

                        // Mobile Number Field
                        _buildLabel("Mobile Number"),
                        _buildTextField(
                          controller: _phoneController,
                          hint: "10-digit mobile number",
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                        ),

                        const SizedBox(height: 15),

                        _buildLabel("House Number"),
                        _buildTextField(
                          controller: _houseNumberController,
                          hint: "e.g. 12A",
                          icon: Icons.numbers,
                        ),

                        const SizedBox(height: 15),

                        // Ward Selection
                        _buildLabel("Select Ward"),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedWardId,
                              isExpanded: true,
                              hint: const Text('Select your ward', style: TextStyle(fontSize: 14, color: Colors.black38)),
                              items: _wards.map((w) => DropdownMenuItem<String>(value: w['_id'], child: Text('Ward ${w['wardNumber']}: ${w['name']}'))).toList(),
                              onChanged: (val) {
                                setState(() => _selectedWardId = val);
                                if (val != null) _fetchRoutes(val);
                               },
                            ),
                          ),
                        ),

                        const SizedBox(height: 15),

                        // Route Selection
                        _buildLabel("Select Route"),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedRouteId,
                              isExpanded: true,
                              hint: const Text('Select your route', style: TextStyle(fontSize: 14, color: Colors.black38)),
                              items: _routes.map((r) => DropdownMenuItem<String>(value: r['_id'], child: Text(r['name']))).toList(),
                              onChanged: (val) => setState(() => _selectedRouteId = val),
                            ),
                          ),
                        ),

                        const SizedBox(height: 15),

                        // Address Field
                        _buildLabel("Full Address"),
                        _buildTextField(
                          controller: _addressController,
                          hint: "Locality, Post office, District",
                          icon: Icons.map_rounded,
                        ),

                        const SizedBox(height: 15),

                        // Password Field
                        _buildLabel("Password"),
                        _buildTextField(
                          controller: _passwordController,
                          hint: "Create a strong password",
                          icon: Icons.lock,
                          obscureText: true,
                        ),

                        const SizedBox(height: 30),

                        // Register Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: _isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(color: Colors.white),
                                )
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00FF55),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: _register,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Text(
                                        "REGISTER",
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(width: 5),
                                      Icon(
                                        Icons.arrow_forward,
                                        color: Colors.black,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                        ),

                        const SizedBox(height: 25),

                        // Divider or Bottom text
                        Container(
                          height: 1,
                          color: Colors.white.withOpacity(0.1),
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Already have an account? ",
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Text(
                                "Login here",
                                style: TextStyle(
                                  color: Color(0xFF00FF55),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 25),

                        // Footer
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.security, color: Colors.white54, size: 12),
                            SizedBox(width: 5),
                            Text(
                              "Secure registration powered by Harithakarma Sena",
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.black87, fontSize: 14),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.black45, size: 20),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
