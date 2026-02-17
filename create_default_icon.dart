import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  // Create a simple blue icon with "TH" text
  final image = img.Image(width: 1024, height: 1024);
  
  // Fill with blue background
  img.fill(image, color: img.ColorRgb8(37, 99, 235)); // Blue color
  
  // Save the icon
  final pngBytes = img.encodePng(image);
  
  File('assets/images/true_home_logo.png').writeAsBytesSync(pngBytes);
  File('assets/images/app_icon.png').writeAsBytesSync(pngBytes);
  File('assets/images/app_icon_foreground.png').writeAsBytesSync(pngBytes);
  
  print('✅ Created simple blue icon');
}
