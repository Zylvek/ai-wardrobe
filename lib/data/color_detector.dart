import 'dart:io';
import 'dart:ui' as ui;

/// Определяет название цвета вещи по фото. Чистая математика, без API.
Future<String?> detectColorName(String imagePath) async {
  try {
    final bytes = await File(imagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 64,
      targetHeight: 64,
    );
    final frame = await codec.getNextFrame();
    final data =
        await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    frame.image.dispose();
    codec.dispose();
    if (data == null) return null;
    final pixels = data.buffer.asUint8List();

    final chromatic = <String, int>{};
    var chromaticCount = 0;
    var achromaticCount = 0;
    var achromaticLightSum = 0.0;

    for (var i = 0; i + 3 < pixels.length; i += 4) {
      final hsl = _rgbToHsl(pixels[i], pixels[i + 1], pixels[i + 2]);
      final h = hsl[0], s = hsl[1], l = hsl[2];

      if (l < 0.05 || l > 0.98) continue; // пропускаем тени и пересветы

      if (s >= 0.2) {
        final name = _hueToColorName(h, s, l);
        chromatic[name] = (chromatic[name] ?? 0) + 1;
        chromaticCount++;
      } else {
        achromaticCount++;
        achromaticLightSum += l;
      }
    }

    final considered = chromaticCount + achromaticCount;
    if (considered == 0) return null;

    // Если хотя бы треть фото — цветная, берём самый частый оттенок.
    if (chromaticCount / considered >= 0.3) {
      String? best;
      var bestCount = 0;
      chromatic.forEach((name, count) {
        if (count > bestCount) {
          best = name;
          bestCount = count;
        }
      });
      return best;
    }

    // Иначе вещь серых тонов — различаем по яркости.
    final avgLight =
        achromaticLightSum / (achromaticCount == 0 ? 1 : achromaticCount);
    if (avgLight < 0.25) return 'Чёрный';
    if (avgLight > 0.8) return 'Белый';
    return 'Серый';
  } catch (_) {
    return null;
  }
}

/// Переводит цвет из RGB в HSL. h: 0..360, s и l: 0..1
List<double> _rgbToHsl(int r8, int g8, int b8) {
  final r = r8 / 255, g = g8 / 255, b = b8 / 255;
  final max = r > g ? (r > b ? r : b) : (g > b ? g : b);
  final min = r < g ? (r < b ? r : b) : (g < b ? g : b);
  final l = (max + min) / 2;
  if (max == min) return [0, 0, l];
  final d = max - min;
  final s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
  double h;
  if (max == r) {
    h = (g - b) / d + (g < b ? 6 : 0);
  } else if (max == g) {
    h = (b - r) / d + 2;
  } else {
    h = (r - g) / d + 4;
  }
  h *= 60;
  return [h, s, l];
}

/// Подбирает название цвета по оттенку, насыщенности и яркости.
String _hueToColorName(double h, double s, double l) {
  if (h < 15 || h >= 345) return l >= 0.75 ? 'Розовый' : 'Красный';
  if (h < 45) {
    if (l < 0.4) return 'Коричневый';
    if (l > 0.85 && s < 0.5) return 'Бежевый';
    return 'Оранжевый';
  }
  if (h < 70) {
    if (l > 0.8) return 'Бежевый';
    return 'Жёлтый';
  }
  if (h < 165) return 'Зелёный';
  if (h < 255) return 'Синий';
  if (h < 295) return 'Фиолетовый';
  return 'Розовый';
}
