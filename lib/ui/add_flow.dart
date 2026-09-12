import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        item != null
            ? 'Вещь добавлена — фон вычищен автоматически ✨'
            : 'Не получилось обработать фото 😔',
      ),
    ),
  );
  return item != null;
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