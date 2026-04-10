import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SchedulingScreen extends StatefulWidget {
  const SchedulingScreen({super.key});

  @override
  _SchedulingScreenState createState() => _SchedulingScreenState();
}

class _SchedulingScreenState extends State<SchedulingScreen> {
  final ApiService _apiService = ApiService();
  final _categoryNameController = TextEditingController();
  final _areaController = TextEditingController();
  final _notesController = TextEditingController();
  
  List<dynamic> _categories = [];
  bool _isLoading = true;
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  bool _isMonthlyPlan = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final cats = await _apiService.getCategories();
    setState(() {
      _categories = cats;
      _isLoading = false;
    });
  }

  Future<void> _addCategory() async {
    if (_categoryNameController.text.isEmpty) return;
    await _apiService.createCategory(_categoryNameController.text, 'Waste collection');
    _categoryNameController.clear();
    _fetchData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Category Added'), backgroundColor: Color(0xFF00E676)),
    );
  }

  final List<String> _months = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ];

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
        title: const Text('Scheduling & Categories', style: TextStyle(color: Color(0xFF1A1C1E), fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Manage Waste Categories'),
                  const SizedBox(height: 16),
                  _buildAddCategoryRow(),
                  const SizedBox(height: 24),
                  _buildCategoryList(),
                  const SizedBox(height: 48),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('Monthly Waste Schedule'),
                      Switch(
                        value: _isMonthlyPlan,
                        onChanged: (v) => setState(() => _isMonthlyPlan = v),
                        activeColor: const Color(0xFF2E7D32),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildScheduleForm(),
                  const SizedBox(height: 40),
                  _buildSectionTitle('Active Schedules'),
                  const SizedBox(height: 16),
                  _buildSchedulesList(),
                ],
              ),
            ),
    );
  }

  Widget _buildSchedulesList() {
    return FutureBuilder<List<dynamic>>(
      future: _apiService.getMonthlySchedules(
        month: _isMonthlyPlan ? _selectedMonth : null,
        year: _isMonthlyPlan ? _selectedYear : null,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)));
        final schedules = snapshot.data!;
        if (schedules.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
            ),
            child: const Center(child: Text('No schedules found for this period', style: TextStyle(color: Colors.black26))),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: schedules.length,
          itemBuilder: (context, index) {
            final s = schedules[index];
            final cat = s['category']?['name'] ?? 'Waste';
            final date = s['date'] != null ? DateTime.tryParse(s['date']) : null;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                   Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.event_note_outlined, color: Color(0xFF2E7D32), size: 18),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cat, style: const TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.bold)),
                        Text('Ward ${s['wardNumber']}', style: const TextStyle(color: Colors.black38, fontSize: 12)),
                      ],
                    ),
                  ),
                  Text(
                    date != null ? '${date.day} ${_months[date.month - 1].substring(0, 3)}' : 'Monthly',
                    style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2E7D32),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildAddCategoryRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _categoryNameController,
            style: const TextStyle(color: Color(0xFF1A1C1E)),
            decoration: InputDecoration(
              hintText: 'New Category (e.g. Plastic)',
              hintStyle: const TextStyle(color: Colors.black26, fontSize: 14),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withOpacity(0.05))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withOpacity(0.05))),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _addCategory,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryList() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: _categories.isEmpty
          ? const Center(child: Text('No categories found', style: TextStyle(color: Colors.black26)))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _categories.length,
              separatorBuilder: (context, index) => const Divider(color: Colors.black12),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.category_outlined, color: Color(0xFF2E7D32), size: 18),
                  title: Text(cat['name'], style: const TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.bold)),
                );
              },
            ),
    );
  }

  Widget _buildScheduleForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            dropdownColor: Colors.white,
            style: const TextStyle(color: Color(0xFF1A1C1E)),
            decoration: _formInputDecoration('Waste Type', Icons.type_specimen_outlined),
            items: _categories.map((c) => DropdownMenuItem<String>(
              value: c['_id'],
              child: Text(c['name']),
            )).toList(),
            onChanged: (v) => setState(() => _selectedCategory = v),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _areaController,
            style: const TextStyle(color: Color(0xFF1A1C1E)),
            decoration: _formInputDecoration('Ward Number', Icons.location_on_outlined),
          ),
          const SizedBox(height: 20),
          
          if (_isMonthlyPlan) ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedMonth,
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Color(0xFF1A1C1E)),
                    decoration: _formInputDecoration('Month', Icons.calendar_month),
                    items: List.generate(12, (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text(_months[index]),
                    )),
                    onChanged: (v) => setState(() => _selectedMonth = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedYear,
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Color(0xFF1A1C1E)),
                    decoration: _formInputDecoration('Year', Icons.numbers),
                    items: [2024, 2025, 2026].map((y) => DropdownMenuItem(
                      value: y,
                      child: Text(y.toString()),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedYear = v!),
                  ),
                ),
              ],
            ),
          ] else ...[
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Color(0xFF2E7D32),
                        onPrimary: Colors.white,
                        surface: Colors.white,
                        onSurface: Color(0xFF1A1C1E),
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              child: InputDecorator(
                decoration: _formInputDecoration('Select Date', Icons.calendar_today_outlined),
                child: Text(
                  "${_selectedDate.toLocal()}".split(' ')[0],
                  style: const TextStyle(color: Color(0xFF1A1C1E), fontSize: 14),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 20),
          TextField(
            controller: _notesController,
            style: const TextStyle(color: Color(0xFF1A1C1E)),
            decoration: _formInputDecoration('Special Notes (e.g. Non-biodegradable)', Icons.note_alt_outlined),
          ),
          
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _saveSchedule,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text('PUBLISH SCHEDULE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSchedule() async {
    if (_selectedCategory == null || _areaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }
    
    final payload = {
      'date': _selectedDate.toIso8601String(),
      'month': _isMonthlyPlan ? _selectedMonth : _selectedDate.month,
      'year': _isMonthlyPlan ? _selectedYear : _selectedDate.year,
      'wardNumber': _areaController.text,
      'category': _selectedCategory,
      'notes': _notesController.text,
    };

    await _apiService.createSchedule(payload);
    setState(() {
      _notesController.clear();
      _areaController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Schedule published successfully'), backgroundColor: Color(0xFF00E676)),
    );
  }

  InputDecoration _formInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black38, fontSize: 13),
      prefixIcon: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAF9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1)),
    );
  }
}
