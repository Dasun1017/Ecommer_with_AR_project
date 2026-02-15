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
import '../models/product_model.dart';
import '../models/cart_item_model.dart';

class AppRoutes {
  static const String getStarted = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String shop = '/shop';
  static const String products = '/products';
  static const String productDetails = '/product-details';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String profile = '/profile';
  static const String notifications = '/notifications';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case getStarted:
        return MaterialPageRoute(builder: (_) => const GetStartedPage());
      
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterPage());
      
      case home:
        return MaterialPageRoute(builder: (_) => const HomePage());
      
      case shop:
        return MaterialPageRoute(builder: (_) => const ShopPage());
      
      case products:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ProductsPage(
            category: args?['category'] as String?,
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
