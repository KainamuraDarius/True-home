enum UserRole {
  customer,
  propertyManager,
  propertyOwner,
  admin,
}

class UserModel {
  final String id;
  final String email;
  final String name;
  final String phoneNumber;
  final UserRole role;
  final String? profileImageUrl;
  final List<String> favoritePropertyIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // For property managers/owners
  final String? companyName;
  final String? companyAddress;
  final String? whatsappNumber;
  final bool isVerified;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.phoneNumber,
    required this.role,
    this.profileImageUrl,
    this.favoritePropertyIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.companyName,
    this.companyAddress,
    this.whatsappNumber,
    this.isVerified = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'phoneNumber': phoneNumber,
      'role': role.name,
      'profileImageUrl': profileImageUrl,
      'favoritePropertyIds': favoritePropertyIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'companyName': companyName,
      'companyAddress': companyAddress,
      'whatsappNumber': whatsappNumber,
      'isVerified': isVerified,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.customer,
      ),
      profileImageUrl: json['profileImageUrl'],
      favoritePropertyIds: List<String>.from(json['favoritePropertyIds'] ?? []),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : now,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : now,
      companyName: json['companyName'],
      companyAddress: json['companyAddress'],
      whatsappNumber: json['whatsappNumber'],
      isVerified: json['isVerified'] ?? false,
    );
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? phoneNumber,
    UserRole? role,
    String? profileImageUrl,
    List<String>? favoritePropertyIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? companyName,
    String? companyAddress,
    String? whatsappNumber,
    bool? isVerified,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      favoritePropertyIds: favoritePropertyIds ?? this.favoritePropertyIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      companyName: companyName ?? this.companyName,
      companyAddress: companyAddress ?? this.companyAddress,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}
