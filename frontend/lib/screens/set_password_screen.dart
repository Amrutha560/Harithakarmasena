import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SetPasswordScreen extends StatefulWidget {
  final String token;

  const SetPasswordScreen({super.key, required this.token});

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final ApiService _apiService = ApiService();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;

  Future<void> _submit() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (widget.token.isEmpty) {
      _showMessage('Password setup link is missing a token', Colors.redAccent);
      return;
    }
    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters', Colors.orange);
      return;
    }
    if (password != confirm) {
      _showMessage('Passwords do not match', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    final result = await _apiService.setPassword(widget.token, password);
    if (!mounted) return;
    setState(() => _isLoading = false);

    final message = result['message'] ?? 'Unable to set password';
    if (message.toString().toLowerCase().contains('success')) {
      _showMessage(message, const Color(0xFF2E7D32));
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      _showMessage(message, Colors.redAccent);
    }
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      body: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_reset_rounded, color: Color(0xFF2E7D32), size: 48),
              const SizedBox(height: 20),
              const Text('Set Your Password', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E))),
              const SizedBox(height: 8),
              const Text('Create a password for your approved account.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black45)),
              const SizedBox(height: 28),
              _passwordField('New password', _passwordController),
              const SizedBox(height: 16),
              _passwordField('Confirm password', _confirmController),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), minimumSize: const Size(double.infinity, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Set Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passwordField(String hint, TextEditingController controller) {
    return TextField(
      controller: controller,
      obscureText: _obscure,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}
