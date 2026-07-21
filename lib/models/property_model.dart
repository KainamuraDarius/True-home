import 'package:cloud_firestore/cloud_firestore.dart';

enum PropertyType { sale, rent, hostel, commercial }

enum PropertyStatus { pending, approved, rejected, removed }

enum PricingPeriod { month, semester }

enum GenderPolicy { maleOnly, femaleOnly, mixed }

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
  /// Promotional Add-ons
  final bool featuredPromotion;
  final bool developerAdvertising;
  final String id;
  final String title;
  final String
  category; // Property category (Flat, Bungalow, Condo, Villa, Apartment, Studio room)
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
  final String?
  rentalUnit; // For commercial property pricing: per hour/day/week/month/year
  final List<String> imageUrls;
  final String ownerId;
  final String? organizationId;
  final String? createdByUserId;
  final String ownerName;
  final String ownerEmail;
  final String? ownerEmailLower;
  final String? ownerPhoneKey;
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
  final GenderPolicy
  genderPolicy; // For hostels: male only, female only, or mixed
  final String?
  roomStructure; // For hostels: 'Self Contained' or 'Not Self Contained'
  final bool isNewProject; // Mark as new project for developers
  final bool hasActivePromotion; // Whether promotion is active
  final DateTime? promotionEndDate; // When promotion ends
  final bool promotionRequested; // Agent requested spotlight promotion
  final double? inspectionFee; // Custom inspection fee for rental properties
  final bool
  isActive; // Whether property is active (true) or sold/deactivated (false)
  final int viewCount; // Number of times this property has been viewed
  final bool
  showPriceToCustomers; // Whether customers should see this property's price

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
    this.rentalUnit,
    required this.imageUrls,
    required this.ownerId,
    this.organizationId,
    this.createdByUserId,
    required this.ownerName,
    required this.ownerEmail,
    this.ownerEmailLower,
    this.ownerPhoneKey,
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
    this.genderPolicy = GenderPolicy.mixed,
    this.roomStructure,
    this.isNewProject = false,
    this.hasActivePromotion = false,
    this.promotionEndDate,
    this.promotionRequested = false,
    this.inspectionFee,
    this.isActive = true, // Default to active
    this.viewCount = 0, // Default to 0 views
    this.featuredPromotion = false,
    this.developerAdvertising = false,
    this.showPriceToCustomers = true,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
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
      'createdByUserId': createdByUserId ?? ownerId,
      'ownerName': ownerName,
      'ownerEmail': ownerEmail,
      'ownerEmailLower': ownerEmailLower,
      'ownerPhoneKey': ownerPhoneKey,
      'companyName': companyName,
      'agentName': agentName,
      'agentProfileImageUrl': agentProfileImageUrl,
      'contactPhone': contactPhone,
      'whatsappPhone': whatsappPhone,
      'contactEmail': contactEmail,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'rejectionReason': rejectionReason,
      'amenities': amenities,
      'university': university,
      'roomTypes': roomTypes.map((rt) => rt.toJson()).toList(),
      'paymentInstructions': paymentInstructions,
      'genderPolicy': genderPolicy.name,
      'roomStructure': roomStructure,
      'isNewProject': isNewProject,
      'hasActivePromotion': hasActivePromotion,
      'promotionEndDate': promotionEndDate != null
          ? Timestamp.fromDate(promotionEndDate!)
          : null,
      'promotionRequested': promotionRequested,
      'inspectionFee': inspectionFee,
      'isActive': isActive,
      'viewCount': viewCount,
      'featuredPromotion': featuredPromotion,
      'developerAdvertising': developerAdvertising,
      'showPriceToCustomers': showPriceToCustomers,
    };
    // Only include organizationId when it has a value —
    // writing null confuses Firestore security-rule type checks.
    if (organizationId != null && organizationId!.isNotEmpty) {
      json['organizationId'] = organizationId;
    }
    if (rentalUnit != null && rentalUnit!.trim().isNotEmpty) {
      json['rentalUnit'] = rentalUnit!.trim();
    }
    return json;
  }

  // Helper method to safely parse DateTime from various Firestore formats
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    // Already a DateTime object
    if (value is DateTime) return value;

    // Firestore Timestamp object
    if (value is Timestamp) return value.toDate();

    // Milliseconds since epoch (integer)
    if (value is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } catch (e) {
        return null;
      }
    }

    // ISO 8601 string
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null; // Fail gracefully for invalid formats
      }
    }

    return null;
  }

  // Helper method to safely parse roomTypes from various formats (List or Map)
  static List<RoomType> _parseRoomTypes(dynamic value) {
    if (value == null) return [];

    try {
      // If it's already a List
      if (value is List) {
        return value
            .map(
              (rt) => RoomType.fromJson(
                rt is Map<String, dynamic>
                    ? rt
                    : Map<String, dynamic>.from(rt as Map),
              ),
            )
            .toList();
      }

      // If it's a Map (old format), convert to List
      if (value is Map) {
        return value.entries.map((entry) {
          final data = entry.value is Map<String, dynamic>
              ? entry.value as Map<String, dynamic>
              : Map<String, dynamic>.from(entry.value as Map);
          // Add name from key if not present
          if (!data.containsKey('name')) {
            data['name'] = entry.key;
          }
          return RoomType.fromJson(data);
        }).toList();
      }
    } catch (e) {
      // Return empty list on error
      return [];
    }

    return [];
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
      rentalUnit:
          (json['rentalUnit'] ??
                  json['pricePeriod'] ??
                  json['priceDuration'] ??
                  json['priceUnit'] ??
                  json['rentalPeriod'] ??
                  json['rentPeriod'] ??
                  json['rentalDuration'] ??
                  json['durationUnit'] ??
                  json['billingPeriod'])
              ?.toString(),
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      ownerId: json['ownerId'] ?? '',
      organizationId: json['organizationId'],
      createdByUserId: json['createdByUserId'],
      ownerName: json['ownerName'] ?? '',
      ownerEmail: json['ownerEmail'] ?? '',
      ownerEmailLower:
          json['ownerEmailLower'] ??
          (json['ownerEmail']?.toString().trim().toLowerCase()),
      ownerPhoneKey: json['ownerPhoneKey'],
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
      createdAt: _parseDateTime(json['createdAt']) ?? now,
      updatedAt: _parseDateTime(json['updatedAt']) ?? now,
      rejectionReason: json['rejectionReason'],
      amenities: List<String>.from(json['amenities'] ?? []),
      university: json['university'],
      roomTypes: _parseRoomTypes(json['roomTypes']),
      paymentInstructions: json['paymentInstructions'],
      genderPolicy: GenderPolicy.values.firstWhere(
        (e) => e.name == json['genderPolicy'],
        orElse: () => GenderPolicy.mixed,
      ),
      roomStructure: json['roomStructure'],
      isNewProject: json['isNewProject'] ?? false,
      hasActivePromotion: json['hasActivePromotion'] ?? false,
      promotionEndDate: _parseDateTime(json['promotionEndDate']),
      promotionRequested: json['promotionRequested'] ?? false,
      inspectionFee: json['inspectionFee']?.toDouble(),
      isActive: json['isActive'] ?? true, // Default to active for old data
      viewCount: json['viewCount'] ?? 0, // Default to 0 for old data
      featuredPromotion: json['featuredPromotion'] ?? false,
      developerAdvertising: json['developerAdvertising'] ?? false,
      showPriceToCustomers: json['showPriceToCustomers'] is bool
          ? json['showPriceToCustomers'] as bool
          : true,
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
    String? rentalUnit,
    List<String>? imageUrls,
    String? ownerId,
    String? organizationId,
    String? createdByUserId,
    String? ownerName,
    String? ownerEmail,
    String? ownerEmailLower,
    String? ownerPhoneKey,
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
    bool? featuredPromotion,
    bool? developerAdvertising,
    GenderPolicy? genderPolicy,
    String? roomStructure,
    bool? isNewProject,
    bool? hasActivePromotion,
    DateTime? promotionEndDate,
    double? inspectionFee,
    bool? isActive,
    bool? showPriceToCustomers,
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
      rentalUnit: rentalUnit ?? this.rentalUnit,
      imageUrls: imageUrls ?? this.imageUrls,
      ownerId: ownerId ?? this.ownerId,
      organizationId: organizationId ?? this.organizationId,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      ownerName: ownerName ?? this.ownerName,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      ownerEmailLower: ownerEmailLower ?? this.ownerEmailLower,
      ownerPhoneKey: ownerPhoneKey ?? this.ownerPhoneKey,
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
      genderPolicy: genderPolicy ?? this.genderPolicy,
      roomStructure: roomStructure ?? this.roomStructure,
      featuredPromotion: featuredPromotion ?? this.featuredPromotion,
      developerAdvertising: developerAdvertising ?? this.developerAdvertising,
      isNewProject: isNewProject ?? this.isNewProject,
      hasActivePromotion: hasActivePromotion ?? this.hasActivePromotion,
      promotionEndDate: promotionEndDate ?? this.promotionEndDate,
      inspectionFee: inspectionFee ?? this.inspectionFee,
      isActive: isActive ?? this.isActive,
      showPriceToCustomers: showPriceToCustomers ?? this.showPriceToCustomers,
    );
  }

  String get typeDisplayLabel {
    switch (type) {
      case PropertyType.sale:
        return 'For Sale';
      case PropertyType.rent:
        return 'For Rent';
      case PropertyType.hostel:
        return 'Hostel';
      case PropertyType.commercial:
        return 'Commercial';
    }
  }

  String get typeBadgeLabel => typeDisplayLabel.toUpperCase();

  String get priceSuffix {
    switch (type) {
      case PropertyType.rent:
        return '/month';
      case PropertyType.hostel:
        return '/semester';
      case PropertyType.commercial:
        return ' $commercialPriceDurationLabel';
      case PropertyType.sale:
        return '';
    }
  }

  String get commercialPriceDurationLabel {
    final unit = _normalizeCommercialRentalUnit(rentalUnit);
    return 'per $unit';
  }

  static String _normalizeCommercialRentalUnit(String? value) {
    var unit = value?.trim().toLowerCase() ?? '';
    if (unit.isEmpty) return 'month';

    unit = unit.replaceFirst(RegExp(r'^/+'), '');
    unit = unit.replaceFirst(RegExp(r'^per\s+'), '');

    switch (unit) {
      case 'hr':
      case 'hrs':
      case 'hourly':
      case 'hours':
        return 'hour';
      case 'daily':
      case 'days':
        return 'day';
      case 'weekly':
      case 'weeks':
        return 'week';
      case 'monthly':
      case 'months':
        return 'month';
      case 'annually':
      case 'yearly':
      case 'years':
      case 'annum':
      case 'per annum':
        return 'year';
      default:
        return unit;
    }
  }

  String get normalizedAreaUnit {
    final unit = areaUnit.trim().toLowerCase();
    if (unit == 'sqm' || unit == 'm2' || unit == 'spm') {
      return 'sqm';
    }
    return 'sqft';
  }

  String get areaUnitLabel => normalizedAreaUnit == 'sqm' ? 'sq m' : 'sq ft';

  String get formattedAreaValue {
    final rounded = areaSqft.roundToDouble();
    if (areaSqft == rounded) {
      return areaSqft.toInt().toString();
    }
    return areaSqft.toStringAsFixed(1);
  }

  String get formattedArea => '$formattedAreaValue $normalizedAreaUnit';
}
