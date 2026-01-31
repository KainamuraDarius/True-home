

class AgentRatingModel {
  final String id;
  final String agentId;
  final String customerId;
  final String customerName;
  final double rating; // 1.0 to 5.0
  final String? reviewText;
  final DateTime createdAt;
  final DateTime updatedAt;

  AgentRatingModel({
    required this.id,
    required this.agentId,
    required this.customerId,
    required this.customerName,
    required this.rating,
    this.reviewText,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'agentId': agentId,
      'customerId': customerId,
      'customerName': customerName,
      'rating': rating,
      'reviewText': reviewText,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AgentRatingModel.fromJson(Map<String, dynamic> json, String documentId) {
    final now = DateTime.now();
    
    return AgentRatingModel(
      id: json['id'] ?? documentId,
      agentId: json['agentId'] ?? '',
      customerId: json['customerId'] ?? '',
      customerName: json['customerName'] ?? 'Anonymous',
      rating: (json['rating'] ?? 0).toDouble(),
      reviewText: json['reviewText'],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : now,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : now,
    );
  }

  AgentRatingModel copyWith({
    String? id,
    String? agentId,
    String? customerId,
    String? customerName,
    double? rating,
    String? reviewText,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AgentRatingModel(
      id: id ?? this.id,
      agentId: agentId ?? this.agentId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      rating: rating ?? this.rating,
      reviewText: reviewText ?? this.reviewText,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
