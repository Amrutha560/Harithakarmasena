import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'route_management_screen.dart';

class WardManagementScreen extends StatefulWidget {
  final bool embedded;

  const WardManagementScreen({super.key, this.embedded = false});

  @override
  _WardManagementScreenState createState() => _WardManagementScreenState();
}

class _WardManagementScreenState extends State<WardManagementScreen> {
  final ApiService _apiService = ApiService();
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  List<dynamic> _wards = [];
  bool _isLoading = true;
  dynamic _selectedWard;

  @override
  void initState() {
    super.initState();
    _fetchWards();
  }

  Future<void> _fetchWards() async {
    final wards = await _apiService.getWards();
    setState(() {
      _wards = wards;
      if (_selectedWard != null && !_wards.any((ward) => ward['_id'] == _selectedWard['_id'])) {
        _selectedWard = null;
      }
      _isLoading = false;
    });
  }

  void _addWard() async {
    if (_nameController.text.isEmpty || _numberController.text.isEmpty) return;
    await _apiService.createWard({
      'name': _nameController.text,
      'wardNumber': _numberController.text,
    });
    _nameController.clear();
    _numberController.clear();
    _fetchWards();
  }

  void _deleteWard(String id) async {
    final res = await _apiService.deleteWard(id);
    if (res['message']?.contains('success') == true) {
      _fetchWards();
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2E7D32);

    if (widget.embedded && _selectedWard != null) {
      return RouteManagementScreen(
        ward: _selectedWard,
        embedded: true,
        onBack: () => setState(() => _selectedWard = null),
      );
    }

    final content = _isLoading
        ? const Center(child: CircularProgressIndicator(color: primaryColor))
        : Padding(
            padding: EdgeInsets.all(widget.embedded ? 24 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.embedded) ...[
                  const Text('Wards & Routes', style: TextStyle(color: Color(0xFF1A1C1E), fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Create wards and open route management without leaving the admin workspace.', style: TextStyle(color: Colors.black45, fontSize: 15)),
                  const SizedBox(height: 22),
                ],
                _buildAddForm(primaryColor),
                const SizedBox(height: 22),
                Expanded(
                  child: ListView.builder(
                    itemCount: _wards.length,
                    itemBuilder: (context, index) {
                      final ward = _wards[index];
                      return _wardCard(ward, primaryColor);
                    },
                  ),
                ),
              ],
            ),
          );

    if (widget.embedded) {
      return Container(
        color: const Color(0xFFF8FAF9),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        title: const Text('Manage Wards', style: TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
      ),
      body: content,
    );
  }

  Widget _buildAddForm(Color primary) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withOpacity(0.05))),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _inputField('Ward Name', _nameController)),
              const SizedBox(width: 14),
              Expanded(child: _inputField('Ward Number', _numberController)),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _addWard,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              minimumSize: const Size(double.infinity, 34),
              padding: const EdgeInsets.symmetric(vertical: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Add Ward',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black45)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: label,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _wardCard(dynamic ward, Color primary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(ward['wardNumber']?.toString() ?? '', style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ward['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 17),
            onPressed: () => _deleteWard(ward['_id']),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios_rounded, color: primary, size: 15),
            onPressed: () {
              if (widget.embedded) {
                setState(() => _selectedWard = ward);
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => RouteManagementScreen(ward: ward)));
              }
            },
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
          ),
        ],
      ),
    );
  }
}
