import 'package:flutter/material.dart';
import '../models/order_model.dart' as models;
import '../services/order_service.dart';
import '../services/auth_service.dart';
import 'order_details_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final OrderService _orderService = OrderService();
  final AuthService _authService = AuthService();
  
  models.OrderStatus? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final userId = _authService.currentUser?.uid;
    
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Orders')),
        body: const Center(
          child: Text('Please login to view orders'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        actions: [
          PopupMenuButton<models.OrderStatus?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (status) {
              setState(() {
                _selectedStatus = status;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Orders'),
              ),
              ...models.OrderStatus.values.map((status) {
                return PopupMenuItem(
                  value: status,
                  child: Text(_getStatusLabel(status)),
                );
              }),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<models.Order>>(
        stream: _orderService.getUserOrders(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined, 
                      size: 100, 
                      color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No orders yet',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start shopping to see your orders here',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/shop'),
                    child: const Text('Start Shopping'),
                  ),
                ],
              ),
            );
          }

          var orders = snapshot.data!;
          
          // Filter by status if selected
          if (_selectedStatus != null) {
            orders = orders.where((order) => order.status == _selectedStatus).toList();
          }

          // Sort by date (newest first)
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (orders.isEmpty) {
            return Center(
              child: Text(
                'No ${_getStatusLabel(_selectedStatus!).toLowerCase()} orders',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              return _buildOrderCard(orders[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(models.Order order) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 2,
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${order.id.substring(0, 8).toUpperCase()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(order.createdAt),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(order.status),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  Icon(Icons.shopping_bag_outlined, 
                      size: 18, 
                      color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    '${order.items.length} ${order.items.length == 1 ? "item" : "items"}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const Spacer(),
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
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, 
                      size: 18, 
                      color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.shippingAddress,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
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
        _getStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getStatusLabel(models.OrderStatus status) {
    return status.toString().split('.').last.toUpperCase();
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
