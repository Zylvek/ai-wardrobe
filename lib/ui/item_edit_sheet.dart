import 'dart:io';

import 'package:flutter/material.dart';

import '../data/color_detector.dart';
import '../data/constants.dart';
import '../data/image_cleaner.dart';
import '../data/models.dart';
import '../data/wardrobe_store.dart';

/// Шторка редактирования вещи: характеристики + «улучшить фото» +
/// сохранение/удаление.
class ItemEditSheet extends StatefulWidget {
  const ItemEditSheet({super.key, required this.item});

  final ClothingItem item;

  @override
  State<ItemEditSheet> createState() => _ItemEditSheetState();
}

class _ItemEditSheetState extends State<ItemEditSheet> {
  late String? _type = widget.item.type;
  late String? _color = widget.item.color;
  late String? _weather = widget.item.weather;
  late String _imagePath = widget.item.imagePath;
  final PageController _angleController = PageController();
  int _angleIndex = 0;

  double _sensitivity = 0.45;
  bool _cleaning = false;

  @override
  void dispose() {
    _angleController.dispose();
    super.dispose();
  }

  /// Повторная очистка фона по оригиналу фото.
  Future<void> _reclean() async {
    final src = widget.item.originalPath;
    if (src == null || _cleaning) return;
    setState(() => _cleaning = true);

    final dir = File(_imagePath).parent.path;
    final out = '$dir${Platform.pathSeparator}'
        'item_${widget.item.id}_${DateTime.now().millisecondsSinceEpoch}.png';

    final cleaned = await cleanClothingPhoto(
      src,
      sensitivity: _sensitivity,
      outPath: out,
    );
    if (cleaned != null) {
      widget.item.imagePath = cleaned;
      _imagePath = cleaned;
      // Фон вырезан текущим фильтром — вещь «актуальна».
      widget.item.filterVersion = kFilterVersion;
      await WardrobeStore.save();
      wardrobeVersion.value++;
    }
    if (mounted) {
      setState(() => _cleaning = false);
      if (cleaned == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не получилось — попробуй другой ползунок')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ракурсы вещи: спереди, слева, сзади, справа — листаются
            // пальцем, как «вращение». Точки внизу показывают, какой кадр.
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 240,
                child: Stack(
                  children: [
                    PageView(
                      controller: _angleController,
                      onPageChanged: (i) =>
                          setState(() => _angleIndex = i),
                      children: [
                        for (final path in widget.item.allAngles)
                          Image.file(
                            File(path),
                            // contain, а не cover: вещь целиком видна,
                            // фон прозрачный — обрезать нечего.
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                const SizedBox.expand(),
                          ),
                      ],
                    ),
                    if (widget.item.allAngles.length > 1)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 6,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0;
                                i < widget.item.allAngles.length;
                                i++)
                              Container(
                                width: 6,
                                height: 6,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i == _angleIndex
                                      ? scheme.primary
                                      : scheme.outlineVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (widget.item.originalPath != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Улучшить фото',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.auto_fix_high, size: 18),
                        Expanded(
                          child: Slider(
                            value: _sensitivity,
                            label: '${(_sensitivity * 100).round()}%',
                            divisions: 10,
                            onChanged: (v) =>
                                setState(() => _sensitivity = v),
                          ),
                        ),
                        Text(
                          _sensitivity <= 0.3
                              ? 'мягко'
                              : _sensitivity >= 0.7
                                  ? 'сильно'
                                  : 'средне',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _cleaning ? null : _reclean,
                        icon: _cleaning
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cleaning_services, size: 18),
                        label: Text(_cleaning
                            ? 'Обрабатываю...'
                            : 'Вычистить фон заново'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            _picker('Тип', kTypes, _type, (v) => setState(() => _type = v)),
            _picker(
              'Цвет',
              kNamedColors.keys.toList(),
              _color,
              (v) => setState(() => _color = v),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final c = await detectColorName(widget.item.originalPath ??
                      widget.item.imagePath);
                  if (c != null && mounted) setState(() => _color = c);
                },
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Определить цвет по фото'),
              ),
            ),
            _picker(
              'Погода',
              kWeathers,
              _weather,
              (v) => setState(() => _weather = v),
            ),
            const SizedBox(height: 12),
            // Версия приложения, в которой вещь добавлена, и версия
            // фильтра, которым вырезан фон. Нужно, чтобы после улучшения
            // фильтра можно было перекроить старые вещи заново.
            Text(
              'Добавлена: ${widget.item.appVersion ?? 'старая версия'}'
              ' · фильтр: ${widget.item.filterVersion ?? 'старая версия'}'
              ' (текущий $kFilterVersion)',
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      widget.item
                        ..type = _type
                        ..color = _color
                        ..weather = _weather;
                      Navigator.pop(context, 'save');
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Сохранить'),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.pop(context, 'delete'),
                  style: FilledButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Удалить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _picker(
    String title,
    List<String> options,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: value,
          hint: const Text('Не выбрано'),
          isExpanded: true,
          items: options
              .map((o) => DropdownMenuItem<String>(value: o, child: Text(o)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}