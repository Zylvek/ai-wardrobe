// Тест: синтетическое фото (одежда на однотонном фоне) → чистая карточка.
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;
import 'package:wardrobe_ai/data/image_cleaner.dart';

Future<void> main() async {
  // Рисуем «фото»: бежевый фон + зелёная кофта-пятнище по центру.
  final src = img.Image(width: 640, height: 640);
  img.fill(src, color: img.ColorRgba8(225, 215, 200, 255));
  final rnd = Random(7);
  for (var i = 0; i < 40000; i++) {
    // «Кофта» — плотное пятно зелёного цвета с рваными краями.
    final a = rnd.nextDouble() * 2 * pi;
    final r = rnd.nextDouble() * 180 + 20;
    final x = (320 + cos(a) * r).round();
    final y = (330 + sin(a) * r * 0.75).round();
    if (x > 0 && x < 640 && y > 0 && y < 640) {
      src.setPixelRgba(x, y, 40 + rnd.nextInt(40), 110 + rnd.nextInt(50),
          70 + rnd.nextInt(30), 255);
    }
  }
  final path = 'C:/Users/Admin/AppData/Local/Temp/synth_photo.png';
  File(path).writeAsBytesSync(img.encodePng(src));

  final out = await cleanClothingPhoto(
    path,
    sensitivity: 0.45,
    outPath: 'C:/Users/Admin/AppData/Local/Temp/synth_clean.png',
    debug: true,
  );
  print(out == null ? 'FAIL' : 'OK: $out');
}