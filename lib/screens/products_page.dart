import 'package:flutter/material.dart';
import '../services/product_service.dart';
import '../models/product_model.dart';

class ProductsPage extends StatefulWidget {
  final String? category;
  final String? searchQuery;
  final String? sortBy;
  final String? filter;

  const ProductsPage({
    super.key,
    this.category,
    this.searchQuery,
    this.sortBy,
    this.filter,
  });

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final ProductService _productService = ProductService();
  bool _isGridView = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_buildTitle()),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Product>>(
        stream: widget.category != null && widget.category!.trim().isNotEmpty
            ? _productService.getProductsByCategory(widget.category!.trim())
            : _productService.getAllProducts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var products = List<Product>.from(snapshot.data!);
          products = _applySearchFilter(products);
          products = _applyFilter(products);
          products = _applySort(products);

          if (products.isEmpty) {
            final query = widget.searchQuery?.trim();
            return Center(
              child: Text(
                query != null && query.isNotEmpty
                    ? 'No products found for "$query"'
                    : 'No products found',
              ),
            );
          }

          return _isGridView
              ? _buildGridView(products)
              : _buildListView(products);
        },
      ),
    );
  }

  String _buildTitle() {
    final query = widget.searchQuery?.trim();
    if (query != null && query.isNotEmpty) {
      return 'Search: $query';
    }
    if (widget.category != null && widget.category!.trim().isNotEmpty) {
      return widget.category!.trim();
    }
    return 'All Products';
  }

  List<Product> _applySearchFilter(List<Product> products) {
    final query = widget.searchQuery?.trim().toLowerCase();
    if (query == null || query.isEmpty) return products;

    return products.where((product) {
      final fields = [
        product.name,
        product.description,
        product.category,
        product.brand ?? '',
        product.material ?? '',
        product.tags.join(' '),
        product.colors.join(' '),
        product.sizes.join(' '),
      ];

      return fields.any((value) => value.toLowerCase().contains(query));
    }).toList();
  }

  List<Product> _applyFilter(List<Product> products) {
    final filter = widget.filter?.trim().toLowerCase();
    if (filter == null || filter.isEmpty) return products;

    switch (filter) {
      case 'deals':
        return products.where((p) => p.rating >= 4.0).toList();
      case 'availability':
        return products.where((p) => p.stock > 0).toList();
      case 'rating':
        return products.where((p) => p.rating >= 4.0).toList();
      default:
        return products;
    }
  }

  List<Product> _applySort(List<Product> products) {
    final sortBy = widget.sortBy?.trim();
    if (sortBy == null || sortBy.isEmpty) return products;

    switch (sortBy) {
      case 'Popularity':
      case 'popularity':
        products.sort((a, b) => b.soldAmount.compareTo(a.soldAmount));
        break;
      case 'Price: Low to High':
      case 'price_low':
        products.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Price: High to Low':
      case 'price_high':
        products.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'Newest First':
      case 'newest':
        products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'Rating':
      case 'rating':
        products.sort((a, b) => b.rating.compareTo(a.rating));
        break;
    }

    return products;
  }

  Widget _buildGridView(List<Product> products) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        return _buildProductCard(products[index]);
      },
    );
  }

  Widget _buildListView(List<Product> products) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        return _buildProductListTile(products[index]);
      },
    );
  }

  Widget _buildProductCard(Product product) {
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
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.image, size: 50);
                            },
                          )
                        : const Icon(Icons.image, size: 50),
                  ),
                  if (product.arModelUrl != null)
                    Positioned(
                      top: 8,
                      right: 8,
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
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      Text(
                        ' ${product.rating.toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rs. ${product.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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

  Widget _buildProductListTile(Product product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          '/product-details',
          arguments: product,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: product.images.isNotEmpty
                    ? Image.network(
                        product.images.first,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.image, size: 40);
                        },
                      )
                    : const Icon(Icons.image, size: 40),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        Text(
                          ' ${product.rating.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const Spacer(),
                        Text(
                          'Rs. ${product.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (product.arModelUrl != null)
                const Icon(
                  Icons.view_in_ar,
                  color: Colors.blue,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
