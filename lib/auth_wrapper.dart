import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/role_service.dart';
import 'screens/get_started_page.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'screens/admin/admin_dashboard.dart';

/// AuthWrapper: Main navigation controller for the app
/// 
/// FLOW:
/// 1. App Start → AuthWrapper (set as home in main.dart)
/// 2. Check if first launch (onboarding not seen) → GetStartedPage
/// 3. GetStartedPage → LoginPage
/// 4. After successful login → Pop back to AuthWrapper
/// 5. AuthWrapper detects auth change and checks user role
/// 6. Routes based on role:
///    - role = 'admin' → AdminDashboard (ADMIN SIDE)
///    - role = 'client' → HomePage (CLIENT SIDE)
/// 
/// NAVIGATION SEPARATION:
/// - Admin pages (AdminDashboard, ManageProducts, etc.) ONLY navigate to admin routes
/// - Client pages (HomePage, ShopPage, Cart, etc.) ONLY navigate to client routes
/// - No cross-contamination between admin and client navigation
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isFirstLaunch = true;
  bool _isCheckingFirstLaunch = true;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
    
    setState(() {
      _isFirstLaunch = !hasSeenOnboarding;
      _isCheckingFirstLaunch = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking if first launch
    if (_isCheckingFirstLaunch) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // If first launch, always show Get Started page regardless of auth state
    if (_isFirstLaunch) {
      return const GetStartedPage();
    }

    // Not first launch - check authentication normally
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Not logged in - show login page (onboarding already completed)
        if (!snapshot.hasData) {
          return const LoginPage();
        }

        // Logged in - check role and route accordingly
        final userId = snapshot.data!.uid;
        final userEmail = snapshot.data!.email ?? 'Unknown';
        
        print('🔐 AuthWrapper: User logged in - ID: $userId, Email: $userEmail');
        
        return FutureBuilder<String>(
          future: RoleService().getUserRole(userId),
          builder: (context, roleSnapshot) {
            // Show loading while checking role
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Checking user permissions...'),
                    ],
                  ),
                ),
              );
            }

            // Show error if role check failed
            if (roleSnapshot.hasError) {
              print('❌ AuthWrapper Error: ${roleSnapshot.error}');
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 60,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading user data: ${roleSnapshot.error}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          FirebaseAuth.instance.signOut();
                        },
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // 🔀 SEPARATION POINT - Route based on role
            final role = (roleSnapshot.data ?? 'client').toLowerCase().trim();
            
            print('👤 AuthWrapper: User role detected = "$role"');
            
            // Route based on role with explicit comparison
            if (role == 'admin') {
              print('✅ Routing to ADMIN Dashboard');
              return const AdminDashboard();
            } else {
              print('✅ Routing to CLIENT Home Page');
              return const HomePage();
            }
          },
        );
      },
    );
  }
}

