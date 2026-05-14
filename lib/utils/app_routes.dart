import 'package:flutter/material.dart';
import '../screens/get_started_page.dart';
import '../screens/login_page.dart';
import '../screens/register_page.dart';
import '../screens/home_page.dart';
import '../screens/shop_page.dart';
import '../screens/products_page.dart';
import '../screens/product_details_page.dart';
import '../screens/cart_page.dart';
import '../screens/checkout_page.dart';
import '../screens/profile_page.dart';
import '../screens/notification_page.dart';
import '../screens/ar_tryon_page.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/admin/manage_products_page.dart';
import '../screens/admin/manage_orders_page.dart';
import '../screens/admin/manage_users_page.dart';
import '../models/product_model.dart';
import '../models/cart_item_model.dart';

class AppRoutes {
  // ==================== APP NAVIGATION STRUCTURE ====================
  //
  // INITIAL FLOW:
  // 1. App opens → AuthWrapper (checks authentication)
  // 2. First launch → GetStartedPage (onboarding)
  // 3. GetStarted/Skip → HomePage (guest browsing)
  // 4. HomePage allows browsing products without login
  // 5. When accessing authenticated features (Cart, Profile, etc.) → Login prompt
  // 6. After login → AuthWrapper checks role in Firestore:
  //    - role = 'admin' → AdminDashboard (ADMIN SIDE)
  //    - role = 'client' → HomePage (CLIENT SIDE with full access)
  //
  // GUEST BROWSING:
  // - Users can view home page and browse products without logging in
  // - Authentication required for: Cart, Checkout, Profile, Orders, Notifications
  // - Login prompts appear when accessing protected features
  //
  // NAVIGATION SEPARATION:
  // - Admin Side: AdminDashboard → only navigates to admin/* routes
  // - Client Side: HomePage → only navigates to client routes (shop, cart, profile, etc.)
  // - No cross-navigation between admin and client sides
  //
  // ==================================================================

  static const String getStarted = '/';
  static const String login = '/login';
  static const String register = '/register';

  // CLIENT ROUTES (accessible from client side only)
  static const String home = '/home';
  static const String shop = '/shop';
  static const String products = '/products';
  static const String productDetails = '/product-details';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String profile = '/profile';
  static const String notifications = '/notifications';
  static const String arTryOn = '/ar-try-on';

  // ADMIN ROUTES (accessible from admin side only)
  static const String adminDashboard = '/admin/dashboard';
  static const String adminProducts = '/admin/products';
  static const String adminOrders = '/admin/orders';
  static const String adminUsers = '/admin/users';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    // NOTE: Role-based access is controlled by navigation structure, not route guards:
    // - AuthWrapper handles initial routing based on user role
    // - Admin pages only contain navigation to admin routes
    // - Client pages only contain navigation to client routes
    // - This prevents unauthorized access through proper app architecture

    switch (settings.name) {
      case getStarted:
        return MaterialPageRoute(builder: (_) => const GetStartedPage());

      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());

      case register:
        return MaterialPageRoute(builder: (_) => const RegisterPage());

      // ==================== CLIENT ROUTES ====================
      case home:
        return MaterialPageRoute(builder: (_) => const HomePage());

      case shop:
        return MaterialPageRoute(builder: (_) => const ShopPage());

      case products:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ProductsPage(
            category: args?['category'] as String?,
            searchQuery: args?['searchQuery'] as String?,
            sortBy: args?['sortBy'] as String?,
            filter: args?['filter'] as String?,
          ),
        );

      case productDetails:
        final product = settings.arguments as Product;
        return MaterialPageRoute(
          builder: (_) => ProductDetailsPage(product: product),
        );

      case cart:
        return MaterialPageRoute(builder: (_) => const CartPage());

      case checkout:
        final args = settings.arguments as Map<String, dynamic>;
        final items = args['items'] as List<CartItem>;
        final total = args['total'] as double;
        return MaterialPageRoute(
          builder: (_) => CheckoutPage(items: items, total: total),
        );

      case profile:
        return MaterialPageRoute(builder: (_) => const ProfilePage());

      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationPage());

      case arTryOn:
        return MaterialPageRoute(builder: (_) => const ARTryOnPage());

      // ==================== ADMIN ROUTES ====================
      // These routes are for admin users only
      // Client pages don't navigate to these routes
      // Access controlled by:
      // 1. AuthWrapper routes admins to AdminDashboard initially
      // 2. Admin pages only contain navigation to other admin routes
      // 3. No direct links from client side to admin routes

      case adminDashboard:
        return MaterialPageRoute(builder: (_) => const AdminDashboard());

      case adminProducts:
        return MaterialPageRoute(builder: (_) => const ManageProductsPage());

      case adminOrders:
        return MaterialPageRoute(builder: (_) => const ManageOrdersPage());

      case adminUsers:
        return MaterialPageRoute(builder: (_) => const ManageUsersPage());

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
