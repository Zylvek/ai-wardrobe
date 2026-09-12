// ignore_for_file: avoid_print
import 'dart:io';
import 'package:image/image.dart' as img;

void main(List<String> args) {
  for (final path in args) {
    final bytes = File(path).readAsBytesSync();
    final image = img.decodePng(bytes);
    if (image == null) {
      print('$path: не декодируется');
      continue;
    }
    print('$path: ${image.width}x${image.height}, каналов=${image.numChannels}');
    for (final p in [
      [5, 5],
      [400, 30],
    ]) {
      final c = image.getPixel(p[0], p[1]);
      print('  (${p[0]},${p[1]}): r=${c.r} g=${c.g} b=${c.b} a=${c.a}');
    }
  }
}