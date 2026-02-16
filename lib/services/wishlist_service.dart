import 'package:cloud_firestore/cloud_firestore.dart';

class WishlistService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get wishlist items for user
  Stream<List<String>> getWishlist(String userId) {
    return _firestore
        .collection('wishlists')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return List<String>.from(data['productIds'] ?? []);
      }
      return [];
    });
  }

  // Add item to wishlist
  Future<void> addToWishlist(String userId, String productId) async {
    try {
      await _firestore.collection('wishlists').doc(userId).set({
        'productIds': FieldValue.arrayUnion([productId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to add to wishlist: $e');
    }
  }

  // Remove item from wishlist
  Future<void> removeFromWishlist(String userId, String productId) async {
    try {
      await _firestore.collection('wishlists').doc(userId).update({
        'productIds': FieldValue.arrayRemove([productId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to remove from wishlist: $e');
    }
  }

  // Toggle wishlist status
  Future<void> toggleWishlist(String userId, String productId, bool isInWishlist) async {
    if (isInWishlist) {
      await removeFromWishlist(userId, productId);
    } else {
      await addToWishlist(userId, productId);
    }
  }

  // Check if product is in wishlist
  Future<bool> isInWishlist(String userId, String productId) async {
    try {
      final doc = await _firestore.collection('wishlists').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final productIds = List<String>.from(doc.data()!['productIds'] ?? []);
        return productIds.contains(productId);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Clear wishlist
  Future<void> clearWishlist(String userId) async {
    try {
      await _firestore.collection('wishlists').doc(userId).delete();
    } catch (e) {
      throw Exception('Failed to clear wishlist: $e');
    }
  }
}
