import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _houseNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _lsgiNameController = TextEditingController();
  final _wardController = TextEditingController();

  final ApiService apiService = ApiService();
  bool _isLoading = false;
  List<dynamic> _wards = [];
  List<dynamic> _routes = [];

  String? _selectedWardId;
  String? _selectedRouteId;
  String? _selectedDistrict = 'Kottayam';
  String? _selectedLsgiType = 'Gramapanchayath';
  Uint8List? _verificationDocBytes;
  String? _verificationDocName;

  final List<String> _districts = ['Kottayam'];

  final List<String> _lsgiTypes = ['Gramapanchayath'];

  @override
  void initState() {
    super.initState();
    _fetchWards();
  }

  Future<void> _fetchWards() async {
    try {
      final wards = await apiService.getWards();
      if (mounted) setState(() => _wards = wards);
    } catch (e) {
      debugPrint("Error fetching wards: $e");
    }
  }

  Future<void> _fetchRoutes(String wardId) async {
    try {
      final routes = await apiService.getRoutes(wardId: wardId);
      if (mounted) {
        setState(() {
          _routes = routes;
          _selectedRouteId = null; // Reset route when ward changes
        });
      }
    } catch (e) {
      debugPrint("Error fetching routes: $e");
    }
  }

  Future<void> _pickVerificationPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    if (!file.name.toLowerCase().endsWith('.pdf')) {
      _showMsg('Please upload a PDF file only', Colors.orange);
      return;
    }
    if (file.size > 5 * 1024 * 1024) {
      _showMsg('PDF must be 5 MB or smaller', Colors.orange);
      return;
    }
    if (file.bytes == null) {
      _showMsg(
        'Could not read selected PDF. Please try again.',
        Colors.redAccent,
      );
      return;
    }

    setState(() {
      _verificationDocBytes = file.bytes;
      _verificationDocName = file.name;
    });
  }

  int _wordCount(String value) {
    final text = value.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  void _register() async {
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _houseNumberController.text.trim().isEmpty ||
        _selectedDistrict == null ||
        _selectedLsgiType == null ||
        _lsgiNameController.text.trim().isEmpty ||
        _selectedWardId == null ||
        _addressController.text.trim().isEmpty ||
        _verificationDocBytes == null) {
      _showMsg('Please fill all mandatory fields', Colors.orange);
      return;
    }

    if (_wordCount(_firstNameController.text) > 10) {
      _showMsg('First name must be maximum 10 words', Colors.orange);
      return;
    }

    if (_wordCount(_lastNameController.text) > 10) {
      _showMsg('Last name must be maximum 10 words', Colors.orange);
      return;
    }

    if (_phoneController.text.length != 10) {
      _showMsg('Please enter a valid 10-digit mobile number', Colors.orange);
      return;
    }

    if (!RegExp(r'^\d{1,3}$').hasMatch(_houseNumberController.text.trim())) {
      _showMsg(
        'House number must be 1 to 3 digits, e.g. 1, 18 or 133',
        Colors.orange,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String phoneValue = _phoneController.text.trim();
      final String cleanHouseNumber = _houseNumberController.text.trim();
      final String cleanWardId = (_selectedWardId ?? '')
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
          .toLowerCase();
      final String emailValue =
          'house_${cleanHouseNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase()}_$cleanWardId@resident.local';
      final selectedWard = _wards.firstWhere(
        (w) => w['_id']?.toString() == _selectedWardId,
        orElse: () => null,
      );
      final selectedWardName = selectedWard == null
          ? ''
          : 'Ward ${selectedWard['wardNumber']}: ${selectedWard['name']}';

      final result = await apiService
          .residentRegister(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            email: emailValue,
            address: _addressController.text,
            phone: _phoneController.text,
            houseNumber: cleanHouseNumber,
            wardId: _selectedWardId,
            routeId: null,
            district: _selectedDistrict,
            lsgiType: _selectedLsgiType,
            lsgiName: _lsgiNameController.text.trim(),
            wardName: selectedWardName,
            verificationDocBytes: _verificationDocBytes,
            verificationDocName: _verificationDocName,
          )
          .timeout(const Duration(seconds: 20));

      if (result['token'] != null ||
          result['message'].toString().contains('successfully')) {
        if (!mounted) return;
        _showMsg(
          result['message'] ??
              'Registration successful! Pending Admin approval.',
          Colors.green,
        );
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
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _houseNumberController.dispose();
    _addressController.dispose();
    _lsgiNameController.dispose();
    _wardController.dispose();
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 10,
                    ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 25,
                      vertical: 30,
                    ),
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

                        // First Name Field
                        _buildLabel("First Name"),
                        _buildTextField(
                          controller: _firstNameController,
                          hint: "Enter your first name",
                          icon: Icons.person_outline_rounded,
                        ),

                        const SizedBox(height: 15),

                        // Last Name Field
                        _buildLabel("Last Name"),
                        _buildTextField(
                          controller: _lastNameController,
                          hint: "Enter your last name",
                          icon: Icons.person_outline_rounded,
                        ),

                        const SizedBox(height: 15),

                        // Mobile Number Field
                        _buildLabel("Mobile Number"),
                        _buildTextField(
                          controller: _phoneController,
                          hint: "10-digit mobile number",
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),

                        const SizedBox(height: 15),

                        // House Number Field
                        _buildLabel("House Number"),
                        _buildTextField(
                          controller: _houseNumberController,
                          hint: "1 to 3 digit house number",
                          icon: Icons.home_outlined,
                          keyboardType: TextInputType.number,
                          maxLength: 3,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),

                        const SizedBox(height: 15),

                        // District Selection
                        _buildLabel("Select District"),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedDistrict,
                              isExpanded: true,
                              hint: const Text(
                                'Select your district',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black38,
                                ),
                              ),
                              items: _districts
                                  .map(
                                    (d) => DropdownMenuItem<String>(
                                      value: d,
                                      child: Text(d),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                setState(() => _selectedDistrict = val);
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 15),

                        // LSGI Type Selection
                        _buildLabel("LSGI Type"),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedLsgiType,
                              isExpanded: true,
                              hint: const Text(
                                'Select LSGI Type',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black38,
                                ),
                              ),
                              items: _lsgiTypes
                                  .map(
                                    (t) => DropdownMenuItem<String>(
                                      value: t,
                                      child: Text(t),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                setState(() => _selectedLsgiType = val);
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 15),

                        // LSGI Name Field
                        _buildLabel("LSGI Name"),
                        _buildTextField(
                          controller: _lsgiNameController,
                          hint: "Enter Municipality/Panchayat name",
                          icon: Icons.location_city,
                        ),

                        const SizedBox(height: 15),

                        // Ward Selection
                        _buildLabel("Select Ward"),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedWardId,
                              isExpanded: true,
                              hint: const Text(
                                'Select ward number and name',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black38,
                                ),
                              ),
                              items: _wards
                                  .map(
                                    (w) => DropdownMenuItem<String>(
                                      value: w['_id'],
                                      child: Text(
                                        'Ward ${w['wardNumber']} - ${w['name']}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedWardId = val);
                                  _fetchRoutes(val);
                                }
                              },
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

                        _buildLabel("Verification PDF"),
                        _buildPdfUploadField(),
                        const SizedBox(height: 15),

                        // Register Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: _isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
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
                                        "REGISTER NOW",
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
                          margin: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Already have an account? ",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
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
                            Icon(
                              Icons.security,
                              color: Colors.white54,
                              size: 12,
                            ),
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
    bool isPassword = false,
    VoidCallback? onToggleVisibility,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return SizedBox(
      height: maxLength != null
          ? 68
          : 48, // Accommodate counter if maxLength is set
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        style: const TextStyle(color: Colors.black87, fontSize: 14),
        decoration: InputDecoration(
          counterText: "", // Hide the default counter text
          filled: true,
          fillColor: Colors.white,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.black45, size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.black38,
                    size: 20,
                  ),
                  onPressed: onToggleVisibility,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildPdfUploadField() {
    final hasFile = _verificationDocName != null;
    return InkWell(
      onTap: _pickVerificationPdf,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasFile ? const Color(0xFF00C853) : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasFile
                  ? Icons.picture_as_pdf_rounded
                  : Icons.upload_file_rounded,
              color: hasFile ? const Color(0xFF2E7D32) : Colors.black45,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasFile
                    ? _verificationDocName!
                    : 'Upload verification document PDF',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hasFile ? Colors.black87 : Colors.black38,
                  fontSize: 14,
                  fontWeight: hasFile ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Text(
              hasFile ? 'Change' : 'PDF',
              style: const TextStyle(
                color: Color(0xFF2E7D32),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
