import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'role_service.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/home_page.dart';

/// Route guard to protect routes based on user role
class RouteGuard {
  static final RoleService _roleService = RoleService();
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if user has required role and route accordingly
  static Future<Widget> guardRoute({
    required BuildContext context,
    required Widget adminWidget,
    required Widget clientWidget,
    bool requireAdmin = false,
    bool requireClient = false,
  }) async {
    final user = _auth.currentUser;
    
    if (user == null) {
      // Not logged in - this shouldn't happen due to AuthWrapper
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final role = await _roleService.getUserRole(user.uid);
    final isAdmin = role.toLowerCase().trim() == 'admin';

    // If admin is required and user is not admin, redirect to client home
    if (requireAdmin && !isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⛔ Access Denied: Admin privileges required'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      });
      return const HomePage();
    }

    // If client is required and user is admin, redirect to admin dashboard
    if (requireClient && isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ℹ️ Redirected to Admin Dashboard'),
            backgroundColor: Colors.blue,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
          (route) => false,
        );
      });
      return const AdminDashboard();
    }

    // Return appropriate widget based on role
    return isAdmin ? adminWidget : clientWidget;
  }

  /// Check if current user is admin
  static Future<bool> isAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    return await _roleService.isAdmin(user.uid);
  }

  /// Check if current user is client
  static Future<bool> isClient() async {
    final user = _auth.currentUser;
    if (user == null) return true; // Default to client
    return await _roleService.isClient(user.uid);
  }

  /// Redirect to appropriate home based on role
  static Future<void> redirectToHome(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      return;
    }

    final isAdminUser = await isAdmin();
    
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => isAdminUser ? const AdminDashboard() : const HomePage(),
        ),
        (route) => false,
      );
    }
  }
}
