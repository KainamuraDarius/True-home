import 'dart:io';
import '../config/api_config.dart';
import '../models/property.dart';
import 'api_service.dart';

class PropertyService {
  final ApiService _apiService = ApiService();

  // Get all properties
  Future<List<Property>> getAllProperties() async {
    try {
      final response = await _apiService.get(ApiConfig.getProperties);
      final List<dynamic> data = response['properties'] ?? [];
      return data.map((json) => Property.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get properties: $e');
    }
  }

  // Get properties by type
  Future<List<Property>> getPropertiesByType(PropertyType type) async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.getProperties}?type=${type.name}',
      );
      final List<dynamic> data = response['properties'] ?? [];
      return data.map((json) => Property.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get properties by type: $e');
    }
  }

  // Get properties by manager
  Future<List<Property>> getPropertiesByManager(String managerId) async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.getProperties}?managerId=$managerId',
      );
      final List<dynamic> data = response['properties'] ?? [];
      return data.map((json) => Property.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get properties by manager: $e');
    }
  }

  // Get single property
  Future<Property?> getProperty(String propertyId) async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.getProperties}/$propertyId',
      );
      if (response['property'] != null) {
        return Property.fromJson(response['property']);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get property: $e');
    }
  }

  // Search properties
  Future<List<Property>> searchProperties({
    String? searchQuery,
    PropertyType? type,
    double? minPrice,
    double? maxPrice,
    String? location,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (searchQuery != null) queryParams['search'] = searchQuery;
      if (type != null) queryParams['type'] = type.name;
      if (minPrice != null) queryParams['minPrice'] = minPrice.toString();
      if (maxPrice != null) queryParams['maxPrice'] = maxPrice.toString();
      if (location != null) queryParams['location'] = location;

      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final response = await _apiService.get(
        '${ApiConfig.searchProperties}?$queryString',
      );
      final List<dynamic> data = response['properties'] ?? [];
      return data.map((json) => Property.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to search properties: $e');
    }
  }

  // Create property
  Future<Property> createProperty(Property property) async {
    try {
      final response = await _apiService.post(
        ApiConfig.createProperty,
        data: property.toJson(),
      );
      return Property.fromJson(response['property']);
    } catch (e) {
      throw Exception('Failed to create property: $e');
    }
  }

  // Update property
  Future<Property> updateProperty(String propertyId, Map<String, dynamic> updates) async {
    try {
      final response = await _apiService.put(
        '${ApiConfig.updateProperty}/$propertyId',
        data: updates,
      );
      return Property.fromJson(response['property']);
    } catch (e) {
      throw Exception('Failed to update property: $e');
    }
  }

  // Delete property
  Future<void> deleteProperty(String propertyId) async {
    try {
      await _apiService.delete('${ApiConfig.deleteProperty}/$propertyId');
    } catch (e) {
      throw Exception('Failed to delete property: $e');
    }
  }

  // Upload property images
  Future<List<String>> uploadPropertyImages(
    String propertyId,
    List<File> images,
  ) async {
    try {
      final imageUrls = <String>[];
      
      for (final image in images) {
        final response = await _apiService.uploadFile(
          '${ApiConfig.uploadPropertyImages}/$propertyId',
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

  // Delete property image
  Future<void> deletePropertyImage(String propertyId, String imageUrl) async {
    try {
      await _apiService.delete(
        '${ApiConfig.deletePropertyImage}/$propertyId',
        data: {'imageUrl': imageUrl},
      );
    } catch (e) {
      throw Exception('Failed to delete image: $e');
    }
  }

  // Toggle favorite
  Future<void> toggleFavorite(String propertyId) async {
    try {
      await _apiService.post(
        '${ApiConfig.toggleFavorite}/$propertyId',
        data: {},
      );
    } catch (e) {
      throw Exception('Failed to toggle favorite: $e');
    }
  }

  // Get user's favorite properties
  Future<List<Property>> getFavoriteProperties() async {
    try {
      final response = await _apiService.get(ApiConfig.getFavorites);
      final List<dynamic> data = response['properties'] ?? [];
      return data.map((json) => Property.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get favorite properties: $e');
    }
  }
}
