import 'dart:io';
import '../config/api_config.dart';
import '../models/property_submission.dart';
import 'api_service.dart';

class PropertySubmissionService {
  final ApiService _apiService = ApiService();

  // Create property submission
  Future<PropertySubmission> createSubmission(PropertySubmission submission) async {
    try {
      final response = await _apiService.post(
        ApiConfig.createSubmission,
        data: submission.toJson(),
      );
      return PropertySubmission.fromJson(response['submission']);
    } catch (e) {
      throw Exception('Failed to create submission: $e');
    }
  }

  // Get submissions for owner
  Future<List<PropertySubmission>> getOwnerSubmissions() async {
    try {
      final response = await _apiService.get(ApiConfig.getOwnerSubmissions);
      final List<dynamic> data = response['submissions'] ?? [];
      return data.map((json) => PropertySubmission.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get owner submissions: $e');
    }
  }

  // Get all submissions (for admin/manager)
  Future<List<PropertySubmission>> getAllSubmissions({
    SubmissionStatus? status,
  }) async {
    try {
      final url = status != null
          ? '${ApiConfig.getAllSubmissions}?status=${status.name}'
          : ApiConfig.getAllSubmissions;
      
      final response = await _apiService.get(url);
      final List<dynamic> data = response['submissions'] ?? [];
      return data.map((json) => PropertySubmission.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get all submissions: $e');
    }
  }

  // Get pending submissions
  Future<List<PropertySubmission>> getPendingSubmissions() async {
    return getAllSubmissions(status: SubmissionStatus.pending);
  }

  // Get single submission
  Future<PropertySubmission?> getSubmission(String submissionId) async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.getSubmission}/$submissionId',
      );
      if (response['submission'] != null) {
        return PropertySubmission.fromJson(response['submission']);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get submission: $e');
    }
  }

  // Approve submission
  Future<PropertySubmission> approveSubmission(
    String submissionId, {
    String? adminNotes,
  }) async {
    try {
      final response = await _apiService.put(
        '${ApiConfig.approveSubmission}/$submissionId',
        data: {
          if (adminNotes != null) 'adminNotes': adminNotes,
        },
      );
      return PropertySubmission.fromJson(response['submission']);
    } catch (e) {
      throw Exception('Failed to approve submission: $e');
    }
  }

  // Reject submission
  Future<PropertySubmission> rejectSubmission(
    String submissionId, {
    required String rejectionReason,
    String? adminNotes,
  }) async {
    try {
      final response = await _apiService.put(
        '${ApiConfig.rejectSubmission}/$submissionId',
        data: {
          'rejectionReason': rejectionReason,
          if (adminNotes != null) 'adminNotes': adminNotes,
        },
      );
      return PropertySubmission.fromJson(response['submission']);
    } catch (e) {
      throw Exception('Failed to reject submission: $e');
    }
  }

  // Update submission
  Future<PropertySubmission> updateSubmission(
    String submissionId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _apiService.put(
        '${ApiConfig.updateSubmission}/$submissionId',
        data: updates,
      );
      return PropertySubmission.fromJson(response['submission']);
    } catch (e) {
      throw Exception('Failed to update submission: $e');
    }
  }

  // Delete submission
  Future<void> deleteSubmission(String submissionId) async {
    try {
      await _apiService.delete('${ApiConfig.deleteSubmission}/$submissionId');
    } catch (e) {
      throw Exception('Failed to delete submission: $e');
    }
  }

  // Upload submission images
  Future<List<String>> uploadSubmissionImages(
    String submissionId,
    List<File> images,
  ) async {
    try {
      final imageUrls = <String>[];
      
      for (final image in images) {
        final response = await _apiService.uploadFile(
          '${ApiConfig.uploadSubmissionImages}/$submissionId',
          image,
          fieldName: 'image',
        );
        imageUrls.add(response['imageUrl']);
      }
      
      return imageUrls;
    } catch (e) {
      throw Exception('Failed to upload images: $e');
    }
  }

  // Get pending submissions count
  Future<int> getPendingSubmissionsCount() async {
    try {
      final submissions = await getPendingSubmissions();
      return submissions.length;
    } catch (e) {
      throw Exception('Failed to get pending submissions count: $e');
    }
  }
}
