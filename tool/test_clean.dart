// Тестовый скрипт: проверка очистки фона на реальном фото.
// ignore_for_file: avoid_print
// Запуск: dart run tool/test_clean.dart <путь_к_фото> [sensitivity]
import 'dart:io';

import 'package:wardrobe_ai/data/image_cleaner.dart';

Future<void> main(List<String> args) async {
  final src = args.isNotEmpty
      ? args[0]
      : 'C:/Users/Admin/AppData/Roaming/com.example/wardrobe_ai/clothing_photos/1789127563150.jpg';
  final sens = args.length > 1 ? double.parse(args[1]) : 0.45;
  final out = 'C:/Users/Admin/AppData/Local/Temp/test_clean_$sens.png';
  final result = await cleanClothingPhoto(
    src,
    sensitivity: sens,
    outPath: out,
    debug: true,
  );
  print(result == null
      ? 'FAIL: очистка не удалась'
      : 'OK: $result (${File(result).lengthSync()} bytes)');
}