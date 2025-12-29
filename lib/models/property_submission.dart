import 'property.dart';

enum SubmissionStatus {
  pending,
  approved,
  rejected,
}

class PropertySubmission {
  final String id;
  final String ownerId;
  final String ownerName;
  final String ownerEmail;
  final String ownerPhone;
  final String title;
  final String description;
  final PropertyType type;
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
  final SubmissionStatus status;
  final String? adminNotes;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? approvedPropertyId; // Reference to created property if approved

  PropertySubmission({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.ownerEmail,
    required this.ownerPhone,
    required this.title,
    required this.description,
    required this.type,
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
    this.status = SubmissionStatus.pending,
    this.adminNotes,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
    this.approvedPropertyId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'ownerEmail': ownerEmail,
      'ownerPhone': ownerPhone,
      'title': title,
      'description': description,
      'type': type.name,
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
      'status': status.name,
      'adminNotes': adminNotes,
      'rejectionReason': rejectionReason,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'approvedPropertyId': approvedPropertyId,
    };
  }

  factory PropertySubmission.fromJson(Map<String, dynamic> json) {
    return PropertySubmission(
      id: json['id'] ?? '',
      ownerId: json['ownerId'] ?? '',
      ownerName: json['ownerName'] ?? '',
      ownerEmail: json['ownerEmail'] ?? '',
      ownerPhone: json['ownerPhone'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      type: PropertyType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PropertyType.rental,
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
      status: SubmissionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SubmissionStatus.pending,
      ),
      adminNotes: json['adminNotes'],
      rejectionReason: json['rejectionReason'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      approvedPropertyId: json['approvedPropertyId'],
    );
  }

  PropertySubmission copyWith({
    String? id,
    String? ownerId,
    String? ownerName,
    String? ownerEmail,
    String? ownerPhone,
    String? title,
    String? description,
    PropertyType? type,
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
    SubmissionStatus? status,
    String? adminNotes,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? approvedPropertyId,
  }) {
    return PropertySubmission(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
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
      status: status ?? this.status,
      adminNotes: adminNotes ?? this.adminNotes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedPropertyId: approvedPropertyId ?? this.approvedPropertyId,
    );
  }
}
