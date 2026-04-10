import 'package:flutter/material.dart';
import 'register_screen.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final ApiService apiService = ApiService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  void _login() async {
    final username = _usernameController.text.trim().toLowerCase();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      _showMsg('Please enter both username and password', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      Map<String, dynamic>? result;
      String currentRole = 'resident';

      // 1. Try resident login with raw username
      result = await apiService.login('resident/login', username, password);

      // 2. If resident login fails (no token), try staff login
      if (result['token'] == null) {
        result = await apiService.login('staff/login', username, password);
        currentRole = 'staff';
      }

      // 3. If staff login fails, try admin login
      if (result['token'] == null) {
        result = await apiService.login('admin/login', username, password);
        currentRole = 'admin';
      }

      if (!mounted) return;

      // Ensure that we successfully retrieved a token
      if (result['token'] != null) {
        await apiService.saveToken(result['token'], currentRole);
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
        _showMsg(result['message'] ?? 'Invalid credentials. Please try again.', Colors.redAccent);
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
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF1FAF63),
              Color(0xFF6EDC44),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 40),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
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
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.eco,
                      color: Colors.white,
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
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    "Waste Management System",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),

                  const SizedBox(height: 40),

                  /// Username Field
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.15),
                      prefixIcon: const Icon(Icons.person, color: Colors.white),
                      hintText: "Username or mobile number",
                      hintStyle: const TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),

                  const SizedBox(height: 20),

                  /// Password Field
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.15),
                      prefixIcon: const Icon(Icons.lock, color: Colors.white),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      hintText: "Enter your password",
                      hintStyle: const TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),

                  const SizedBox(height: 10),

                  /// Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(color: Colors.white70),
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
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.green)
                          : const Text(
                              "Login",
                              style: TextStyle(
                                color: Colors.green,
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
                        style: TextStyle(color: Colors.white70),
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
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
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
                      color: Colors.white70,
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