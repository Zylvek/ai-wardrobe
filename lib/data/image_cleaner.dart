import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'ml_segmenter.dart';

/// «Умная камера»: делает из фото чистую карточку вещи с прозрачным
/// фоном (PNG 800×800).
///
/// Путь 1 (основной) — нейросеть U²-Net: понимает, где на фото вещь,
/// даже на тёмном/пёстром фоне. Локально и бесплатно.
/// Путь 2 (запасной) — классический алгоритм: заливка от краёв.
/// Не получилось — возвращаем null, приложение оставляет оригинал.
///
/// [sensitivity] 0..1 влияет только на запасной алгоритм.
/// Возвращает путь к чистому PNG или null.
Future<String?> cleanClothingPhoto(
  String sourcePath, {
  double sensitivity = 0.45,
  String? outPath,
  bool debug = false,
}) async {
  void log(String s) {
    if (debug) print('[image_cleaner] $s'); // ignore: avoid_print
  }

  try {
    final bytes = await File(sourcePath).readAsBytes();
    img.Image? src = img.decodeImage(bytes);
    if (src == null) {
      log('не удалось декодировать файл');
      return null;
    }
    src = img.bakeOrientation(src);

    // Ограничиваем размер ради скорости.
    const maxDim = 900;
    if (src.width > maxDim || src.height > maxDim) {
      src = src.width >= src.height
          ? img.copyResize(src, width: maxDim)
          : img.copyResize(src, height: maxDim);
    }
    final w = src.width;
    final h = src.height;
    final rgba = src.getBytes(order: img.ChannelOrder.rgba);

    // 1. Нейросеть: где вещь?
    Uint8List? alpha;
    try {
      final mask = await MlSegmenter.runU2Net(src);
      if (mask != null) {
        final a = MlSegmenter.maskToAlpha(mask, w, h);
        MlSegmenter.keepLargestComponent(a, w, h);
        // v2 фильтра: дыры внутри вещи закрываем, маску сглаживаем,
        // край делаем мягким.
        MlSegmenter.fillHoles(a, w, h);
        MlSegmenter.smoothAlpha(a, w, h);
        MlSegmenter.featherEdge(a, w, h);
        var cnt = 0;
        for (final v in a) {
          if (v > 128) cnt++;
        }
        final ratio = cnt / (w * h);
        log('нейросеть: вещь занимает ${(ratio * 100).round()}% фото');
        // Совсем пустая карта или «вещь заняла всё» — не верим.
        if (ratio > 0.03 && ratio < 0.95) alpha = a;
      }
    } catch (e) {
      log('нейросеть не сработала: $e');
    }

    // 2. Запасной путь — классический алгоритм (заливка от краёв).
    alpha ??= _classicAlpha(rgba, w, h, sensitivity, log);
    if (alpha == null) return null;

    // 3. Границы вещи + небольшое поле.
    var minX = w, minY = h, maxX = -1, maxY = -1;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (alpha[y * w + x] > 10) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < 0) {
      log('отказ: объект не найден');
      return null;
    }
    final objW = maxX - minX + 1;
    final objH = maxY - minY + 1;
    if (objW * objH < w * h * 0.03) {
      log('отказ: объект слишком мелкий');
      return null;
    }

    // 4. Квадратный холст 800×800, вещь вписана в ~88%.
    const canvasSize = 800;
    final scale = min(
      canvasSize * 0.88 / objW,
      canvasSize * 0.88 / objH,
    );
    final scaled = img.copyResize(
      _cropWithAlpha(rgba, alpha, w, h, minX, minY, maxX, maxY),
      width: (objW * scale).round().clamp(1, canvasSize),
      height: (objH * scale).round().clamp(1, canvasSize),
      interpolation: img.Interpolation.average,
    );

    // numChannels: 4 — иначе прозрачность молча теряется (image 4.x
    // по умолчанию делает RGB без альфы, и фон становится чёрным).
    final canvas = img.Image(
      width: canvasSize,
      height: canvasSize,
      numChannels: 4,
    );
    img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));
    img.compositeImage(
      canvas,
      scaled,
      blend: img.BlendMode.alpha,
      dstX: (canvasSize - scaled.width) ~/ 2,
      dstY: (canvasSize - scaled.height) ~/ 2,
    );

    final result = outPath ??
        '${File(sourcePath).parent.path}'
        '${Platform.pathSeparator}clean_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(result).writeAsBytes(img.encodePng(canvas));
    return result;
  } catch (_) {
    return null;
  }
}

// ───────── Запасной классический алгоритм ─────────

