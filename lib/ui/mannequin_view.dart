import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/outfit_builder.dart';

/// Образ дня: вещи просто лежат стопкой картинками — обувь снизу,
/// над ней низ, потом верх и верхняя одежда. Никакого 3D.
class MannequinOutfit extends StatefulWidget {
  const MannequinOutfit({super.key, required this.outfit});

  final Outfit outfit;

  @override
  State<MannequinOutfit> createState() => _MannequinOutfitState();
}

class _MannequinOutfitState extends State<MannequinOutfit> {
  /// Расшифрованные фото вещей: путь → картинка (null = ещё грузится).
  final Map<String, ui.Image?> _images = {};
  final Set<String> _failed = {};

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

  /// Картинка вещи, вписанная в свою строку. Высота строки зависит от
  /// того, сколько вещей в образе: одна — крупно, четыре — компактно.
  Widget _layer(ClothingItem? item, double cell) {
    if (item == null) return const SizedBox.shrink();
    final image = _images[item.imagePath];
    if (image == null) {
      return SizedBox(
        height: cell,
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        height: cell - 8,
        child: Center(
          child: RawImage(image: image, fit: BoxFit.contain),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Сверху вниз: верхняя одежда, верх, низ, обувь — как разложено
    // на кровати перед сбором.
    final layers = [
      widget.outfit.outer,
      widget.outfit.top,
      widget.outfit.bottom,
      widget.outfit.shoes,
    ].whereType<ClothingItem>().toList();

    return LayoutBuilder(
      builder: (context, c) {
        // Если высота не ограничена — даём каждой вещи 260 px.
        final h = c.maxHeight.isFinite ? c.maxHeight : 260.0;
        final cell = layers.isEmpty ? h : h / layers.length;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in layers) _layer(item, cell),
            ],
          ),
        );
      },
    );
  }
}