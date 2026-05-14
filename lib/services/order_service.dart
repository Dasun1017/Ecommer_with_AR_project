import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cart_item_model.dart';
import '../models/order_model.dart' as models;

class PlacedOrderResult {
  final String orderId;
  final double totalAmount;

  const PlacedOrderResult({
    required this.orderId,
    required this.totalAmount,
  });
}

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

  // Create order from the user's current cart and clear cart atomically
  Future<PlacedOrderResult> placeOrderFromCart({
    required String userId,
    required String shippingAddress,
    required String paymentMethod,
    required double deliveryFee,
  }) async {
    try {
      final cartSnapshot = await _firestore
          .collection('carts')
          .doc(userId)
          .collection('items')
          .get();

      if (cartSnapshot.docs.isEmpty) {
        throw Exception('Your cart is empty.');
      }

      final cartItems = cartSnapshot.docs
          .map((doc) => CartItem.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      final subtotal = cartItems.fold<double>(
        0,
        (total, item) => total + item.totalPrice,
      );
      final totalAmount = subtotal + deliveryFee;
      final orderRef = _firestore.collection('orders').doc();

      final order = models.Order(
        id: orderRef.id,
        userId: userId,
        items: cartItems
            .map(
              (item) => models.OrderItem(
                productId: item.productId,
                productName: item.productName,
                productImage: item.productImage,
                price: item.price,
                quantity: item.quantity,
                selectedColor: item.selectedColor,
                selectedSize: item.selectedSize,
              ),
            )
            .toList(),
        totalAmount: totalAmount,
        status: models.OrderStatus.pending,
        shippingAddress: shippingAddress,
        paymentMethod: paymentMethod,
        createdAt: DateTime.now(),
      );

      final batch = _firestore.batch();
      batch.set(orderRef, order.toJson());

      for (final doc in cartSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      return PlacedOrderResult(
        orderId: orderRef.id,
        totalAmount: totalAmount,
      );
    } catch (e) {
      throw Exception('Failed to place order: $e');
    }
  }

  // Get user orders
  Stream<List<models.Order>> getUserOrders(String userId) {
    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => models.Order.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
      // Sort in memory to avoid needing a Firestore index
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
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
  Future<void> updateOrderStatus(
      String orderId, models.OrderStatus status) async {
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
