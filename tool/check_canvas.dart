// ignore_for_file: avoid_print
import 'dart:typed_data';
import 'package:image/image.dart' as img;

void main() {
  const size = 100;
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

  // «Вещь» — красный квадрат с альфой, только в центре.
  final obj = Uint8List(40 * 40 * 4);
  for (var i = 0; i < 40 * 40; i++) {
    obj[i * 4] = 200;
    obj[i * 4 + 1] = 30;
    obj[i * 4 + 2] = 30;
    obj[i * 4 + 3] = 255;
  }
  final objImg = img.Image.fromBytes(
    width: 40,
    height: 40,
    bytes: obj.buffer,
    order: img.ChannelOrder.rgba,
  );
  img.compositeImage(
    canvas,
    objImg,
    blend: img.BlendMode.alpha,
    dstX: 30,
    dstY: 30,
  );

  final png = img.encodePng(canvas);
  final back = img.decodePng(png)!;
  print('каналов=${back.numChannels}');
  final corner = back.getPixel(2, 2);
  final center = back.getPixel(50, 50);
  print('угол: r=${corner.r} a=${corner.a}');
  print('центр: r=${center.r} a=${center.a}');
}