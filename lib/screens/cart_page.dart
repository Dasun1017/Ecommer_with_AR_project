import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/cart_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../models/cart_item_model.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final CartService _cartService = CartService();
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  final int _selectedIndex = 3;

  @override
  Widget build(BuildContext context) {
    final userId = _authService.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const Expanded(
                child: Center(
                  child: Text('Please login to view cart'),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNavBar(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: StreamBuilder<List<CartItem>>(
        stream: _cartService.getCartItems(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final cartItems = snapshot.data!;

          if (cartItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 100,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your cart is empty',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/shop'),
                    child: const Text('Start Shopping'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ...cartItems.map((item) => _buildCartItem(item, userId)),
                      const SizedBox(height: 16),
                      _buildOrderSummary(cartItems),
                    ],
                  ),
                ),
              ),
              _buildCheckoutButton(cartItems),
            ],
          );
        },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pushReplacementNamed(context, '/home');
            },
            child: Image.asset(
              'assets/logo/tryverse_logo.png',
              height: 60,
              errorBuilder: (context, error, stackTrace) {
                return const Text(
                  'TryVerse',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                );
              },
            ),
          ),
          _buildNotificationIcon(),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon() {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return IconButton(
        icon: const Icon(Icons.notifications_outlined, size: 28),
        onPressed: () => Navigator.pushNamed(context, '/notifications'),
      );
    }

    return StreamBuilder<int>(
      stream: _notificationService.getUnreadCount(user.uid),
      builder: (context, snapshot) {
        final unreadCount = snapshot.hasData ? snapshot.data! : 0;

        if (unreadCount == 0) {
          return IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 28),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          );
        }

        return IconButton(
          icon: Badge(
            label: Text('$unreadCount'),
            backgroundColor: Colors.red,
            textColor: Colors.white,
            child: const Icon(Icons.notifications_outlined, size: 28),
          ),
          onPressed: () => Navigator.pushNamed(context, '/notifications'),
        );
      },
    );
  }

  Widget _buildCartItem(CartItem item, String userId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 80,
              height: 80,
              color: Colors.grey[200],
              child: Image.network(
                item.productImage,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.image, size: 40);
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await _cartService.removeFromCart(userId, item.id);
                        if (!mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Item removed from cart')),
                        );
                      },
                    ),
                  ],
                ),
                if (item.selectedColor != null || item.selectedSize != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      [
                        if (item.selectedColor != null) 'Color: ${item.selectedColor}',
                        if (item.selectedSize != null) 'Size: ${item.selectedSize}',
                      ].join(', '),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'LKR ${item.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    _buildQuantityControls(item, userId),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityControls(CartItem item, String userId) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.remove, size: 18, color: Colors.blue[700]),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () async {
              await _cartService.updateCartItemQuantity(
                userId,
                item.id,
                item.quantity - 1,
              );
            },
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${item.quantity}'.padLeft(2, '0'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.add, size: 18, color: Colors.blue[700]),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () async {
              await _cartService.updateCartItemQuantity(
                userId,
                item.id,
                item.quantity + 1,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(List<CartItem> items) {
    final subtotal = items.fold<double>(0, (total, item) => total + item.totalPrice);
    const discount = 0.0;
    const deliveryCharges = 350.0;
    final total = subtotal - discount + deliveryCharges;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Items', items.length.toString(), isCount: true),
          const SizedBox(height: 8),
          _buildSummaryRow('Subtotal', 'LKR ${subtotal.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _buildSummaryRow('Discount', 'LKR ${discount.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _buildSummaryRow('Delivery Charges', 'LKR ${deliveryCharges.toStringAsFixed(2)}'),
          const Divider(height: 24),
          _buildSummaryRow('Total', 'LKR ${total.toStringAsFixed(2)}', isTotal: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false, bool isCount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? Colors.black : Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? Colors.black : Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckoutButton(List<CartItem> items) {
    final subtotal = items.fold<double>(0, (total, item) => total + item.totalPrice);
    final total = subtotal + 350.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () {
            Navigator.pushNamed(
              context,
              '/checkout',
              arguments: {'items': items, 'total': total},
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[600],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Check Out',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        boxShadow: [
          BoxShadow(
            color: Colors.grey[300]!,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == _selectedIndex) return;

          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/home');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/shop');
              break;
            case 2:
              // Try AR logic here
              break;
            case 3:
              // Already on cart
              break;
            case 4:
              Navigator.pushNamed(context, '/profile');
              break;
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.blue.shade50,
        selectedItemColor: Colors.blue.shade700,
        unselectedItemColor: Colors.grey.shade600,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        elevation: 0,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home, size: 24),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag, size: 24),
            label: 'Shop',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt, size: 24),
            label: 'Try AR',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shopping_cart, color: Colors.blue[900], size: 24),
            ),
            label: 'Cart',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person, size: 24),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}