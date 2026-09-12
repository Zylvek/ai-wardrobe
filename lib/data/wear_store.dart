import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';
import 'outfit_builder.dart';
import 'wardrobe_store.dart';

/// Счётчик изменений истории носки: увеличили — экраны обновились.
final wearVersion = ValueNotifier<int>(0);

/// День, когда надели образ (ISO «2026-09-12»).
class WearEvent {
  WearEvent({
    required this.date,
    required this.itemIds,
    required this.weather,
  });

  final String date; // yyyy-MM-dd
  final List<String> itemIds;
  final String weather;

  Map<String, dynamic> toJson() => {
        'date': date,
        'itemIds': itemIds,
        'weather': weather,
      };

  factory WearEvent.fromJson(Map<String, dynamic> json) => WearEvent(
        date: json['date'] as String,
        itemIds: (json['itemIds'] as List<dynamic>).cast<String>(),
        weather: json['weather'] as String,
      );
}

/// Сохранённый «избранный» образ — набор id вещей.
class FavoriteOutfit {
  FavoriteOutfit({required this.id, required this.itemIds});

  final String id;
  final List<String> itemIds;

  Map<String, dynamic> toJson() => {'id': id, 'itemIds': itemIds};

  factory FavoriteOutfit.fromJson(Map<String, dynamic> json) =>
      FavoriteOutfit(
        id: json['id'] as String,
        itemIds: (json['itemIds'] as List<dynamic>).cast<String>(),
      );
}

/// История носки и избранные образы: один файл wear_history.json.
class WearStore {
  static final List<WearEvent> events = [];
  static final List<FavoriteOutfit> favorites = [];

  static Future<String> _filePath() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}${Platform.pathSeparator}wear_history.json';
  }

  static Future<void> load() async {
    try {
      final file = File(await _filePath());
      if (!await file.exists()) return;
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      events
        ..clear()
        ..addAll((data['events'] as List<dynamic>? ?? [])
            .map((e) => WearEvent.fromJson(e as Map<String, dynamic>)));
      favorites
        ..clear()
        ..addAll((data['favorites'] as List<dynamic>? ?? [])
            .map((e) => FavoriteOutfit.fromJson(e as Map<String, dynamic>)));
    } catch (_) {}
  }

  static Future<void> save() async {
    final file = File(await _filePath());
    await file.writeAsString(jsonEncode({
      'events': events.map((e) => e.toJson()).toList(),
      'favorites': favorites.map((e) => e.toJson()).toList(),
    }));
  }

  static String _today() {
    final t = DateTime.now();
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
  }

  /// Записывает «надел сегодня» за образ.
  static Future<void> addWear(Outfit outfit, String weather) async {
    final ids = outfit.items.map((e) => e.id).toList();
    final today = _today();
    // Один образ в день не дублируем.
    events.removeWhere(
        (e) => e.date == today && e.itemIds.join(',') == ids.join(','));
    events.add(WearEvent(date: today, itemIds: ids, weather: weather));
    await save();
    wearVersion.value++;
  }

  /// Сколько раз вещь была надета (во всех образах).
  static int wearCount(String itemId) {
    var n = 0;
    for (final e in events) {
      if (e.itemIds.contains(itemId)) n++;
    }
    return n;
  }

  /// Последний день, когда вещь была надета, или null.
  static String? lastWorn(String itemId) {
    String? last;
    for (final e in events) {
      if (e.itemIds.contains(itemId)) {
        if (last == null || e.date.compareTo(last) > 0) last = e.date;
      }
    }
    return last;
  }

  /// Есть ли запись носки за этот день.
  static WearEvent? eventFor(String date) {
    for (final e in events) {
      if (e.date == date) return e;
    }
    return null;
  }

  static bool hasFavorite(List<String> ids) {
    final key = ids.join(',');
    return favorites.any((f) => f.itemIds.join(',') == key);
  }

  /// Добавляет/убирает образ из избранного. Возвращает true, если теперь
  /// образ в избранном.
  static Future<bool> toggleFavorite(Outfit outfit) async {
    final ids = outfit.items.map((e) => e.id).toList();
    final key = ids.join(',');
    final existing =
        favorites.where((f) => f.itemIds.join(',') == key).toList();
    if (existing.isNotEmpty) {
      for (final f in existing) {
        favorites.remove(f);
      }
      await save();
      wearVersion.value++;
      return false;
    }
    favorites.add(FavoriteOutfit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      itemIds: ids,
    ));
    await save();
    wearVersion.value++;
    return true;
  }

  static void removeFavorite(FavoriteOutfit f) {
    favorites.remove(f);
    save();
    wearVersion.value++;
  }

  // ───────── Статистика ─────────

  /// Вещи, отсортированные по частоте носки (частые сверху).
  static List<(ClothingItem, int)> itemsByWearCount() {
    final list = <(ClothingItem, int)>[];
    for (final item in WardrobeStore.items) {
      final c = wearCount(item.id);
      if (c > 0) list.add((item, c));
    }
    list.sort((a, b) => b.$2.compareTo(a.$2));
    return list;
  }

  /// Вещи, которые ещё ни разу не надевали.
  static List<ClothingItem> neverWorn() => WardrobeStore.items
      .where((i) => wearCount(i.id) == 0)
      .toList();
}