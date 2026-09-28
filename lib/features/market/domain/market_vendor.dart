class MarketVendor {
  const MarketVendor({
    required this.id,
    required this.name,
    required this.category,
    required this.rating,
    required this.isVerified,
    required this.distance,
    required this.imageUrl,
    this.stallNumber,
    this.marketSection,
    this.reviewCount = 0,
    this.topReviewText,
    this.isOpen = true,
    this.tags,
  });

  final String id;
  final String name;
  final String category;
  final double rating;
  final bool isVerified;
  final String distance;
  final String imageUrl;
  final String? stallNumber;
  final String? marketSection;
  final int reviewCount;
  final String? topReviewText;
  final bool isOpen;
  final List<String>? tags;

  factory MarketVendor.fromMap(Map<String, dynamic> map) {
    return MarketVendor(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Stall Holder',
      category: map['category'] as String? ?? 'General',
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      isVerified: map['isVerified'] as bool? ?? false,
      distance: map['distance'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      stallNumber: map['stallNumber'] as String?,
      marketSection: map['marketSection'] as String?,
      reviewCount: map['reviewCount'] as int? ?? 0,
      topReviewText: map['topReviewText'] as String?,
      isOpen: map['isOpen'] as bool? ?? true,
      tags: (map['tags'] as List?)?.map((e) => e as String).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'rating': rating,
      'isVerified': isVerified,
      'distance': distance,
      'imageUrl': imageUrl,
      if (stallNumber != null) 'stallNumber': stallNumber,
      'reviewCount': reviewCount,
      if (topReviewText != null) 'topReviewText': topReviewText,
      'isOpen': isOpen,
      if (tags != null) 'tags': tags,
    };
  }

  MarketVendor copyWith({
    String? id,
    String? name,
    String? category,
    double? rating,
    bool? isVerified,
    String? distance,
    String? imageUrl,
    String? stallNumber,
    String? marketSection,
    int? reviewCount,
    String? topReviewText,
    bool? isOpen,
    List<String>? tags,
  }) {
    return MarketVendor(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      rating: rating ?? this.rating,
      isVerified: isVerified ?? this.isVerified,
      distance: distance ?? this.distance,
      imageUrl: imageUrl ?? this.imageUrl,
      stallNumber: stallNumber ?? this.stallNumber,
      marketSection: marketSection ?? this.marketSection,
      reviewCount: reviewCount ?? this.reviewCount,
      topReviewText: topReviewText ?? this.topReviewText,
      isOpen: isOpen ?? this.isOpen,
      tags: tags ?? this.tags,
    );
  }
}
