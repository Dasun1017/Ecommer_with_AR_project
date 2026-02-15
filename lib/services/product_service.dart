import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all products
  Stream<List<Product>> getAllProducts() {
    return _firestore
        .collection('products')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Product.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // Get products by category
  Stream<List<Product>> getProductsByCategory(String category) {
    return _firestore
        .collection('products')
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Product.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // Get featured products
  Stream<List<Product>> getFeaturedProducts() {
    return _firestore
        .collection('products')
        .where('isFeatured', isEqualTo: true)
        .limit(10)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Product.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // Get product by ID
  Future<Product?> getProductById(String productId) async {
    try {
      final doc = await _firestore.collection('products').doc(productId).get();
      if (doc.exists) {
        return Product.fromJson({...doc.data()!, 'id': doc.id});
      }
    } catch (e) {
      throw Exception('Failed to get product: $e');
    }
    return null;
  }

  // Search products
  Stream<List<Product>> searchProducts(String query) {
    return _firestore
        .collection('products')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Product.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // Add product (admin only)
  Future<String> addProduct(Product product) async {
    try {
      final docRef = await _firestore.collection('products').add(product.toJson());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add product: $e');
    }
  }

  // Update product (admin only)
  Future<void> updateProduct(Product product) async {
    try {
      await _firestore.collection('products').doc(product.id).update(product.toJson());
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  // Delete product (admin only)
  Future<void> deleteProduct(String productId) async {
    try {
      await _firestore.collection('products').doc(productId).delete();
    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }

  // Get categories
  Future<List<String>> getCategories() async {
    try {
      final snapshot = await _firestore.collection('products').get();
      final categories = snapshot.docs
          .map((doc) => doc.data()['category'] as String)
          .toSet()
          .toList();
      return categories;
    } catch (e) {
      throw Exception('Failed to get categories: $e');
    }
  }
}
