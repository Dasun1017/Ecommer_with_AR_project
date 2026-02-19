import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/notification_helper.dart';
import '../../models/notification_model.dart';

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
      _totalRevenue = ordersSnapshot.docs.fold(0.0, (total, doc) {
        return total + (doc.data()['totalAmount'] as num? ?? 0).toDouble();
      });

      // Get total users
      final usersSnapshot = await _firestore.collection('users').get();
      _totalUsers = usersSnapshot.docs.length;

      setState(() {
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
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
            icon: const Icon(Icons.notifications_active),
            tooltip: 'Send Notification',
            onPressed: () => _showSendNotificationDialog(),
          ),
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
                    childAspectRatio: 1.1,
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
                        _formatRevenue(_totalRevenue),
                        Icons.attach_money,
                        Colors.purple,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Recent Orders Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Activity',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/admin/orders'),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('orders')
                        .orderBy('createdAt', descending: true)
                        .limit(3)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(
                              child: Text(
                                'No recent orders',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: snapshot.data!.docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final orderId = doc.id.substring(0, 8);
                          final status = data['status'] ?? 'pending';
                          final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(status),
                                child: const Icon(Icons.shopping_bag, color: Colors.white, size: 20),
                              ),
                              title: Text('Order #$orderId'),
                              subtitle: Text('Status: ${status.toUpperCase()}'),
                              trailing: Text(
                                'LKR ${amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/admin/orders',
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
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
                  const SizedBox(height: 16),
                  _buildManagementCard(
                    context,
                    'Send Notifications',
                    'Send notifications to all users',
                    Icons.notifications_active,
                    Colors.purple,
                    _showSendNotificationDialog,
                  ),
                ],
              ),
            ),
    );
  }


  String _formatRevenue(double amount) {
    if (amount >= 1000000) {
      return 'Rs ${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return 'Rs ${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return 'Rs ${amount.toStringAsFixed(0)}';
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
                  color: color.withValues(alpha: 0.1),
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'shipped':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showSendNotificationDialog() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    NotificationType selectedType = NotificationType.system;
    bool sending = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Send Notification to All Users'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<NotificationType>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: NotificationType.values.map((type) {
                    return DropdownMenuItem<NotificationType>(
                      value: type,
                      child: Text(type.toString().split('.').last),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedType = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: sending
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty ||
                          messageController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill all fields'),
                          ),
                        );
                        return;
                      }

                      setState(() {
                        sending = true;
                      });

                      try {
                        // Get all users
                        final usersSnapshot =
                            await _firestore.collection('users').get();

                        // Send notification to each user
                        for (var userDoc in usersSnapshot.docs) {
                          await NotificationHelper.sendSystemNotification(
                            userDoc.id,
                            titleController.text.trim(),
                            messageController.text.trim(),
                          );
                        }

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Notification sent to ${usersSnapshot.docs.length} users'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        setState(() {
                          sending = false;
                        });
                      }
                    },
              child: sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send to All'),
            ),
          ],
        ),
      ),
    );
  }
}
