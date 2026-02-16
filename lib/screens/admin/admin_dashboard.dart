import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _totalProducts = 0;
  int _totalOrders = 0;
  int _totalUsers = 0;
  double _totalRevenue = 0.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      // Get total products
      final productsSnapshot = await _firestore.collection('products').get();
      _totalProducts = productsSnapshot.docs.length;

      // Get total orders and calculate revenue
      final ordersSnapshot = await _firestore.collection('orders').get();
      _totalOrders = ordersSnapshot.docs.length;
      _totalRevenue = ordersSnapshot.docs.fold(0.0, (sum, doc) {
        return sum + (doc.data()['totalAmount'] as num? ?? 0).toDouble();
      });

      // Get total users
      final usersSnapshot = await _firestore.collection('users').get();
      _totalUsers = usersSnapshot.docs.length;

      setState(() {
        _loading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _loading = true;
              });
              _loadDashboardData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Overview',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Statistics Cards
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildStatCard(
                        'Total Products',
                        _totalProducts.toString(),
                        Icons.inventory,
                        Colors.blue,
                      ),
                      _buildStatCard(
                        'Total Orders',
                        _totalOrders.toString(),
                        Icons.shopping_bag,
                        Colors.green,
                      ),
                      _buildStatCard(
                        'Total Users',
                        _totalUsers.toString(),
                        Icons.people,
                        Colors.orange,
                      ),
                      _buildStatCard(
                        'Revenue',
                        'LKR ${_totalRevenue.toStringAsFixed(2)}',
                        Icons.attach_money,
                        Colors.purple,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Management',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Management Options
                  _buildManagementCard(
                    context,
                    'Manage Products',
                    'Add, edit, or remove products',
                    Icons.inventory_2,
                    Colors.blue,
                    () => Navigator.pushNamed(context, '/admin/products'),
                  ),
                  const SizedBox(height: 16),
                  _buildManagementCard(
                    context,
                    'Manage Orders',
                    'View and update order status',
                    Icons.local_shipping,
                    Colors.green,
                    () => Navigator.pushNamed(context, '/admin/orders'),
                  ),
                  const SizedBox(height: 16),
                  _buildManagementCard(
                    context,
                    'Manage Users',
                    'View and manage user accounts',
                    Icons.people,
                    Colors.orange,
                    () => Navigator.pushNamed(context, '/admin/users'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 40,
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 20,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
