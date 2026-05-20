import 'package:flutter/material.dart';
import 'register_screen.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final ApiService apiService = ApiService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _selectedRole = 'resident';

  @override
  void initState() {
    super.initState();
    apiService.logout();
  }

  void _login() async {
    final username = _usernameController.text.trim().toLowerCase();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      _showMsg('Please enter both username and password', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await apiService.login(
        '$_selectedRole/login',
        username,
        password,
      );
      final currentRole = result['user']?['role'] ?? _selectedRole;

      if (!mounted) return;

      // Ensure that we successfully retrieved a token
      if (result != null && result['token'] != null) {
        await apiService.saveToken(result['token'], currentRole);
        if (!mounted) return;
        _showMsg('Login successful!', Colors.green);

        // Navigate based on resolved role
        if (currentRole == 'resident') {
          Navigator.pushReplacementNamed(context, '/resident');
        } else if (currentRole == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin');
        } else if (currentRole == 'staff') {
          Navigator.pushReplacementNamed(context, '/staff');
        }
      } else {
        _showMsg(
          result?['message'] ?? 'Invalid credentials. Please try again.',
          Colors.redAccent,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showMsg('Connection error. Is the backend running?', Colors.redAccent);
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

  void _showForgotPasswordDialog() {
    final identifierController = TextEditingController(
      text: _usernameController.text.trim(),
    );
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureNewPassword = true;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              final identifier = identifierController.text.trim();
              final newPassword = newPasswordController.text;
              final confirmPassword = confirmPasswordController.text;

              if (identifier.isEmpty ||
                  newPassword.isEmpty ||
                  confirmPassword.isEmpty) {
                _showMsg(
                  'Please fill all password reset fields',
                  Colors.orange,
                );
                return;
              }
              if (newPassword.length < 6) {
                _showMsg(
                  'Password must be at least 6 characters',
                  Colors.orange,
                );
                return;
              }
              if (newPassword != confirmPassword) {
                _showMsg('Passwords do not match', Colors.orange);
                return;
              }

              setDialogState(() => isSubmitting = true);
              final result = await apiService.forgotPassword(
                role: _selectedRole,
                identifier: identifier,
                newPassword: newPassword,
              );
              if (!mounted) return;
              setDialogState(() => isSubmitting = false);

              final message =
                  result['message']?.toString() ?? 'Password reset failed';
              if (message.toLowerCase().contains('success')) {
                Navigator.pop(dialogContext);
                _passwordController.text = newPassword;
                _showMsg(message, Colors.green);
              } else {
                _showMsg(message, Colors.redAccent);
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Forgot Password',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Reset password for ${_selectedRole[0].toUpperCase()}${_selectedRole.substring(1)} account',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: identifierController,
                      decoration: InputDecoration(
                        labelText: _selectedRole == 'resident'
                            ? 'House number, mobile, or name'
                            : 'Email, phone, or name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNewPassword,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(
                            () => obscureNewPassword = !obscureNewPassword,
                          ),
                          icon: Icon(
                            obscureNewPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureNewPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: (_) => submit(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Reset Password'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      identifierController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE6F2E9)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  /// Leaf Icon Circle
                  Container(
                    height: 90,
                    width: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F6EA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.eco,
                      color: Color(0xFF2E7D32),
                      size: 45,
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// Title
                  const Text(
                    "Harithakarma Sena",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1C1E),
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    "Waste Management System",
                    style: TextStyle(fontSize: 14, color: Color(0xFF6F7A72)),
                  ),

                  const SizedBox(height: 40),

                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'resident',
                        label: Text('Resident'),
                        icon: Icon(Icons.home_rounded),
                      ),
                      ButtonSegment(
                        value: 'staff',
                        label: Text('Staff'),
                        icon: Icon(Icons.badge_rounded),
                      ),
                      ButtonSegment(
                        value: 'admin',
                        label: Text('Admin'),
                        icon: Icon(Icons.admin_panel_settings_rounded),
                      ),
                    ],
                    selected: {_selectedRole},
                    onSelectionChanged: (selection) {
                      setState(() => _selectedRole = selection.first);
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? Colors.white
                            : const Color(0xFF2E7D32),
                      ),
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? const Color(0xFF2E7D32)
                            : Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// Username Field
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF7FAF8),
                      prefixIcon: const Icon(
                        Icons.person,
                        color: Color(0xFF2E7D32),
                      ),
                      hintText: _selectedRole == 'admin'
                          ? "Admin email"
                          : _selectedRole == 'staff'
                          ? "Staff email, phone, or name"
                          : "House number, mobile, or name",
                      hintStyle: const TextStyle(color: Color(0xFF8A928D)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Color(0xFF1A1C1E)),
                  ),

                  const SizedBox(height: 20),

                  /// Password Field
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF7FAF8),
                      prefixIcon: const Icon(
                        Icons.lock,
                        color: Color(0xFF2E7D32),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: const Color(0xFF2E7D32),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      hintText: "Enter your password",
                      hintStyle: const TextStyle(color: Color(0xFF8A928D)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Color(0xFF1A1C1E)),
                  ),

                  const SizedBox(height: 10),

                  /// Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(color: Color(0xFF2E7D32)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  /// Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Login",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  /// Register Text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account? ",
                        style: TextStyle(color: Color(0xFF6F7A72)),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          "Register as resident",
                          style: TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "CLEAN GREEN FUTURE",
                    style: TextStyle(
                      letterSpacing: 2,
                      fontSize: 10,
                      color: Color(0xFF2E7D32),
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
}
