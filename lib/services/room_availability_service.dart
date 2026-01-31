import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/property_model.dart';

class RoomAvailabilityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Update room availability for a specific room type
  Future<bool> updateRoomAvailability({
    required String propertyId,
    required String roomTypeName,
    required int newAvailableCount,
  }) async {
    try {
      // Get the property
      final propertyDoc = await _firestore
          .collection('properties')
          .doc(propertyId)
          .get();

      if (!propertyDoc.exists) {
        throw Exception('Property not found');
      }

      final property = PropertyModel.fromJson({
        ...propertyDoc.data()!,
        'id': propertyDoc.id,
      });

      // Find and update the specific room type
      final updatedRoomTypes = property.roomTypes.map((roomType) {
        if (roomType.name == roomTypeName) {
          // Validate that available rooms doesn't exceed total
          if (newAvailableCount > roomType.totalRooms) {
            throw Exception(
                'Available rooms ($newAvailableCount) cannot exceed total rooms (${roomType.totalRooms})');
          }
          if (newAvailableCount < 0) {
            throw Exception('Available rooms cannot be negative');
          }
          return roomType.copyWith(availableRooms: newAvailableCount);
        }
        return roomType;
      }).toList();

      // Update in Firestore
      await _firestore.collection('properties').doc(propertyId).update({
        'roomTypes': updatedRoomTypes.map((rt) => rt.toJson()).toList(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Error updating room availability: $e');
      return false;
    }
  }

  /// Book a room (decrease available count by 1)
  Future<bool> bookRoom({
    required String propertyId,
    required String roomTypeName,
  }) async {
    try {
      final propertyDoc = await _firestore
          .collection('properties')
          .doc(propertyId)
          .get();

      if (!propertyDoc.exists) {
        throw Exception('Property not found');
      }

      final property = PropertyModel.fromJson({
        ...propertyDoc.data()!,
        'id': propertyDoc.id,
      });

      // Find the room type and check availability
      final roomType = property.roomTypes.firstWhere(
        (rt) => rt.name == roomTypeName,
        orElse: () => throw Exception('Room type not found'),
      );

      if (roomType.availableRooms <= 0) {
        throw Exception('No rooms available for $roomTypeName');
      }

      // Decrease available count
      final newAvailableCount = roomType.availableRooms - 1;
      return await updateRoomAvailability(
        propertyId: propertyId,
        roomTypeName: roomTypeName,
        newAvailableCount: newAvailableCount,
      );
    } catch (e) {
      print('Error booking room: $e');
      return false;
    }
  }

  /// Cancel a booking (increase available count by 1)
  Future<bool> cancelBooking({
    required String propertyId,
    required String roomTypeName,
  }) async {
    try {
      final propertyDoc = await _firestore
          .collection('properties')
          .doc(propertyId)
          .get();

      if (!propertyDoc.exists) {
        throw Exception('Property not found');
      }

      final property = PropertyModel.fromJson({
        ...propertyDoc.data()!,
        'id': propertyDoc.id,
      });

      final roomType = property.roomTypes.firstWhere(
        (rt) => rt.name == roomTypeName,
        orElse: () => throw Exception('Room type not found'),
      );

      // Can't exceed total rooms
      if (roomType.availableRooms >= roomType.totalRooms) {
        throw Exception('All rooms are already available');
      }

      final newAvailableCount = roomType.availableRooms + 1;
      return await updateRoomAvailability(
        propertyId: propertyId,
        roomTypeName: roomTypeName,
        newAvailableCount: newAvailableCount,
      );
    } catch (e) {
      print('Error canceling booking: $e');
      return false;
    }
  }

  /// Get current availability for a specific room type
  Future<RoomType?> getRoomAvailability({
    required String propertyId,
    required String roomTypeName,
  }) async {
    try {
      final propertyDoc = await _firestore
          .collection('properties')
          .doc(propertyId)
          .get();

      if (!propertyDoc.exists) {
        return null;
      }

      final property = PropertyModel.fromJson({
        ...propertyDoc.data()!,
        'id': propertyDoc.id,
      });

      return property.roomTypes.firstWhere(
        (rt) => rt.name == roomTypeName,
        orElse: () => throw Exception('Room type not found'),
      );
    } catch (e) {
      print('Error getting room availability: $e');
      return null;
    }
  }

  /// Check if any rooms are available for the hostel
  Future<bool> hasAvailableRooms(String propertyId) async {
    try {
      final propertyDoc = await _firestore
          .collection('properties')
          .doc(propertyId)
          .get();

      if (!propertyDoc.exists) {
        return false;
      }

      final property = PropertyModel.fromJson({
        ...propertyDoc.data()!,
        'id': propertyDoc.id,
      });

      return property.roomTypes.any((rt) => rt.hasAvailability);
    } catch (e) {
      print('Error checking room availability: $e');
      return false;
    }
  }
}
