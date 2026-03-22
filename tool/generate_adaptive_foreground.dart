import 'dart:collection';
import 'dart:io';

import 'package:image/image.dart' as img;

const String _sourcePath = 'assets/images/true_home_logo.png';
const String _outputPath = 'assets/images/app_icon_foreground_adaptive.png';
const int _canvasSize = 1024;
const int _foregroundSize = 640;
const int _whiteThreshold = 245;

void main() {
  final sourceFile = File(_sourcePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Source icon not found: $_sourcePath');
    exit(1);
  }

  final sourceBytes = sourceFile.readAsBytesSync();
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) {
    stderr.writeln('Failed to decode source image: $_sourcePath');
    exit(1);
  }

  final cleaned = img.Image.from(decoded, noAnimation: true);
  _removeBorderConnectedWhite(cleaned);

  final resized = img.copyResize(
    cleaned,
    width: _foregroundSize,
    height: _foregroundSize,
    interpolation: img.Interpolation.average,
  );

  final canvas = img.Image(width: _canvasSize, height: _canvasSize, numChannels: 4);
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

  final offset = (_canvasSize - _foregroundSize) ~/ 2;
  img.compositeImage(canvas, resized, dstX: offset, dstY: offset);

  final out = File(_outputPath);
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(img.encodePng(canvas));

  stdout.writeln('Generated adaptive foreground icon: $_outputPath');
}

void _removeBorderConnectedWhite(img.Image image) {
  final width = image.width;
  final height = image.height;
  final visited = List<bool>.filled(width * height, false);
  final queue = ListQueue<int>();

  void enqueue(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      return;
    }
    final index = y * width + x;
    if (visited[index] || !_isNearWhite(image.getPixel(x, y))) {
      return;
    }
    visited[index] = true;
    queue.add(index);
  }

  for (var x = 0; x < width; x++) {
    enqueue(x, 0);
    enqueue(x, height - 1);
  }
  for (var y = 0; y < height; y++) {
    enqueue(0, y);
    enqueue(width - 1, y);
  }

  while (queue.isNotEmpty) {
    final index = queue.removeFirst();
    final x = index % width;
    final y = index ~/ width;

    image.setPixelRgba(x, y, 255, 255, 255, 0);

    enqueue(x + 1, y);
    enqueue(x - 1, y);
    enqueue(x, y + 1);
    enqueue(x, y - 1);
  }
}

bool _isNearWhite(img.Pixel pixel) {
  return pixel.r >= _whiteThreshold &&
      pixel.g >= _whiteThreshold &&
      pixel.b >= _whiteThreshold;
}
