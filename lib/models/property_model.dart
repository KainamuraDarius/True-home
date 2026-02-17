enum PropertyType { sale, rent, hostel }

enum PropertyStatus { pending, approved, rejected, removed }

enum PricingPeriod { month, semester }

class RoomType {
  final String name; // e.g., "Single Room", "Double Room", "Triple Room"
  final double price;
  final PricingPeriod pricingPeriod;
  final String description;
  final int totalRooms; // Total number of rooms of this type
  final int availableRooms; // Currently available rooms

  RoomType({
    required this.name,
    required this.price,
    required this.pricingPeriod,
    this.description = '',
    this.totalRooms = 0,
    int? availableRooms,
  }) : availableRooms =
           availableRooms ?? totalRooms; // Default available = total

  bool get isFull => availableRooms <= 0;
  bool get hasAvailability => availableRooms > 0;
  int get bookedRooms => totalRooms - availableRooms;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'pricingPeriod': pricingPeriod.name,
      'description': description,
      'totalRooms': totalRooms,
      'availableRooms': availableRooms,
    };
  }

  factory RoomType.fromJson(Map<String, dynamic> json) {
    return RoomType(
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      pricingPeriod: PricingPeriod.values.firstWhere(
        (e) => e.name == json['pricingPeriod'],
        orElse: () => PricingPeriod.month,
      ),
      description: json['description'] ?? '',
      totalRooms: json['totalRooms'] ?? 0,
      availableRooms: json['availableRooms'],
    );
  }

  RoomType copyWith({
    String? name,
    double? price,
    PricingPeriod? pricingPeriod,
    String? description,
    int? totalRooms,
    int? availableRooms,
  }) {
    return RoomType(
      name: name ?? this.name,
      price: price ?? this.price,
      pricingPeriod: pricingPeriod ?? this.pricingPeriod,
      description: description ?? this.description,
      totalRooms: totalRooms ?? this.totalRooms,
      availableRooms: availableRooms ?? this.availableRooms,
    );
  }
}

class PropertyModel {
  final String id;
  final String title;
  final String category; // Property category (Flat, Bungalow, Condo, Villa, Apartment, Studio room)
  final String description;
  final PropertyType type;
  final double price;
  final String location;
  final String address;
  final int bedrooms;
  final int bathrooms;
  final double areaSqft;
  final String areaUnit; // 'sqft' or 'sqm'
  final String currency; // 'UGX' or 'USD'
  final List<String> imageUrls;
  final String ownerId;
  final String ownerName;
  final String ownerEmail;
  final String companyName;
  final String agentName;
  final String? agentProfileImageUrl;
  final String contactPhone;
  final String whatsappPhone;
  final String contactEmail;
  final PropertyStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? rejectionReason;
  final List<String> amenities;
  final String? university; // For student hostels
  final List<RoomType> roomTypes; // For student hostels
  final String?
  paymentInstructions; // Optional payment instructions for hostels (deposit info, bank account, etc.)
  final bool isNewProject; // Mark as new project for developers
  final bool hasActivePromotion; // Whether promotion is active
  final DateTime? promotionEndDate; // When promotion ends
  final bool promotionRequested; // Agent requested spotlight promotion
  final double? inspectionFee; // Custom inspection fee for rental properties
  final bool isActive; // Whether property is active (true) or sold/deactivated (false)
  final int viewCount; // Number of times this property has been viewed

  PropertyModel({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.type,
    required this.price,
    required this.location,
    required this.address,
    required this.bedrooms,
    required this.bathrooms,
    required this.areaSqft,
    this.areaUnit = 'sqft', // Default to sqft for backward compatibility
    this.currency = 'UGX', // Default to UGX for backward compatibility
    required this.imageUrls,
    required this.ownerId,
    required this.ownerName,
    required this.ownerEmail,
    required this.companyName,
    required this.agentName,
    this.agentProfileImageUrl,
    required this.contactPhone,
    required this.whatsappPhone,
    required this.contactEmail,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.rejectionReason,
    this.amenities = const [],
    this.university,
    this.roomTypes = const [],
    this.paymentInstructions,
    this.isNewProject = false,
    this.hasActivePromotion = false,
    this.promotionEndDate,
    this.promotionRequested = false,
    this.inspectionFee,
    this.isActive = true, // Default to active
    this.viewCount = 0, // Default to 0 views
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'description': description,
      'type': type.name,
      'price': price,
      'location': location,
      'address': address,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'areaSqft': areaSqft,
      'areaUnit': areaUnit,
      'currency': currency,
      'imageUrls': imageUrls,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'ownerEmail': ownerEmail,
      'companyName': companyName,
      'agentName': agentName,
      'agentProfileImageUrl': agentProfileImageUrl,
      'contactPhone': contactPhone,
      'whatsappPhone': whatsappPhone,
      'contactEmail': contactEmail,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'rejectionReason': rejectionReason,
      'amenities': amenities,
      'university': university,
      'roomTypes': roomTypes.map((rt) => rt.toJson()).toList(),
      'paymentInstructions': paymentInstructions,
      'isNewProject': isNewProject,
      'hasActivePromotion': hasActivePromotion,
      'promotionEndDate': promotionEndDate?.toIso8601String(),
      'promotionRequested': promotionRequested,
      'inspectionFee': inspectionFee,
      'isActive': isActive,
      'viewCount': viewCount,
    };
  }

