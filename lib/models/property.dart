enum PropertyType {
  rental,
  condo,
  hostel,
}

enum PropertyStatus {
  available,
  rented,
  sold,
  pending,
}

class Property {
  final String id;
  final String title;
  final String description;
  final PropertyType type;
  final PropertyStatus status;
  final double price;
  final String currency;
  final String location;
  final double latitude;
  final double longitude;
  final List<String> imageUrls;
  final List<String> videoUrls;
  final int bedrooms;
  final int bathrooms;
  final double squareMeters;
  final List<String> amenities;
  final String managerId;
  final String managerName;
  final String managerPhone;
  final String managerEmail;
  final String managerWhatsApp;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isApproved;
  final String? rejectionReason;

  Property({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.price,
    this.currency = 'USD',
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.imageUrls,
    this.videoUrls = const [],
    required this.bedrooms,
    required this.bathrooms,
    required this.squareMeters,
    required this.amenities,
    required this.managerId,
    required this.managerName,
    required this.managerPhone,
    required this.managerEmail,
    required this.managerWhatsApp,
    required this.createdAt,
    required this.updatedAt,
    this.isApproved = false,
    this.rejectionReason,
  });

  // Convert Property to Map for API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'status': status.name,
      'price': price,
      'currency': currency,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrls': imageUrls,
      'videoUrls': videoUrls,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'squareMeters': squareMeters,
      'amenities': amenities,
      'managerId': managerId,
      'managerName': managerName,
      'managerPhone': managerPhone,
      'managerEmail': managerEmail,
      'managerWhatsApp': managerWhatsApp,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isApproved': isApproved,
      'rejectionReason': rejectionReason,
    };
  }

  // Create Property from API response
  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      type: PropertyType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PropertyType.rental,
      ),
      status: PropertyStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PropertyStatus.available,
      ),
      price: (json['price'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'USD',
      location: json['location'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      videoUrls: List<String>.from(json['videoUrls'] ?? []),
      bedrooms: json['bedrooms'] ?? 0,
      bathrooms: json['bathrooms'] ?? 0,
      squareMeters: (json['squareMeters'] ?? 0).toDouble(),
      amenities: List<String>.from(json['amenities'] ?? []),
      managerId: json['managerId'] ?? '',
      managerName: json['managerName'] ?? '',
      managerPhone: json['managerPhone'] ?? '',
      managerEmail: json['managerEmail'] ?? '',
      managerWhatsApp: json['managerWhatsApp'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
      isApproved: json['isApproved'] ?? false,
      rejectionReason: json['rejectionReason'],
    );
  }

  Property copyWith({
    String? id,
    String? title,
    String? description,
    PropertyType? type,
    PropertyStatus? status,
    double? price,
    String? currency,
    String? location,
    double? latitude,
    double? longitude,
    List<String>? imageUrls,
    List<String>? videoUrls,
    int? bedrooms,
    int? bathrooms,
    double? squareMeters,
    List<String>? amenities,
    String? managerId,
    String? managerName,
    String? managerPhone,
    String? managerEmail,
    String? managerWhatsApp,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isApproved,
    String? rejectionReason,
  }) {
    return Property(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrls: imageUrls ?? this.imageUrls,
      videoUrls: videoUrls ?? this.videoUrls,
      bedrooms: bedrooms ?? this.bedrooms,
      bathrooms: bathrooms ?? this.bathrooms,
      squareMeters: squareMeters ?? this.squareMeters,
      amenities: amenities ?? this.amenities,
      managerId: managerId ?? this.managerId,
      managerName: managerName ?? this.managerName,
      managerPhone: managerPhone ?? this.managerPhone,
      managerEmail: managerEmail ?? this.managerEmail,
      managerWhatsApp: managerWhatsApp ?? this.managerWhatsApp,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isApproved: isApproved ?? this.isApproved,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}