/// Старый путь: цвета фона по рамке → BFS-заливка с барьером из
/// резких краёв → мягкая кромка. Возвращает альфу или null.
Uint8List? _classicAlpha(
  Uint8List rgba,
  int w,
  int h,
  double sensitivity,
  void Function(String) log,
) {
  // Карта резких перепадов яркости (контуры вещи) — барьер для заливки.
  final edges = _gradientMag(rgba, w, h);
  final edgeLimit = 30.0 + sensitivity * 20.0;

  // Цвета фона по рамке фото.
  final centers = _backgroundCenters(rgba, w, h);
  if (centers.isEmpty) return null;

  // Заливка от краёв: всё похожее на фон И не за резким краем — стираем.
  final tolerance = 26.0 + sensitivity * 70.0; // 26..96
  final bg = _floodFillFromBorders(
    rgba, w, h, centers, tolerance, edges, edgeLimit,
  );

  var bgCount = 0;
  for (final m in bg) {
    if (m == 1) bgCount++;
  }
  final bgRatio = bgCount / (w * h);
  log('классика: bgRatio=$bgRatio');
  // Фон занял почти всё (съели вещь) или мало (пёстрая сцена).
  if (bgRatio > 0.985 || bgRatio < 0.45) {
    log('классика: отказ, доля фона вне разумных пределов');
    return null;
  }

  // Мягкие края: полупрозрачная кромка у границы с фоном.
  return _featheredAlpha(bg, w, h);
}

// ───────── Внутренние алгоритмы ─────────

/// Взвешенное «расстояние» между цветами (близко к восприятию глаз).
double _colorDist(int r1, int g1, int b1, int r2, int g2, int b2) {
  final dr = (r1 - r2).toDouble();
  final dg = (g1 - g2).toDouble();
  final db = (b1 - b2).toDouble();
  return sqrt(2 * dr * dr + 4 * dg * dg + 3 * db * db) / 3.0;
}

/// Собирает 1–3 «центра» цвета фона по рамке фото (мини k-means).
List<List<int>> _backgroundCenters(Uint8List px, int w, int h) {
  final samples = <List<int>>[];
  void sample(int x, int y) {
    final i = (y * w + x) * 4;
    samples.add([px[i], px[i + 1], px[i + 2]]);
  }

  for (var x = 0; x < w; x += 2) {
    sample(x, 0);
    sample(x, 1);
    sample(x, h - 1);
    if (h > 2) sample(x, h - 2);
  }
  for (var y = 0; y < h; y += 2) {
    sample(0, y);
    sample(1, y);
    sample(w - 1, y);
    if (w > 2) sample(w - 2, y);
  }
  if (samples.isEmpty) return const [];

  // Первый центр — средний цвет рамки.
  var sumR = 0, sumG = 0, sumB = 0;
  for (final s in samples) {
    sumR += s[0];
    sumG += s[1];
    sumB += s[2];
  }
  final n = samples.length;
  var centers = <List<int>>[
    [sumR ~/ n, sumG ~/ n, sumB ~/ n],
  ];

  // Добавляем центры для «неоднотонного» фона (градиент/два цвета).
  for (var pass = 0; pass < 2; pass++) {
    List<int>? farthest;
    var farDist = 0.0;
    for (final s in samples) {
      var best = double.infinity;
      for (final c in centers) {
        final d = _colorDist(s[0], s[1], s[2], c[0], c[1], c[2]);
        if (d < best) best = d;
      }
      if (best > farDist) {
        farDist = best;
        farthest = s;
      }
    }
    if (farthest == null || farDist < 38) break;
    centers.add(List<int>.of(farthest));
  }

  // 4 итерации k-means для уточнения.
  for (var iter = 0; iter < 4; iter++) {
    final sums = centers
        .map((_) => [0, 0, 0, 0]) // r, g, b, count
        .toList();
    for (final s in samples) {
      var bestIdx = 0;
      var bestDist = double.infinity;
      for (var c = 0; c < centers.length; c++) {
        final d = _colorDist(s[0], s[1], s[2], centers[c][0], centers[c][1],
            centers[c][2]);
        if (d < bestDist) {
          bestDist = d;
          bestIdx = c;
        }
      }
      sums[bestIdx][0] += s[0];
      sums[bestIdx][1] += s[1];
      sums[bestIdx][2] += s[2];
      sums[bestIdx][3]++;
    }
    centers = [
      for (var c = 0; c < centers.length; c++)
        sums[c][3] > 0
            ? [sums[c][0] ~/ sums[c][3], sums[c][1] ~/ sums[c][3],
               sums[c][2] ~/ sums[c][3]]
            : centers[c],
    ];
  }
  return centers;
}

