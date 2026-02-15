class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final List<String> images;
  final String? arModelUrl;
  final int stock;
  final double rating;
  final int reviewCount;
  final List<String> colors;
  final List<String> sizes;
  final bool isFeatured;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.images,
    this.arModelUrl,
    required this.stock,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.colors = const [],
    this.sizes = const [],
    this.isFeatured = false,
    required this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      category: json['category'] as String,
      images: List<String>.from(json['images'] as List),
      arModelUrl: json['arModelUrl'] as String?,
      stock: json['stock'] as int,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      colors: List<String>.from(json['colors'] as List? ?? []),
      sizes: List<String>.from(json['sizes'] as List? ?? []),
      isFeatured: json['isFeatured'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'images': images,
      'arModelUrl': arModelUrl,
      'stock': stock,
      'rating': rating,
      'reviewCount': reviewCount,
      'colors': colors,
      'sizes': sizes,
      'isFeatured': isFeatured,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? category,
    List<String>? images,
    String? arModelUrl,
    int? stock,
    double? rating,
    int? reviewCount,
    List<String>? colors,
    List<String>? sizes,
    bool? isFeatured,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      images: images ?? this.images,
      arModelUrl: arModelUrl ?? this.arModelUrl,
      stock: stock ?? this.stock,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      colors: colors ?? this.colors,
      sizes: sizes ?? this.sizes,
      isFeatured: isFeatured ?? this.isFeatured,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
