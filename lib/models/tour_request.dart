enum TourRequestStatus {
  pending,
  confirmed,
  cancelled,
  completed,
}

class TourRequest {
  final String id;
  final String propertyId;
  final String propertyTitle;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String managerId;
  final DateTime requestedDate;
  final String requestedTime;
  final TourRequestStatus status;
  final String? notes;
  final String? managerNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  TourRequest({
    required this.id,
    required this.propertyId,
    required this.propertyTitle,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.managerId,
    required this.requestedDate,
    required this.requestedTime,
    required this.status,
    this.notes,
    this.managerNotes,
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
      'requestedDate': requestedDate.toIso8601String(),
      'requestedTime': requestedTime,
      'status': status.name,
      'notes': notes,
      'managerNotes': managerNotes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TourRequest.fromJson(Map<String, dynamic> json) {
    return TourRequest(
      id: json['id'] ?? '',
      propertyId: json['propertyId'] ?? '',
      propertyTitle: json['propertyTitle'] ?? '',
      customerId: json['customerId'] ?? '',
      customerName: json['customerName'] ?? '',
      customerPhone: json['customerPhone'] ?? '',
      customerEmail: json['customerEmail'] ?? '',
      managerId: json['managerId'] ?? '',
      requestedDate: DateTime.parse(json['requestedDate']),
      requestedTime: json['requestedTime'] ?? '',
      status: TourRequestStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TourRequestStatus.pending,
      ),
      notes: json['notes'],
      managerNotes: json['managerNotes'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  TourRequest copyWith({
    String? id,
    String? propertyId,
    String? propertyTitle,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? managerId,
    DateTime? requestedDate,
    String? requestedTime,
    TourRequestStatus? status,
    String? notes,
    String? managerNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TourRequest(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      propertyTitle: propertyTitle ?? this.propertyTitle,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      managerId: managerId ?? this.managerId,
      requestedDate: requestedDate ?? this.requestedDate,
      requestedTime: requestedTime ?? this.requestedTime,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      managerNotes: managerNotes ?? this.managerNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
