import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/order_model.dart' as order_model;

class ManageOrdersPage extends StatefulWidget {
  const ManageOrdersPage({super.key});

  @override
  State<ManageOrdersPage> createState() => _ManageOrdersPageState();
}

class _ManageOrdersPageState extends State<ManageOrdersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedStatus = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Orders'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Status filter
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatusChip('All'),
                  _buildStatusChip('Pending'),
                  _buildStatusChip('Processing'),
                  _buildStatusChip('Shipped'),
                  _buildStatusChip('Delivered'),
                  _buildStatusChip('Cancelled'),
                ],
              ),
            ),
          ),
          // Orders list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('orders')
                  .orderBy('orderDate', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No orders found'),
                  );
                }

                var orders = snapshot.data!.docs.map((doc) {
                  return order_model.Order.fromJson(doc.data() as Map<String, dynamic>);
                }).toList();

                // Filter by status
                if (_selectedStatus != 'All') {
                  orders = orders.where((order) {
                    final statusString = order.status.toString().split('.').last;
                    return statusString.toLowerCase() == _selectedStatus.toLowerCase();
                  }).toList();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _buildOrderCard(order);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final isSelected = _selectedStatus == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(status),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedStatus = status;
          });
        },
        selectedColor: Colors.green[700],
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildOrderCard(order_model.Order order) {
    Color statusColor;
    final statusString = order.status.toString().split('.').last;
    switch (order.status) {
      case order_model.OrderStatus.pending:
        statusColor = Colors.orange;
        break;
      case order_model.OrderStatus.processing:
      case order_model.OrderStatus.confirmed:
        statusColor = Colors.blue;
        break;
      case order_model.OrderStatus.shipped:
        statusColor = Colors.purple;
        break;
      case order_model.OrderStatus.delivered:
        statusColor = Colors.green;
        break;
      case order_model.OrderStatus.cancelled:
        statusColor = Colors.red;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showOrderDetailsDialog(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order.id.substring(0, 8)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      statusString.replaceFirst(statusString[0], statusString[0].toUpperCase()),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.shippingAddress,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(order.createdAt),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.shopping_bag, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    '${order.items.length} item(s)',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'LKR ${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _showUpdateStatusDialog(order),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Update Status'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showOrderDetailsDialog(order_model.Order order) {
    final statusString = order.status.toString().split('.').last;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order #${order.id.substring(0, 8)}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Status', statusString.replaceFirst(statusString[0], statusString[0].toUpperCase())),
              const SizedBox(height: 8),
              _buildDetailRow('Date', _formatDate(order.createdAt)),
              const SizedBox(height: 8),
              _buildDetailRow('Total', 'LKR ${order.totalAmount.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              _buildDetailRow('Payment', order.paymentMethod ?? 'N/A'),
              const Divider(height: 24),
              const Text(
                'Shipping Address',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(order.shippingAddress),
              const Divider(height: 24),
              const Text(
                'Items',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...order.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('${item.productName} x${item.quantity}'),
                        ),
                        Text('LKR ${item.totalPrice.toStringAsFixed(2)}'),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(value),
      ],
    );
  }

  void _showUpdateStatusDialog(order_model.Order order) {
    order_model.OrderStatus newStatus = order.status;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Order Status'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<order_model.OrderStatus>(
                  title: const Text('Pending'),
                  value: order_model.OrderStatus.pending,
                  groupValue: newStatus,
                  onChanged: (value) {
                    setDialogState(() {
                      newStatus = value!;
                    });
                  },
                ),
                RadioListTile<order_model.OrderStatus>(
                  title: const Text('Confirmed'),
                  value: order_model.OrderStatus.confirmed,
                  groupValue: newStatus,
                  onChanged: (value) {
                    setDialogState(() {
                      newStatus = value!;
                    });
                  },
                ),
                RadioListTile<order_model.OrderStatus>(
                  title: const Text('Processing'),
                  value: order_model.OrderStatus.processing,
                  groupValue: newStatus,
                  onChanged: (value) {
                    setDialogState(() {
                      newStatus = value!;
                    });
                  },
                ),
                RadioListTile<order_model.OrderStatus>(
                  title: const Text('Shipped'),
                  value: order_model.OrderStatus.shipped,
                  groupValue: newStatus,
                  onChanged: (value) {
                    setDialogState(() {
                      newStatus = value!;
                    });
                  },
                ),
                RadioListTile<order_model.OrderStatus>(
                  title: const Text('Delivered'),
                  value: order_model.OrderStatus.delivered,
                  groupValue: newStatus,
                  onChanged: (value) {
                    setDialogState(() {
                      newStatus = value!;
                    });
                  },
                ),
                RadioListTile<order_model.OrderStatus>(
                  title: const Text('Cancelled'),
                  value: order_model.OrderStatus.cancelled,
                  groupValue: newStatus,
                  onChanged: (value) {
                    setDialogState(() {
                      newStatus = value!;
                    });
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _firestore.collection('orders').doc(order.id).update({
                  'status': newStatus.toString().split('.').last,
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Order status updated successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
