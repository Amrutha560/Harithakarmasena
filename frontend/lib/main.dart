import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/resident_dashboard.dart';
import 'screens/staff_dashboard.dart';
import 'screens/welcome_screen.dart';
import 'screens/manage_users_screen.dart';
import 'screens/staff_management_screen.dart'; // Ensure this exists or rename from pending_staff_screen if that was the plan
import 'screens/scheduling_screen.dart';
import 'screens/admin_complaints_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/admin_resident_list_screen.dart';
import 'screens/change_password_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Harithakarmasena',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF6200EE),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF6200EE),
          secondary: Color(0xFF03DAC6),
          surface: Colors.white,
          onPrimary: Colors.white,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Color(0xFF6200EE),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6200EE),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 4,
            shadowColor: const Color(0xFF6200EE).withOpacity(0.4),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF6200EE), width: 2),
          ),
          prefixIconColor: const Color(0xFF6200EE),
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => WelcomeScreen(),
        '/welcome': (context) => WelcomeScreen(),
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/admin': (context) => AdminDashboard(),
        '/admin/users': (context) => const ManageUsersScreen(),
        '/admin/residents': (context) => const AdminResidentListScreen(),
        '/admin/staff': (context) => const StaffManagementScreen(),
        '/admin/scheduling': (context) => const SchedulingScreen(),
        '/admin/complaints': (context) => const AdminComplaintsScreen(),
        '/admin/reports': (context) => const ReportsScreen(),
        '/change-password': (context) => const ChangePasswordScreen(),
        '/resident': (context) => const ResidentDashboard(),
        '/staff': (context) => const StaffDashboard(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