  factory PropertyModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return PropertyModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      category: json['category'] ?? 'Flat', // Default to Flat for old data
      description: json['description'] ?? '',
      type: PropertyType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PropertyType.sale,
      ),
      price: (json['price'] ?? 0).toDouble(),
      location: json['location'] ?? '',
      address: json['address'] ?? '',
      bedrooms: json['bedrooms'] ?? 0,
      bathrooms: json['bathrooms'] ?? 0,
      areaSqft: (json['areaSqft'] ?? 0).toDouble(),
      areaUnit: json['areaUnit'] ?? 'sqft', // Default to sqft for old data
      currency: json['currency'] ?? 'UGX', // Default to UGX for old data
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      ownerId: json['ownerId'] ?? '',
      ownerName: json['ownerName'] ?? '',
      ownerEmail: json['ownerEmail'] ?? '',
      companyName: json['companyName'] ?? '',
      agentName: json['agentName'] ?? '',
      agentProfileImageUrl: json['agentProfileImageUrl'],
      contactPhone: json['contactPhone'] ?? '',
      whatsappPhone: json['whatsappPhone'] ?? '',
      contactEmail: json['contactEmail'] ?? '',
      status: PropertyStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PropertyStatus.pending,
      ),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : now,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : now,
      rejectionReason: json['rejectionReason'],
      amenities: List<String>.from(json['amenities'] ?? []),
      university: json['university'],
      roomTypes: json['roomTypes'] != null
          ? (json['roomTypes'] as List)
                .map((rt) => RoomType.fromJson(rt))
                .toList()
          : [],
      paymentInstructions: json['paymentInstructions'],
      isNewProject: json['isNewProject'] ?? false,
      hasActivePromotion: json['hasActivePromotion'] ?? false,
      promotionEndDate: json['promotionEndDate'] != null
          ? DateTime.parse(json['promotionEndDate'])
          : null,
      promotionRequested: json['promotionRequested'] ?? false,
      inspectionFee: json['inspectionFee']?.toDouble(),
      isActive: json['isActive'] ?? true, // Default to active for old data
      viewCount: json['viewCount'] ?? 0, // Default to 0 for old data
    );
  }

  PropertyModel copyWith({
    String? id,
    String? title,
    String? category,
    String? description,
    PropertyType? type,
    double? price,
    String? location,
    String? address,
    int? bedrooms,
    int? bathrooms,
    double? areaSqft,
    String? areaUnit,
    String? currency,
    List<String>? imageUrls,
    String? ownerId,
    String? ownerName,
    String? ownerEmail,
    String? companyName,
    String? agentName,
    String? agentProfileImageUrl,
    String? contactPhone,
    String? whatsappPhone,
    String? contactEmail,
    PropertyStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? rejectionReason,
    List<String>? amenities,
    String? university,
    List<RoomType>? roomTypes,
    String? paymentInstructions,
    bool? isNewProject,
    bool? hasActivePromotion,
    DateTime? promotionEndDate,
    double? inspectionFee,
    bool? isActive,
  }) {
    return PropertyModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      type: type ?? this.type,
      price: price ?? this.price,
      location: location ?? this.location,
      address: address ?? this.address,
      bedrooms: bedrooms ?? this.bedrooms,
      bathrooms: bathrooms ?? this.bathrooms,
      areaSqft: areaSqft ?? this.areaSqft,
      areaUnit: areaUnit ?? this.areaUnit,
      currency: currency ?? this.currency,
      imageUrls: imageUrls ?? this.imageUrls,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      companyName: companyName ?? this.companyName,
      agentName: agentName ?? this.agentName,
      agentProfileImageUrl: agentProfileImageUrl ?? this.agentProfileImageUrl,
      contactPhone: contactPhone ?? this.contactPhone,
      whatsappPhone: whatsappPhone ?? this.whatsappPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      amenities: amenities ?? this.amenities,
      university: university ?? this.university,
      roomTypes: roomTypes ?? this.roomTypes,
      paymentInstructions: paymentInstructions ?? this.paymentInstructions,
      isNewProject: isNewProject ?? this.isNewProject,
      hasActivePromotion: hasActivePromotion ?? this.hasActivePromotion,
      promotionEndDate: promotionEndDate ?? this.promotionEndDate,
      inspectionFee: inspectionFee ?? this.inspectionFee,
      isActive: isActive ?? this.isActive,
    );
  }
}
