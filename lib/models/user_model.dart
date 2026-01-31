enum UserRole {
  customer,
  propertyAgent,
  admin,
}

class UserModel {
  final String id;
  final String email;
  final String name;
  final String phoneNumber;
  final List<UserRole> roles; // Changed: now supports multiple roles
  final UserRole activeRole; // Changed: currently active role
  final String? profileImageUrl;
  final List<String> favoritePropertyIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // For property managers/owners
  final String? companyName;
  final String? companyAddress;
  final String? whatsappNumber;
  final bool isVerified;
  
  // Agent rating fields
  final double? averageRating; // Average rating from customers (0-5)
  final int totalRatings; // Total number of ratings received
  final int totalReviews; // Total number of reviews with text
  
  // Terms and conditions
  final bool termsAccepted; // Whether user accepted terms
  final DateTime? termsAcceptedAt; // When terms were accepted

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.phoneNumber,
    required this.roles,
    required this.activeRole,
    this.profileImageUrl,
    this.favoritePropertyIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.companyName,
    this.companyAddress,
    this.whatsappNumber,
    this.isVerified = false,
    this.averageRating,
    this.totalRatings = 0,
    this.totalReviews = 0,
    this.termsAccepted = false,
    this.termsAcceptedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'phoneNumber': phoneNumber,
      'roles': roles.map((r) => r.name).toList(),
      'activeRole': activeRole.name,
      'profileImageUrl': profileImageUrl,
      'favoritePropertyIds': favoritePropertyIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'companyName': companyName,
      'companyAddress': companyAddress,
      'whatsappNumber': whatsappNumber,
      'isVerified': isVerified,
      'averageRating': averageRating,
      'totalRatings': totalRatings,
      'totalReviews': totalReviews,
      'termsAccepted': termsAccepted,
      'termsAcceptedAt': termsAcceptedAt?.toIso8601String(),
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    
    // Handle backward compatibility: if old 'role' field exists, migrate to 'roles'
    List<UserRole> userRoles;
    if (json['roles'] != null) {
      userRoles = (json['roles'] as List)
          .map((r) => UserRole.values.firstWhere(
                (e) => e.name == r,
                orElse: () => UserRole.customer,
              ))
          .toList();
    } else if (json['role'] != null) {
      // Old single role format - migrate to array
      final singleRole = UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.customer,
      );
      userRoles = [singleRole];
    } else {
      userRoles = [UserRole.customer];
    }
    
    // Get active role
    final UserRole currentActiveRole;
    if (json['activeRole'] != null) {
      currentActiveRole = UserRole.values.firstWhere(
        (e) => e.name == json['activeRole'],
        orElse: () => userRoles.first,
      );
    } else {
      currentActiveRole = userRoles.first;
    }
    
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      roles: userRoles,
      activeRole: currentActiveRole,
      profileImageUrl: json['profileImageUrl'],
      favoritePropertyIds: List<String>.from(json['favoritePropertyIds'] ?? []),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : now,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : now,
      companyName: json['companyName'],
      averageRating: json['averageRating']?.toDouble(),
      totalRatings: json['totalRatings'] ?? 0,
      totalReviews: json['totalReviews'] ?? 0,
      companyAddress: json['companyAddress'],
      whatsappNumber: json['whatsappNumber'],
      isVerified: json['isVerified'] ?? false,
      termsAccepted: json['termsAccepted'] ?? false,
      termsAcceptedAt: json['termsAcceptedAt'] != null 
          ? DateTime.parse(json['termsAcceptedAt']) 
          : null,
    );
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? phoneNumber,
    List<UserRole>? roles,
    UserRole? activeRole,
    String? profileImageUrl,
    List<String>? favoritePropertyIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? companyName,
    String? companyAddress,
    String? whatsappNumber,
    bool? isVerified,
    double? averageRating,
    int? totalRatings,
    int? totalReviews,
    bool? termsAccepted,
    DateTime? termsAcceptedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      roles: roles ?? this.roles,
      activeRole: activeRole ?? this.activeRole,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      favoritePropertyIds: favoritePropertyIds ?? this.favoritePropertyIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      companyName: companyName ?? this.companyName,
      companyAddress: companyAddress ?? this.companyAddress,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      isVerified: isVerified ?? this.isVerified,
      averageRating: averageRating ?? this.averageRating,
      totalRatings: totalRatings ?? this.totalRatings,
      totalReviews: totalReviews ?? this.totalReviews,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      termsAcceptedAt: termsAcceptedAt ?? this.termsAcceptedAt,
    );
  }
}
