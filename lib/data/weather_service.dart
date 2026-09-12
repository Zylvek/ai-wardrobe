import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Настоящая погода за окном.
///
/// Как работает: по интернету узнаём примерное место (по IP, без ключей
/// и входов), потом берём текущую погоду с открытого сервиса open-meteo
/// и переводим её в наши категории: Жара / Тепло / Прохладно / Холод /
/// Дождь.
class WeatherInfo {
  const WeatherInfo({required this.category, this.temp});

  /// Категория из списка kWeathers.
  final String category;

  /// Температура в °C (если успели получить).
  final double? temp;
}

/// Получает погоду. Возвращает null, если интернета нет или сервис
/// не ответил — тогда приложение просто оставит выбранную погоду.
Future<WeatherInfo?> fetchRealWeather() async {
  try {
    // Примерное место по IP.
    final locResp = await http
        .get(Uri.parse('https://ipwho.is/'))
        .timeout(const Duration(seconds: 6));
    if (locResp.statusCode != 200) return null;
    final loc = jsonDecode(locResp.body) as Map<String, dynamic>;
    final lat = loc['latitude'];
    final lon = loc['longitude'];
    if (lat is! num || lon is! num) return null;

    // Текущая погода (без ключей).
    final wxResp = await http
        .get(Uri.parse(
            'https://api.open-meteo.com/v1/forecast'
            '?latitude=$lat&longitude=$lon'
            '&current=temperature_2m,weather_code'))
        .timeout(const Duration(seconds: 6));
    if (wxResp.statusCode != 200) return null;
    final wx = jsonDecode(wxResp.body) as Map<String, dynamic>;
    final current = wx['current'] as Map<String, dynamic>?;
    if (current == null) return null;

    final temp = (current['temperature_2m'] as num?)?.toDouble();
    final code = (current['weather_code'] as num?)?.toInt();
    if (temp == null || code == null) return null;

    return WeatherInfo(category: _categorize(temp, code), temp: temp);
  } catch (_) {
    return null;
  }
}

/// Переводит код погоды и температуру в нашу категорию.
String _categorize(double temp, int code) {
  // Дождь: морось 51–57, дождь 61–67, ливни 80–82, гроза 95–99.
  final rain = (code >= 51 && code <= 67) ||
      (code >= 80 && code <= 82) ||
      code >= 95;
  if (rain) return 'Дождь';
  // Снег: 71–77, 85–86 — это всё равно «Холод».
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
    return 'Холод';
  }
  if (temp >= 27) return 'Жара';
  if (temp >= 15) return 'Тепло';
  if (temp >= 2) return 'Прохладно';
  return 'Холод';
}