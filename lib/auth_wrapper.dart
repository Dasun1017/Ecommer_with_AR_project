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
/// 3. GetStartedPage → HomePage (guest browsing allowed)
/// 4. HomePage prompts for login when accessing authenticated features (Cart, Profile, etc.)
/// 5. After successful login → AuthWrapper detects auth change and checks user role
/// 6. Routes based on role:
///    - role = 'admin' → AdminDashboard (ADMIN SIDE)
///    - role = 'client' → HomePage (CLIENT SIDE with full access)
/// 
/// GUEST BROWSING:
/// - Users can browse home page and products without logging in
/// - Features requiring authentication (Cart, Profile, Checkout, etc.) prompt for login
/// - After login, users get full access based on their role
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
  bool _isFirstLaunch = false;
  bool _isCheckingFirstLaunch = true;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
    
    print('═══════════════════════════════════════');
    print('🔍 AuthWrapper: Checking first launch');
    print('   hasSeenOnboarding flag: $hasSeenOnboarding');
    print('   Will show GetStarted: ${!hasSeenOnboarding}');
    print('═══════════════════════════════════════');
    
    setState(() {
      // Only show GetStarted page if user has never seen onboarding
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

    // Not first launch - allow browsing home page without login
    // Check authentication for role-based routing
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

        // Not logged in - show home page (allow browsing as guest)
        // User will be prompted to login when accessing authenticated features
        if (!snapshot.hasData) {
          return const HomePage();
        }

        // Logged in - check role and route accordingly
        final userId = snapshot.data!.uid;
        final userEmail = snapshot.data!.email ?? 'Unknown';
        
        print('═══════════════════════════════════════');
        print('🔐 AuthWrapper: User logged in');
        print('   User ID: $userId');
        print('   Email: $userEmail');
        print('═══════════════════════════════════════');
        
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
            
            print('═══════════════════════════════════════');
            print('👤 AuthWrapper: Role detected = "$role"');
            print('═══════════════════════════════════════');
            
            // Route based on role with explicit comparison
            if (role == 'admin') {
              print('✅ Routing to ADMIN Dashboard');
              print('═══════════════════════════════════════\n');
              return const AdminDashboard();
            } else {
              print('✅ Routing to CLIENT Home Page');
              print('═══════════════════════════════════════\n');
              return const HomePage();
            }
          },
        );
      },
    );
  }
}

