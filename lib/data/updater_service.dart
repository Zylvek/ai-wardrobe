import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Информация о доступном обновлении.
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.buildNumber,
    required this.apkUrl,
    required this.notes,
    required this.sizeBytes,
  });

  /// Версия без 'v' и без '+сборка', например '1.0.1'.
  final String version;

  /// Номер сборки из тега релиза (после '+'). Сравниваем по нему.
  final int buildNumber;

  /// Прямая ссылка на APK в GitHub Releases.
  final String apkUrl;

  final String notes;
  final int sizeBytes;
}

/// Самообновление приложения: телефон проверяет последний релиз на GitHub,
/// скачивает APK и запускает установщик.
///
/// Релизы называем тегом вида `v1.0.1+5` — номер после '+' это versionCode
/// из pubspec.yaml, только по нему и сравниваем.
class UpdaterService {
  static const _repoApi =
      'https://api.github.com/repos/Zylvek/ai-wardrobe/releases/latest';
  static const _installChannel = MethodChannel('ai_wardrobe/install');

  /// Проверяет последний релиз на GitHub. Возвращает null, если:
  /// сети нет / релизов нет / новой версии нет / нашлось без APK.
  static Future<AppUpdate?> checkLatest() async {
    try {
      final resp = await http.get(
        Uri.parse(_repoApi),
        headers: const {
          'User-Agent': 'AI Wardrobe',
          'Accept': 'application/vnd.github+json',
        },
      );
      if (resp.statusCode != 200) return null;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final tag = json['tag_name'] as String? ?? '';
      final plus = tag.indexOf('+');
      final build =
          plus >= 0 ? int.tryParse(tag.substring(plus + 1)) : null;
      if (build == null) return null;

      final info = await PackageInfo.fromPlatform();
      if (build <= (int.tryParse(info.buildNumber) ?? 0)) return null;

      final assets = (json['assets'] as List?) ?? const [];
      Map<String, dynamic>? apk;
      for (final asset in assets) {
        final name = (asset['name'] as String?) ?? '';
        if (name.toLowerCase().endsWith('.apk')) {
          apk = asset;
          break;
        }
      }
      if (apk == null) return null;

      return AppUpdate(
        version: plus >= 0 ? tag.substring(1, plus) : tag.substring(1),
        buildNumber: build,
        apkUrl: apk['browser_download_url'] as String,
        notes: json['body'] as String? ?? '',
        sizeBytes: apk['size'] as int? ?? 0,
      );
    } catch (_) {
      return null; // нет сети — молча пропускаем, приложение работает дальше
    }
  }

  /// Скачивает APK во временный каталог, отдаёт прогресс 0..1.
  static Future<File> downloadApk(
    AppUpdate update, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}'
        'wardrobe_update.apk');
    final client = http.Client();
    try {
      final resp = await client.send(
        http.Request('GET', Uri.parse(update.apkUrl)),
      );
      final total = resp.contentLength ?? update.sizeBytes;
      var received = 0;
      final sink = file.openWrite();
      await for (final chunk in resp.stream) {
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      return file;
    } finally {
      client.close();
    }
  }

  /// Запускает системный установщик APK (только Android; на других
  /// платформах — ничего).
  static Future<void> installApk(String filePath) async {
    if (!Platform.isAndroid) return;
    try {
      await _installChannel
          .invokeMethod('installApk', {'path': filePath});
    } catch (_) {}
  }
}