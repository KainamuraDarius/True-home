import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';

class ImgBBService {
  static const String _uploadEndpoint = 'https://api.imgbb.com/1/upload';

  /// Upload image to ImgBB and return the image URL
  /// Returns null if upload fails
  static Future<String?> uploadImage(Uint8List imageBytes) async {
    try {
      // Convert image bytes to base64
      final base64Image = base64Encode(imageBytes);

      // Create multipart request
      final uri = Uri.parse(_uploadEndpoint);
      final request = http.MultipartRequest('POST', uri);
      
      // Add API key and image data
      request.fields['key'] = ApiKeys.imgbbApiKey;
      request.fields['image'] = base64Image;

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        
        if (jsonResponse['success'] == true) {
          // Return the direct image URL
          final imageUrl = jsonResponse['data']['url'] as String;
          print('Image uploaded successfully: $imageUrl');
          return imageUrl;
        } else {
          print('ImgBB API error: ${jsonResponse['error']['message']}');
          return null;
        }
      } else {
        print('ImgBB upload failed with status: ${response.statusCode}');
        print('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error uploading to ImgBB: $e');
      return null;
    }
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
