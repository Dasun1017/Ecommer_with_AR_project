import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../models/cart_item_model.dart';
import '../services/product_service.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/wishlist_service.dart';
import 'product_details_page.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  final ProductService _productService = ProductService();
  final AuthService _authService = AuthService();
  final CartService _cartService = CartService();
  final WishlistService _wishlistService = WishlistService();
  
  final List<String> _wishlistIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    final userId = _authService.currentUser?.uid;
    if (userId != null) {
      _wishlistService.getWishlist(userId).listen((wishlist) {
        if (mounted) {
          setState(() {
            _wishlistIds.clear();
            _wishlistIds.addAll(wishlist);
            _isLoading = false;
          });
        }
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _removeFromWishlist(String productId) async {
    final userId = _authService.currentUser?.uid;
    if (userId != null) {
      try {
        await _wishlistService.removeFromWishlist(userId, productId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from wishlist')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _addToCart(Product product) {
    final userId = _authService.currentUser?.uid;
    if (userId != null) {
      final cartItem = CartItem(
        id: product.id,
        productId: product.id,
        productName: product.name,
        productImage: product.images.isNotEmpty ? product.images[0] : '',
        price: product.price,
        quantity: 1,
      );
      _cartService.addToCart(userId, cartItem);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} added to cart')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _authService.currentUser?.uid;
    
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wishlist')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_border, size: 100, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text('Please login to view wishlist'),
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
        title: const Text('My Wishlist'),
        actions: [
          if (_wishlistIds.isNotEmpty)
            TextButton(
              onPressed: () async {
                final userId = _authService.currentUser?.uid;
                if (userId != null) {
                  try {
                    await _wishlistService.clearWishlist(userId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Wishlist cleared')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text(
                'Clear All',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _wishlistIds.isEmpty
              ? _buildEmptyWishlist()
              : _buildWishlistGrid(),
    );
  }

  Widget _buildEmptyWishlist() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 120, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            'Your wishlist is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add products you love to your wishlist',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/shop'),
            icon: const Icon(Icons.shopping_bag),
            label: const Text('Start Shopping'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlistGrid() {
    return StreamBuilder<List<Product>>(
      stream: _productService.getAllProducts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filter products that are in wishlist
        final wishlistProducts = snapshot.data!
            .where((product) => _wishlistIds.contains(product.id))
            .toList();

        if (wishlistProducts.isEmpty) {
          return _buildEmptyWishlist();
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: wishlistProducts.length,
          itemBuilder: (context, index) {
            return _buildWishlistCard(wishlistProducts[index]);
          },
        );
      },
    );
  }

  Widget _buildWishlistCard(Product product) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailsPage(product: product),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Image.network(
                    product.images.isNotEmpty
                        ? product.images[0]
                        : '',
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: 150,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image_not_supported, size: 50),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 18,
                    child: IconButton(
                      icon: const Icon(
                        Icons.favorite,
                        color: Colors.red,
                        size: 18,
                      ),
                      onPressed: () => _removeFromWishlist(product.id),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (product.stock <= 0)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'OUT OF STOCK',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      'Rs. ${product.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: ElevatedButton(
                        onPressed: product.stock > 0
                            ? () => _addToCart(product)
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          'Add to Cart',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
