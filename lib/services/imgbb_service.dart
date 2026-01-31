import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';

class ImgBBService {
  static const String _uploadEndpoint = 'https://api.imgbb.com/1/upload';

  /// Upload image to ImgBB and return the image URL
  /// Returns null if upload fails
  static Future<String?> uploadImage(Uint8List imageBytes, {int retryCount = 2}) async {
    for (int attempt = 0; attempt <= retryCount; attempt++) {
      try {
        // Convert image bytes to base64
        final base64Image = base64Encode(imageBytes);

        // Create multipart request
        final uri = Uri.parse(_uploadEndpoint);
        final request = http.MultipartRequest('POST', uri);
        
        // Add API key and image data
        request.fields['key'] = ApiKeys.imgbbApiKey;
        request.fields['image'] = base64Image;

        // Send request with increased timeout for slow networks
        print('🔄 Uploading image (attempt ${attempt + 1}/${retryCount + 1})...');
        final streamedResponse = await request.send().timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            throw Exception('Upload timeout after 60 seconds - please check your internet connection');
          },
        );
        print('📡 Received response, processing...');
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final jsonResponse = json.decode(response.body);
          
          if (jsonResponse['success'] == true) {
            // Return the direct image URL
            final imageUrl = jsonResponse['data']['url'] as String;
            print('Image uploaded successfully: $imageUrl');
            return imageUrl;
          } else {
            final errorMsg = jsonResponse['error']?['message'] ?? 'Unknown error';
            print('ImgBB API error: $errorMsg');
            
            // Don't retry on API errors (bad request, invalid key, etc.)
            if (response.statusCode >= 400 && response.statusCode < 500) {
              return null;
            }
          }
        } else if (response.statusCode == 429) {
          // Rate limit exceeded - wait and retry
          print('ImgBB rate limit exceeded. Waiting before retry ${attempt + 1}/$retryCount...');
          if (attempt < retryCount) {
            await Future.delayed(Duration(seconds: (attempt + 1) * 2));
            continue;
          }
          print('ImgBB upload failed: Rate limit exceeded. Please try again later.');
          return null;
        } else {
          print('ImgBB upload failed with status: ${response.statusCode}');
          print('Response: ${response.body}');
          
          // Retry on server errors (5xx)
          if (response.statusCode >= 500 && attempt < retryCount) {
            print('Server error. Retrying ${attempt + 1}/$retryCount...');
            await Future.delayed(Duration(seconds: (attempt + 1) * 2));
            continue;
          }
          return null;
        }
      } catch (e) {
        print('❌ Error uploading to ImgBB (attempt ${attempt + 1}/${retryCount + 1}): $e');
        print('   Error type: ${e.runtimeType}');
        
        // Retry on network errors
        if (attempt < retryCount) {
          final waitSeconds = (attempt + 1) * 2;
          print('⏳ Retrying in $waitSeconds seconds...');
          await Future.delayed(Duration(seconds: waitSeconds));
          continue;
        }
        print('💥 All retry attempts exhausted. Upload failed.');
        return null;
      }
    }
    
    return null;
  }

  /// Upload multiple images and return list of URLs
  /// Returns empty list if all uploads fail
  static Future<List<String>> uploadMultipleImages(
    List<Uint8List> imageBytesList,
    {Function(int current, int total)? onProgress}
  ) async {
    final List<String> uploadedUrls = [];

    for (int i = 0; i < imageBytesList.length; i++) {
      onProgress?.call(i + 1, imageBytesList.length);
      
      final url = await uploadImage(imageBytesList[i]);
      if (url != null) {
        uploadedUrls.add(url);
      }
    }

    return uploadedUrls;
  }
}
