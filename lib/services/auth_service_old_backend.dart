import 'dart:io';
import 'dart:async';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Sign up with email and password
  Future<UserModel?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
    required UserRole role,
    String? companyName,
    String? companyAddress,
    String? whatsappNumber,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConfig.register,
        data: {
          'email': email,
          'password': password,
          'name': name,
          'phoneNumber': phoneNumber,
          'role': role.name,
          'companyName': companyName,
          'companyAddress': companyAddress,
          'whatsappNumber': whatsappNumber,
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Connection timeout. Please check your internet connection and try again.');
        },
      );

      // Save tokens
      await _apiService.saveTokens(
        response['accessToken'],
        response['refreshToken'],
      );
      
      // Save user info
      await _storage.write(key: ApiConfig.userIdKey, value: response['user']['id'].toString());
      await _storage.write(key: ApiConfig.userRoleKey, value: response['user']['role']);
      
      return UserModel.fromJson(response['user']);
    } on TimeoutException catch (e) {
      throw Exception('Connection timeout: ${e.message}');
    } on SocketException {
      throw Exception('No internet connection. Please check your network and try again.');
    } on HttpException {
      throw Exception('Server error. Please try again later.');
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  // Sign in with email and password
  Future<UserModel?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConfig.login,
        data: {
          'email': email,
          'password': password,
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Connection timeout. Please check your internet connection and try again.');
        },
      );

      // Save tokens
      await _apiService.saveTokens(
        response['accessToken'],
        response['refreshToken'],
      );
      
      // Save user info
      await _storage.write(key: ApiConfig.userIdKey, value: response['user']['id'].toString());
      await _storage.write(key: ApiConfig.userRoleKey, value: response['user']['role']);
      
      return UserModel.fromJson(response['user']);
    } on TimeoutException catch (e) {
      throw Exception('Connection timeout: ${e.message}');
    } on SocketException {
      throw Exception('No internet connection. Please check your network and try again.');
    } on HttpException {
      throw Exception('Server error. Please try again later.');
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  // Get current user ID
  Future<String?> getCurrentUserId() async {
    return await _storage.read(key: ApiConfig.userIdKey);
  }

  // Get current user role
  Future<UserRole?> getCurrentUserRole() async {
    final roleString = await _storage.read(key: ApiConfig.userRoleKey);
    if (roleString == null) return null;
    
    return UserRole.values.firstWhere(
      (e) => e.name == roleString,
      orElse: () => UserRole.customer,
    );
  }

  // Get user data
  Future<UserModel?> getUserData(String userId) async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.userProfile}/$userId',
      );

      return UserModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get user data: $e');
    }
  }

  // Get current user profile
  Future<UserModel?> getCurrentUser() async {
    try {
      final response = await _apiService.get(ApiConfig.userProfile);
      return UserModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get current user: $e');
    }
  }

  // Update user profile
  Future<void> updateUserProfile(UserModel user) async {
    try {
      await _apiService.put(
        ApiConfig.userProfile,
        data: user.toJson(),
      );
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _apiService.post(ApiConfig.logout);
      await _apiService.clearTokens();
    } catch (e) {
      // Clear tokens anyway even if API call fails
      await _apiService.clearTokens();
      throw Exception('Sign out failed: $e');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _apiService.post(
        '/auth/forgot-password',
        data: {'email': email},
      );
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final userId = await getCurrentUserId();
    return userId != null;
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      await _apiService.delete('/auth/account');
      await _apiService.clearTokens();
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }
}
