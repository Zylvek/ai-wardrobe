import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'color_detector.dart';
import 'image_cleaner.dart';
import 'models.dart';

/// Счётчик изменений гардероба: увеличили — все экраны обновились.
final wardrobeVersion = ValueNotifier<int>(0);

/// Хранилище гардероба: сохраняет вещи в файл на диске.
class WardrobeStore {
  static final List<ClothingItem> items = [];

  static Future<String> _filePath() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}${Platform.pathSeparator}wardrobe.json';
  }

  static Future<void> load() async {
    try {
      final file = File(await _filePath());
      if (!await file.exists()) return;
      final data = jsonDecode(await file.readAsString()) as List<dynamic>;
      items
        ..clear()
        ..addAll(
          data.map((e) => ClothingItem.fromJson(e as Map<String, dynamic>)),
        );
    } catch (_) {}
  }

  static Future<void> save() async {
    final file = File(await _filePath());
    await file.writeAsString(
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  /// Папка для копий фото.
  static Future<Directory> _photosDir() async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory(
      '${appDir.path}${Platform.pathSeparator}clothing_photos',
    );
    await dir.create(recursive: true);
    return dir;
  }

  /// Добавляет вещь из уже выбранного фото: копирует оригинал,
  /// вычищает фон («умная камера»), определяет цвет, сохраняет.
  static Future<ClothingItem?> addFromPickedPhoto(String pickedPath) async {
    final photosDir = await _photosDir();
    final originalsDir = Directory(
      '${photosDir.path}${Platform.pathSeparator}originals',
    );
    await originalsDir.create(recursive: true);

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final ext = pickedPath.contains('.')
        ? pickedPath.split('.').last.toLowerCase()
        : 'jpg';
    final originalPath =
        '${originalsDir.path}${Platform.pathSeparator}$id.$ext';
    await File(pickedPath).copy(originalPath);

    // «Умная камера»: чистим фон (прозрачный PNG). Не получилось —
    // оставляем оригинал.
    final cleanedPath = '${photosDir.path}${Platform.pathSeparator}$id.png';
    final cleaned = await cleanClothingPhoto(
      originalPath,
      sensitivity: 0.45,
      outPath: cleanedPath,
    );
    final cardPath = cleaned ?? originalPath;

    // Цвет определяем по оригиналу (фон там не прозрачный белый холст).
    final detectedColor = await detectColorName(originalPath);

    final item = ClothingItem(
      id: id,
      imagePath: cardPath,
      originalPath: originalPath,
      color: detectedColor,
    );
    items.add(item);
    await save();
    wardrobeVersion.value++;
    return item;
  }

  /// Добавляет к вещи ещё один ракурс: та же «умная камера», что и при
  /// первом фото — копия оригинала, чистка фона, прозрачный PNG.
  /// Возвращает путь к очищенному кадру (или null, если обработка не вышла).
  static Future<String?> addAnglePhoto(
    ClothingItem item,
    String pickedPath,
  ) async {
    final photosDir = await _photosDir();
    final originalsDir = Directory(
      '${photosDir.path}${Platform.pathSeparator}originals',
    );
    await originalsDir.create(recursive: true);

    final stamp = DateTime.now().millisecondsSinceEpoch.toString();
    final ext = pickedPath.contains('.')
        ? pickedPath.split('.').last.toLowerCase()
        : 'jpg';
    final originalPath =
        '${originalsDir.path}${Platform.pathSeparator}'
        'angle_${item.id}_$stamp.$ext';
    await File(pickedPath).copy(originalPath);

    final cleanedPath =
        '${photosDir.path}${Platform.pathSeparator}angle_${item.id}_$stamp.png';
    final cleaned = await cleanClothingPhoto(
      originalPath,
      sensitivity: 0.45,
      outPath: cleanedPath,
    );
    if (cleaned == null) return null;

    item.anglePaths.add(cleaned);
    await save();
    wardrobeVersion.value++;
    return cleaned;
  }
}

/// Открывает диалог выбора фото и возвращает путь (или null при отмене).
Future<String?> pickPhotoFromFiles() async {
  final files = await FilePicker.pickFiles(
    dialogTitle: 'Выбери фото одежды',
    type: FileType.custom,
    allowedExtensions: const ['png', 'jpg', 'jpeg', 'bmp', 'gif', 'webp'],
  );
  if (files.isEmpty) return null;
  return files.first.path;
}