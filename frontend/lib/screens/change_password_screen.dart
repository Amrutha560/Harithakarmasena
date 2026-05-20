import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  final bool forceChange;

  const ChangePasswordScreen({super.key, this.forceChange = false});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  void _updatePassword() async {
    final oldP = _oldPasswordController.text;
    final newP = _newPasswordController.text;
    final confP = _confirmPasswordController.text;

    if (oldP.isEmpty || newP.isEmpty || confP.isEmpty) {
      _showMsg('Please fill all fields', Colors.orange);
      return;
    }
    if (newP != confP) {
      _showMsg('New passwords do not match', Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await _apiService.changePassword(oldP, newP);
      if (res['message'].toString().contains('updated')) {
        await _apiService.clearPasswordChangeRequirement();
        _showMsg('Password updated successfully!', Colors.green);
        if (!mounted) return;
        final role = await _apiService.getRole();
        if (!mounted) return;
        if (role == 'staff') {
          Navigator.pushReplacementNamed(context, '/staff');
        } else if (role == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin');
        } else {
          Navigator.pushReplacementNamed(context, '/resident');
        }
      } else {
        _showMsg(res['message'] ?? 'Update failed', Colors.redAccent);
      }
    } catch (e) {
      _showMsg('Error updating password', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMsg(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: !widget.forceChange,
        leading: widget.forceChange
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
        title: const Text(
          'Change Password',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                const Icon(
                  Icons.lock_reset_rounded,
                  size: 68,
                  color: Color(0xFF2E7D32),
                ),
                const SizedBox(height: 28),
                if (widget.forceChange) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'You are using a temporary WhatsApp password. Please set a new password to continue.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF1B5E20),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                _field(
                  _oldPasswordController,
                  'Old/Temporary Password',
                  Icons.lock_outline,
                  _obscureOldPassword,
                  () {
                    setState(() => _obscureOldPassword = !_obscureOldPassword);
                  },
                ),
                const SizedBox(height: 14),
                _field(
                  _newPasswordController,
                  'New Password',
                  Icons.vpn_key_outlined,
                  _obscureNewPassword,
                  () {
                    setState(() => _obscureNewPassword = !_obscureNewPassword);
                  },
                ),
                const SizedBox(height: 14),
                _field(
                  _confirmPasswordController,
                  'Confirm Password',
                  Icons.check_circle_outline,
                  _obscureConfirmPassword,
                  () {
                    setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    );
                  },
                ),
                const SizedBox(height: 34),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updatePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'UPDATE PASSWORD',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon,
    bool obscureText,
    VoidCallback onToggleVisibility,
  ) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF2E7D32)),
        prefixIconConstraints: const BoxConstraints(minWidth: 44),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: const Color(0xFF2E7D32),
          ),
          onPressed: onToggleVisibility,
          tooltip: obscureText ? 'Show password' : 'Hide password',
        ),
        suffixIconConstraints: const BoxConstraints(minWidth: 44),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2E7D32)),
        ),
      ),
    );
  }
}
