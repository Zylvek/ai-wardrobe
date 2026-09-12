import 'package:flutter/material.dart';

// ───────── Справочники характеристик вещи ─────────
// Значения по умолчанию (не меняются во время работы):

const List<String> kDefaultTypes = [
  'Футболка', 'Кофта', 'Рубашка', 'Свитер', 'Брюки', 'Джинсы',
  'Шорты', 'Юбка', 'Платье', 'Куртка', 'Пальто', 'Обувь',
];

const Map<String, Color> kDefaultNamedColors = {
  'Белый': Colors.white,
  'Чёрный': Colors.black87,
  'Серый': Colors.grey,
  'Бежевый': Color(0xFFE8D5B5),
  'Красный': Colors.red,
  'Розовый': Colors.pink,
  'Оранжевый': Colors.orange,
  'Жёлтый': Colors.yellow,
  'Зелёный': Colors.green,
  'Синий': Colors.blue,
  'Фиолетовый': Colors.purple,
  'Коричневый': Colors.brown,
};

const List<String> kDefaultWeathers = [
  'Жара', 'Тепло', 'Прохладно', 'Холод', 'Дождь',
];

// ───────── Рабочие справочники ─────────
// Сюда добавляются пользовательские значения (кнопка «+ Свой»).

final List<String> kTypes = List.of(kDefaultTypes);
final Map<String, Color> kNamedColors = Map.of(kDefaultNamedColors);
final List<String> kWeathers = List.of(kDefaultWeathers);

/// Нейтральные цвета — сочетаются почти с любым другим цветом.
const Set<String> kNeutralColors = {
  'Белый', 'Чёрный', 'Серый', 'Бежевый', 'Коричневый',
};
