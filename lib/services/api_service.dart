import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  
  late Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      sendTimeout: ApiConfig.sendTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      validateStatus: (status) {
        return status! < 500;
      },
    ));
    
    _setupInterceptors();
  }
  
  void _setupInterceptors() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add auth token to requests
        final token = await _storage.read(key: ApiConfig.accessTokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        // Handle 401 Unauthorized - token expired
        if (error.response?.statusCode == 401) {
          // Try to refresh token
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry the original request
            return handler.resolve(await _retry(error.requestOptions));
          }
        }
        return handler.next(error);
      },
    ));
  }
  
  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    final options = Options(
      method: requestOptions.method,
      headers: requestOptions.headers,
    );
    return _dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }
  
  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: ApiConfig.refreshTokenKey);
      if (refreshToken == null) return false;
      
      final response = await _dio.post(
        ApiConfig.refreshToken,
        data: {'refreshToken': refreshToken},
      );
      
      if (response.statusCode == 200) {
        final newAccessToken = response.data['accessToken'];
        await _storage.write(
          key: ApiConfig.accessTokenKey,
          value: newAccessToken,
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  // Save authentication tokens
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: ApiConfig.accessTokenKey, value: accessToken);
    await _storage.write(key: ApiConfig.refreshTokenKey, value: refreshToken);
  }
  
  // Clear authentication tokens
  Future<void> clearTokens() async {
    await _storage.delete(key: ApiConfig.accessTokenKey);
    await _storage.delete(key: ApiConfig.refreshTokenKey);
    await _storage.delete(key: ApiConfig.userIdKey);
    await _storage.delete(key: ApiConfig.userRoleKey);
  }
  
  // GET request
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  // POST request with retry logic
  Future<Map<String, dynamic>> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    int retries = 0;
    Exception? lastError;
    
    while (retries < ApiConfig.maxRetries) {
      try {
        final response = await _dio.post(path, data: data, queryParameters: queryParameters);
        return response.data as Map<String, dynamic>;
      } on DioException catch (e) {
        lastError = _handleError(e);
        
        // Don't retry for client errors (4xx)
        if (e.response?.statusCode != null && e.response!.statusCode! >= 400 && e.response!.statusCode! < 500) {
          throw lastError;
        }
        
        if (retries >= ApiConfig.maxRetries - 1) {
          throw lastError;
        }
        
        retries++;
        await Future.delayed(ApiConfig.retryDelay * retries);
      }
    }
    
    throw lastError ?? Exception('Failed after ${ApiConfig.maxRetries} attempts');
  }
  
  // PUT request
  Future<Map<String, dynamic>> put(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.put(path, data: data, queryParameters: queryParameters);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  // PATCH request
  Future<Map<String, dynamic>> patch(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.patch(path, data: data, queryParameters: queryParameters);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  // DELETE request
  Future<Map<String, dynamic>> delete(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  // Upload file
  Future<Map<String, dynamic>> uploadFile(String path, File file, {String fieldName = 'file'}) async {
    try {
      FormData formData = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(file.path),
      });
      final response = await _dio.post(path, data: formData);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  // Upload multiple files
  Future<Map<String, dynamic>> uploadFiles(String path, List<File> files, {String fieldName = 'files'}) async {
    try {
      List<MultipartFile> multipartFiles = [];
      for (File file in files) {
        multipartFiles.add(await MultipartFile.fromFile(file.path));
      }
      
      FormData formData = FormData.fromMap({
        fieldName: multipartFiles,
      });
      
      final response = await _dio.post(path, data: formData);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  // Error handling
  Exception _handleError(DioException error) {
    String errorMessage = 'An error occurred';
    
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        errorMessage = 'Connection timeout.\n\n'
            'The server at ${ApiConfig.baseUrl} is taking too long to respond.\n\n'
            'Please check:\n'
            '• Your backend server is running\n'
            '• The server URL is correct\n'
            '• Your internet connection';
        break;
      case DioExceptionType.sendTimeout:
        errorMessage = 'Send timeout. Failed to send data to server.';
        break;
      case DioExceptionType.receiveTimeout:
        errorMessage = 'Receive timeout. Server is not responding.';
        break;
      case DioExceptionType.badResponse:
        errorMessage = _handleResponseError(error.response);
        break;
      case DioExceptionType.cancel:
        errorMessage = 'Request cancelled';
        break;
      case DioExceptionType.connectionError:
        if (error.error is SocketException) {
          errorMessage = 'Cannot connect to server.\n\n'
              'Server URL: ${ApiConfig.baseUrl}\n\n'
              'Please ensure:\n'
              '• Your backend server is running\n'
              '• You have internet connection\n'
              '• Server URL is configured correctly\n'
              '• Firewall is not blocking the connection';
        } else {
          errorMessage = 'Connection error. Please check your internet connection.';
        }
        break;
      case DioExceptionType.unknown:
        if (error.error is SocketException) {
          final socketError = error.error as SocketException;
          errorMessage = 'Network error.\n\n'
              'Cannot reach server at ${ApiConfig.baseUrl}\n\n'
              'Details: ${socketError.message}\n\n'
              'OS Error: ${socketError.osError?.message ?? "Unknown"}';
        } else {
          errorMessage = 'Unexpected error: ${error.message}';
        }
        break;
      default:
        errorMessage = 'Unexpected error occurred';
    }
    
    return Exception(errorMessage);
  }
  
  String _handleResponseError(Response? response) {
    if (response == null) return 'Unknown error occurred';
    
    switch (response.statusCode) {
      case 400:
        return response.data['message'] ?? 'Bad request';
      case 401:
        return 'Unauthorized. Please login again.';
      case 403:
        return 'Access forbidden';
      case 404:
        return 'Resource not found';
      case 422:
        return response.data['message'] ?? 'Validation error';
      case 500:
        return 'Server error. Please try again later.';
      default:
        return response.data['message'] ?? 'An error occurred';
    }
  }
}
