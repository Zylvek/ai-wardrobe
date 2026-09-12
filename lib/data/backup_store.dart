import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'constants.dart';
import 'options_store.dart';
import 'outfit_builder.dart';
import 'wardrobe_store.dart';
import 'wear_store.dart';

/// Бэкап гардероба: всё приложение (фото + данные) в один zip-файл.
///
/// Внутри архива:
///   wardrobe.json, outfits.json, wear_history.json,
///   custom_options.json, clothing_photos/<фото вещей>
///
/// При восстановлении пути внутри данных переписываются под папку
/// на этом компьютере/телефоне, поэтому бэкап переносится между
/// устройствами.
class BackupStore {
  static const _jsonNames = [
    'wardrobe.json',
    'outfits.json',
    'wear_history.json',
    'custom_options.json',
  ];

  static Future<String> _supportDir() async =>
      (await getApplicationSupportDirectory()).path;

  static Future<Directory> _photosDir() async {
    final dir = Directory(
      '${await _supportDir()}${Platform.pathSeparator}clothing_photos',
    );
    await dir.create(recursive: true);
    return dir;
  }

  /// Собирает zip с данными и фото и сохраняет в выбранное место.
  /// Возвращает путь (null — отмена).
  static Future<String?> exportBackup() async {
    final archive = Archive();

    // JSON-данные.
    final support = await _supportDir();
    for (final name in _jsonNames) {
      final f = File('$support${Platform.pathSeparator}$name');
      if (!await f.exists()) continue;
      archive.addFile(ArchiveFile.bytes(name, await f.readAsBytes()));
    }

    // Фото вещей.
    final photos = await _photosDir();
    await for (final f in photos.list()) {
      if (f is! File) continue;
      final name = f.path.split(Platform.pathSeparator).last;
      archive.addFile(
        ArchiveFile.bytes('clothing_photos/$name', await f.readAsBytes()),
      );
    }

    final zip = ZipEncoder().encode(archive);

    final now = DateTime.now();
    final defaultName =
        'wardrobe_backup_${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}.zip';
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Куда сохранить бэкап',
      fileName: defaultName,
      bytes: Uint8List.fromList(zip),
    );
    if (uri == null) return null;
    return uri.isScheme('file') ? uri.toFilePath() : uri.toString();
  }

  /// Восстанавливает из выбранного zip. Возвращает короткое описание
  /// результата (или null — отмена).
  static Future<String?> importBackup() async {
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'Выбери файл бэкапа',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (picked.isEmpty) return null;
    final bytes = await picked.first.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final support = await _supportDir();
    final photos = await _photosDir();

    // Распаковываем json и фото.
    var photosCount = 0;
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = file.name;
      if (_jsonNames.contains(name)) {
        await File('$support${Platform.pathSeparator}$name')
            .writeAsBytes(file.content as List<int>);
      } else if (name.startsWith('clothing_photos/')) {
        final fileName = name.split('/').last;
        if (fileName.isEmpty) continue;
        await File('${photos.path}${Platform.pathSeparator}$fileName')
            .writeAsBytes(file.content as List<int>);
        photosCount++;
      }
    }

    // Пути в wardrobe.json указывали на старое устройство — переписываем
    // под папку здесь.
    final photosBase = photos.path;
    String? remap(String? p) {
      if (p == null) return null;
      final marker = 'clothing_photos';
      final idx = p.indexOf(marker);
      if (idx == -1) return p;
      return '$photosBase${p.substring(idx + marker.length)}';
    }

    // Справочники пользовательских значений начинаем с чистого листа,
    // чтобы импорт не задвоил их с текущими.
    kTypes
      ..clear()
      ..addAll(kDefaultTypes);
    kWeathers
      ..clear()
      ..addAll(kDefaultWeathers);
    kNamedColors
      ..clear()
      ..addAll(kDefaultNamedColors);

    await OptionsStore.load();
    await WardrobeStore.load();
    await OutfitHistory.load();
    await WearStore.load();

    for (final item in WardrobeStore.items) {
      item
        ..imagePath = remap(item.imagePath) ?? item.imagePath
        ..originalPath = remap(item.originalPath);
      for (var i = 0; i < item.anglePaths.length; i++) {
        item.anglePaths[i] = remap(item.anglePaths[i]) ?? item.anglePaths[i];
      }
    }
    await WardrobeStore.save();

    wardrobeVersion.value++;
    wearVersion.value++;
    return 'Вещей: ${WardrobeStore.items.length} · фото: $photosCount';
  }
}