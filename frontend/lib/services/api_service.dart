import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class ApiService {
  // Dynamically get the base URL based on platform
  static String get baseUrl {
    if (kIsWeb) {
      // Safe fallback for web
      return 'http://localhost:5000/api';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:5000/api'; // Android Emulator default localhost IP
      }
    } catch (e) {
      // Ignore platform errors
    }
    return 'http://127.0.0.1:5000/api';
  }
  final storage = const FlutterSecureStorage();

  Future<void> saveToken(String token, String role) async {
    await storage.write(key: 'jwt_token', value: token);
    await storage.write(key: 'user_role', value: role);
  }

  Future<String?> getToken() async => await storage.read(key: 'jwt_token');
  Future<String?> getRole() async => await storage.read(key: 'user_role');

  Future<void> logout() async {
    await storage.delete(key: 'jwt_token');
    await storage.delete(key: 'user_role');
  }

  // ── Authentication ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String roleUrl, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/$roleUrl'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'message': 'Network error: Please check if server is running ($e)'};
    }
  }

  Future<Map<String, dynamic>> residentRegister(
      String name, String email, String password, {String? houseName, String? houseNumber, String? address, String? phone, String? wardNumber, String? wardId, String? routeId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/resident/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'houseName': houseName,
        'houseNumber': houseNumber,
        'address': address,
        'phoneNumber': phone,
        'wardNumber': wardNumber,
        'ward': wardId,
        'route': routeId
      }),
    );
    return jsonDecode(response.body);
  }

  // ── Admin Features ─────────────────────────────────────────────────────────

  Future<List<dynamic>> getUsers() async {
    final token = await getToken();
    final response = await http.get(Uri.parse('$baseUrl/admin/users'), headers: {'Authorization': 'Bearer $token'});
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  Future<List<dynamic>> getStaff() async {
    final token = await getToken();
    final response = await http.get(Uri.parse('$baseUrl/admin/staff'), headers: {'Authorization': 'Bearer $token'});
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  Future<List<dynamic>> getPendingStaff() async {
    final token = await getToken();
    final response = await http.get(Uri.parse('$baseUrl/admin/pending-staff'), headers: {'Authorization': 'Bearer $token'});
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  Future<Map<String, dynamic>> createCategory(String name, String description) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/admin/categories'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'name': name, 'description': description}),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> approveStaff(String id) async {
    final token = await getToken();
    final response = await http.put(Uri.parse('$baseUrl/admin/approve-staff/$id'), headers: {'Authorization': 'Bearer $token'});
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> createStaff(String name, String email, String password, {String? wardNumber, String? wardId, String? routeId, String? phoneNumber, String? address, String? houseName, String? houseNumber}) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/staff/create'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'wardNumber': wardNumber,
        'ward': wardId,
        'route': routeId,
        'phoneNumber': phoneNumber,
        'houseName': houseName,
        'houseNumber': houseNumber,
        'address': address
      }),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> updateUser(String id, Map<String, dynamic> data) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/admin/user/$id'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> deleteUser(String id) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/admin/user/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getCategories() async {
    final token = await getToken();
    final response = await http.get(Uri.parse('$baseUrl/admin/categories'), headers: {'Authorization': 'Bearer $token'});
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  Future<Map<String, dynamic>> createSchedule(Map<String, dynamic> data) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/admin/schedules'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getMonthlySchedules({String? ward, int? month, int? year}) async {
    final token = await getToken();
    final params = <String, String>{};
    if (ward != null) params['ward'] = ward;
    if (month != null) params['month'] = month.toString();
    if (year != null) params['year'] = year.toString();
    final uri = Uri.parse('$baseUrl/admin/schedules/monthly').replace(queryParameters: params);
    final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  Future<List<dynamic>> getAllSchedules() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/admin/schedules'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  Future<Map<String, dynamic>> getAdminStats() async {
    final token = await getToken();
    final response = await http.get(Uri.parse('$baseUrl/admin/reports/stats'), headers: {'Authorization': 'Bearer $token'});
    return response.statusCode == 200 ? jsonDecode(response.body) : {};
  }

  Future<List<dynamic>> getAllComplaints() async {
    final token = await getToken();
    final response = await http.get(Uri.parse('$baseUrl/admin/complaints'), headers: {'Authorization': 'Bearer $token'});
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  Future<Map<String, dynamic>> updateComplaint(String id, String status, String remarks) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/admin/complaints/$id'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'status': status, 'remarks': remarks}),
    );
    return jsonDecode(response.body);
  }

  // ── Staff Features ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStaffDashboard() async {
    final token = await getToken();
    final response = await http.get(Uri.parse('$baseUrl/staff/dashboard'), headers: {'Authorization': 'Bearer $token'});
    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getResidentsByWard(String wardNumber) async {
    final token = await getToken();
    final response = await http.get(Uri.parse('$baseUrl/staff/residents/$wardNumber'), headers: {'Authorization': 'Bearer $token'});
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  Future<Map<String, dynamic>> markCollection(Map<String, dynamic> data) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/staff/mark-collection'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> recordPayment(Map<String, dynamic> data) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/staff/record-payment'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> getDailyReport() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/staff/daily-report'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  // ── Ward & Route Features ───────────────────────────────────────────────

  Future<List<dynamic>> getWards() async {
    final token = await getToken();
    final response = await http.get(Uri.parse('$baseUrl/admin/wards'), headers: {'Authorization': 'Bearer $token'});
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  Future<Map<String, dynamic>> createWard(Map<String, dynamic> data) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/admin/wards'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> deleteWard(String id) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/admin/wards/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getRoutes({String? wardId}) async {
    final token = await getToken();
    String url = '$baseUrl/admin/routes';
    if (wardId != null) url += '?ward=$wardId';
    final response = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'});
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  Future<Map<String, dynamic>> deleteRoute(String id) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/admin/routes/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> updateRoute(String id, Map<String, dynamic> data) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/admin/routes/$id'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> createRoute(Map<String, dynamic> data) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/admin/routes'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> assignRouteToStaff(String routeId, String staffId) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/admin/routes/$routeId/assign'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'staffId': staffId}),
    );
    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getHousesInRoute(String routeId) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/admin/routes/$routeId/houses'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  Future<Map<String, dynamic>> addHousesToRoute(String routeId, List<Map<String, dynamic>> houses) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/admin/routes/$routeId/houses'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'houses': houses}),
    );
    return jsonDecode(response.body);
  }

  Future<bool> deleteHouse(String houseId) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/admin/houses/$houseId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200;
  }

  // ── Resident Features ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getResidentDashboard() async {
    final token = await getToken();
    final response = await http.get(Uri.parse('$baseUrl/resident/dashboard'), headers: {'Authorization': 'Bearer $token'});
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> fileComplaint(String description) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/resident/complaints'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'description': description}),
    );
    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getMyComplaints() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/resident/my-complaints'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  // ── Resident Wallet & Notifications ─────────────────────────────────────
  
  Future<Map<String, dynamic>> addWalletMoney(int amount) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/resident/wallet/add'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'amount': amount}),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> payFromWallet() async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/resident/wallet/pay'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getNotifications() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/resident/notifications'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  Future<Map<String, dynamic>> notifyWard(String wardNumber, {String? message}) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/staff/notify-ward'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'wardNumber': wardNumber, 'message': message}),
    );
    return jsonDecode(response.body);
  }
}
