import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/outfit_builder.dart';

/// 3D-манекен на главном экране.
///
/// Тело — настоящая объёмная фигура: собирается из «сфер» в трёхмерном
/// пространстве и поворачивается вокруг вертикальной оси. Крути пальцем
/// влево/вправо — фигура повернётся, бока сожмутся, как у настоящего
/// предмета.
///
/// Вещи из образа — фото-карточки, надетые на фигуру. При повороте они
/// сжимаются по ширине и зеркалятся, когда смотришь на спину; оказавшись
/// «за телом», рисуются позади него.
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

  // Зоны «надевания» (доли ширины/высоты манекена).
  static const Rect _torsoZone =
      Rect.fromLTRB(0.29, 0.17, 0.71, 0.50); // верх
  static const Rect _outerZone =
      Rect.fromLTRB(0.23, 0.16, 0.77, 0.54); // верхняя одежда
  static const Rect _bottomZone =
      Rect.fromLTRB(0.30, 0.47, 0.70, 0.87); // низ
  static const Rect _shoesZone =
      Rect.fromLTRB(0.26, 0.84, 0.74, 0.97); // обувь

  void _drag(DragUpdateDetails d) {
    setState(() {
      _angle += d.delta.dx * 0.012;
      if (_angle.abs() > 1000) _angle %= 2 * math.pi;
      _touched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        // Фигура всегда портретная: на широком экране не даём ей
        // растянуться на всю ширину, а держим нормальные пропорции
        // и ставим по центру.
        final w = math.min(constraints.maxWidth, h * 0.72);
        final sidePad = (constraints.maxWidth - w) / 2;

        final cos = math.cos(_angle);

        Rect absZone(Rect r) => Rect.fromLTRB(
              sidePad + r.left * w,
              r.top * h,
              sidePad + r.right * w,
              r.bottom * h,
            );

        Widget piece(Rect rect, String path) {
          // Карточка-вещь крутится в настоящем 3D: перспектива + поворот
          // вокруг вертикальной оси. На боку карточка сжимается в линию,
          // с тыла видно её зеркальную сторону. Чуть гаснет у ребра.
          final t = cos.abs().clamp(0.0, 1.0);
          return Positioned.fromRect(
            rect: rect,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.35 + 0.65 * t,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012) // перспектива
                    ..rotateY(-_angle),
                  child: Image.file(
                    File(path),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          );
        }

        // Порядок слоёв снизу вверх: обувь → низ → верх → верхняя одежда.
        final layers = <Widget>[
          if (widget.outfit.shoes != null)
            piece(absZone(_shoesZone), widget.outfit.shoes!.imagePath),
          if (widget.outfit.bottom != null)
            piece(absZone(_bottomZone), widget.outfit.bottom!.imagePath),
          if (widget.outfit.top != null)
            piece(absZone(_torsoZone), widget.outfit.top!.imagePath),
          if (widget.outfit.outer != null)
            piece(absZone(_outerZone), widget.outfit.outer!.imagePath),
        ];

        final painter = CustomPaint(
          size: Size(w, h),
          painter: _Mannequin3DPainter(
            angle: _angle,
            body: scheme.primaryContainer,
            hi: Color.lerp(scheme.primaryContainer, Colors.white, 0.35)!,
            edge: scheme.brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.20),
          ),
        );

        // Когда смотришь на спину — вещи «за телом»: рисуем их позади.
        final stackChildren = cos >= 0
            ? <Widget>[Positioned.fill(child: painter), ...layers]
            : <Widget>[...layers, Positioned.fill(child: painter)];

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: _drag,
          child: Stack(
            children: [
              ...stackChildren,
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
                        color: scheme.onSurfaceVariant
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

/// Одна «сфера» объёмного тела.
///
/// Позиция и радиусы заданы долями высоты фигуры; эллиптические кольца
/// (торс, ступни) имеют два радиуса — по ширине и в глубину, поэтому
/// при повороте их ширина на экране честно меняется.
class _Blob {
  const _Blob(
    this.x,
    this.y,
    this.z, {
    required this.hh,
    this.r,
    this.rx,
    this.rz,
  });

  /// x/z — по ширине, y — вниз. Всё в долях высоты фигуры.
  final double x, y, z;

  /// Радиус круглой сферы (конечности, голова).
  final double? r;

  /// Полуоси эллиптического кольца: по ширине и в глубину.
  final double? rx, rz;

  /// Полувысота «шара» по вертикали (для сплюснутых колец).
  final double hh;

  bool get isRing => r == null;
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

/// Собирает тело манекена из «сфер». Сферы налезают друг на друга,
/// поэтому силуэт выходит гладким, без «бусин».
List<_Blob> _buildBody() {
  final blobs = <_Blob>[];

  // Голова и шея.
  blobs.add(const _Blob(0, 0.072, 0, r: 0.056, hh: 0.056));
  for (var i = 0; i < 3; i++) {
    blobs.add(_Blob(0, 0.128 + i * 0.021, 0, r: 0.030, hh: 0.030));
  }

  // Торс рисуется в художнике одним гладким контуром (см. _torsoAt).

  // Конечности: цепочки плотных сфер = гладкая «трубка».
  void limb({
    required double x0,
    required double y0,
    required double z0,
    required double x1,
    required double y1,
    required double z1,
    required double radius,
  }) {
    final len = math.sqrt((x1 - x0) * (x1 - x0) +
        (y1 - y0) * (y1 - y0) + (z1 - z0) * (z1 - z0));
    final n = (len / 0.018).ceil();
    for (var i = 0; i <= n; i++) {
      final t = i / n;
      blobs.add(_Blob(
        x0 + (x1 - x0) * t,
        y0 + (y1 - y0) * t,
        z0 + (z1 - z0) * t,
        r: radius,
        hh: radius,
      ));
    }
  }

  for (final side in const [-1.0, 1.0]) {
    // Руки: от плеч чуть в стороны и вниз, ладонь на конце.
    limb(
      x0: side * 0.150, y0: 0.195, z0: -0.015,
      x1: side * 0.255, y1: 0.470, z1: -0.045,
      radius: 0.028,
    );
    blobs.add(_Blob(side * 0.262, 0.495, -0.050, r: 0.022, hh: 0.022));

    // Ноги: от бёдер вниз.
    limb(
      x0: side * 0.075, y0: 0.505, z0: 0,
      x1: side * 0.088, y1: 0.880, z1: 0,
      radius: 0.036,
    );
    // Ступня и носок.
    blobs.add(_Blob(side * 0.088, 0.898, 0.010,
        rx: 0.055, rz: 0.026, hh: 0.022));
    blobs.add(_Blob(side * 0.090, 0.902, 0.045,
        rx: 0.040, rz: 0.020, hh: 0.016));
  }

  return blobs;
}

/// Рисует объёмный манекен: поворачивает все «сферы» вокруг вертикальной
/// оси, собирает их в один силуэт и красит единой светотенью — выходит
/// «глиняная» фигура.
class _Mannequin3DPainter extends CustomPainter {
  _Mannequin3DPainter({
    required this.angle,
    required this.body,
    required this.hi,
    required this.edge,
  });

  final double angle;
  final Color body;
  final Color hi;
  final Color edge;

  static final List<_Blob> _blobs = _buildBody();

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    final cx = w / 2;

    // Мягкая тень-«пол» под ногами.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, h * 0.955),
        width: w * 0.34,
        height: h * 0.035,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.15),
    );

    // Если окно уже «портретной» ширины — слегка сжимаем фигуру по бокам.
    final k = math.min(w / (h * 0.72), 1.0);
    final c = math.cos(angle);
    final s = math.sin(angle);

    // Силуэт: все сферы одним контуром.
    final path = Path();

    // Торс — одним гладким контуром: правый край вниз, левый вверх.
    // Ширина на экране считается с поворотом, как у настоящего тела.
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

    // Плечи — скругление в углах, вращается вместе с телом.
    path.addOval(
      Rect.fromCenter(
        center: Offset(cx - 0.145 * c * h * k, 0.190 * h),
        width: 0.072 * h * k,
        height: 0.072 * h,
      ),
    );
    path.addOval(
      Rect.fromCenter(
        center: Offset(cx + 0.145 * c * h * k, 0.190 * h),
        width: 0.072 * h * k,
        height: 0.072 * h,
      ),
    );

    for (final b in _blobs) {
      final px = (b.x * c + b.z * s) * h * k;
      final double halfW;
      if (b.isRing) {
        halfW =
            math.sqrt((b.rx! * c) * (b.rx! * c) + (b.rz! * s) * (b.rz! * s)) *
                h *
                k;
      } else {
        halfW = b.r! * h * k;
      }
      path.addOval(
        Rect.fromCenter(
          center: Offset(cx + px, b.y * h),
          width: halfW * 2,
          height: b.hh * h * 2,
        ),
      );
    }

    // Ровный цвет + светотень слева-сверху + тонкая кромка.
    canvas.drawPath(path, Paint()..color = body);
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - w * 0.28, 0),
          Offset(cx + w * 0.38, h),
          [hi, body, body],
        ),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_Mannequin3DPainter oldDelegate) =>
      oldDelegate.angle != angle;
}