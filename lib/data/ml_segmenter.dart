import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

/// Нейросетевой «умный камера-пониматор»: модель U²-Net (бесплатная,
/// работает локально и оффлайн) смотрит на фото и говорит для каждого
/// пикселя, насколько он «вещь» (вероятность 0..1).
///
/// Модель обучена находить самый заметный объект на фото — одежду она
/// вырезает даже с тёмного фона и из пёстрых сцен.
class MlSegmenter {
  static OrtSession? _session;

  static Future<OrtSession> _getSession() async {
    _session ??= await OnnxRuntime()
        .createSessionFromAsset('assets/models/u2netp.onnx');
    return _session!;
  }

  /// Возвращает карту «заметности» 320×320 (значения 0..1) или null при сбое.
  static Future<Float32List?> runU2Net(img.Image src) async {
    try {
      final session = await _getSession();

      // Модель ест квадрат 320×320, RGB, нормализованный.
      const size = 320;
      const n = size * size;
      final resized = img.copyResize(src, width: size, height: size);
      final rgb = resized.getBytes(order: img.ChannelOrder.rgb);

      final input = Float32List(3 * n);
      const meanR = 0.485, meanG = 0.456, meanB = 0.406;
      const stdR = 0.229, stdG = 0.224, stdB = 0.225;
      for (var i = 0; i < n; i++) {
        input[i] = (rgb[i * 3] / 255.0 - meanR) / stdR;
        input[n + i] = (rgb[i * 3 + 1] / 255.0 - meanG) / stdG;
        input[2 * n + i] = (rgb[i * 3 + 2] / 255.0 - meanB) / stdB;
      }

      final outputs = await session.run({
        'input.1': await OrtValue.fromList(input, [1, 3, size, size]),
      });
      if (outputs.isEmpty) return null;

      // Первый выход — итоговая карта заметности 1×1×320×320.
      final flat = await outputs.values.first.asFlattenedList();
      if (flat.length < n) return null;

      final mask = Float32List(n);
      for (var i = 0; i < n; i++) {
        mask[i] = (flat[i] as num).toDouble().clamp(0.0, 1.0);
      }
      return mask;
    } catch (_) {
      return null;
    }
  }

  /// Растягивает карту 320×320 на размер фото и превращает в альфу:
  /// <0.35 — точно фон, >0.65 — точно вещь, между — мягкий край.
  static Uint8List maskToAlpha(Float32List mask, int w, int h) {
    const size = 320;
    final alpha = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      // Билинейная интерполяция по y.
      final gy = y * (size - 1) / (h - 1);
      final y0 = gy.floor();
      final y1 = min(y0 + 1, size - 1);
      final fy = gy - y0;
      for (var x = 0; x < w; x++) {
        final gx = x * (size - 1) / (w - 1);
        final x0 = gx.floor();
        final x1 = min(x0 + 1, size - 1);
        final fx = gx - x0;

        final v00 = mask[y0 * size + x0];
        final v01 = mask[y0 * size + x1];
        final v10 = mask[y1 * size + x0];
        final v11 = mask[y1 * size + x1];
        final v = (v00 * (1 - fx) + v01 * fx) * (1 - fy) +
            (v10 * (1 - fx) + v11 * fx) * fy;

        alpha[y * w + x] = ((v - 0.35) / 0.30 * 255).round().clamp(0, 255);
      }
    }
    return alpha;
  }

  /// Оставляет самую большую «вещь», мелкие куски стирает.
  static void keepLargestComponent(Uint8List alpha, int w, int h) {
    final total = w * h;
    final label = Int32List(total);
    final queue = <int>[];
    final sizes = <int>[0];

    for (var start = 0; start < total; start++) {
      if (alpha[start] < 128 || label[start] != 0) continue;
      final mark = sizes.length;
      sizes.add(0);
      label[start] = mark;
      queue
        ..clear()
        ..add(start);
      var head = 0;
      while (head < queue.length) {
        final i = queue[head++];
        sizes[mark]++;
        final x = i % w;
        final y = i ~/ w;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final nx = x + dx;
            final ny = y + dy;
            if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;
            final j = ny * w + nx;
            if (alpha[j] >= 128 && label[j] == 0) {
              label[j] = mark;
              queue.add(j);
            }
          }
        }
      }
    }

    if (sizes.length <= 2) return;
    var best = 1;
    for (var m = 2; m < sizes.length; m++) {
      if (sizes[m] > sizes[best]) best = m;
    }
    for (var i = 0; i < total; i++) {
      if (alpha[i] >= 128 && label[i] != best) alpha[i] = 0;
    }
  }

  /// v2 фильтра: заливает «дыры» внутри вещи. Фон, попавший внутрь
  /// объекта (пятна на футболке, просветы между деталями), но не
  /// связанный с настоящим фоном по краям фото, становится вещью.
  static void fillHoles(Uint8List alpha, int w, int h) {
    const bg = 0, obj = 1, visited = 2;
    final mark = Uint8List(w * h);
    for (var i = 0; i < mark.length; i++) {
      mark[i] = alpha[i] >= 128 ? obj : bg;
    }
    final queue = <int>[];
    void seed(int i) {
      if (mark[i] == bg) {
        mark[i] = visited;
        queue.add(i);
      }
    }

    // Фон, связанный с рамкой фото, помечаем как «настоящий».
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
      if (x > 0 && mark[i - 1] == bg) {
        mark[i - 1] = visited;
        queue.add(i - 1);
      }
      if (x < w - 1 && mark[i + 1] == bg) {
        mark[i + 1] = visited;
        queue.add(i + 1);
      }
      if (y > 0 && mark[i - w] == bg) {
        mark[i - w] = visited;
        queue.add(i - w);
      }
      if (y < h - 1 && mark[i + w] == bg) {
        mark[i + w] = visited;
        queue.add(i + w);
      }
    }
    // Всё оставшееся «фоновое» — дыры внутри вещи, закрашиваем.
    for (var i = 0; i < mark.length; i++) {
      if (mark[i] == bg) alpha[i] = 255;
    }
  }

  /// v2 фильтра: сглаживает маску «голосованием соседей» — стирает
  /// одиночные пятна фона внутри вещи и одиночные пиксели вещи снаружи.
  static void smoothAlpha(Uint8List alpha, int w, int h) {
    final copy = Uint8List.fromList(alpha);
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final i = y * w + x;
        var n = 0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            if (copy[i + dy * w + dx] >= 128) n++;
          }
        }
        if (copy[i] < 128 && n >= 5) {
          alpha[i] = 255; // дырка внутри вещи — закрасить
        } else if (copy[i] >= 128 && n <= 2) {
          alpha[i] = 0; // одинокий пиксель вещи — стереть
        }
      }
    }
  }

  /// Мягкая кромка: край вещи делается полупрозрачным, чтобы срез не
  /// выглядел «пилой» после нейросети.
  static void featherEdge(Uint8List alpha, int w, int h) {
    final copy = Uint8List.fromList(alpha);
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final i = y * w + x;
        if (copy[i] < 128) continue;
        var softNeighbors = 0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final v = copy[i + dy * w + dx];
            if (v > 0 && v < 128) softNeighbors++;
          }
        }
        if (softNeighbors > 0 && copy[i] == 255) {
          alpha[i] = 200; // приглушаем резкий край рядом с мягкой кромкой
        }
      }
    }
  }
}