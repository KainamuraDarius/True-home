import '../config/api_config.dart';
import '../models/tour_request.dart';
import 'api_service.dart';

class TourService {
  final ApiService _apiService = ApiService();

  // Create tour request
  Future<TourRequest> createTourRequest(TourRequest request) async {
    try {
      final response = await _apiService.post(
        ApiConfig.createTourRequest,
        data: request.toJson(),
      );
      return TourRequest.fromJson(response['tourRequest']);
    } catch (e) {
      throw Exception('Failed to create tour request: $e');
    }
  }

  // Get tour requests for customer
  Future<List<TourRequest>> getCustomerTourRequests() async {
    try {
      final response = await _apiService.get(ApiConfig.getCustomerTourRequests);
      final List<dynamic> data = response['tourRequests'] ?? [];
      return data.map((json) => TourRequest.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get customer tour requests: $e');
    }
  }

  // Get tour requests for manager
  Future<List<TourRequest>> getManagerTourRequests() async {
    try {
      final response = await _apiService.get(ApiConfig.getManagerTourRequests);
      final List<dynamic> data = response['tourRequests'] ?? [];
      return data.map((json) => TourRequest.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get manager tour requests: $e');
    }
  }

  // Get tour requests by property
  Future<List<TourRequest>> getTourRequestsByProperty(String propertyId) async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.getTourRequestsByProperty}/$propertyId',
      );
      final List<dynamic> data = response['tourRequests'] ?? [];
      return data.map((json) => TourRequest.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get tour requests for property: $e');
    }
  }

  // Get single tour request
  Future<TourRequest?> getTourRequest(String requestId) async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.getTourRequest}/$requestId',
      );
      if (response['tourRequest'] != null) {
        return TourRequest.fromJson(response['tourRequest']);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get tour request: $e');
    }
  }

  // Update tour request status
  Future<TourRequest> updateTourRequestStatus(
    String requestId,
    TourRequestStatus status, {
    String? managerNotes,
  }) async {
    try {
      final response = await _apiService.put(
        '${ApiConfig.updateTourRequestStatus}/$requestId',
        data: {
          'status': status.name,
          if (managerNotes != null) 'managerNotes': managerNotes,
        },
      );
      return TourRequest.fromJson(response['tourRequest']);
    } catch (e) {
      throw Exception('Failed to update tour request status: $e');
    }
  }

  // Confirm tour request
  Future<TourRequest> confirmTourRequest(String requestId, {String? managerNotes}) async {
    return updateTourRequestStatus(
      requestId,
      TourRequestStatus.confirmed,
      managerNotes: managerNotes,
    );
  }

  // Cancel tour request
  Future<TourRequest> cancelTourRequest(String requestId) async {
    return updateTourRequestStatus(requestId, TourRequestStatus.cancelled);
  }

  // Complete tour request
  Future<TourRequest> completeTourRequest(String requestId) async {
    return updateTourRequestStatus(requestId, TourRequestStatus.completed);
  }

  // Delete tour request
  Future<void> deleteTourRequest(String requestId) async {
    try {
      await _apiService.delete('${ApiConfig.deleteTourRequest}/$requestId');
    } catch (e) {
      throw Exception('Failed to delete tour request: $e');
    }
  }

  // Get pending tour requests count for manager
  Future<int> getPendingTourRequestsCount() async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.getManagerTourRequests}?status=pending',
      );
      final List<dynamic> data = response['tourRequests'] ?? [];
      return data.length;
    } catch (e) {
      throw Exception('Failed to get pending tour requests count: $e');
    }
  }
}
