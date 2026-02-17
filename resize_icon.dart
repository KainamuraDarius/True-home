import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

void main() async {
  // Read the original icon
  final file = File('assets/images/true_home_logo.png');
  final bytes = await file.readAsBytes();
  
  // Decode the image
  final image = img.decodeImage(bytes);
  
  if (image == null) {
    print('❌ Failed to decode image');
    return;
  }
  
  print('Original size: ${image.width}x${image.height}');
  
  // Resize to 1024x1024 using high quality
  final resized = img.copyResize(
    image,
    width: 1024,
    height: 1024,
    interpolation: img.Interpolation.cubic,
  );
  
  // Save as PNG
  final pngBytes = img.encodePng(resized);
  
  await File('assets/images/true_home_logo.png').writeAsBytes(pngBytes);
  await File('assets/images/app_icon.png').writeAsBytes(pngBytes);
  await File('assets/images/app_icon_foreground.png').writeAsBytes(pngBytes);
  
  print('✅ Icon resized to 1024x1024 and saved!');
  print('   - true_home_logo.png');
  print('   - app_icon.png');
  print('   - app_icon_foreground.png');
}
