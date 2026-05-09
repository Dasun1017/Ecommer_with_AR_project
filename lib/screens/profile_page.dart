import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../services/cart_service.dart';
import '../models/user_model.dart';
import '../models/order_model.dart' as models;
import 'edit_profile_page.dart';
import 'orders_page.dart';
import 'order_details_page.dart';
import 'wishlist_page.dart';
import 'settings_page.dart';
import 'help_support_page.dart';
import 'payment_methods_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _selectedIndex = 4; // Profile page index
  final AuthService _authService = AuthService();
  final OrderService _orderService = OrderService();
  final CartService _cartService = CartService();
  UserModel? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userId = _authService.currentUser?.uid;
    if (userId != null) {
      final user = await _authService.getUserData(userId);
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Please login to view profile'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfilePage(user: _user!),
                ),
              );
              if (result == true) {
                _loadUserData();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 20),
            _buildProfileOptions(),
            const SizedBox(height: 20),
            _buildOrdersSection(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: _user!.photoUrl != null
                ? NetworkImage(_user!.photoUrl!)
                : null,
            child: _user!.photoUrl == null
                ? const Icon(Icons.person, size: 50)
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            _user!.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _user!.email,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          if (_user!.phoneNumber != null) ...[
            const SizedBox(height: 4),
            Text(
              _user!.phoneNumber!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileOptions() {
    return Column(
      children: [
        _buildOptionTile(
          icon: Icons.person_outline,
          title: 'Edit Profile',
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EditProfilePage(user: _user!),
              ),
            );
            if (result == true) {
              _loadUserData(); // Reload user data after edit
            }
          },
        ),
        _buildOptionTile(
          icon: Icons.location_on_outlined,
          title: 'Addresses',
          subtitle: _user!.address,
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EditProfilePage(user: _user!),
              ),
            );
            if (result == true) {
              _loadUserData();
            }
          },
        ),
        _buildOptionTile(
          icon: Icons.payment,
          title: 'Payment Methods',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PaymentMethodsPage(),
              ),
            );
          },
        ),
        _buildOptionTile(
          icon: Icons.shopping_bag_outlined,
          title: 'My Orders',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const OrdersPage(),
              ),
            );
          },
        ),
        _buildOptionTile(
          icon: Icons.favorite_outline,
          title: 'Wishlist',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const WishlistPage(),
              ),
            );
          },
        ),
        _buildOptionTile(
          icon: Icons.settings_outlined,
          title: 'Settings',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SettingsPage(),
              ),
            );
          },
        ),
        _buildOptionTile(
          icon: Icons.help_outline,
          title: 'Help & Support',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const HelpSupportPage(),
              ),
            );
          },
        ),
        const Divider(),
        _buildOptionTile(
          icon: Icons.logout,
          title: 'Logout',
          iconColor: Colors.red,
          onTap: () => _logout(),
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildOrdersSection() {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Orders',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OrdersPage(),
                    ),
                  );
                },
                child: const Text('View All'),
              ),
            ],
          ),
        ),
        StreamBuilder<List<models.Order>>(
          stream: _orderService.getUserOrders(userId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final orders = snapshot.data!.take(3).toList();

            if (orders.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No orders yet'),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                return _buildOrderItem(orders[index]);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildOrderItem(models.Order order) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderDetailsPage(order: order),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order.id.substring(0, 8)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  _buildStatusChip(order.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${order.items.length} items',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                'Rs. ${order.totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(models.OrderStatus status) {
    Color color;
    switch (status) {
      case models.OrderStatus.pending:
        color = Colors.orange;
        break;
      case models.OrderStatus.confirmed:
      case models.OrderStatus.processing:
        color = Colors.blue;
        break;
      case models.OrderStatus.shipped:
        color = Colors.purple;
        break;
      case models.OrderStatus.delivered:
        color = Colors.green;
        break;
      case models.OrderStatus.cancelled:
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toString().split('.').last.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }



  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;
    if (confirm != true) return;

    await _authService.signOut();
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _requireAuth(VoidCallback onAuthenticated) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // User not logged in, show login prompt
      _showLoginPrompt();
    } else {
      // User is logged in, proceed with action
      onAuthenticated();
    }
  }

  /// Show dialog prompting user to login
  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Required'),
        content: const Text('Please login to access this feature'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/login');
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/home');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/shop');
              break;
            case 2:
              // Try AR - will be implemented later
              break;
            case 3:
              // Cart - requires authentication
              _requireAuth(() {
                Navigator.pushNamed(context, '/cart');
              });
              break;
            case 4:
              // Profile - already here
              break;
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.blue.shade100,
        selectedItemColor: Colors.blue.shade700,
        unselectedItemColor: Colors.grey.shade600,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        elevation: 0,
        items: [
          BottomNavigationBarItem(
            icon: _selectedIndex == 0
                ? Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.home, color: Colors.blue.shade900, size: 24),
                  )
                : const Icon(Icons.home, size: 24),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: _selectedIndex == 1
                ? Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.shopping_bag, color: Colors.blue.shade900, size: 24),
                  )
                : const Icon(Icons.shopping_bag, size: 24),
            label: 'Shop',
          ),
          BottomNavigationBarItem(
            icon: _selectedIndex == 2
                ? Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.camera_alt, color: Colors.blue.shade900, size: 24),
                  )
                : const Icon(Icons.camera_alt, size: 24),
            label: 'Try AR',
          ),
          BottomNavigationBarItem(
            icon: _buildCartIcon(),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: _selectedIndex == 4
                ? Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person, color: Colors.blue.shade900, size: 24),
                  )
                : const Icon(Icons.person, size: 24),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildCartIcon() {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      // User not logged in, show icon without badge
      return _selectedIndex == 3
          ? Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade300,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shopping_cart_outlined, color: Colors.blue.shade900, size: 24),
            )
          : const Icon(Icons.shopping_cart_outlined, size: 24);
    }

    // User logged in, show cart count badge
    return StreamBuilder<List<dynamic>>(
      stream: _cartService.getCartItems(user.uid),
      builder: (context, snapshot) {
        final itemCount = snapshot.hasData ? snapshot.data!.length : 0;
        
        final icon = _selectedIndex == 3
            ? Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade300,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shopping_cart_outlined, color: Colors.blue.shade900, size: 24),
              )
            : const Icon(Icons.shopping_cart_outlined, size: 24);

        if (itemCount == 0) {
          return icon;
        }

        return Badge(
          label: Text('$itemCount'),
          backgroundColor: Colors.red,
          textColor: Colors.white,
          child: icon,
        );
      },
    );
  }
}
