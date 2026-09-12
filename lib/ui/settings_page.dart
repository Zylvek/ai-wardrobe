import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/settings_store.dart';
import 'update_dialog.dart';

/// Страница настроек. Сейчас: тема + обновления. Позже добавим город/погоду,
/// статистику, словарь и сброс истории.
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