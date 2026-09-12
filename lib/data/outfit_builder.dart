import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

import 'constants.dart';
import 'models.dart';
import 'wardrobe_store.dart';

// ───────── Модель образа ─────────

class Outfit {
  Outfit({this.top, this.bottom, this.shoes, this.outer});

  final ClothingItem? top;
  final ClothingItem? bottom;
  final ClothingItem? shoes;
  final ClothingItem? outer;

  List<ClothingItem> get items => [
        ?top,
        ?bottom,
        ?shoes,
        ?outer,
      ];
}

// ───────── Категории одежды ─────────

const Set<String> _topTypes = {'Футболка', 'Кофта', 'Рубашка', 'Свитер'};
const Set<String> _bottomTypes = {'Брюки', 'Джинсы', 'Шорты', 'Юбка'};
const Set<String> _dressTypes = {'Платье'};
const Set<String> _shoeTypes = {'Обувь'};
const Set<String> _outerTypes = {'Куртка', 'Пальто'};

/// Какая одежда подходит под какую погоду.
const Map<String, Set<String>> kWeatherCompatible = {
  'Жара': {'Жара'},
  'Тепло': {'Тепло', 'Жара'},
  'Прохладно': {'Прохладно', 'Тепло'},
  'Холод': {'Холод', 'Прохладно'},
  'Дождь': {'Дождь', 'Прохладно', 'Холод', 'Тепло', 'Жара'},
};

final _random = Random();

T? _pick<T>(List<T> list) =>
    list.isEmpty ? null : list[_random.nextInt(list.length)];

/// Собирает образ из вещей гардероба.
/// Возвращает null, если собрать не из чего.
Outfit? buildOutfit({required String weather, Outfit? avoid}) {
  Outfit? result;
  for (var attempt = 0; attempt < 10; attempt++) {
    result = _buildOnce(weather);
    if (avoid == null || _idsOf(result!) != _idsOf(avoid)) break;
  }
  return result;
}

String _idsOf(Outfit outfit) => outfit.items.map((e) => e.id).join(',');

Outfit? _buildOnce(String weather) {
  final ok = kWeatherCompatible[weather] ?? kWeathers.toSet();

  List<ClothingItem> suitable(Set<String> types) => WardrobeStore.items
      .where((i) =>
          i.type != null &&
          types.contains(i.type) &&
          i.weather != null &&
          ok.contains(i.weather))
      .toList();

  final tops = suitable(_topTypes);
  final bottoms = suitable(_bottomTypes);
  final dresses = suitable(_dressTypes);
  final shoes = suitable(_shoeTypes);
  final outers = suitable(_outerTypes);

  final ClothingItem? top;
  final ClothingItem? bottom;
  if (tops.isNotEmpty && bottoms.isNotEmpty) {
    top = _pick(tops);
    bottom = _pick(bottoms);
  } else if (dresses.isNotEmpty) {
    // Платье заменяет верх + низ.
    top = _pick(dresses);
    bottom = null;
  } else {
    top = null;
    bottom = null;
  }

  if (top == null && bottom == null) return null;

  ClothingItem? outer;
  if ((weather == 'Холод' || weather == 'Дождь') && outers.isNotEmpty) {
    outer = _pick(outers);
  }

  return Outfit(top: top, bottom: bottom, shoes: _pick(shoes), outer: outer);
}

// ───────── История оценок (для «понимания вкуса») ─────────

class OutfitEntry {
  OutfitEntry({
    required this.itemIds,
    required this.rating,
    required this.weather,
  });

  final List<String> itemIds;
  final int rating; // 1 = понравилось, -1 = нет
  final String weather;

  Map<String, dynamic> toJson() => {
        'itemIds': itemIds,
        'rating': rating,
        'weather': weather,
      };

  factory OutfitEntry.fromJson(Map<String, dynamic> json) => OutfitEntry(
        itemIds: (json['itemIds'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
        rating: json['rating'] as int,
        weather: json['weather'] as String,
      );
}

class OutfitHistory {
  static final List<OutfitEntry> entries = [];

  static Future<String> _filePath() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}${Platform.pathSeparator}outfits.json';
  }

  static Future<void> load() async {
    try {
      final file = File(await _filePath());
      if (!await file.exists()) return;
      final data = jsonDecode(await file.readAsString()) as List<dynamic>;
      entries
        ..clear()
        ..addAll(data
            .map((e) => OutfitEntry.fromJson(e as Map<String, dynamic>)));
    } catch (_) {}
  }

  static Future<void> save() async {
    final file = File(await _filePath());
    await file
        .writeAsString(jsonEncode(entries.map((e) => e.toJson()).toList()));
  }
}

/// Записывает оценку образа в историю.
Future<void> rateOutfit(Outfit outfit, int rating, String weather) async {
  OutfitHistory.entries.add(
    OutfitEntry(
      itemIds: outfit.items.map((e) => e.id).toList(),
      rating: rating,
      weather: weather,
    ),
  );
  await OutfitHistory.save();
}
 