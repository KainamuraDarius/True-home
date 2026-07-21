import 'package:flutter_test/flutter_test.dart';
import 'package:true_home/models/property_model.dart';

void main() {
  group('PropertyModel commercial price duration', () {
    test('shows selected commercial rental unit beside the price', () {
      final property = _property(
        type: PropertyType.commercial,
        rentalUnit: 'per week',
      );

      expect(property.priceSuffix, ' per week');
    });

    test('normalizes legacy commercial duration values', () {
      final property = _property(
        type: PropertyType.commercial,
        rentalUnit: '/day',
      );

      expect(property.priceSuffix, ' per day');
    });

    test('falls back to monthly duration for older commercial records', () {
      final property = _property(type: PropertyType.commercial);

      expect(property.priceSuffix, ' per month');
    });

    test('reads older Firestore duration field names', () {
      final property = PropertyModel.fromJson({
        ..._baseJson(),
        'type': 'commercial',
        'priceUnit': 'weekly',
      });

      expect(property.priceSuffix, ' per week');
    });
  });
}

PropertyModel _property({required PropertyType type, String? rentalUnit}) {
  final now = DateTime(2026, 7, 21);

  return PropertyModel(
    id: 'property-1',
    title: 'Commercial Space',
    category: 'Office',
    description: 'Office space',
    type: type,
    price: 1000000,
    location: 'Kampala',
    address: 'Kampala',
    bedrooms: 0,
    bathrooms: 0,
    areaSqft: 0,
    rentalUnit: rentalUnit,
    imageUrls: const [],
    ownerId: 'owner-1',
    ownerName: 'Agent',
    ownerEmail: 'agent@example.com',
    companyName: 'True Home',
    agentName: 'Agent',
    contactPhone: '+256700000000',
    whatsappPhone: '+256700000000',
    contactEmail: 'agent@example.com',
    status: PropertyStatus.pending,
    createdAt: now,
    updatedAt: now,
  );
}

Map<String, dynamic> _baseJson() {
  final property = _property(type: PropertyType.commercial);
  return property.toJson()..remove('rentalUnit');
}
