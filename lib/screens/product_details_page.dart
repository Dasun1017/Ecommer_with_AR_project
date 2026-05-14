import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/cart_service.dart';
import '../services/auth_service.dart';
import '../services/wishlist_service.dart';
import '../models/cart_item_model.dart';
import 'ar_tryon_page.dart';

class ProductDetailsPage extends StatefulWidget {
  final Product product;

  const ProductDetailsPage({super.key, required this.product});

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  final CartService _cartService = CartService();
  final AuthService _authService = AuthService();
  final WishlistService _wishlistService = WishlistService();
  int _selectedImageIndex = 0;
  final int _quantity = 1;
  String? _selectedColor;
  String? _selectedSize;
  List<int> _validImageIndices = [];
  int _selectedTab = 0;
  bool _isInWishlist = false;
  
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _overviewKey = GlobalKey();
  final GlobalKey _ratingsKey = GlobalKey();
  final GlobalKey _detailsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.product.colors.isNotEmpty) {
      _selectedColor = widget.product.colors.first;
    }
    if (widget.product.sizes.isNotEmpty) {
      _selectedSize = widget.product.sizes.first;
    }
    // Initialize with all image indices, they will be filtered as they load/fail
    _validImageIndices = List.generate(widget.product.images.length, (index) => index);
    _checkWishlistStatus();
  }

  void _checkWishlistStatus() async {
    final userId = _authService.currentUser?.uid;
    if (userId != null) {
      final isInWishlist = await _wishlistService.isInWishlist(userId, widget.product.id);
      if (!mounted) return;
      setState(() {
        _isInWishlist = isInWishlist;
      });
    }
  }

  Future<void> _goToARTryOn() async {
    final userId = _authService.currentUser?.uid;
    
    try {
      final cartItems = userId != null ? await _cartService.getCartItems(userId).first : <CartItem>[];
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ARTryOnPage(
            product: widget.product,
            cartItems: cartItems,
            selectedSize: _selectedSize,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening AR: $e')),
      );
    }
  }

  Future<void> _toggleWishlist() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to add to wishlist')),
      );
      return;
    }

    try {
      await _wishlistService.toggleWishlist(userId, widget.product.id, _isInWishlist);
      if (!mounted) return;
      setState(() {
        _isInWishlist = !_isInWishlist;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isInWishlist
                ? '${widget.product.name} added to wishlist'
                : 'Removed from wishlist',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(GlobalKey key, int tabIndex) {
    setState(() {
      _selectedTab = tabIndex;
    });
    
    final context = key.currentContext;
    if (context != null) {
      final box = context.findRenderObject() as RenderBox;
      final position = box.localToGlobal(Offset.zero, ancestor: null);
      final offset = _scrollController.offset + position.dy - 100; // 100px offset for app bar and tabs
      
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
          ),
          child: const TextField(
            decoration: InputDecoration(
              hintText: 'Search any Product..',
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, size: 20),
              suffixIcon: Icon(Icons.mic, size: 20),
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        actions: [
          _buildCartIconWithBadge(),
        ],
      ),
      body: Column(
        children: [
          _buildProductTitle(),
          _buildTabs(),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOverviewTab(),
                  _buildRatingsTab(),
                  _buildProductDetailsTab(),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildProductTitle() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: Text(
        widget.product.name,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
        child: Row(
          children: [
            Expanded(child: _buildTab('Overview', 0)),
            const SizedBox(width: 8),
            Expanded(child: _buildTab('Ratings', 1)),
            const SizedBox(width: 8),
            Expanded(child: _buildTab('Product Details', 2)),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        final key = index == 0 ? _overviewKey : (index == 1 ? _ratingsKey : _detailsKey);
        _scrollToSection(key, index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey[300] : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? Colors.black : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildImageGallery() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          height: MediaQuery.of(context).size.height * 0.38,
          constraints: const BoxConstraints(minHeight: 220, maxHeight: 380),
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              Center(
                child: widget.product.images.isNotEmpty
                    ? Image.network(
                        widget.product.images[_selectedImageIndex],
                        fit: BoxFit.contain,
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
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                _validImageIndices.remove(_selectedImageIndex);
                                if (_validImageIndices.isNotEmpty) {
                                  _selectedImageIndex = _validImageIndices.first;
                                }
                              });
                            }
                          });
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, size: 80, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Image not available'),
                              ],
                            ),
                          );
                        },
                      )
                    : const Icon(Icons.image, size: 100),
              ),
              if (_validImageIndices.length > 1)
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.8),
                      ),
                      onPressed: () {
                        setState(() {
                          final currentListIndex = _validImageIndices.indexOf(_selectedImageIndex);
                          if (currentListIndex > 0) {
                            _selectedImageIndex = _validImageIndices[currentListIndex - 1];
                          }
                        });
                      },
                    ),
                  ),
                ),
              if (_validImageIndices.length > 1)
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.8),
                      ),
                      onPressed: () {
                        setState(() {
                          final currentListIndex = _validImageIndices.indexOf(_selectedImageIndex);
                          if (currentListIndex < _validImageIndices.length - 1) {
                            _selectedImageIndex = _validImageIndices[currentListIndex + 1];
                          }
                        });
                      },
                    ),
                  ),
                ),
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[700],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.view_in_ar, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'AR',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_validImageIndices.length > 1)
          SizedBox(
            height: (MediaQuery.of(context).size.height * 0.10).clamp(60.0, 100.0),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              itemCount: _validImageIndices.length,
              itemBuilder: (context, listIndex) {
                final index = _validImageIndices[listIndex];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedImageIndex = index;
                    });
                  },
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.155,
                    constraints: const BoxConstraints(minWidth: 44, maxWidth: 72),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _selectedImageIndex == index
                            ? Colors.blue
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        widget.product.images[index],
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          // Remove this broken image from valid images
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                _validImageIndices.remove(index);
                                if (_selectedImageIndex == index && _validImageIndices.isNotEmpty) {
                                  _selectedImageIndex = _validImageIndices.first;
                                }
                              });
                            }
                          });
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.broken_image,
                              size: 30,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildProductInfo() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LKR ${widget.product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        Text(
                          ' ${widget.product.rating.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          ' ( ${widget.product.reviewCount} )',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                        Text(
                          ' | ${widget.product.stock}Sold',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isInWishlist ? Colors.red : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    _isInWishlist ? Icons.favorite : Icons.favorite_border,
                    color: _isInWishlist ? Colors.red : Colors.grey[600],
                    size: 28,
                  ),
                  onPressed: _toggleWishlist,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityAndDescription() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        widget.product.description,
        style: TextStyle(
          color: Colors.grey[700],
          height: 1.5,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildColorSelector() {
    if (widget.product.colors.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Color Family',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: widget.product.colors.map((colorName) {
              final isSelected = _selectedColor == colorName;
              final colorValue = _getColorFromName(colorName);
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedColor = colorName;
                  });
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorValue,
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey[300]!,
                      width: isSelected ? 3 : 2,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 24,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _getColorFromName(String colorName) {
    final lowerName = colorName.toLowerCase().trim();
    
    // Basic colors
    if (lowerName.contains('black')) return Colors.black;
    if (lowerName.contains('white')) return Colors.white;
    if (lowerName.contains('red')) return Colors.red;
    if (lowerName.contains('blue')) return Colors.blue;
    if (lowerName.contains('green')) return Colors.green;
    if (lowerName.contains('yellow')) return Colors.yellow;
    if (lowerName.contains('orange')) return Colors.orange;
    if (lowerName.contains('purple')) return Colors.purple;
    if (lowerName.contains('pink')) return Colors.pink;
    if (lowerName.contains('brown')) return Colors.brown;
    if (lowerName.contains('grey') || lowerName.contains('gray')) return Colors.grey;
    
    // Shades
    if (lowerName.contains('navy')) return const Color(0xFF000080);
    if (lowerName.contains('maroon')) return const Color(0xFF800000);
    if (lowerName.contains('olive')) return const Color(0xFF808000);
    if (lowerName.contains('teal')) return Colors.teal;
    if (lowerName.contains('cyan')) return Colors.cyan;
    if (lowerName.contains('magenta')) return Colors.pinkAccent;
    if (lowerName.contains('lime')) return Colors.lime;
    if (lowerName.contains('indigo')) return Colors.indigo;
    if (lowerName.contains('beige')) return const Color(0xFFF5F5DC);
    if (lowerName.contains('khaki')) return const Color(0xFFC3B091);
    if (lowerName.contains('cream')) return const Color(0xFFFFFDD0);
    
    // Default fallback
    return Colors.grey[400]!;
  }

  Widget _buildSizeSelector() {
    if (widget.product.sizes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose Size',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.product.sizes.map((size) {
              final isSelected = _selectedSize == size;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedSize = size;
                  });
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.black : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.grey[300]!,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      size,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Tab Content Builders
  Widget _buildOverviewTab() {
    return Column(
      key: _overviewKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildImageGallery(),
        _buildProductInfo(),
        _buildQuantityAndDescription(),
        _buildSizeSelector(),
        _buildColorSelector(),
      ],
    );
  }

  Widget _buildRatingsTab() {
    return Column(
      key: _ratingsKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.grey[100],
          child: const Text(
            'RATINGS & REVIEWS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rating Summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < widget.product.rating.floor()
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 20,
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.product.reviewCount} reviews',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _buildRatingBar(5, 0.7),
                      _buildRatingBar(4, 0.2),
                      _buildRatingBar(3, 0.06),
                      _buildRatingBar(2, 0.03),
                      _buildRatingBar(1, 0.01),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Reviews Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Customer Reviews',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Write a Review'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Sample Reviews
          _buildReviewCard(
            'John Doe',
            5.0,
            'Great quality hoodie! Very comfortable and the graphics are amazing.',
            '2 days ago',
          ),
          _buildReviewCard(
            'Sarah Smith',
            4.0,
            'Love the design. Fits well but slightly larger than expected.',
            '1 week ago',
          ),
          _buildReviewCard(
            'Mike Johnson',
            5.0,
            'Excellent product! Fast delivery and perfect packaging.',
            '2 weeks ago',
          ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRatingBar(int stars, double percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$stars', style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          const Icon(Icons.star, size: 12, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(percentage * 100).toInt()}%',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(String name, double rating, String comment, String date) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue[700],
                child: Text(
                  name[0],
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < rating.floor() ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 14,
                        );
                      }),
                    ),
                  ],
                ),
              ),
              Text(
                date,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            comment,
            style: TextStyle(
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductDetailsTab() {
    return Column(
      key: _detailsKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.grey[100],
          child: const Text(
            'PRODUCT DETAILS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Product Specifications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Product Name', widget.product.name),
              _buildDetailRow('Category', widget.product.category),
              _buildDetailRow('Price', 'LKR ${widget.product.price.toStringAsFixed(2)}'),
              _buildDetailRow('Stock Available', '${widget.product.stock} units'),
              if (widget.product.colors.isNotEmpty)
                _buildDetailRow('Available Colors', widget.product.colors.join(', ')),
              if (widget.product.sizes.isNotEmpty)
                _buildDetailRow('Available Sizes', widget.product.sizes.join(', ')),
              _buildDetailRow('Rating', '${widget.product.rating.toStringAsFixed(1)} / 5.0'),
              _buildDetailRow('Total Reviews', '${widget.product.reviewCount}'),
              _buildDetailRow('Product ID', widget.product.id),
              if (widget.product.arModelUrl != null)
                _buildDetailRow('AR Model', 'Available'),
              const SizedBox(height: 24),
              const Text(
                'Product Description',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.product.description,
                style: TextStyle(
                  color: Colors.grey[700],
                  height: 1.6,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Features',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildFeatureItem('High-quality material'),
              _buildFeatureItem('Available in multiple colors and sizes'),
              _buildFeatureItem('AR view supported for better visualization'),
              _buildFeatureItem('Fast shipping and secure packaging'),
              _buildFeatureItem('Easy returns within 30 days'),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Additional Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• Free shipping on orders above LKR 5000\n'
                      '• Cash on delivery available\n'
                      '• 100% authentic products\n'
                      '• Customer support available 24/7',
                      style: TextStyle(
                        color: Colors.blue[800],
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              feature,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.attach_money, size: 18),
              label: const Text('Buy Now'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: widget.product.stock > 0 ? _buyNow : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.shopping_cart_outlined, size: 18),
              label: const Text('Go to cart'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: widget.product.stock > 0
                  ? () {
                      _addToCart();
                      Navigator.pushNamed(context, '/cart');
                    }
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt, size: 18),
              label: const Text('Try AR'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _goToARTryOn,
            ),
          ),
        ],
      ),
    );
  }

  void _addToCart() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    final cartItem = CartItem(
      id: widget.product.id,
      productId: widget.product.id,
      productName: widget.product.name,
      productImage: widget.product.images.first,
      price: widget.product.price,
      quantity: _quantity,
      selectedColor: _selectedColor,
      selectedSize: _selectedSize,
    );

    try {
      await _cartService.addToCart(userId, cartItem);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to cart successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _buyNow() {
    _addToCart();
    Navigator.pushNamed(context, '/cart');
  }

  Widget _buildCartIconWithBadge() {
    final userId = _authService.currentUser?.uid;
    
    if (userId == null) {
      return IconButton(
        icon: const Icon(Icons.shopping_cart_outlined),
        onPressed: () => Navigator.pushNamed(context, '/cart'),
      );
    }

    return StreamBuilder<List<dynamic>>(
      stream: _cartService.getCartItems(userId),
      builder: (context, snapshot) {
        final itemCount = snapshot.hasData ? snapshot.data!.length : 0;

        if (itemCount == 0) {
          return IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => Navigator.pushNamed(context, '/cart'),
          );
        }

        return IconButton(
          icon: Badge(
            label: Text('$itemCount'),
            backgroundColor: Colors.red,
            textColor: Colors.white,
            child: const Icon(Icons.shopping_cart_outlined),
          ),
          onPressed: () => Navigator.pushNamed(context, '/cart'),
        );
      },
    );
  }
}
