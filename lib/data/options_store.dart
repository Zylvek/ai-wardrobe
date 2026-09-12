import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'constants.dart';

/// Сохраняет пользовательские (добавленные вручную) значения справочников.
class OptionsStore {
  static Future<String> _filePath() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}${Platform.pathSeparator}custom_options.json';
  }

  static Future<void> load() async {
    try {
      final file = File(await _filePath());
      if (!await file.exists()) return;
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;

      final types = (data['types'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .where((t) => !kDefaultTypes.contains(t));
      kTypes.addAll(types);

      final weathers = (data['weathers'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .where((w) => !kDefaultWeathers.contains(w));
      kWeathers.addAll(weathers);

      final colors = data['colors'] as Map<String, dynamic>? ?? {};
      colors.forEach((name, value) {
        if (!kDefaultNamedColors.containsKey(name)) {
          kNamedColors[name] = Color(value as int);
        }
      });
    } catch (_) {}
  }

  static Future<void> save() async {
    final customTypes =
        kTypes.where((t) => !kDefaultTypes.contains(t)).toList();
    final customWeathers =
        kWeathers.where((w) => !kDefaultWeathers.contains(w)).toList();
    final customColors = <String, int>{};
    kNamedColors.forEach((name, color) {
      if (!kDefaultNamedColors.containsKey(name)) {
        customColors[name] = color.toARGB32();
      }
    });

    final file = File(await _filePath());
    await file.writeAsString(jsonEncode({
      'types': customTypes,
      'weathers': customWeathers,
      'colors': customColors,
    }));
  }
}
