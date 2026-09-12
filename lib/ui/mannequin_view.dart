import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/outfit_builder.dart';

/// Манекен «как в магазине» на главном экране.
///
/// Тело — матовая фигура на подставке, собранная из отдельных объёмных
/// деталей: голова, шея, торс, руки, ноги и ступни. Каждая деталь красится
/// своей цилиндрической светотенью, а детали сортируются по глубине —
/// дальняя рука уходит за торс, ближняя выступает вперёд. Крути пальцем
/// влево/вправо — фигура повернётся, бока сожмутся, как у настоящего тела.
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
      Rect.fromLTRB(0.29, 0.17, 0.71, 0.50); // верх
  static const Rect _outerZone =
      Rect.fromLTRB(0.23, 0.16, 0.77, 0.54); // верхняя одежда
  static const Rect _bottomZone =
      Rect.fromLTRB(0.30, 0.47, 0.70, 0.87); // низ
  static const Rect _shoesZone =
      Rect.fromLTRB(0.26, 0.84, 0.74, 0.97); // обувь

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
              rx: 0.062,
              rz: 0.030,
            ),
          if (widget.outfit.bottom != null)
            _Piece(
              img(widget.outfit.bottom!.imagePath),
              absZone(_bottomZone),
              clipPart: 'legs',
              rx: 0.110,
              rz: 0.065,
            ),
          if (widget.outfit.top != null)
            _Piece(
              img(widget.outfit.top!.imagePath),
              absZone(_torsoZone),
              clipPart: 'torso',
              rx: 0.150,
              rz: 0.078,
            ),
          if (widget.outfit.outer != null)
            _Piece(
              img(widget.outfit.outer!.imagePath),
              absZone(_outerZone),
              // Куртка шире тела — не обрезаем по силуэту.
              clipPart: null,
              rx: 0.150,
              rz: 0.078,
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

/// Профиль торса: (высота, полуширина, полуглубина) в долях высоты.
const List<(double, double, double)> _torsoProfile = [
  (0.170, 0.155, 0.075), // плечи
  (0.250, 0.138, 0.070),
  (0.330, 0.130, 0.078), // грудь
  (0.400, 0.118, 0.070), // талия
  (0.455, 0.125, 0.074),
  (0.505, 0.138, 0.082), // бёдра
];

/// Полуширина и полуглубина торса на высоте y.
(double, double) _torsoAt(double y) {
  for (var i = 0; i < _torsoProfile.length - 1; i++) {
    final (y0, rx0, rz0) = _torsoProfile[i];
    final (y1, rx1, rz1) = _torsoProfile[i + 1];
    if (y <= y1) {
      final t = (y - y0) / (y1 - y0);
      return (rx0 + (rx1 - rx0) * t, rz0 + (rz1 - rz0) * t);
    }
  }
  final last = _torsoProfile.last;
  return (last.$2, last.$3);
}

/// Части тела как капсулы: (начало, конец, радиус, имя части).
/// Каждая рисуется отдельно со своей светотенью и сортируется по глубине.
const List<((double, double, double), (double, double, double), double, String)>
    _capsules = [
  // Шея.
  ((0, 0.122, 0), (0, 0.178, 0), 0.030, 'neck'),
  // Руки с ладонями на конце.
  ((-0.150, 0.195, -0.015), (-0.262, 0.495, -0.050), 0.028, 'arm'),
  ((0.150, 0.195, -0.015), (0.262, 0.495, -0.050), 0.028, 'arm'),
  // Ноги (начинаются под торсом, чтобы не было щели на бёдрах).
  ((-0.075, 0.470, 0), (-0.088, 0.895, 0), 0.036, 'leg'),
  ((0.075, 0.470, 0), (0.088, 0.895, 0), 0.036, 'leg'),
  // Ступни (смотрят вперёд, поэтому честно укорачиваются при повороте).
  ((-0.088, 0.900, -0.020), (-0.090, 0.900, 0.055), 0.022, 'foot'),
  ((0.088, 0.900, -0.020), (0.090, 0.900, 0.055), 0.022, 'foot'),
];

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

  /// Свет слева-спереди, в экранных координатах.
  static const double _lightScreen = -0.55;

  Color get _cLight =>
      dark ? const Color(0xFF82828E) : const Color(0xFFF8F7F4);
  Color get _cBase =>
      dark ? const Color(0xFF565662) : const Color(0xFFE6E3DD);
  Color get _cShadow =>
      dark ? const Color(0xFF3C3C46) : const Color(0xFFB4AFA7);
  Color get _cStand =>
      dark ? const Color(0xFF3A3A44) : const Color(0xFFA8A39B);

  /// Яркость точки на цилиндре с экранным азимутом a (−π/2 … π/2).
  double _shade(double a) {
    final lit = math.max(0.0, math.cos(a + _lightScreen));
    final facing = 0.55 + 0.45 * math.cos(a);
    return (0.35 + 0.65 * lit) * facing;
  }

  /// Краска-градиент «цилиндра» перпендикулярно оси: from → to по ширине.
  Paint _cylPaint(double from, double to) {
    Color c(double t) =>
        Color.lerp(_cShadow, _cLight, _shade(math.asin(t)))!;
    return Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, from),
        Offset(0, to),
        [c(-1.0), c(-0.5), c(0.0), c(0.5), c(1.0)],
        const [0.0, 0.25, 0.5, 0.75, 1.0],
      );
  }

  /// Капсула (объёмная «трубка») между двумя точками, с светотенью
  /// поперёк: светлый бок слева-сверху, тёмный — справа.
  void _capsule(Canvas canvas, Offset p0, Offset p1, double radius) {
    final dir = p1 - p0;
    final len = dir.distance;
    if (len < radius) {
      // Почти шар — рисуем круг с радиальной светотенью.
      canvas.drawCircle(
        p0,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(
            p0 - Offset(radius * 0.35, radius * 0.45),
            radius * 1.7,
            [_cLight, _cBase, _cShadow],
            const [0.0, 0.5, 1.0],
          ),
      );
      return;
    }
    canvas.save();
    canvas.translate(p0.dx, p0.dy);
    canvas.rotate(math.atan2(dir.dy, dir.dx));
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, -radius, len, radius * 2),
        Radius.circular(radius),
      ));
    canvas.drawPath(path, _cylPaint(-radius, radius));
    canvas.restore();
  }

  /// Голова — матовый шар без лица, как у магазинного манекена.
  void _head(Canvas canvas, double cx, double h, double k) {
    final r = 0.056 * h * k;
    final center = Offset(cx, 0.072 * h);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          center - Offset(r * 0.35, r * 0.45),
          r * 1.7,
          [_cLight, _cBase, _cShadow],
          const [0.0, 0.5, 1.0],
        ),
    );
  }

  /// Торс — гладкий контур по профилю, с цилиндрической светотенью.
  void _torsoPart(Canvas canvas, double cx, double h, double k) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    final path = Path();
    final pts = <Offset>[];
    for (var y = 0.170; y <= 0.5051; y += 0.010) {
      final (rx, rz) = _torsoAt(y);
      final halfW =
          math.sqrt((rx * c) * (rx * c) + (rz * s) * (rz * s)) * h * k;
      pts.add(Offset(cx + halfW, y * h));
    }
    for (var i = pts.length - 1; i >= 0; i--) {
      pts.add(Offset(2 * cx - pts[i].dx, pts[i].dy));
    }
    path.addPolygon(pts, true);
    // Ширина градиента — текущая ширина торса на экране.
    final half =
        math.sqrt((0.155 * c) * (0.155 * c) + (0.075 * s) * (0.075 * s)) *
            h *
            k;
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx - half, 0),
        Offset(cx + half, 0),
        [
          Color.lerp(_cShadow, _cLight, _shade(-1.0))!,
          Color.lerp(_cShadow, _cLight, _shade(-0.5))!,
          Color.lerp(_cShadow, _cLight, _shade(0.0))!,
          Color.lerp(_cShadow, _cLight, _shade(0.5))!,
          Color.lerp(_cShadow, _cLight, _shade(1.0))!,
        ],
        const [0.0, 0.25, 0.5, 0.75, 1.0],
      );
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    final cx = w / 2;

    final k = math.min(w / (h * 0.72), 1.0);
    final c = math.cos(angle);
    final s = math.sin(angle);

    // Экранные точки и глубина трёхмерной точки (x, y, z).
    Offset pt(double x, double y, double z) =>
        Offset(cx + (x * c + z * s) * h * k, y * h);
    double depthOf(double x, double z) => (z * c - x * s) * h * k;

    // Тень на полу, подставка-диск и штанга (как у магазинного манекена).
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, h * 0.982),
        width: w * 0.44,
        height: h * 0.030,
      ),
      Paint()..color = Colors.black.withValues(alpha: dark ? 0.35 : 0.13),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, h * 0.984),
        width: h * 0.26,
        height: h * 0.022,
      ),
      Paint()..color = _cStand,
    );
    canvas.drawRect(
      Rect.fromLTWH(cx - h * 0.006, h * 0.86, h * 0.012, h * 0.125),
      Paint()..color = _cStand,
    );

    // Части тела: сортируем по глубине и рисуем от дальних к ближним.
    final parts = <(double, void Function())>[
      (depthOf(0, 0) + 2, () => _torsoPart(canvas, cx, h, k)),
    ];
    for (final (p0, p1, r, _) in _capsules) {
      parts.add((
        depthOf(((p0.$1 + p1.$1) / 2), ((p0.$3 + p1.$3) / 2)),
        () => _capsule(
              canvas,
              pt(p0.$1, p0.$2, p0.$3),
              pt(p1.$1, p1.$2, p1.$3),
              r * h * k,
            ),
      ));
    }
    // Голова поверх шеи, шея поверх торса.
    parts.add((depthOf(0, 0) + 1, () {
      _capsule(
        canvas,
        pt(0, 0.122, 0),
        pt(0, 0.178, 0),
        0.030 * h * k,
      );
    }));
    parts.add((depthOf(0, 0) + 3, () => _head(canvas, cx, h, k)));
    parts.sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, draw) in parts) {
      draw();
    }

    // Контуры частей тела: каждый слот одежды обрезается по своей части,
    // чтобы, например, футболка не налезала на руку.
    final clips = <String, Path>{
      'torso': Path(),
      'legs': Path(),
      'feet': Path(),
      'all': Path(),
    };
    void addCapsuleTo(Path path, Offset a, Offset b, double radius) {
      final dir = b - a;
      final len = dir.distance;
      if (len < radius) {
        path.addOval(Rect.fromCircle(center: a, radius: radius));
        return;
      }
      // Капсула в контур: два круга на концах + прямоугольник между ними.
      final dirN = Offset(dir.dx / len, dir.dy / len);
      final n = Offset(-dirN.dy, dirN.dx) * radius;
      path.addPolygon([a + n, b + n, b - n, a - n], true);
      path.addOval(Rect.fromCircle(center: a, radius: radius));
      path.addOval(Rect.fromCircle(center: b, radius: radius));
    }

    // Торс: гладкий контур по профилю + плечи.
    final torsoPts = <Offset>[];
    for (var y = 0.170; y <= 0.5051; y += 0.010) {
      final (rx, rz) = _torsoAt(y);
      final halfW =
          math.sqrt((rx * c) * (rx * c) + (rz * s) * (rz * s)) * h * k;
      torsoPts.add(Offset(cx + halfW, y * h));
    }
    for (var i = torsoPts.length - 1; i >= 0; i--) {
      torsoPts.add(Offset(2 * cx - torsoPts[i].dx, torsoPts[i].dy));
    }
    for (final key in const ['torso', 'all']) {
      clips[key]!.addPolygon(torsoPts, true);
      clips[key]!.addOval(
        Rect.fromCenter(
          center: Offset(cx - 0.145 * c * h * k, 0.190 * h),
          width: 0.072 * h * k,
          height: 0.072 * h,
        ),
      );
      clips[key]!.addOval(
        Rect.fromCenter(
          center: Offset(cx + 0.145 * c * h * k, 0.190 * h),
          width: 0.072 * h * k,
          height: 0.072 * h,
        ),
      );
    }
    // Капсулы — по своим частям.
    for (final (p0, p1, r, part) in _capsules) {
      final a = pt(p0.$1, p0.$2, p0.$3);
      final b = pt(p1.$1, p1.$2, p1.$3);
      addCapsuleTo(clips['all']!, a, b, r * h * k);
      if (part == 'leg') addCapsuleTo(clips['legs']!, a, b, r * h * k);
      if (part == 'foot') addCapsuleTo(clips['feet']!, a, b, r * h * k);
    }

    // Одежда поверх фигуры: каждая вещь оборачивается вокруг тела.
    for (final p in pieces) {
      final image = p.image;
      if (image != null) {
        _drawPiece(canvas, p, image, clips, cx, c, s);
      }
    }
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
      // Тот же свет, что и на теле: тень красит только саму вещь
      // (srcATop не трогает прозрачные пиксели фото — без полос на теле).
      final darkAlpha = ((1 - _shade(a)) * 0.55).clamp(0.0, 0.42);
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