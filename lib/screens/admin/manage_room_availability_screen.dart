import 'package:flutter/material.dart';
import '../../utils/currency_formatter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/property_model.dart';
import '../../utils/app_theme.dart';
import '../../services/room_availability_service.dart';

class ManageRoomAvailabilityScreen extends StatefulWidget {
  final PropertyModel property;

  const ManageRoomAvailabilityScreen({
    super.key,
    required this.property,
  });

  @override
  State<ManageRoomAvailabilityScreen> createState() =>
      _ManageRoomAvailabilityScreenState();
}

class _ManageRoomAvailabilityScreenState
    extends State<ManageRoomAvailabilityScreen> {
  final _roomAvailabilityService = RoomAvailabilityService();
  final Map<String, TextEditingController> _availabilityControllers = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with current availability
    for (var roomType in widget.property.roomTypes) {
      _availabilityControllers[roomType.name] = TextEditingController(
        text: roomType.availableRooms.toString(),
      );
    }
  }

  @override
  void dispose() {
    for (var controller in _availabilityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _updateAvailability(String roomTypeName, int totalRooms) async {
    final newAvailable = int.tryParse(
      _availabilityControllers[roomTypeName]!.text.trim(),
    );

    if (newAvailable == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (newAvailable < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Available rooms cannot be negative'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (newAvailable > totalRooms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Available rooms ($newAvailable) cannot exceed total rooms ($totalRooms)',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _roomAvailabilityService.updateRoomAvailability(
        propertyId: widget.property.id,
        roomTypeName: roomTypeName,
        newAvailableCount: newAvailable,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated $roomTypeName availability to $newAvailable'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh the screen data
        _refreshPropertyData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update availability'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshPropertyData() async {
    try {
      final propertyDoc = await FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.property.id)
          .get();

      if (propertyDoc.exists && mounted) {
        final updatedProperty = PropertyModel.fromJson({
          ...propertyDoc.data()!,
          'id': propertyDoc.id,
        });

        // Update controllers with new data
        for (var roomType in updatedProperty.roomTypes) {
          _availabilityControllers[roomType.name]?.text =
              roomType.availableRooms.toString();
        }

        setState(() {
          // Trigger rebuild with updated data
        });
      }
    } catch (e) {
      print('Error refreshing property data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Room Availability'),
        backgroundColor: AppColors.primary,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('properties')
            .doc(widget.property.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final property = PropertyModel.fromJson({
            ...snapshot.data!.data() as Map<String, dynamic>,
            'id': snapshot.data!.id,
          });

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hostel Info Card
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          property.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              property.location,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        if (property.university != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.school,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                property.university!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Instructions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue.shade700, size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Update the available rooms as bookings are made or cancelled. Available rooms cannot exceed total rooms.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Room Types
                const Text(
                  'Room Availability',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                ...property.roomTypes.map((roomType) {
                  // Update controller if value changed from stream
                  if (_availabilityControllers[roomType.name]?.text !=
                      roomType.availableRooms.toString()) {
                    _availabilityControllers[roomType.name]?.text =
                        roomType.availableRooms.toString();
                  }

                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getRoomTypeIcon(roomType.name),
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      roomType.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'UGX ${CurrencyFormatter.format(roomType.price)}/${roomType.pricingPeriod.name}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Availability stats
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatBox(
                                  'Total Rooms',
                                  roomType.totalRooms.toString(),
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatBox(
                                  'Booked',
                                  roomType.bookedRooms.toString(),
                                  Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatBox(
                                  'Available',
                                  roomType.availableRooms.toString(),
                                  roomType.hasAvailability
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Update availability
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller:
                                      _availabilityControllers[roomType.name],
                                  decoration: InputDecoration(
                                    labelText: 'New Available Count',
                                    border: const OutlineInputBorder(),
                                    helperText:
                                        'Max: ${roomType.totalRooms}',
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => _updateAvailability(
                                          roomType.name,
                                          roomType.totalRooms,
                                        ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : const Text('Update'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getRoomTypeIcon(String roomTypeName) {
    switch (roomTypeName.toLowerCase()) {
      case 'single room':
        return Icons.person;
      case 'double room':
        return Icons.people;
      case 'triple room':
        return Icons.groups;
      case 'shared room':
        return Icons.group;
      default:
        return Icons.bed;
    }
  }
}
