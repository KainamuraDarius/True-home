enum ContactRequestStatus {
  new_request,
  inProgress,
  resolved,
}

class ContactRequest {
  final String id;
  final String propertyId;
  final String propertyTitle;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String managerId;
  final String message;
  final ContactRequestStatus status;
  final String? managerResponse;
  final DateTime createdAt;
  final DateTime updatedAt;

  ContactRequest({
    required this.id,
    required this.propertyId,
    required this.propertyTitle,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.managerId,
    required this.message,
    required this.status,
    this.managerResponse,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'propertyId': propertyId,
      'propertyTitle': propertyTitle,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'managerId': managerId,
      'message': message,
      'status': status.name,
      'managerResponse': managerResponse,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ContactRequest.fromJson(Map<String, dynamic> json) {
    return ContactRequest(
      id: json['id'] ?? '',
      propertyId: json['propertyId'] ?? '',
      propertyTitle: json['propertyTitle'] ?? '',
      customerId: json['customerId'] ?? '',
      customerName: json['customerName'] ?? '',
      customerPhone: json['customerPhone'] ?? '',
      customerEmail: json['customerEmail'] ?? '',
      managerId: json['managerId'] ?? '',
      message: json['message'] ?? '',
      status: ContactRequestStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ContactRequestStatus.new_request,
      ),
      managerResponse: json['managerResponse'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  ContactRequest copyWith({
    String? id,
    String? propertyId,
    String? propertyTitle,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? managerId,
    String? message,
    ContactRequestStatus? status,
    String? managerResponse,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ContactRequest(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      propertyTitle: propertyTitle ?? this.propertyTitle,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      managerId: managerId ?? this.managerId,
      message: message ?? this.message,
      status: status ?? this.status,
      managerResponse: managerResponse ?? this.managerResponse,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
