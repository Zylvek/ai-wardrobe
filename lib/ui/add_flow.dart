import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models.dart';
import '../data/wardrobe_store.dart';
import 'theme/decor.dart';

/// «Умная камера»: на телефоне предлагает «Снять камерой» или
/// «Из галереи», на Windows открывает выбор файла.
/// Дальше само: копирует фото, вычищает фон, определяет цвет.
Future<bool> runAddFlow(BuildContext context) async {
  final isMobile = Platform.isAndroid || Platform.isIOS;
  String? picked;

  if (isMobile) {
    picked = await _pickMobile(context);
  } else {
    picked = await pickPhotoFromFiles();
  }
  if (picked == null) return false;

  final item = await WardrobeStore.addFromPickedPhoto(picked);
  if (!context.mounted) return item != null;

  if (item != null && isMobile) {
    // Проводим съёмку ракурсов (не обязательно — можно пропустить).
    await runAngleCapture(context, item);
    if (!context.mounted) return true;
    final angles = item.anglePaths.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          angles > 0
              ? 'Вещь добавлена: ракурсов для вращения — $angles ✨'
              : 'Вещь добавлена — фон вычищен автоматически ✨',
        ),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          item != null
              ? 'Вещь добавлена — фон вычищен автоматически ✨'
              : 'Не получилось обработать фото 😔',
        ),
      ),
    );
  }
  return item != null;
}

/// Съёмка вещи с нескольких сторон для «вращения» в карточке.
/// Первый ракурс (спереди) — уже снят. Возвращает, сколько ракурсов снято.
Future<int> runAngleCapture(BuildContext context, ClothingItem item) async {
  const steps = <(String, String)>[
    ('Слева', 'Поверни вещь на 90° — боком влево'),
    ('Сзади', 'Положи вещь задней стороной вверх'),
    ('Справа', 'Поверни вещь боком вправо'),
  ];
  await showModalBottomSheet<bool>(
    context: context,
    isDismissible: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) =>
        _AngleCaptureSheet(steps: steps, item: item),
  );
  return item.anglePaths.length;
}

class _AngleCaptureSheet extends StatefulWidget {
  const _AngleCaptureSheet({required this.steps, required this.item});

  final List<(String, String)> steps;
  final ClothingItem item;

  @override
  State<_AngleCaptureSheet> createState() => _AngleCaptureSheetState();
}

class _AngleCaptureSheetState extends State<_AngleCaptureSheet> {
  /// Сколько ракурсов уже снято (спереди = 0, дальше растёт).
  int _taken = 0;
  bool _busy = false;

  String get _title => _taken == 0
      ? 'Спереди — уже готово ✓'
      : widget.steps[_taken - 1].$1;
  String get _hint => _taken == 0
      ? 'Первое фото снято. Теперь снимем вещь с других сторон —\n'
          'это нужно, чтобы крутить её в карточке.'
      : widget.steps[_taken - 1].$2;

  Future<void> _shoot(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1600,
      );
      if (picked != null) {
        await WardrobeStore.addAnglePhoto(widget.item, picked.path);
        if (!mounted) return;
        if (_taken + 1 >= widget.steps.length) {
          // Сняли последний ракурс — закрываем шторку.
          Navigator.pop(context, true);
          return;
        }
        setState(() => _taken++);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Съёмка ракурсов',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Шаг ${_taken + 1} из ${widget.steps.length + 1}: $_title',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: heroGradient(Theme.of(context).brightness),
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.threed_rotation,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _hint,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : () => _shoot(ImageSource.camera),
              icon: const Icon(Icons.photo_camera),
              label: Text(_busy ? 'Обрабатываю…' : 'Снять ракурс камерой'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _shoot(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Выбрать из галереи'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Пропустить — хватит одного фото'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Диалог выбора источника фото на телефоне.
Future<String?> _pickMobile(BuildContext context) async {
  final scheme = Theme.of(context).colorScheme;
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Добавить вещь',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Лучше снимать одежду на однотонном фоне',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _sourceButton(
              sheetContext,
              icon: Icons.photo_camera,
              title: 'Снять камерой',
              subtitle: 'Откроется камера телефона',
              value: ImageSource.camera,
            ),
            const SizedBox(height: 10),
            _sourceButton(
              sheetContext,
              icon: Icons.photo_library,
              title: 'Из галереи',
              subtitle: 'Выбрать готовое фото',
              value: ImageSource.gallery,
            ),
          ],
        ),
      ),
    ),
  );
  if (source == null) return null;
  final picked = await ImagePicker().pickImage(
    source: source,
    imageQuality: 90,
    maxWidth: 1600,
  );
  return picked?.path;
}

Widget _sourceButton(
  BuildContext sheetContext, {
  required IconData icon,
  required String title,
  required String subtitle,
  required ImageSource value,
}) {
  final scheme = Theme.of(sheetContext).colorScheme;
  return DecoratedBox(
    decoration: BoxDecoration(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pop(sheetContext, value),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: heroGradient(Theme.of(sheetContext).brightness),
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    ),
  );
}