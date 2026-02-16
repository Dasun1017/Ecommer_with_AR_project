import 'package:flutter/material.dart';
import '../services/product_service.dart';
import '../services/wishlist_service.dart';
import '../services/auth_service.dart';
import '../models/product_model.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final ProductService _productService = ProductService();
  final WishlistService _wishlistService = WishlistService();
  final AuthService _authService = AuthService();
  String? _selectedCategory;
  String _sortBy = 'newest';
  int _selectedIndex = 1;
  bool _isCategorySidebarExpanded = false;
  List<String> _wishlistIds = [];

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  void _loadWishlist() {
    final userId = _authService.currentUser?.uid;
    if (userId != null) {
      _wishlistService.getWishlist(userId).listen((wishlist) {
        if (mounted) {
          setState(() {
            _wishlistIds = wishlist;
          });
        }
      });
    }
  }

  Future<void> _toggleWishlist(String productId, String productName) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to add to wishlist')),
      );
      return;
    }

    final isInWishlist = _wishlistIds.contains(productId);
    try {
      await _wishlistService.toggleWishlist(userId, productId, isInWishlist);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isInWishlist
                  ? 'Removed from wishlist'
                  : '$productName added to wishlist',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchAndSort(),
            Expanded(
              child: Row(
                children: [
                  _buildCategorySidebar(),
                  Expanded(
                    child: _buildProductGrid(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pushReplacementNamed(context, '/home');
            },
            child: Image.asset(
              'assets/logo/tryverse_logo.png',
              height: 60,
              errorBuilder: (context, error, stackTrace) {
                return const Text(
                  'TryVerse',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 28),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndSort() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search any Product..',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                      suffixIcon: Icon(Icons.mic, color: Colors.grey.shade600),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: PopupMenuButton<String>(
                  icon: Row(
                    children: [
                      const Text(
                        'Sort',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.swap_vert, size: 18, color: Colors.grey.shade700),
                    ],
                  ),
                  onSelected: (value) {
                    setState(() {
                      _sortBy = value;
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'newest',
                      child: Text('Newest'),
                    ),
                    const PopupMenuItem(
                      value: 'price_low',
                      child: Text('Price: Low to High'),
                    ),
                    const PopupMenuItem(
                      value: 'price_high',
                      child: Text('Price: High to Low'),
                    ),
                    const PopupMenuItem(
                      value: 'rating',
                      child: Text('Rating'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Icon(Icons.filter_list, size: 20, color: Colors.grey.shade700),
              ),
            ],
          ),
          // Show selected category when sidebar is collapsed
          if (!_isCategorySidebarExpanded && _selectedCategory != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.category, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 6),
                    Text(
                      _selectedCategory!,
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = null;
                        });
                      },
                      child: Icon(Icons.close, size: 16, color: Colors.blue.shade700),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategorySidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _isCategorySidebarExpanded ? 120 : 50,
      color: Colors.grey[100],
      child: Column(
        children: [
          // Toggle button
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                _isCategorySidebarExpanded ? Icons.chevron_left : Icons.chevron_right,
                size: 24,
              ),
              onPressed: () {
                setState(() {
                  _isCategorySidebarExpanded = !_isCategorySidebarExpanded;
                });
              },
            ),
          ),
          // Categories list
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _productService.getCategories(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final categories = ['All', ...snapshot.data!];

                return ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = _selectedCategory == category ||
                        (category == 'All' && _selectedCategory == null);

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedCategory = category == 'All' ? null : category;
                        });
                      },
                      child: Tooltip(
                        message: category,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: _isCategorySidebarExpanded ? 16 : 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue[50] : null,
                            border: Border(
                              left: BorderSide(
                                color: isSelected ? Colors.blue : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          child: _isCategorySidebarExpanded
                              ? Text(
                                  category,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.blue : Colors.black,
                                    fontSize: 14,
                                  ),
                                )
                              : Icon(
                                  _getCategoryIcon(category),
                                  size: 24,
                                  color: isSelected ? Colors.blue : Colors.grey.shade600,
                                ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'all':
        return Icons.grid_view;
      
      // Clothing Categories
      case 'shirts':
        return Icons.checkroom;
      case 'hoodies':
      case 'hoodie':
        return Icons.checkroom_outlined;
      case 't-shirts':
      case 'tshirts':
      case 't-shirt':
        return Icons.checkroom;
      case 'pants':
      case 'jeans':
      case 'trousers':
        return Icons.accessibility_new;
      case 'dresses':
      case 'dress':
        return Icons.woman;
      case 'jackets':
      case 'jacket':
      case 'coats':
        return Icons.style;
      case 'activewear':
      case 'sportswear':
        return Icons.sports;
      
      // Footwear
      case 'shoes':
      case 'sneakers':
      case 'footwear':
        return Icons.backpack;
      case 'sandals':
        return Icons.beach_access;
      
      // Accessories
      case 'accessories':
        return Icons.watch;
      case 'watches':
      case 'watch':
        return Icons.watch;
      case 'bags':
      case 'handbags':
      case 'backpacks':
        return Icons.backpack;
      case 'jewelry':
      case 'jewellery':
        return Icons.diamond;
      case 'sunglasses':
      case 'glasses':
        return Icons.visibility;
      case 'hats':
      case 'caps':
        return Icons.checkroom;
      
      // Gender/Age Categories
      case 'men':
      case 'mens':
        return Icons.man;
      case 'women':
      case 'womens':
        return Icons.woman;
      case 'kids':
      case 'children':
        return Icons.child_care;
      case 'baby':
        return Icons.child_friendly;
      
      // General Categories
      case 'electronics':
      case 'gadgets':
        return Icons.devices;
      case 'fashion':
      case 'clothing':
        return Icons.checkroom;
      case 'home':
      case 'home & living':
        return Icons.home;
      case 'furniture':
        return Icons.weekend;
      case 'beauty':
      case 'cosmetics':
        return Icons.face;
      case 'sports':
      case 'fitness':
        return Icons.sports_basketball;
      case 'books':
        return Icons.book;
      case 'toys':
      case 'games':
        return Icons.toys;
      case 'grocery':
      case 'food':
        return Icons.shopping_basket;
      case 'pets':
        return Icons.pets;
      
      // Special Categories
      case 'sale':
      case 'offers':
        return Icons.local_offer;
      case 'new':
      case 'new arrivals':
        return Icons.fiber_new;
      case 'trending':
      case 'popular':
        return Icons.trending_up;
      
      default:
        return Icons.category;
    }
  }

  Widget _buildProductGrid() {
    return StreamBuilder<List<Product>>(
      stream: _selectedCategory != null
          ? _productService.getProductsByCategory(_selectedCategory!)
          : _productService.getAllProducts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var products = snapshot.data!;

        // Sort products
        products = _sortProducts(products);

        if (products.isEmpty) {
          return const Center(
            child: Text('No products found'),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.62,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            return _buildProductCard(products[index]);
          },
        );
      },
    );
  }

  List<Product> _sortProducts(List<Product> products) {
    switch (_sortBy) {
      case 'price_low':
        products.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_high':
        products.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'rating':
        products.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'newest':
      default:
        products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return products;
  }

  Widget _buildProductCard(Product product) {
    final isInWishlist = _wishlistIds.contains(product.id);
    
    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        '/product-details',
        arguments: product,
      ),
      child: Card(
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                    child: product.images.isNotEmpty
                        ? Image.network(
                            product.images.first,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              print('Image load error for ${product.name}: $error');
                              print('Image URL: ${product.images.isNotEmpty ? product.images.first : "No URL"}');
                              return const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                    SizedBox(height: 4),
                                    Text('Image not available', style: TextStyle(fontSize: 9), textAlign: TextAlign.center),
                                    Text('(Check console)', style: TextStyle(fontSize: 8, color: Colors.grey)),
                                  ],
                                ),
                              );
                            },
                          )
                        : const Icon(Icons.image, size: 50),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _toggleWishlist(product.id, product.name),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          isInWishlist ? Icons.favorite : Icons.favorite_border,
                          color: isInWishlist ? Colors.red : Colors.grey[600],
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  if (product.arModelUrl != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.view_in_ar,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 12, color: Colors.amber),
                      Text(
                        ' ${product.rating.toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Rs. ${product.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/home');
              break;
            case 1:
              // Shop - already here
              break;
            case 2:
              // Try AR - will be implemented later
              break;
            case 3:
              Navigator.pushNamed(context, '/cart');
              break;
            case 4:
              Navigator.pushNamed(context, '/profile');
              break;
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.blue.shade100,
        selectedItemColor: Colors.blue.shade700,
        unselectedItemColor: Colors.grey.shade600,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        elevation: 0,
        items: [
          BottomNavigationBarItem(
            icon: _selectedIndex == 0
                ? Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.home, color: Colors.blue.shade900, size: 24),
                  )
                : const Icon(Icons.home, size: 24),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: _selectedIndex == 1
                ? Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.shopping_bag, color: Colors.blue.shade900, size: 24),
                  )
                : const Icon(Icons.shopping_bag, size: 24),
            label: 'Shop',
          ),
          BottomNavigationBarItem(
            icon: _selectedIndex == 2
                ? Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.camera_alt, color: Colors.blue.shade900, size: 24),
                  )
                : const Icon(Icons.camera_alt, size: 24),
            label: 'Try AR',
          ),
          BottomNavigationBarItem(
            icon: _selectedIndex == 3
                ? Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.shopping_cart_outlined, color: Colors.blue.shade900, size: 24),
                  )
                : const Icon(Icons.shopping_cart_outlined, size: 24),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: _selectedIndex == 4
                ? Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person, color: Colors.blue.shade900, size: 24),
                  )
                : const Icon(Icons.person, size: 24),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
