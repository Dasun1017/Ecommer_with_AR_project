import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart' as models;

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create order
  Future<String> createOrder(models.Order order) async {
    try {
      final docRef = await _firestore.collection('orders').add(order.toJson());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  // Get user orders
  Stream<List<models.Order>> getUserOrders(String userId) {
    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => models.Order.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // Get order by ID
  Future<models.Order?> getOrderById(String orderId) async {
    try {
      final doc = await _firestore.collection('orders').doc(orderId).get();
      if (doc.exists) {
        return models.Order.fromJson({...doc.data()!, 'id': doc.id});
      }
    } catch (e) {
      throw Exception('Failed to get order: $e');
    }
    return null;
  }

  // Update order status
  Future<void> updateOrderStatus(String orderId, models.OrderStatus status) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': status.toString().split('.').last,
      });
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  // Cancel order
  Future<void> cancelOrder(String orderId) async {
    try {
      await updateOrderStatus(orderId, models.OrderStatus.cancelled);
    } catch (e) {
      throw Exception('Failed to cancel order: $e');
    }
  }

  // Get all orders (admin only)
  Stream<List<models.Order>> getAllOrders() {
    return _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => models.Order.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }
}
