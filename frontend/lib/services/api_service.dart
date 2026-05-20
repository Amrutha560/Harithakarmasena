import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
// import 'dart:io' show Platform; // Removed for web compatibility

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      final host = Uri.base.host.toLowerCase();

      // Flutter's debug web server runs on a random localhost port and does not
      // proxy /api, so local web debug should call the Node backend directly.
      if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
        return 'http://127.0.0.1:3000/api';
      }

      // Hosted/tunnel web builds use the same origin. The web server proxies
      // /api to Node, so mobile tunnel links work without LAN IPs.
      return '$origin/api';
    }
    // For physical mobile devices, use the local network IP of this computer instead of 10.0.2.2
    return 'http://192.168.137.1:3000/api';
  }

  final storage = const FlutterSecureStorage();

  String _dateOnly(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> saveToken(
    String token,
    String role, {
    bool forcePasswordChange = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setString('user_role', role);
    if (forcePasswordChange) {
      await prefs.setBool('force_password_change', true);
    } else {
      await prefs.remove('force_password_change');
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }

  Future<bool> mustChangePassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('force_password_change') ?? false;
  }

  Future<void> clearPasswordChangeRequirement() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('force_password_change');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_role');
    await prefs.remove('force_password_change');
  }

  Future<dynamic> httpGet(String endpoint) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load data: ${response.statusCode}');
    }
  }

  // ── Authentication ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(
    String roleUrl,
    String email,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/$roleUrl'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 12));
      return jsonDecode(response.body);
    } catch (e) {
      return {
        'message': 'Network error: Please check if server is running ($e)',
      };
    }
  }

  Future<Map<String, dynamic>> forgotPassword({
    required String role,
    required String identifier,
    required String newPassword,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/forgot-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'role': role,
              'identifier': identifier,
              'newPassword': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 12));
      return jsonDecode(response.body);
    } catch (e) {
      return {
        'message': 'Network error: Please check if server is running ($e)',
      };
    }
  }

  Future<Map<String, dynamic>> residentRegister({
    required String firstName,
    required String lastName,
    required String email,
    required String? address,
    required String? phone,
    required String? houseNumber,
    required String? wardId,
    required String? routeId,
    required String? district,
    required String? lsgiType,
    required String? lsgiName,
    required String? wardName,
    Uint8List? verificationDocBytes,
    String? verificationDocName,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/auth/resident/register'),
      );

      // Add text fields
      request.fields['firstName'] = firstName;
      request.fields['lastName'] = lastName;
      request.fields['email'] = email;
      request.fields['address'] = address ?? '';
      request.fields['phoneNumber'] = phone ?? '';
      request.fields['houseNumber'] = houseNumber ?? '';
      request.fields['ward'] = wardId ?? '';
      request.fields['route'] = routeId ?? '';
      request.fields['district'] = district ?? '';
      request.fields['lsgiType'] = lsgiType ?? '';
      request.fields['lsgiName'] = lsgiName ?? '';
      request.fields['wardName'] = wardName ?? '';

      if (verificationDocBytes != null && verificationDocName != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'verificationDoc',
            verificationDocBytes,
            filename: verificationDocName,
          ),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      print(
        '[DEBUG] residentRegister response: ${response.statusCode} - ${response.body}',
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('[DEBUG] residentRegister error: $e');
      return {'message': 'Network error: $e'};
    }
  }

  // ── Admin Features ─────────────────────────────────────────────────────────

  Future<List<dynamic>> getUsers() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/admin/users'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  Future<List<dynamic>> getStaff() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/admin/staff'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  Future<List<dynamic>> getPendingStaff() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/admin/pending-staff'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  Future<Map<String, dynamic>> createCategory(
    String name,
    String description,
  ) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/admin/categories'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'name': name, 'description': description}),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> approveUser(String id) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/admin/approve-user/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> resendResidentCredentials(String id) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/admin/resend-resident-credentials/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> createStaff(
    String name,
    String email,
    String password, {
    String? wardNumber,
    String? wardId,
    String? routeId,
    String? phoneNumber,
    String? address,
    String? houseName,
    String? houseNumber,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/staff/create'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'wardNumber': wardNumber,
        'wardId': wardId,
        'routeId': routeId,
        'phoneNumber': phoneNumber,
        'houseName': houseName,
        'houseNumber': houseNumber,
        'address': address,
      }),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> setPassword(
    String token,
    String newPassword,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/set-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'newPassword': newPassword}),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> updateUser(
    String id,
    Map<String, dynamic> data,
  ) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/admin/user/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
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
    final response = await http.get(
      Uri.parse('$baseUrl/admin/categories'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  Future<Map<String, dynamic>> getMonthlyWasteTypes({
    required int month,
    required int year,
  }) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/admin/monthly-waste-types').replace(
      queryParameters: {'month': month.toString(), 'year': year.toString()},
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : {};
  }

  Future<Map<String, dynamic>> saveMonthlyWasteTypes({
    required int month,
    required int year,
    required List<String> wasteTypes,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/admin/monthly-waste-types'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'month': month,
        'year': year,
        'wasteTypes': wasteTypes,
      }),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> createSchedule(Map<String, dynamic> data) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/admin/schedules'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getMonthlySchedules({
    String? ward,
    int? month,
    int? year,
  }) async {
    final token = await getToken();
    final params = <String, String>{};
    if (ward != null) params['ward'] = ward;
    if (month != null) params['month'] = month.toString();
    if (year != null) params['year'] = year.toString();
    final uri = Uri.parse(
      '$baseUrl/admin/schedules/monthly',
    ).replace(queryParameters: params);
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
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
    final response = await http.get(
      Uri.parse('$baseUrl/admin/reports/stats'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : {};
  }

  Future<List<dynamic>> getRouteCompletions() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/admin/route-completions'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  Future<List<dynamic>> getCollectionReports() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/admin/reports/collections'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  Future<List<dynamic>> getAllComplaints() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/admin/complaints'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  Future<Map<String, dynamic>> updateComplaint(
    String id,
    String status,
    String remarks,
  ) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/admin/complaints/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'status': status, 'remarks': remarks}),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> deleteComplaint(String id) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/admin/complaints/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getPaymentReports({
    String? ward,
    String? route,
    String? house,
    String? status,
    String? method,
  }) async {
    final token = await getToken();
    final params = <String, String>{};
    if (ward != null && ward.isNotEmpty) params['ward'] = ward;
    if (route != null && route.isNotEmpty) params['route'] = route;
    if (house != null && house.isNotEmpty) params['house'] = house;
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (method != null && method.isNotEmpty) params['method'] = method;
    final uri = Uri.parse(
      '$baseUrl/admin/reports/payments',
    ).replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  Future<List<dynamic>> getAssignmentReports({
    String? ward,
    String? route,
    String? house,
    String? paymentStatus,
    String? collectionStatus,
    String? date,
  }) async {
    final token = await getToken();
    final params = <String, String>{};
    if (ward != null && ward.isNotEmpty) params['ward'] = ward;
    if (route != null && route.isNotEmpty) params['route'] = route;
    if (house != null && house.isNotEmpty) params['house'] = house;
    if (paymentStatus != null && paymentStatus.isNotEmpty) {
      params['paymentStatus'] = paymentStatus;
    }
    if (collectionStatus != null && collectionStatus.isNotEmpty) {
      params['collectionStatus'] = collectionStatus;
    }
    if (date != null && date.isNotEmpty) params['date'] = date;
    final uri = Uri.parse(
      '$baseUrl/admin/reports/assignments',
    ).replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  // ── Staff Features ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStaffDashboard() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/staff/dashboard'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getResidentsByWard(String wardNumber) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/staff/residents/$wardNumber'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  Future<Map<String, dynamic>> markCollection(Map<String, dynamic> data) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/staff/mark-collection'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> markRouteVisited(
    String routeId,
    String date,
  ) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/staff/routes/$routeId/visit'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'date': date}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Could not mark route visit date');
    }
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> unmarkRouteVisited(
    String routeId,
    String date,
  ) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/staff/routes/$routeId/unvisit'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'date': date}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Could not remove route visit date');
    }
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> completeRoute(
    String routeId,
    String date,
  ) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/staff/routes/$routeId/complete'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'date': date}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Could not complete route');
    }
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> notifyResident(Map<String, dynamic> data) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/staff/notify-resident'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> recordPayment(Map<String, dynamic> data) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/staff/record-payment'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
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

  Future<List<dynamic>> getAssignedResidents() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/staff/assigned-residents'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  // ── Ward & Route Features ───────────────────────────────────────────────

  Future<List<dynamic>> getUnassignedResidents(String wardId) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/admin/residents/unassigned/$wardId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  Future<List<dynamic>> getWards() async {
    final token = await getToken();
    final headers = <String, String>{};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final response = await http.get(
      Uri.parse('$baseUrl/admin/wards'),
      headers: headers,
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  Future<Map<String, dynamic>> createWard(Map<String, dynamic> data) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/admin/wards'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
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

  Future<Map<String, dynamic>> autoAssignWardRoutes(String wardId) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/admin/wards/$wardId/auto-assign-routes'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> scheduleWardRange(
    String wardId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/admin/wards/$wardId/schedule'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'startDate': _dateOnly(startDate),
        'endDate': _dateOnly(endDate),
      }),
    );
    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getRoutes({String? wardId}) async {
    final token = await getToken();
    final headers = <String, String>{};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    String url = '$baseUrl/admin/routes';
    if (wardId != null) url += '?ward=$wardId';
    final response = await http.get(Uri.parse(url), headers: headers);
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

  Future<Map<String, dynamic>> updateRoute(
    String id,
    Map<String, dynamic> data,
  ) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/admin/routes/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> createRoute(Map<String, dynamic> data) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/admin/routes'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> assignRouteToStaff(
    String routeId,
    String staffId,
  ) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/admin/routes/$routeId/assign'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
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

  Future<Map<String, dynamic>> addHousesToRoute(
    String routeId,
    List<Map<String, dynamic>> houses, {
    bool preserveRoute = false,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/admin/routes/$routeId/houses'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'houses': houses, 'preserveRoute': preserveRoute}),
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

  Future<Map<String, dynamic>> saveRouteSchedule(
    String routeId,
    String date,
    List<Map<String, dynamic>> assignments, {
    String? commonTime,
    List<String>? commonWasteTypes,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/admin/routes/$routeId/schedules'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'date': date,
        'assignments': assignments,
        'commonTime': commonTime,
        'commonWasteTypes': commonWasteTypes,
      }),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> getRouteSchedule(
    String routeId,
    String date,
  ) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/admin/routes/$routeId/schedules/$date'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : {};
  }

  Future<List<dynamic>> getAllRouteSchedules(String routeId) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/admin/routes/$routeId/schedules'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  // ── Resident Features ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getResidentDashboard() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/resident/dashboard'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> updateResidentProfile(
    Map<String, dynamic> data,
  ) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/resident/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> fileComplaint(String description) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/resident/complaints'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
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

  Future<List<dynamic>> getCollectionHistory() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/resident/my-collection-history'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  Future<List<dynamic>> getMyPayments() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/resident/my-payments'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  Future<Map<String, dynamic>> getPaymentReceipt(String paymentId) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/resident/payments/$paymentId/receipt'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : {};
  }

  // ── Resident Wallet & Notifications ─────────────────────────────────────

  Future<Map<String, dynamic>> addWalletMoney(int amount) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/resident/wallet/add'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'amount': amount}),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> payFromWallet() async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/resident/wallet/pay'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
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

  Future<Map<String, dynamic>> respondToCollection(
    String responseValue, {
    String? date,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/resident/collection-response'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'response': responseValue,
        if (date != null) 'date': date,
      }),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> choosePaymentMode({
    required String assignmentId,
    required String date,
    required String mode,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/resident/payment-choice'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'assignmentId': assignmentId,
        'date': date,
        'mode': mode,
      }),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> submitCollectionFeedback(String status) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/resident/collection-feedback'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'status': status}),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> notifyWard(
    String wardNumber, {
    String? message,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/staff/notify-ward'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'wardNumber': wardNumber, 'message': message}),
    );
    return jsonDecode(response.body);
  }

  // ── Razorpay Payments ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> createRazorpayOrder(String scheduleId) async {
    final token = await getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payments/create-order'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'amount': 50, 'scheduleId': scheduleId}),
      );

      print('[DEBUG] Create Order Response: ${response.body}');

      if (response.statusCode != 200) {
        throw 'Failed to create order: ${response.statusCode}';
      }

      return jsonDecode(response.body);
    } catch (e) {
      print('[DEBUG] createRazorpayOrder Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyRazorpayPayment(
    Map<String, dynamic> paymentData,
  ) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/payments/verify-payment'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(paymentData),
    );
    return jsonDecode(response.body);
  }

  // ── Account & Support ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> changePassword(
    String oldPassword,
    String newPassword,
  ) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/change-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      }),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> submitFeedback(
    String subject,
    String message,
  ) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/feedback'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'subject': subject, 'message': message}),
    );
    return jsonDecode(response.body);
  }
}
