import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/settings_store.dart';
import '../data/wardrobe_store.dart';
import 'update_dialog.dart';

/// Страница настроек: тема, обновления, обновление вырезки фона.
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