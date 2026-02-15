import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cart_item_model.dart';

class CartService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get cart items for user
  Stream<List<CartItem>> getCartItems(String userId) {
    return _firestore
        .collection('carts')
        .doc(userId)
        .collection('items')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CartItem.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // Add item to cart
  Future<void> addToCart(String userId, CartItem item) async {
    try {
      await _firestore
          .collection('carts')
          .doc(userId)
          .collection('items')
          .doc(item.productId)
          .set(item.toJson());
    } catch (e) {
      throw Exception('Failed to add item to cart: $e');
    }
  }

  // Update cart item quantity
  Future<void> updateCartItemQuantity(String userId, String productId, int quantity) async {
    try {
      if (quantity <= 0) {
        await removeFromCart(userId, productId);
      } else {
        await _firestore
            .collection('carts')
            .doc(userId)
            .collection('items')
            .doc(productId)
            .update({'quantity': quantity});
      }
    } catch (e) {
      throw Exception('Failed to update cart item: $e');
    }
  }

  // Remove item from cart
  Future<void> removeFromCart(String userId, String productId) async {
    try {
      await _firestore
          .collection('carts')
          .doc(userId)
          .collection('items')
          .doc(productId)
          .delete();
    } catch (e) {
      throw Exception('Failed to remove item from cart: $e');
    }
  }

  // Clear cart
  Future<void> clearCart(String userId) async {
    try {
      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection('carts')
          .doc(userId)
          .collection('items')
          .get();

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to clear cart: $e');
    }
  }

  // Get cart total
  Future<double> getCartTotal(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('carts')
          .doc(userId)
          .collection('items')
          .get();

      double total = 0;
      for (var doc in snapshot.docs) {
        final item = CartItem.fromJson({...doc.data(), 'id': doc.id});
        total += item.totalPrice;
      }

      return total;
    } catch (e) {
      throw Exception('Failed to calculate cart total: $e');
    }
  }

  // Get cart item count
  Future<int> getCartItemCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('carts')
          .doc(userId)
          .collection('items')
          .get();

      int count = 0;
      for (var doc in snapshot.docs) {
        final item = CartItem.fromJson({...doc.data(), 'id': doc.id});
        count += item.quantity;
      }

      return count;
    } catch (e) {
      throw Exception('Failed to get cart item count: $e');
    }
  }
}
