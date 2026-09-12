import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Текущая тема приложения (слушается в main.dart).
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

/// Настройки приложения: тема, город для погоды.
class SettingsStore {
  static String? cityName;
  static double? cityLat;
  static double? cityLon;
  static bool autoWeather = true;

  static Future<String> _filePath() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}${Platform.pathSeparator}settings.json';
  }

  static Future<void> load() async {
    try {
      final file = File(await _filePath());
      if (!await file.exists()) return;
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;

      themeModeNotifier.value = switch (data['themeMode'] as String? ?? 'system') {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      cityName = data['cityName'] as String?;
      cityLat = (data['cityLat'] as num?)?.toDouble();
      cityLon = (data['cityLon'] as num?)?.toDouble();
      autoWeather = data['autoWeather'] as bool? ?? true;
    } catch (_) {}
  }

  static Future<void> save() async {
    final mode = switch (themeModeNotifier.value) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
    final file = File(await _filePath());
    await file.writeAsString(jsonEncode({
      'themeMode': mode,
      'cityName': cityName,
      'cityLat': cityLat,
      'cityLon': cityLon,
      'autoWeather': autoWeather,
    }));
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    await save();
  }
}