import 'dart:io';

import 'package:flutter/material.dart';

import '../data/updater_service.dart';
import 'theme/decor.dart';

/// Проверяет обновления и показывает диалог, если есть новая версия.
/// Возвращает true, если диалог был показан.
Future<bool> maybeShowUpdateDialog(BuildContext context) async {
  final update = await UpdaterService.checkLatest();
  if (update == null) return false;
  if (!context.mounted) return false;
  await showUpdateDialog(context, update);
  return true;
}

/// Окно обновления: предложение → скачивание с прогрессом → установщик.
Future<void> showUpdateDialog(
  BuildContext context,
  AppUpdate update,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateDialog(update: update),
  );
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.update});

  final AppUpdate update;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

enum _Stage { offer, downloading, done, error }

class _UpdateDialogState extends State<_UpdateDialog> {
  _Stage _stage = _Stage.offer;
  double _progress = 0;
  File? _apk;

  Future<void> _downloadAndInstall() async {
    setState(() => _stage = _Stage.downloading);
    try {
      final file = await UpdaterService.downloadApk(
        widget.update,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      _apk = file;
      if (mounted) setState(() => _stage = _Stage.done);
      await UpdaterService.installApk(file.path);
    } catch (_) {
      if (mounted) setState(() => _stage = _Stage.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sizeMb = (widget.update.sizeBytes / 1024 / 1024).toStringAsFixed(1);

    return AlertDialog(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: heroGradient(Theme.of(context).brightness),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.system_update_alt, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Доступно обновление')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Wardrobe ${widget.update.version}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (widget.update.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.update.notes.trim(),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          switch (_stage) {
            _Stage.downloading => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: _progress),
                  const SizedBox(height: 6),
                  Text(
                    'Скачиваем… ${(_progress * 100).round()}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            _Stage.done => Text(
                'Скачано. Подтверди установку в открывшемся окне — '
                'приложение само предложит обновиться.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            _Stage.error => Text(
                'Не удалось скачать. Проверь интернет и попробуй ещё раз.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
              ),
            _Stage.offer => Text(
                'Размер: $sizeMb МБ. Скачаем и предложим установить.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          },
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Позже'),
        ),
        if (_stage != _Stage.downloading)
          FilledButton(
            onPressed: _stage == _Stage.offer || _stage == _Stage.error
                ? _downloadAndInstall
                : () {
                    Navigator.of(context).pop();
                    if (_apk != null) {
                      UpdaterService.installApk(_apk!.path);
                    }
                  },
            child: Text(
              _stage == _Stage.done ? 'Открыть установщик' : 'Обновить',
            ),
          ),
      ],
    );
  }
}