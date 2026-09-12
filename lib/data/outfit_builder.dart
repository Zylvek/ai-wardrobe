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

/// Восстанавливает образ из списка id вещей (для избранных образов и
/// истории носки). Вещи раскладываются по слотам по их типу.
Outfit? outfitFromIds(List<String> ids) {
  final items = <ClothingItem>[];
  for (final id in ids) {
    for (final item in WardrobeStore.items) {
      if (item.id == id) {
        items.add(item);
        break;
      }
    }
  }
  if (ids.isNotEmpty && items.isEmpty) return null;

  ClothingItem? inSlot(Set<String> types) {
    for (final i in items) {
      if (i.type != null && types.contains(i.type)) return i;
    }
    return null;
  }

  final top = inSlot(_topTypes);
  final bottom = inSlot(_bottomTypes);
  final shoes = inSlot(_shoeTypes);
  final outer = inSlot(_outerTypes);
  // Платье занимает слот верха, если верха и низа нет.
  final dress = (top == null && bottom == null) ? inSlot(_dressTypes) : null;

  final outfit = Outfit(
    top: top ?? dress,
    bottom: dress == null ? bottom : null,
    shoes: shoes,
    outer: outer,
  );
  if (outfit.items.isEmpty) return null;
  return outfit;
}

Outfit? _buildOnce(String weather) {
  final ok = kWeatherCompatible[weather] ?? kWeathers.toSet();

  List<ClothingItem> suitable(Set<String> types) => WardrobeStore.items
      .where((i) =>
          i.type != null &&
          types.contains(i.type) &&
          i.weather != null &&
          ok.contains(i.weather) &&
          // Вещь «в стирке» в образы не попадает.
          !i.inLaundry)
      .toList();

  // Каждый слот наполняется независимо: если есть хотя бы одна вещь
  // под погоду — образ соберётся, хоть из одной футболки.
  final top = _pick(suitable(_topTypes));
  final bottom = _pick(suitable(_bottomTypes));
  final shoes = _pick(suitable(_shoeTypes));

  // Платье заменяет верх + низ, только если их нет.
  ClothingItem? dress;
  if (top == null && bottom == null) {
    dress = _pick(suitable(_dressTypes));
  }

  ClothingItem? outer;
  if (weather == 'Холод' || weather == 'Дождь') {
    outer = _pick(suitable(_outerTypes));
  }

  final outfit = Outfit(
    top: top ?? dress,
    bottom: dress == null ? bottom : null,
    shoes: shoes,
    outer: outer,
  );
  if (outfit.items.isEmpty) return null;
  return outfit;
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
 