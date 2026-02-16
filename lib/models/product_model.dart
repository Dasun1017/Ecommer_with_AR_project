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
    // Handle images - Firebase has image_2d and image_3d instead of images array
    List<String> imagesList = [];
    if (json['images'] != null) {
      if (json['images'] is List) {
        imagesList = List<String>.from(json['images'] as List);
      }
    } else {
      // Handle separate image fields from Firebase - can be string or array
      if (json['image_2d'] != null) {
        if (json['image_2d'] is List) {
          // image_2d is an array
          List<String> images2d = List<String>.from(json['image_2d'] as List);
          print('Loading image_2d array: ${images2d.length} images');
          imagesList.addAll(images2d);
        } else if (json['image_2d'] is String && (json['image_2d'] as String).isNotEmpty) {
          // image_2d is a single string
          String imageUrl = json['image_2d'] as String;
          print('Loading image_2d: $imageUrl');
          imagesList.add(imageUrl);
        }
      }
      
      if (json['image_3d'] != null) {
        if (json['image_3d'] is List) {
          // image_3d is an array
          List<String> images3d = List<String>.from(json['image_3d'] as List);
          print('Loading image_3d array: ${images3d.length} images');
          imagesList.addAll(images3d);
        } else if (json['image_3d'] is String && (json['image_3d'] as String).isNotEmpty) {
          // image_3d is a single string
          String imageUrl = json['image_3d'] as String;
          print('Loading image_3d: $imageUrl');
          imagesList.add(imageUrl);
        }
      }
    }
    
    // Handle colors - Firebase has single 'color' field instead of 'colors' array
    List<String> colorsList = [];
    if (json['colors'] != null && json['colors'] is List) {
      colorsList = List<String>.from(json['colors'] as List);
    } else if (json['color'] != null) {
      if (json['color'] is String && (json['color'] as String).isNotEmpty) {
        colorsList.add(json['color'] as String);
      } else if (json['color'] is List) {
        colorsList = List<String>.from(json['color'] as List);
      }
    }
    
    // Handle sizes - Firebase has 'size' instead of 'sizes'
    List<String> sizesList = [];
    if (json['sizes'] != null && json['sizes'] is List) {
      sizesList = List<String>.from(json['sizes'] as List);
    } else if (json['size'] != null && json['size'] is List) {
      sizesList = List<String>.from(json['size'] as List);
    }
    
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      category: json['category'] as String,
      images: imagesList,
      arModelUrl: json['arModelUrl'] as String?,
      stock: (json['stock'] ?? json['stock_amount'] ?? 0) as int,
      rating: (json['rating'] ?? json['reviews'] ?? 0.0) is num 
          ? ((json['rating'] ?? json['reviews']) as num).toDouble() 
          : 0.0,
      reviewCount: json['reviewCount'] as int? ?? json['sold_amount'] as int? ?? 0,
      colors: colorsList,
      sizes: sizesList,
      isFeatured: json['isFeatured'] as bool? ?? false,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
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
