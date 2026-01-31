import 'package:cloud_firestore/cloud_firestore.dart';

enum AdTier {
  basic,
  premium,
  firstPlaceRotational,
}

enum ProjectStatus {
  underConstruction,
  offPlan,
}

class Project {
  final String id;
  final String name;
  final String description;
  final List<String> imageUrls;
  final String developerId;
  final String developerName;
  final String location; // Kololo, Naalya, etc.
  final AdTier adTier;
  final bool isFirstPlaceSubscriber;
  final double paymentAmount;
  final DateTime createdAt;
  final DateTime adExpiresAt;
  final bool isApproved;
  final String? contactPhone;
  final String? contactEmail;
  final String? websiteUrl;
  final ProjectStatus projectStatus;
  final int viewCount;
  final int clickCount;

  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrls,
    required this.developerId,
    required this.developerName,
    required this.location,
    required this.adTier,
    this.isFirstPlaceSubscriber = false,
    required this.paymentAmount,
    required this.createdAt,
    required this.adExpiresAt,
    this.isApproved = false,
    this.contactPhone,
    this.contactEmail,
    this.websiteUrl,
    this.projectStatus = ProjectStatus.underConstruction,
    this.viewCount = 0,
    this.clickCount = 0,
  });

  factory Project.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Project(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      developerId: data['developerId'] ?? '',
      developerName: data['developerName'] ?? '',
      location: data['location'] ?? '',
      adTier: AdTier.values.firstWhere(
        (e) => e.toString() == 'AdTier.${data['adTier']}',
        orElse: () => AdTier.basic,
      ),
      isFirstPlaceSubscriber: data['isFirstPlaceSubscriber'] ?? false,
      paymentAmount: (data['paymentAmount'] ?? 0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      adExpiresAt: (data['adExpiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isApproved: data['isApproved'] ?? false,
      contactPhone: data['contactPhone'],
      contactEmail: data['contactEmail'],
      websiteUrl: data['websiteUrl'],
      projectStatus: ProjectStatus.values.firstWhere(
        (e) => e.toString() == 'ProjectStatus.${data['projectStatus']}',
        orElse: () => ProjectStatus.underConstruction,
      ),
      viewCount: data['viewCount'] ?? 0,
      clickCount: data['clickCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'imageUrls': imageUrls,
      'developerId': developerId,
      'developerName': developerName,
      'location': location,
      'adTier': adTier.toString().split('.').last,
      'isFirstPlaceSubscriber': isFirstPlaceSubscriber,
      'paymentAmount': paymentAmount,
      'createdAt': Timestamp.fromDate(createdAt),
      'adExpiresAt': Timestamp.fromDate(adExpiresAt),
      'isApproved': isApproved,
      'contactPhone': contactPhone,
      'contactEmail': contactEmail,
      'websiteUrl': websiteUrl,
      'projectStatus': projectStatus.toString().split('.').last,
      'viewCount': viewCount,
      'clickCount': clickCount,
    };
  }

  Project copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? imageUrls,
    String? developerId,
    String? developerName,
    String? location,
    AdTier? adTier,
    bool? isFirstPlaceSubscriber,
    double? paymentAmount,
    DateTime? createdAt,
    DateTime? adExpiresAt,
    bool? isApproved,
    String? contactPhone,
    String? contactEmail,
    String? websiteUrl,
    ProjectStatus? projectStatus,
    int? viewCount,
    int? clickCount,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrls: imageUrls ?? this.imageUrls,
      developerId: developerId ?? this.developerId,
      developerName: developerName ?? this.developerName,
      location: location ?? this.location,
      adTier: adTier ?? this.adTier,
      isFirstPlaceSubscriber: isFirstPlaceSubscriber ?? this.isFirstPlaceSubscriber,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      createdAt: createdAt ?? this.createdAt,
      adExpiresAt: adExpiresAt ?? this.adExpiresAt,
      isApproved: isApproved ?? this.isApproved,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      projectStatus: projectStatus ?? this.projectStatus,
      viewCount: viewCount ?? this.viewCount,
      clickCount: clickCount ?? this.clickCount,
    );
  }
}
