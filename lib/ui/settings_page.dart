import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/backup_store.dart';
import '../data/settings_store.dart';
import '../data/wardrobe_store.dart';
import '../data/wear_store.dart';
import 'update_dialog.dart';

/// Страница настроек: тема, обновления, статистика, бэкап,
/// обновление вырезки фона.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Настройки', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _ThemeCard(),
          const SizedBox(height: 16),
          _StatsCard(),
          const SizedBox(height: 16),
          _BackupCard(),
          const SizedBox(height: 16),
          _UpdatesCard(),
          const SizedBox(height: 16),
          _ReprocessCard(),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Тема', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Как оформлять приложение',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeModeNotifier,
              builder: (context, mode, _) {
                return SegmentedButton<ThemeMode>(
                  selected: {mode},
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('Система'),
                      icon: Icon(Icons.brightness_auto_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Светлая'),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Тёмная'),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  onSelectionChanged: (selection) {
                    SettingsStore.setThemeMode(selection.first);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Статистика гардероба: сколько вещей, что носится чаще всего,
/// что лежит без дела.
class _StatsCard extends StatefulWidget {
  @override
  State<_StatsCard> createState() => _StatsCardState();
}

class _StatsCardState extends State<_StatsCard> {
  @override
  void initState() {
    super.initState();
    wardrobeVersion.addListener(_refresh);
    wearVersion.addListener(_refresh);
  }

  @override
  void dispose() {
    wardrobeVersion.removeListener(_refresh);
    wearVersion.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final worn = WearStore.itemsByWearCount();
    final never = WearStore.neverWorn();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Статистика', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Вещей: ${WardrobeStore.items.length} · '
              'образов надето: ${WearStore.events.length}',
              style: TextStyle(color: muted),
            ),
            if (worn.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Носишь чаще всего', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: muted)),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final (item, count) in worn.take(4))
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Column(
                        children: [
                          SizedBox(
                            width: 58,
                            height: 58,
                            child: Image.file(
                              File(item.imagePath),
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.expand(),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text('$count раз', style: TextStyle(
                              fontSize: 10, color: muted)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            if (never.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Лежат без дела', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: muted)),
              const SizedBox(height: 6),
              SizedBox(
                height: 58,
                child: Row(
                  children: [
                    for (final item in never.take(6))
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: SizedBox(
                          width: 58,
                          height: 58,
                          child: Image.file(
                            File(item.imagePath),
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const SizedBox.expand(),
                          ),
                        ),
                      ),
                    if (never.length > 6)
                      Text(
                        '+${never.length - 6}',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Экспорт/восстановление гардероба: один zip со всеми фото и данными.
class _BackupCard extends StatefulWidget {
  @override
  State<_BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends State<_BackupCard> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final path = await BackupStore.exportBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(path == null
              ? 'Бэкап не сохранён'
              : 'Бэкап сохранён: '
                  '${path.split(Platform.pathSeparator).last} ✅'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Восстановить из бэкапа?'),
        content: const Text(
          'Текущий гардероб будет заменён содержимым файла бэкапа.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Восстановить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await BackupStore.importBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result == null
              ? 'Отменено'
              : 'Восстановлено — $result ✅'),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не получилось прочитать файл бэкапа'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Бэкап', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Все вещи и фото в один файл: перенеси на другой '
              'компьютер или телефон либо храни на всякий случай.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _busy ? null : _export,
                    icon: const Icon(Icons.save_alt, size: 18),
                    label: const Text('Создать'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _busy ? null : _import,
                    icon: const Icon(Icons.restore, size: 18),
                    label: const Text('Восстановить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdatesCard extends StatefulWidget {
  @override
  State<_UpdatesCard> createState() => _UpdatesCardState();
}

class _UpdatesCardState extends State<_UpdatesCard> {
  String _version = '…';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) {
            setState(() => _version =
                '${info.version} (${info.buildNumber})');
          }
        })
        .catchError((_) {});
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final shown = await maybeShowUpdateDialog(context);
    if (!shown && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('У тебя уже последняя версия ✨')),
      );
    }
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Обновления', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Версия $_version · приложение проверяет обновления само',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _checking ? null : _check,
              icon: _checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              label: const Text('Проверить обновления'),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Обновить фильтр»: перекраивает все вещи из сохранённых оригиналов
/// фото текущим алгоритмом вырезания фона. Когда в новой версии
/// приложения вырезка станет лучше — достаточно нажать одну кнопку.
class _ReprocessCard extends StatefulWidget {
  @override
  State<_ReprocessCard> createState() => _ReprocessCardState();
}

class _ReprocessCardState extends State<_ReprocessCard> {
  int _outdated = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshCount();
    wardrobeVersion.addListener(_refreshCount);
  }

  @override
  void dispose() {
    wardrobeVersion.removeListener(_refreshCount);
    super.dispose();
  }

  void _refreshCount() {
    setState(() => _outdated = WardrobeStore.outdatedCount());
  }

  Future<void> _reprocess() async {
    setState(() => _busy = true);
    final updated = await WardrobeStore.reprocessAll();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated == 0
              ? 'Все вещи уже перекроены текущей версией'
              : 'Обновлено вещей: $updated ✨',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasWork = _outdated > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Вырезание фона', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Оригиналы фото сохраняются, поэтому если фильтр вырезания '
              'фона станет лучше — нажми одну кнопку, и все вещи '
              'перекроятся заново из оригиналов.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _reprocess,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_fix_high),
              label: Text(
                _busy
                    ? 'Перекраиваю...'
                    : hasWork
                        ? 'Обновить фильтр ($_outdated)'
                        : 'Обновить фильтр',
              ),
            ),
          ],
        ),
      ),
    );
  }
}