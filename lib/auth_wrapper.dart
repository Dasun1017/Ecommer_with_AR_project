import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/role_service.dart';
import 'screens/get_started_page.dart';
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

    debugPrint('═══════════════════════════════════════');
    debugPrint('🔍 AuthWrapper: Checking first launch');
    debugPrint('   hasSeenOnboarding flag: $hasSeenOnboarding');
    debugPrint('   Will show GetStarted: ${!hasSeenOnboarding}');
    debugPrint('═══════════════════════════════════════');

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

        // Not logged in - show home page with a one-time login prompt.
        if (!snapshot.hasData) {
          return const _GuestHomeWithLoginPrompt();
        }

        // Logged in - check role and route accordingly
        final userId = snapshot.data!.uid;
        final userEmail = snapshot.data!.email ?? 'Unknown';

        debugPrint('═══════════════════════════════════════');
        debugPrint('🔐 AuthWrapper: User logged in');
        debugPrint('   User ID: $userId');
        debugPrint('   Email: $userEmail');
        debugPrint('═══════════════════════════════════════');

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
              debugPrint('❌ AuthWrapper Error: ${roleSnapshot.error}');
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

            debugPrint('═══════════════════════════════════════');
            debugPrint('👤 AuthWrapper: Role detected = "$role"');
            debugPrint('═══════════════════════════════════════');

            // Route based on role with explicit comparison
            if (role == 'admin') {
              debugPrint('✅ Routing to ADMIN Dashboard');
              debugPrint('═══════════════════════════════════════\n');
              return const AdminDashboard();
            } else {
              debugPrint('✅ Routing to CLIENT Home Page');
              debugPrint('═══════════════════════════════════════\n');
              return const HomePage();
            }
          },
        );
      },
    );
  }
}

class _GuestHomeWithLoginPrompt extends StatefulWidget {
  const _GuestHomeWithLoginPrompt();

  @override
  State<_GuestHomeWithLoginPrompt> createState() =>
      _GuestHomeWithLoginPromptState();
}

class _GuestHomeWithLoginPromptState extends State<_GuestHomeWithLoginPrompt> {
  bool _hasShownPrompt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasShownPrompt) {
        return;
      }

      _hasShownPrompt = true;
      _showLoginPrompt();
    });
  }

  Future<void> _showLoginPrompt() {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.login_rounded,
                          color: Colors.blue.shade900,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Login Required',
                              style: TextStyle(
                                color: Colors.grey.shade900,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Please login to access your cart, orders, wishlist, profile, and notifications.',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        Navigator.of(context).pushNamed('/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Login'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        Navigator.of(context).pushNamed('/register');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade800,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Create Account'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      'Continue Browsing',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const HomePage();
  }
}
