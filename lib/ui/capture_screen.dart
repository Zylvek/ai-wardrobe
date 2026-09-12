import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Экран съёмки внутри приложения: живой предпросмотр с камеры,
/// рамка-подсказка «клади вещь сюда», большая кнопка снимка.
/// Возвращает путь к снимку (или null, если закрыли).
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, this.hint});

  /// Подсказка, что снимать (например, «Поверни вещь боком влево»).
  final String? hint;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  CameraController? _controller;
  bool _starting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _error = 'Камера не найдена');
        return;
      }
      // Задняя камера — для съёмки вещей нужна именно она.
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _starting = false;
      });
    } on CameraException catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Нет доступа к камере.\nРазреши её в настройках телефона';
          _starting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Камера не запустилась';
          _starting = false;
        });
      }
    }
  }

  Future<void> _shoot() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.pausePreview();
      final file = await controller.takePicture();
      if (mounted) Navigator.pop(context, file.path);
    } on CameraException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не получилось снять — попробуй ещё раз')),
        );
        await controller.resumePreview();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _error != null
            ? _errorView(scheme)
            : _starting || _controller == null
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : _preview(scheme),
      ),
    );
  }

  /// Живой предпросмотр + рамка-подсказка + кнопки.
  Widget _preview(ColorScheme scheme) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_controller!),
        // Рамка-подсказка: куда класть вещь.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _GuidePainter(
                accent: scheme.primary,
                lineColor: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
        // Подсказка словами.
        if (widget.hint != null)
          Positioned(
            left: 24,
            right: 24,
            top: 12,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  widget.hint!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        // Нижняя панель: отмена и большая кнопка снимка.
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton.filledTonal(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 26),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(54, 54),
                ),
              ),
              GestureDetector(
                onTap: _shoot,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.25),
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Icon(
                    Icons.photo_camera,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(width: 54),
            ],
          ),
        ),
      ],
    );
  }

  /// Нет камеры или нет разрешения.
  Widget _errorView(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.no_photography, size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context),
            child: const Text('Назад'),
          ),
        ],
      ),
    );
  }
}

/// Пунктирная рамка с силуэтом вещи в центре кадра.
class _GuidePainter extends CustomPainter {
  _GuidePainter({required this.accent, required this.lineColor});

  final Color accent;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Затемняем всё, кроме центральной зоны съёмки.
    final zone = Rect.fromCenter(
      center: Offset(w / 2, h * 0.44),
      width: w * 0.72,
      height: h * 0.36,
    );
    final rrect = RRect.fromRectAndRadius(
      zone,
      Radius.circular(24),
    );
    final dark = Paint()..color = Colors.black.withValues(alpha: 0.35);
    canvas.drawRect(Rect.fromLTRB(0, 0, w, zone.top), dark);
    canvas.drawRect(Rect.fromLTRB(0, zone.bottom, w, h), dark);
    canvas.drawRect(Rect.fromLTRB(0, zone.top, zone.left, zone.bottom), dark);
    canvas.drawRect(
        Rect.fromLTRB(zone.right, zone.top, w, zone.bottom), dark);

    // Обводка зоны пунктиром.
    final dash = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    _drawDashedRRect(canvas, rrect, dash);

    // Подпись внутри зоны.
    final text = TextPainter(
      text: TextSpan(
        text: 'положи вещь здесь',
        style: TextStyle(color: lineColor, fontSize: 13),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset(w / 2 - text.width / 2, zone.bottom + 10));

    // Уголки-акценты зоны.
    final corner = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const len = 26.0;
    final corners = <(Offset, Offset, Offset)>[
      (Offset(zone.left, zone.top + len), Offset(zone.left, zone.top),
          Offset(zone.left + len, zone.top)),
      (Offset(zone.right - len, zone.top), Offset(zone.right, zone.top),
          Offset(zone.right, zone.top + len)),
      (Offset(zone.right, zone.bottom - len), Offset(zone.right, zone.bottom),
          Offset(zone.right - len, zone.bottom)),
      (Offset(zone.left + len, zone.bottom), Offset(zone.left, zone.bottom),
          Offset(zone.left, zone.bottom - len)),
    ];
    for (final (a, b, c) in corners) {
      final p = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy);
      canvas.drawPath(p, corner);
    }
  }

  void _drawDashedRRect(Canvas canvas, RRect rrect, Paint paint) {
    const step = 12.0;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        canvas.drawPath(
          metric.extractPath(dist, dist + step * 0.6),
          paint,
        );
        dist += step;
      }
    }
  }

  @override
  bool shouldRepaint(_GuidePainter oldDelegate) => false;
}