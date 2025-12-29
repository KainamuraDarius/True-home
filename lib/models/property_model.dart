enum PropertyType {
  sale,
  rent,
}

enum PropertyStatus {
  pending,
  approved,
  rejected,
}

class PropertyModel {
  final String id;
  final String title;
  final String description;
  final PropertyType type;
  final double price;
  final String location;
  final String address;
  final int bedrooms;
  final int bathrooms;
  final double areaSqft;
  final List<String> imageUrls;
  final String ownerId;
  final String ownerName;
  final String ownerEmail;
  final String contactPhone;
  final String whatsappPhone;
  final String contactEmail;
  final PropertyStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? rejectionReason;

  PropertyModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.price,
    required this.location,
    required this.address,
    required this.bedrooms,
    required this.bathrooms,
    required this.areaSqft,
    required this.imageUrls,
    required this.ownerId,
    required this.ownerName,
    required this.ownerEmail,
    required this.contactPhone,
    required this.whatsappPhone,
    required this.contactEmail,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.rejectionReason,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'price': price,
      'location': location,
      'address': address,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'areaSqft': areaSqft,
      'imageUrls': imageUrls,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'ownerEmail': ownerEmail,
      'contactPhone': contactPhone,
      'whatsappPhone': whatsappPhone,
      'contactEmail': contactEmail,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'rejectionReason': rejectionReason,
    };
  }

  factory PropertyModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return PropertyModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
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
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      ownerId: json['ownerId'] ?? '',
      ownerName: json['ownerName'] ?? '',
      ownerEmail: json['ownerEmail'] ?? '',
      contactPhone: json['contactPhone'] ?? '',
      whatsappPhone: json['whatsappPhone'] ?? '',
      contactEmail: json['contactEmail'] ?? '',
      status: PropertyStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PropertyStatus.pending,
      ),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : now,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : now,
      rejectionReason: json['rejectionReason'],
    );
  }

  PropertyModel copyWith({
    String? id,
    String? title,
    String? description,
    PropertyType? type,
    double? price,
    String? location,
    String? address,
    int? bedrooms,
    int? bathrooms,
    double? areaSqft,
    List<String>? imageUrls,
    String? ownerId,
    String? ownerName,
    String? ownerEmail,
    String? contactPhone,
    String? whatsappPhone,
    String? contactEmail,
    PropertyStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? rejectionReason,
  }) {
    return PropertyModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      price: price ?? this.price,
      location: location ?? this.location,
      address: address ?? this.address,
      bedrooms: bedrooms ?? this.bedrooms,
      bathrooms: bathrooms ?? this.bathrooms,
      areaSqft: areaSqft ?? this.areaSqft,
      imageUrls: imageUrls ?? this.imageUrls,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      whatsappPhone: whatsappPhone ?? this.whatsappPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}
