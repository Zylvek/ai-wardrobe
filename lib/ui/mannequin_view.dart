import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/outfit_builder.dart';

/// Манекен «как в магазине» на главном экране.
///
/// Тело — настоящая полигональная 3D-модель, собранная из гладких
/// поверхностей вращения: голова с носом и ушами, шея, торс с плечами
/// и талией, руки от дельтовидной мышцы до ладони, ноги и ступни.
/// Каждая грань освещается по своей нормали (ламбертово освещение),
/// грани сортируются по глубине — дальняя рука уходит за торс,
/// ближняя выступает вперёд. Крути пальцем влево/вправо — фигура
/// повернётся, бока сожмутся, свет останется на месте, как у настоящего
/// тела.
///
/// Вещи «натягиваются» на фигуру: фото режется на узкие полосы, и каждая
/// полоса оборачивается вокруг тела в ту же сторону, в которую крутится
/// манекен. У краёв вещь сжимается, тень ложится на неё так же, как на
/// тело, а со спины видна её зеркальная сторона — как у настоящей одежды.
class MannequinOutfit extends StatefulWidget {
  const MannequinOutfit({super.key, required this.outfit});

  final Outfit outfit;

  @override
  State<MannequinOutfit> createState() => _MannequinOutfitState();
}

class _MannequinOutfitState extends State<MannequinOutfit> {
  /// Поворот вокруг вертикальной оси, радианы. 0 — смотрим спереди.
  double _angle = 0;
  bool _touched = false;

  /// Расшифрованные фото вещей: путь → картинка (null = ещё грузится).
  final Map<String, ui.Image?> _images = {};
  final Set<String> _failed = {};

  // Зоны «надевания» (доли ширины/высоты манекена).
  static const Rect _torsoZone =
      Rect.fromLTRB(0.344, 0.155, 0.656, 0.455); // верх
  static const Rect _outerZone =
      Rect.fromLTRB(0.310, 0.145, 0.690, 0.495); // верхняя одежда
  static const Rect _bottomZone =
      Rect.fromLTRB(0.340, 0.415, 0.660, 0.875); // низ
  static const Rect _shoesZone =
      Rect.fromLTRB(0.360, 0.890, 0.640, 0.962); // обувь

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  @override
  void didUpdateWidget(covariant MannequinOutfit oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadImages();
  }

  Future<void> _loadImages() async {
    for (final item in widget.outfit.items) {
      final path = item.imagePath;
      if (_images.containsKey(path) || _failed.contains(path)) continue;
      try {
        final data = await File(path).readAsBytes();
        final codec = await ui.instantiateImageCodec(data);
        final frame = await codec.getNextFrame();
        if (!mounted) return;
        setState(() => _images[path] = frame.image);
      } catch (_) {
        _failed.add(path);
      }
    }
  }

