import '../config/api_config.dart';
import '../models/contact_request.dart';
import 'api_service.dart';

class ContactService {
  final ApiService _apiService = ApiService();

  // Create contact request
  Future<ContactRequest> createContactRequest(ContactRequest request) async {
    try {
      final response = await _apiService.post(
        ApiConfig.createContactRequest,
        data: request.toJson(),
      );
      return ContactRequest.fromJson(response['contactRequest']);
    } catch (e) {
      throw Exception('Failed to create contact request: $e');
    }
  }

  // Get contact requests for customer
  Future<List<ContactRequest>> getCustomerContactRequests() async {
    try {
      final response = await _apiService.get(ApiConfig.getCustomerContactRequests);
      final List<dynamic> data = response['contactRequests'] ?? [];
      return data.map((json) => ContactRequest.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get customer contact requests: $e');
    }
  }

  // Get contact requests for manager
  Future<List<ContactRequest>> getManagerContactRequests() async {
    try {
      final response = await _apiService.get(ApiConfig.getManagerContactRequests);
      final List<dynamic> data = response['contactRequests'] ?? [];
      return data.map((json) => ContactRequest.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get manager contact requests: $e');
    }
  }

  // Get contact requests by property
  Future<List<ContactRequest>> getContactRequestsByProperty(String propertyId) async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.getContactRequestsByProperty}/$propertyId',
      );
      final List<dynamic> data = response['contactRequests'] ?? [];
      return data.map((json) => ContactRequest.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get contact requests for property: $e');
    }
  }

  // Get single contact request
  Future<ContactRequest?> getContactRequest(String requestId) async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.getContactRequest}/$requestId',
      );
      if (response['contactRequest'] != null) {
        return ContactRequest.fromJson(response['contactRequest']);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get contact request: $e');
    }
  }

  // Update contact request status and response
  Future<ContactRequest> updateContactRequest(
    String requestId, {
    ContactRequestStatus? status,
    String? managerResponse,
  }) async {
    try {
      final response = await _apiService.put(
        '${ApiConfig.updateContactRequestStatus}/$requestId',
        data: {
          if (status != null) 'status': status.name,
          if (managerResponse != null) 'managerResponse': managerResponse,
        },
      );
      return ContactRequest.fromJson(response['contactRequest']);
    } catch (e) {
      throw Exception('Failed to update contact request: $e');
    }
  }

  // Mark as in progress
  Future<ContactRequest> markAsInProgress(String requestId) async {
    return updateContactRequest(requestId, status: ContactRequestStatus.inProgress);
  }

  // Resolve contact request
  Future<ContactRequest> resolveContactRequest(
    String requestId,
    String managerResponse,
  ) async {
    return updateContactRequest(
      requestId,
      status: ContactRequestStatus.resolved,
      managerResponse: managerResponse,
    );
  }

  // Delete contact request
  Future<void> deleteContactRequest(String requestId) async {
    try {
      await _apiService.delete('${ApiConfig.deleteContactRequest}/$requestId');
    } catch (e) {
      throw Exception('Failed to delete contact request: $e');
    }
  }

  // Get new contact requests count for manager
  Future<int> getNewContactRequestsCount() async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.getManagerContactRequests}?status=new_request',
      );
      final List<dynamic> data = response['contactRequests'] ?? [];
      return data.length;
    } catch (e) {
      throw Exception('Failed to get new contact requests count: $e');
    }
  }
}
