class VendorProfile {
  const VendorProfile({
    required this.id,
    required this.name,
    required this.category,
    required this.rating,
    required this.reviewCount,
    required this.isOpen,
    required this.stallLocation,
    required this.imageUrl,
    required this.avatarUrl,
    this.phoneNumber,
  });

  final String id;
  final String name;
  final String category;
  final double rating;
  final int reviewCount;
  final bool isOpen;
  final String stallLocation;
  final String imageUrl;
  final String avatarUrl;
  final String? phoneNumber;
}