/// Карта перепадов яркости (упрощённый Собел, L1-норма).
Uint16List _gradientMag(Uint8List px, int w, int h) {
  final gray = Uint8List(w * h);
  for (var i = 0; i < w * h; i++) {
    final p = i * 4;
    gray[i] = (px[p] * 299 + px[p + 1] * 587 + px[p + 2] * 114) ~/ 1000;
  }
  final mag = Uint16List(w * h);
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      final gx = -gray[i - w - 1] -
          2 * gray[i - 1] -
          gray[i + w - 1] +
          gray[i - w + 1] +
          2 * gray[i + 1] +
          gray[i + w + 1];
      final gy = -gray[i - w - 1] -
          2 * gray[i - w] -
          gray[i - w + 1] +
          gray[i + w - 1] +
          2 * gray[i + w] +
          gray[i + w + 1];
      final v = gx.abs() + gy.abs();
      mag[i] = v > 1023 ? 1023 : v;
    }
  }
  return mag;
}

/// Заливка (BFS) от всех краёв: помечает пиксели фона.
Uint8List _floodFillFromBorders(
  Uint8List px,
  int w,
  int h,
  List<List<int>> centers,
  double tolerance,
  Uint16List edges,
  double edgeLimit,
) {
  final mask = Uint8List(w * h);
  final queue = <int>[];

  bool isBg(int i) {
    if (edges[i] >= edgeLimit) return false; // резкий край — барьер
    final p = i * 4;
    for (final c in centers) {
      final d = _colorDist(px[p], px[p + 1], px[p + 2], c[0], c[1], c[2]);
      if (d < tolerance) return true;
    }
    return false;
  }

  void seed(int i) {
    if (mask[i] == 0 && isBg(i)) {
      mask[i] = 1;
      queue.add(i);
    }
  }

  for (var x = 0; x < w; x++) {
    seed(x);
    seed((h - 1) * w + x);
  }
  for (var y = 0; y < h; y++) {
    seed(y * w);
    seed(y * w + w - 1);
  }

  var head = 0;
  while (head < queue.length) {
    final i = queue[head++];
    final x = i % w;
    final y = i ~/ w;
    if (x > 0) {
      final n = i - 1;
      if (mask[n] == 0 && isBg(n)) {
        mask[n] = 1;
        queue.add(n);
      }
    }
    if (x < w - 1) {
      final n = i + 1;
      if (mask[n] == 0 && isBg(n)) {
        mask[n] = 1;
        queue.add(n);
      }
    }
    if (y > 0) {
      final n = i - w;
      if (mask[n] == 0 && isBg(n)) {
        mask[n] = 1;
        queue.add(n);
      }
    }
    if (y < h - 1) {
      final n = i + w;
      if (mask[n] == 0 && isBg(n)) {
        mask[n] = 1;
        queue.add(n);
      }
    }
  }
  return mask;
}

/// Полупрозрачная кромка: пиксели объекта рядом с фоном — мягкие.
Uint8List _featheredAlpha(Uint8List bg, int w, int h) {
  final alpha = Uint8List(w * h);
  for (var i = 0; i < alpha.length; i++) {
    alpha[i] = bg[i] == 1 ? 0 : 255;
  }
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      if (bg[i] == 1) continue;
      var bgNeighbors = 0;
      if (x > 0 && bg[i - 1] == 1) bgNeighbors++;
      if (x < w - 1 && bg[i + 1] == 1) bgNeighbors++;
      if (y > 0 && bg[i - w] == 1) bgNeighbors++;
      if (y < h - 1 && bg[i + w] == 1) bgNeighbors++;
      if (bgNeighbors > 0) {
        alpha[i] = 255 - 55 * bgNeighbors; // мягкий край
      }
    }
  }
  return alpha;
}

/// Вырезает область [minX..maxX]×[minY..maxY], подставляя альфу.
img.Image _cropWithAlpha(Uint8List rgba, Uint8List alpha, int w, int h,
    int minX, int minY, int maxX, int maxY) {
  final cw = maxX - minX + 1;
  final ch = maxY - minY + 1;
  final out = Uint8List(cw * ch * 4);
  for (var y = 0; y < ch; y++) {
    for (var x = 0; x < cw; x++) {
      final srcIdx = ((minY + y) * w + (minX + x)) * 4;
      final dstIdx = (y * cw + x) * 4;
      out[dstIdx] = rgba[srcIdx];
      out[dstIdx + 1] = rgba[srcIdx + 1];
      out[dstIdx + 2] = rgba[srcIdx + 2];
      out[dstIdx + 3] = alpha[(minY + y) * w + (minX + x)];
    }
  }
  return img.Image.fromBytes(
    width: cw,
    height: ch,
    bytes: out.buffer,
    order: img.ChannelOrder.rgba,
  );
}