  void _drag(DragUpdateDetails d) {
    setState(() {
      _angle += d.delta.dx * 0.012;
      if (_angle.abs() > 1000) _angle %= 2 * math.pi;
      _touched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        // Фигура всегда портретная: на широком экране не даём ей
        // растянуться на всю ширину, а держим нормальные пропорции
        // и ставим по центру.
        final w = math.min(constraints.maxWidth, h * 0.72);
        final sidePad = (constraints.maxWidth - w) / 2;

        Rect absZone(Rect r) => Rect.fromLTRB(
              sidePad + r.left * w,
              r.top * h,
              sidePad + r.right * w,
              r.bottom * h,
            );

        ui.Image? img(String? path) =>
            path == null ? null : _images[path];

        // Порядок слоёв снизу вверх: обувь → низ → верх → верхняя одежда.
        final pieces = <_Piece>[
          if (widget.outfit.shoes != null)
            _Piece(
              img(widget.outfit.shoes!.imagePath),
              absZone(_shoesZone),
              clipPart: 'feet',
              rx: 0.094,
              rz: 0.078,
            ),
          if (widget.outfit.bottom != null)
            _Piece(
              img(widget.outfit.bottom!.imagePath),
              absZone(_bottomZone),
              clipPart: 'legs',
              rx: 0.104,
              rz: 0.074,
            ),
          if (widget.outfit.top != null)
            _Piece(
              img(widget.outfit.top!.imagePath),
              absZone(_torsoZone),
              clipPart: 'torso',
              rx: 0.112,
              rz: 0.072,
            ),
          if (widget.outfit.outer != null)
            _Piece(
              img(widget.outfit.outer!.imagePath),
              absZone(_outerZone),
              // Куртка шире тела — не обрезаем по силуэту.
              clipPart: null,
              rx: 0.118,
              rz: 0.076,
            ),
        ];

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: _drag,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _Mannequin3DPainter(
                    angle: _angle,
                    pieces: pieces,
                    dark: dark,
                  ),
                ),
              ),
              // Подсказка: видна, пока фигуру ни разу не покрутили.
              if (!_touched)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Text(
                      'Потяни в сторону — манекен повернётся ↔',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Вещь, «надетая» на манекен: картинка + зона, где она лежит.
class _Piece {
  const _Piece(
    this.image,
    this.rect, {
    required this.clipPart,
    required this.rx,
    required this.rz,
  });

  /// Фото вещи (null — ещё расшифровывается).
  final ui.Image? image;

  /// Прямоугольник зоны на экране.
  final Rect rect;

  /// По какой части тела обрезать вещь: 'torso', 'legs', 'feet'
  /// или null — не обрезать (куртка шире тела).
  final String? clipPart;

  /// Полуширина и полуглубина «цилиндра» тела в этой зоне (доли высоты) —
  /// вещь сжимается при повороте точно так же, как тело.
  final double rx, rz;
}

// ---------------------------------------------------------------------------
// Полигональная модель тела.
// ---------------------------------------------------------------------------

/// Одна грань четырёхугольной сетки: четыре вершины и нормаль
/// (в координатах модели).
class _Q {
  const _Q(this.a, this.b, this.c, this.d, this.n);
  final (double, double, double) a, b, c, d;
  final (double, double, double) n;
}

/// Строка сечения: (высота, центр X, центр Z, полуширина, полуглубина,
/// показатель «квадратности» сечения; 2 — эллипс, больше — квадратнее).
typedef _Row = (double, double, double, double, double, double);

double _sgn(double v) => v < 0 ? -1.0 : 1.0;

/// Голова: яйцо с затылком, носом и ушами.
const List<_Row> _headRows = [
  (0.004, 0, 0.004, 0.010, 0.010, 2.0),
  (0.014, 0, 0.004, 0.028, 0.029, 2.0),
  (0.030, 0, 0.004, 0.040, 0.042, 2.0),
  (0.046, 0, 0.004, 0.046, 0.048, 2.0),
  (0.061, 0, 0.004, 0.048, 0.051, 2.0),
  (0.076, 0, 0.004, 0.047, 0.052, 2.0),
  (0.089, 0, 0.004, 0.044, 0.050, 2.0),
  (0.101, 0, 0.004, 0.036, 0.044, 2.0),
  (0.111, 0, 0.005, 0.026, 0.034, 2.0),
  (0.119, 0, 0.006, 0.012, 0.017, 2.0),
];

/// Шея.
const List<_Row> _neckRows = [
  (0.106, 0, 0.006, 0.030, 0.030, 2.0),
  (0.125, 0, 0.008, 0.027, 0.027, 2.0),
  (0.142, 0, 0.010, 0.029, 0.029, 2.0),
];

/// Торс: плечи → грудь → талия → бёдра. n > 2 у плеч — «квадратные»
/// плечи, как у настоящей фигуры.
const List<_Row> _torsoRows = [
  (0.138, 0, 0.008, 0.070, 0.046, 2.4),
  (0.150, 0, 0.008, 0.088, 0.054, 2.5),
  (0.162, 0, 0.007, 0.100, 0.062, 2.6),
  (0.195, 0, 0.006, 0.101, 0.068, 2.5),
  (0.230, 0, 0.004, 0.098, 0.072, 2.4),
  (0.268, 0, 0.002, 0.093, 0.072, 2.3),
  (0.306, 0, 0.000, 0.085, 0.064, 2.2),
  (0.346, 0, 0.000, 0.086, 0.063, 2.2),
  (0.386, 0, 0.002, 0.093, 0.068, 2.2),
  (0.422, 0, 0.004, 0.098, 0.071, 2.1),
  (0.455, 0, 0.006, 0.096, 0.069, 2.0),
  (0.480, 0, 0.006, 0.088, 0.062, 2.0),
  (0.500, 0, 0.006, 0.072, 0.050, 2.0),
  (0.512, 0, 0.006, 0.032, 0.024, 2.0),
];

/// Рука (левая, x < 0): дельта → бицепс → локоть → предплечье →
/// запястье → ладонь. Плечевой сустав — снаружи торса.
const List<_Row> _armRows = [
  (0.148, -0.094, 0.012, 0.038, 0.040, 2.0),
  (0.185, -0.098, 0.004, 0.034, 0.036, 2.0),
  (0.240, -0.102, 0.000, 0.030, 0.032, 2.0),
  (0.300, -0.105, 0.006, 0.026, 0.028, 2.0),
  (0.360, -0.107, 0.016, 0.023, 0.025, 2.0),
  (0.418, -0.108, 0.026, 0.019, 0.021, 2.0),
  (0.452, -0.109, 0.034, 0.023, 0.025, 2.0),
  (0.488, -0.109, 0.038, 0.015, 0.017, 2.0),
];

/// Нога (левая): бедро → колено → икра → щиколотка.
const List<_Row> _legRows = [
  (0.470, -0.052, 0.014, 0.052, 0.060, 2.0),
  (0.530, -0.054, 0.014, 0.050, 0.058, 2.0),
  (0.600, -0.056, 0.012, 0.046, 0.054, 2.0),
  (0.660, -0.058, 0.008, 0.040, 0.050, 2.0),
  (0.720, -0.058, 0.004, 0.037, 0.048, 2.0),
  (0.762, -0.058, 0.002, 0.039, 0.044, 2.0),
  (0.802, -0.058, 0.000, 0.033, 0.040, 2.0),
  (0.850, -0.058, -0.002, 0.029, 0.036, 2.0),
  (0.895, -0.058, -0.004, 0.026, 0.030, 2.0),
  (0.908, -0.058, -0.004, 0.024, 0.027, 2.0),
];

/// Ступня (левая): кроссовок носком вперёд (+z).
const List<_Row> _footRows = [
  (0.904, -0.058, -0.004, 0.029, 0.028, 2.0),
  (0.918, -0.058, 0.012, 0.031, 0.056, 2.0),
  (0.932, -0.058, 0.026, 0.030, 0.068, 2.0),
  (0.943, -0.058, 0.031, 0.025, 0.060, 2.0),
  (0.952, -0.058, 0.033, 0.015, 0.040, 2.0),
  (0.958, -0.058, 0.034, 0.007, 0.017, 2.0),
];

/// Деформация головы: нос спереди, подбородок, уши по бокам.
(double, double) _headDeform(double y, double x, double z) {
  // Насколько точка смотрит «вперёд» (к +z): 1 — нос, 0 — профиль.
  final f = ((z - 0.004) / 0.052).clamp(0.0, 1.0);
  final front = f * f * f;
  // Нос: небольшой выступ на уровне середины лица.
  final gn = math.exp(-math.pow((y - 0.077) / 0.013, 2));
  var dz = 0.016 * gn * front;
  // Подбородок.
  final gc = math.exp(-math.pow((y - 0.108) / 0.012, 2));
  dz += 0.006 * gc * front;
  // Уши: выступ по бокам на уровне глаз.
  final ge = math.exp(-math.pow((y - 0.066) / 0.011, 2));
  final sx = (x.abs() / 0.048).clamp(0.0, 1.0);
  final dx = (x < 0 ? -1.0 : 1.0) * 0.008 * ge * sx * sx * sx;
  return (dx, dz);
}

/// Строит «трубу» по строкам сечений: кольца вершин + четырёхугольники
/// между соседними кольцами, с нормалями наружу.
List<_Q> _loft(
  List<_Row> rows,
  int seg, {
  (double, double) Function(double y, double x, double z)? deform,
  bool flip = false,
}) {
  final rings = <List<(double, double, double)>>[];
  for (final (y, cx, cz, rx, rz, n) in rows) {
    final e = 2.0 / n;
    final ring = <(double, double, double)>[];
    for (var j = 0; j < seg; j++) {
      final t = 2 * math.pi * j / seg;
      final sn = math.sin(t), cs = math.cos(t);
      var x = cx + rx * _sgn(sn) * math.pow(sn.abs(), e);
      var z = cz + rz * _sgn(cs) * math.pow(cs.abs(), e);
      if (deform != null) {
        final (dx, dz) = deform(y, x, z);
        x += dx;
        z += dz;
      }
      ring.add((x, y, z));
    }
    // У зеркальной копии обход кольца обращается: иначе нормали и
    // отсечение задних граней «выворачиваются», и конечность пропадает.
    rings.add(flip ? ring.reversed.toList() : ring);
  }
  // Сначала плоские нормали граней…
  final flat = <List<(double, double, double)>>[];
  for (var i = 0; i < rings.length - 1; i++) {
    final row = <(double, double, double)>[];
    final r0 = rings[i], r1 = rings[i + 1];
    for (var j = 0; j < seg; j++) {
      final j1 = (j + 1) % seg;
      final a = r0[j], b = r0[j1], d = r1[j];
      // Нормаль = cross(b − a, d − a), наружу от поверхности.
      final e1 = (b.$1 - a.$1, b.$2 - a.$2, b.$3 - a.$3);
      final e2 = (d.$1 - a.$1, d.$2 - a.$2, d.$3 - a.$3);
      var nx = e1.$2 * e2.$3 - e1.$3 * e2.$2;
      var ny = e1.$3 * e2.$1 - e1.$1 * e2.$3;
      var nz = e1.$1 * e2.$2 - e1.$2 * e2.$1;
      final len = math.sqrt(nx * nx + ny * ny + nz * nz);
      if (len > 1e-9) {
        nx /= len;
        ny /= len;
        nz /= len;
      } else {
        nz = 1;
      }
      row.add((nx, ny, nz));
    }
    flat.add(row);
  }

  // …потом сглаживаем: нормаль вершины — среднее соседних граней,
  // нормаль грани — среднее её четырёх вершин. Так поверхность
  // выглядит гладкой, а не гранёной.
  (double, double, double) vNorm(int i, int j) {
    var nx = 0.0, ny = 0.0, nz = 0.0;
    for (final di in const [-1, 0]) {
      for (final dj in const [-1, 0]) {
        final ii = i + di, jj = (j + dj + seg) % seg;
        if (ii < 0 || ii >= flat.length) continue;
        final f = flat[ii][jj];
        nx += f.$1;
        ny += f.$2;
        nz += f.$3;
      }
    }
    final len = math.sqrt(nx * nx + ny * ny + nz * nz);
    if (len < 1e-9) return (0, 0, 1);
    return (nx / len, ny / len, nz / len);
  }

  final quads = <_Q>[];
  for (var i = 0; i < rings.length - 1; i++) {
    final r0 = rings[i], r1 = rings[i + 1];
    for (var j = 0; j < seg; j++) {
      final j1 = (j + 1) % seg;
      final fa = vNorm(i, j);
      final fb = vNorm(i, j1);
      final fc = vNorm(i + 1, j1);
      final fd = vNorm(i + 1, j);
      var nx = fa.$1 + fb.$1 + fc.$1 + fd.$1;
      var ny = fa.$2 + fb.$2 + fc.$2 + fd.$2;
      var nz = fa.$3 + fb.$3 + fc.$3 + fd.$3;
      final len = math.sqrt(nx * nx + ny * ny + nz * nz);
      if (len > 1e-9) {
        nx /= len;
        ny /= len;
        nz /= len;
      }
      quads.add(_Q(r0[j], r0[j1], r1[j1], r1[j], (nx, ny, nz)));
    }
  }
  return quads;
}

/// Зеркальная копия строк сечений (для второй руки/ноги).
List<_Row> _mirrorRows(List<_Row> rows) => [
      for (final (y, cx, cz, rx, rz, n) in rows) (y, -cx, cz, rx, rz, n),
    ];

/// Собирает всё тело: голова, шея, торс и парные конечности.
List<_Q> _buildBody() {
  final q = <_Q>[];
  q.addAll(_loft(_headRows, 48, deform: _headDeform));
  q.addAll(_loft(_neckRows, 28));
  q.addAll(_loft(_torsoRows, 56));
  q.addAll(_loft(_armRows, 32));
  q.addAll(_loft(_mirrorRows(_armRows), 32, flip: true));
  q.addAll(_loft(_legRows, 40));
  q.addAll(_loft(_mirrorRows(_legRows), 40, flip: true));
  q.addAll(_loft(_footRows, 24));
  q.addAll(_loft(_mirrorRows(_footRows), 24, flip: true));
  return q;
}

/// Рисует манекен «как в магазине» и одетые на него вещи.
class _Mannequin3DPainter extends CustomPainter {
  _Mannequin3DPainter({
    required this.angle,
    required this.pieces,
    required this.dark,
  });

  final double angle;
  final List<_Piece> pieces;
  final bool dark;

  /// Модель тела строится один раз и переиспользуется.
  static final List<_Q> _body = _buildBody();

  /// Сколько уровней яркости в палитре (грани сливаются в «заливки»).
  static const int _levels = 96;

  /// Свет: слева-сверху-спереди (в экранных координатах, единичный).
  static const double _lx = -0.514, _ly = -0.638, _lz = 0.617;

  Color get _cLight =>
      dark ? const Color(0xFF9A9AA6) : const Color(0xFFFCFBF8);
  Color get _cShadow =>
      dark ? const Color(0xFF45454F) : const Color(0xFFA9A298);

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    final cx = w / 2;

    final k = math.min(w / (h * 0.72), 1.0);
    final c = math.cos(angle);
    final s = math.sin(angle);

    // Тень на полу.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, h * 0.978),
        width: w * 0.40,
        height: h * 0.026,
      ),
      Paint()..color = Colors.black.withValues(alpha: dark ? 0.35 : 0.12),
    );

    // Палитра уровней яркости: от тени к свету.
    final paints = <Paint>[
      for (var i = 0; i < _levels; i++)
        Paint()
          ..color = Color.lerp(_cShadow, _cLight, i / (_levels - 1))!
    ];

    // Видимые грани: (глубина, точки на экране, уровень яркости).
    final faces = <(double, List<Offset>, int)>[];
    double sxOf(double x, double z) => cx + (x * c + z * s) * h * k;
    double depthOf(double x, double z) => z * c - x * s;

    for (final q in _body) {
      final pts = [
        Offset(sxOf(q.a.$1, q.a.$3), q.a.$2 * h),
        Offset(sxOf(q.b.$1, q.b.$3), q.b.$2 * h),
        Offset(sxOf(q.c.$1, q.c.$3), q.c.$2 * h),
        Offset(sxOf(q.d.$1, q.d.$3), q.d.$2 * h),
      ];
      // Отсечение задних граней: знак площади на экране.
      final cross2 = (pts[1].dx - pts[0].dx) * (pts[3].dy - pts[0].dy) -
          (pts[1].dy - pts[0].dy) * (pts[3].dx - pts[0].dx);
      if (cross2 <= 0) continue;

      // Нормаль поворачивается вместе с телом.
      final nx = q.n.$1 * c + q.n.$3 * s;
      final ny = q.n.$2;
      final nz = q.n.$3 * c - q.n.$1 * s;
      var lam = nx * _lx + ny * _ly + nz * _lz;
      if (lam < 0) lam = 0;
      final t = 0.30 + 0.70 * lam;
      final bucket =
          (t * (_levels - 1)).round().clamp(0, _levels - 1);

      final depth = (depthOf(q.a.$1, q.a.$3) +
              depthOf(q.b.$1, q.b.$3) +
              depthOf(q.c.$1, q.c.$3) +
              depthOf(q.d.$1, q.d.$3)) /
          4;
      faces.add((depth, pts, bucket));
    }

    // Дальние грани рисуем первыми; грани одного цвета сливаем в один
    // путь — так 1100 граней превращаются в несколько десятков заливок.
    faces.sort((a, b) => a.$1.compareTo(b.$1));
    // Тело рисуем в отдельный слой и накладываем с лёгким размытием:
    // заливки граней сливаются в плавные переходы, как у настоящего
    // манекена, а не смотрятся гранёной моделью.
    final rec = ui.PictureRecorder();
    final body = Canvas(rec);
    Path? run;
    var runBucket = -1;
    for (final (_, pts, bucket) in faces) {
      if (bucket != runBucket) {
        if (run != null) body.drawPath(run, paints[runBucket]);
        run = Path();
        runBucket = bucket;
      }
      run!.addPolygon(pts, true);
    }
    if (run != null) body.drawPath(run, paints[runBucket]);
    final pic = rec.endRecording();
    // Чёткая основа — силуэт остаётся резким.
    canvas.drawPicture(pic);
    // Сверху полупрозрачное размытие: внутренние переходы между
    // гранями сглаживаются, как у настоящего манекена.
    canvas.saveLayer(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 2.4, sigmaY: 2.4),
    );
    canvas.drawPicture(pic);
    canvas.restore();

