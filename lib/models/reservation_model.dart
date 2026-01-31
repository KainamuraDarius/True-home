import 'package:cloud_firestore/cloud_firestore.dart';

enum ReservationStatus { pending, confirmed, cancelled }

class ReservationModel {
  final String id;
  final String propertyId;
  final String propertyTitle;
  final String university;
  final String roomTypeName;
  final double roomPrice;
  final String pricingPeriod; // 'month' or 'semester'

  // Student information
  final String studentName;
  final String studentPhone;
  final String studentEmail;
  final String? studentUserId; // Optional: if student is logged in

  // Payment information
  final double reservationFee; // 20,000 UGX
  final String paymentStatus; // 'pending', 'paid', 'failed'
  final String? paymentReference;
  final String? paymentTransactionId; // MTN transaction ID
  final DateTime? paymentDate;

  // Hostel contact
  final String hostelManagerName;
  final String hostelManagerPhone;
  final String? hostelManagerEmail;

  // Optional payment instructions from hostel
  final String? hostelPaymentInstructions;

  final ReservationStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ReservationModel({
    required this.id,
    required this.propertyId,
    required this.propertyTitle,
    required this.university,
    required this.roomTypeName,
    required this.roomPrice,
    required this.pricingPeriod,
    required this.studentName,
    required this.studentPhone,
    required this.studentEmail,
    this.studentUserId,
    required this.reservationFee,
    required this.paymentStatus,
    this.paymentReference,
    this.paymentTransactionId,
    this.paymentDate,
    required this.hostelManagerName,
    required this.hostelManagerPhone,
    this.hostelManagerEmail,
    this.hostelPaymentInstructions,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  // Create from Firestore document
  factory ReservationModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return ReservationModel(
      id: documentId,
      propertyId: map['propertyId'] ?? '',
      propertyTitle: map['propertyTitle'] ?? '',
      university: map['university'] ?? '',
      roomTypeName: map['roomTypeName'] ?? '',
      roomPrice: (map['roomPrice'] ?? 0).toDouble(),
      pricingPeriod: map['pricingPeriod'] ?? 'month',
      studentName: map['studentName'] ?? '',
      studentPhone: map['studentPhone'] ?? '',
      studentEmail: map['studentEmail'] ?? '',
      studentUserId: map['studentUserId'],
      reservationFee: (map['reservationFee'] ?? 20000).toDouble(),
      paymentStatus: map['paymentStatus'] ?? 'pending',
      paymentReference: map['paymentReference'],
      paymentTransactionId: map['paymentTransactionId'],
      paymentDate: map['paymentDate'] != null
          ? (map['paymentDate'] as Timestamp).toDate()
          : null,
      hostelManagerName: map['hostelManagerName'] ?? '',
      hostelManagerPhone: map['hostelManagerPhone'] ?? '',
      hostelManagerEmail: map['hostelManagerEmail'],
      hostelPaymentInstructions: map['hostelPaymentInstructions'],
      status: ReservationStatus.values.firstWhere(
        (e) => e.toString() == 'ReservationStatus.${map['status']}',
        orElse: () => ReservationStatus.pending,
      ),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'propertyId': propertyId,
      'propertyTitle': propertyTitle,
      'university': university,
      'roomTypeName': roomTypeName,
      'roomPrice': roomPrice,
      'pricingPeriod': pricingPeriod,
      'studentName': studentName,
      'studentPhone': studentPhone,
      'studentEmail': studentEmail,
      'studentUserId': studentUserId,
      'reservationFee': reservationFee,
      'paymentStatus': paymentStatus,
      'paymentReference': paymentReference,
      'paymentTransactionId': paymentTransactionId,
      'paymentDate': paymentDate != null
          ? Timestamp.fromDate(paymentDate!)
          : null,
      'hostelManagerName': hostelManagerName,
      'hostelManagerPhone': hostelManagerPhone,
      'hostelManagerEmail': hostelManagerEmail,
      'hostelPaymentInstructions': hostelPaymentInstructions,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Copy with method for updates
  ReservationModel copyWith({
    String? id,
    String? propertyId,
    String? propertyTitle,
    String? university,
    String? roomTypeName,
    double? roomPrice,
    String? pricingPeriod,
    String? studentName,
    String? studentPhone,
    String? studentEmail,
    String? studentUserId,
    double? reservationFee,
    String? paymentStatus,
    String? paymentReference,
    String? paymentTransactionId,
    DateTime? paymentDate,
    String? hostelManagerName,
    String? hostelManagerPhone,
    String? hostelManagerEmail,
    String? hostelPaymentInstructions,
    ReservationStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReservationModel(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      propertyTitle: propertyTitle ?? this.propertyTitle,
      university: university ?? this.university,
      roomTypeName: roomTypeName ?? this.roomTypeName,
      roomPrice: roomPrice ?? this.roomPrice,
      pricingPeriod: pricingPeriod ?? this.pricingPeriod,
      studentName: studentName ?? this.studentName,
      studentPhone: studentPhone ?? this.studentPhone,
      studentEmail: studentEmail ?? this.studentEmail,
      studentUserId: studentUserId ?? this.studentUserId,
      reservationFee: reservationFee ?? this.reservationFee,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentReference: paymentReference ?? this.paymentReference,
      paymentTransactionId: paymentTransactionId ?? this.paymentTransactionId,
      paymentDate: paymentDate ?? this.paymentDate,
      hostelManagerName: hostelManagerName ?? this.hostelManagerName,
      hostelManagerPhone: hostelManagerPhone ?? this.hostelManagerPhone,
      hostelManagerEmail: hostelManagerEmail ?? this.hostelManagerEmail,
      hostelPaymentInstructions:
          hostelPaymentInstructions ?? this.hostelPaymentInstructions,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