    // Одежда поверх фигуры: каждая вещь оборачивается вокруг тела.
    final clips = _clips(c, s, cx, h, k);
    for (final p in pieces) {
      final image = p.image;
      if (image != null) {
        _drawPiece(canvas, p, image, clips, cx, c, s);
      }
    }
  }

  /// Контур части тела на экране: по строкам сечений берём крайние
  /// точки силуэта слева и справа. Им обрезается одежда.
  Map<String, Path> _clips(
    double c,
    double s,
    double cx,
    double h,
    double k,
  ) {
    Path fromRows(List<_Row> rows) {
      final left = <Offset>[];
      final right = <Offset>[];
      for (final (y, ccx, ccz, rx, rz, n) in rows) {
        final centerX = ccx * c + ccz * s;
        var minX = 1e9, maxX = -1e9;
        const samples = 24;
        final e = 2.0 / n;
        for (var j = 0; j < samples; j++) {
          final t = 2 * math.pi * j / samples;
          final sn = math.sin(t), cs = math.cos(t);
          final x = rx * _sgn(sn) * math.pow(sn.abs(), e);
          final z = rz * _sgn(cs) * math.pow(cs.abs(), e);
          final xScreen = centerX + x * c + z * s;
          if (xScreen < minX) minX = xScreen;
          if (xScreen > maxX) maxX = xScreen;
        }
        left.add(Offset(cx + minX * h * k, y * h));
        right.add(Offset(cx + maxX * h * k, y * h));
      }
      final pts = [...left, ...right.reversed];
      return Path()..addPolygon(pts, true);
    }

    // Ноги и ступни парные: силуэт каждой стороны вырезается отдельно,
    // иначе штаны обтягивают только одну ногу.
    final legsL = fromRows([..._legRows, ..._footRows]);
    final legsR = fromRows([..._mirrorRows(_legRows), ..._mirrorRows(_footRows)]);
    final feetL = fromRows(_footRows);
    final feetR = fromRows(_mirrorRows(_footRows));

    return {
      'torso': fromRows(_torsoRows),
      'legs': Path.combine(PathOperation.union, legsL, legsR),
      'feet': Path.combine(PathOperation.union, feetL, feetR),
    };
  }

  /// «Оборачивает» фото вещи вокруг тела: экранная ширина зоны делится
  /// на узкие полосы, каждой полосе соответствует свой участок фото —
  /// как если бы вещь была натянута на цилиндр. Полосы едут в ту же
  /// сторону, в которую крутится манекен.
  void _drawPiece(
    Canvas canvas,
    _Piece p,
    ui.Image image,
    Map<String, Path> clips,
    double cx,
    double c,
    double s,
  ) {
    final zone = p.rect;
    // Радиус «цилиндра» вещи сжимается при повороте, как у тела.
    final f = math.sqrt((p.rx * c) * (p.rx * c) + (p.rz * s) * (p.rz * s)) /
        p.rx;
    final r = zone.width / 2 * f;
    if (r < 2) return;

    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    const n = 36;
    final stripW = (2 * r) / n;

    // Яркость на «цилиндре» по экранному азимуту a — тот же свет, что
    // и на теле (свет слева-спереди).
    double shade(double a) {
      final lit = math.max(0.0, math.cos(a + _lx * 1.1));
      final facing = 0.55 + 0.45 * math.cos(a);
      return (0.35 + 0.65 * lit) * facing;
    }

    canvas.save();
    final clip = p.clipPart == null ? null : clips[p.clipPart];
    if (clip != null) canvas.clipPath(clip);
    for (var i = 0; i < n; i++) {
      final xRel = -r + (i + 0.5) * stripW;
      // Экранный азимут полосы: 0 — центр, ±π/2 — края силуэта.
      final a = math.asin((xRel / r).clamp(-1.0, 1.0));

      // Азимут точки на вещи: текстура едет ВМЕСТЕ с телом.
      var at = (a - angle) % (2 * math.pi);
      if (at > math.pi) at -= 2 * math.pi;
      if (at <= -math.pi) at += 2 * math.pi;

      // Какой участок фото виден: спереди — прямо, со спины — зеркально.
      double u;
      if (at.abs() <= math.pi / 2) {
        u = at / math.pi + 0.5;
      } else if (at > 0) {
        u = 1.5 - at / math.pi;
      } else {
        u = -0.5 - at / math.pi;
      }
      u = u.clamp(0.0, 1.0);

      // Полоса у края сильнее сжата — её кусочек фото шире.
      final dA = math.min((stripW / (r * math.cos(a))).abs(), 0.35);
      final srcW = math.min((dA / math.pi) * imgW, imgW);
      final src = Rect.fromCenter(
        center: Offset(u * imgW, imgH / 2),
        width: srcW,
        height: imgH,
      );
      final dest = Rect.fromLTWH(
        cx + xRel - stripW / 2,
        zone.top,
        stripW,
        zone.height,
      );
      // Тень красит только саму вещь (srcATop не трогает прозрачные
      // пиксели фото — без полос на теле).
      final darkAlpha = ((1 - shade(a)) * 0.55).clamp(0.0, 0.42);
      final paint = Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = ColorFilter.mode(
          Colors.black.withValues(alpha: darkAlpha),
          BlendMode.srcATop,
        );
      canvas.drawImageRect(image, src, dest, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Mannequin3DPainter oldDelegate) =>
      oldDelegate.angle != angle ||
      oldDelegate.dark != dark ||
      !_samePieces(oldDelegate.pieces, pieces);

  bool _samePieces(List<_Piece> a, List<_Piece> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i].image, b[i].image) || a[i].rect != b[i].rect) {
        return false;
      }
    }
    return true;
  }
}